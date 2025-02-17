//  Copyright (c) 2011-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under both the GPLv2 (found in the
//  COPYING file in the root directory) and Apache 2.0 License
//  (found in the LICENSE.Apache file in the root directory).

#ifndef ROCKSDB_LITE

#include "file/delete_scheduler.h"

#include <cinttypes>
#include <thread>
#include <vector>

#include "file/sst_file_manager_impl.h"
#include "logging/logging.h"
#include "port/port.h"
#include "rocksdb/env.h"
#include "rocksdb/file_system.h"
#include "rocksdb/system_clock.h"
#include "test_util/sync_point.h"
#include "util/mutexlock.h"

namespace ROCKSDB_NAMESPACE {

DeleteScheduler::DeleteScheduler(SystemClock* clock, FileSystem* fs,
                                 int64_t rate_bytes_per_sec, Logger* info_log,
                                 SstFileManagerImpl* sst_file_manager,
                                 double max_trash_db_ratio,
                                 uint64_t bytes_max_delete_chunk)
    : clock_(clock),
      fs_(fs),
      total_trash_size_(0),
      rate_bytes_per_sec_(rate_bytes_per_sec),
      pending_files_(0),
      bytes_max_delete_chunk_(bytes_max_delete_chunk),
      closing_(false),
      cv_(&mu_),
      bg_thread_(nullptr),
      info_log_(info_log),
      sst_file_manager_(sst_file_manager),
      max_trash_db_ratio_(max_trash_db_ratio) {
  assert(sst_file_manager != nullptr);
  assert(max_trash_db_ratio >= 0);
  MaybeCreateBackgroundThread();
}

DeleteScheduler::~DeleteScheduler() {
  {
    InstrumentedMutexLock l(&mu_);
    closing_ = true;
    cv_.SignalAll();
  }
  if (bg_thread_) {
    bg_thread_->join();
  }
  for (const auto& it : bg_errors_) {
    it.second.PermitUncheckedError();
  }
}

Status DeleteScheduler::DeleteFile(const std::string& file_path,
                                   const std::string& dir_to_sync,
                                   const bool force_bg) {
  if (rate_bytes_per_sec_.load() <= 0 || (!force_bg &&
      total_trash_size_.load() >
          sst_file_manager_->GetTotalSize() * max_trash_db_ratio_.load())) {
    // Rate limiting is disabled or trash size makes up more than
    // max_trash_db_ratio_ (default 25%) of the total DB size
    
    TEST_SYNC_POINT("DeleteScheduler::DeleteFile");
    Status s = fs_->DeleteFile(file_path, IOOptions(), nullptr);

    std::string bad_file;
    int level = countlevel[TableFileNameToNumber(file_path.c_str())] - 1;
    printf("mymsg %s DELETE level:%d\n", file_path.c_str(), level);
    if (s.IsPathNotFound()) {
      printf("can't delete!!\n");
      bad_file = Rocks2LevelTableFileName(file_path);
      s = fs_->DeleteFile(bad_file, IOOptions(), nullptr);
      printf("mymsg %s DELETE again\n", bad_file.c_str());
    }
    
    if (s.ok()) {
      s = sst_file_manager_->OnDeleteFile(file_path);
      ROCKS_LOG_INFO(info_log_,
                     "Deleted file %s immediately, rate_bytes_per_sec %" PRIi64
                     ", total_trash_size %" PRIu64 " max_trash_db_ratio %lf",
                     file_path.c_str(), rate_bytes_per_sec_.load(),
                     total_trash_size_.load(), max_trash_db_ratio_.load());
      InstrumentedMutexLock l(&mu_);
      RecordTick(stats_.get(), FILES_DELETED_IMMEDIATELY);
    }
    return s;
  }

  // Move file to trash
  std::string trash_file;
  Status s = MarkAsTrash(file_path, &trash_file);
  ROCKS_LOG_INFO(info_log_, "Mark file: %s as trash -- %s", trash_file.c_str(),
                 s.ToString().c_str());

  if (!s.ok()) {
    ROCKS_LOG_ERROR(info_log_, "Failed to mark %s as trash -- %s",
                    file_path.c_str(), s.ToString().c_str());
                        //printf("i am deleted from delete_scheduler.cc 2\n");
    s = fs_->DeleteFile(file_path, IOOptions(), nullptr);
    if (s.ok()) {
      s = sst_file_manager_->OnDeleteFile(file_path);
      ROCKS_LOG_INFO(info_log_, "Deleted file %s immediately",
                     trash_file.c_str());
      InstrumentedMutexLock l(&mu_);
      RecordTick(stats_.get(), FILES_DELETED_IMMEDIATELY);
    }
    return s;
  }

  // Update the total trash size
  uint64_t trash_file_size = 0;
  IOStatus io_s =
      fs_->GetFileSize(trash_file, IOOptions(), &trash_file_size, nullptr);
  if (io_s.ok()) {
    total_trash_size_.fetch_add(trash_file_size);
  }
  //**TODO: What should we do if we failed to
  // get the file size?

  // Add file to delete queue
  {
    InstrumentedMutexLock l(&mu_);
    RecordTick(stats_.get(), FILES_MARKED_TRASH);
    queue_.emplace(trash_file, dir_to_sync);
    pending_files_++;
    if (pending_files_ == 1) {
      cv_.SignalAll();
    }
  }
  return s;
}

std::map<std::string, Status> DeleteScheduler::GetBackgroundErrors() {
  InstrumentedMutexLock l(&mu_);
  return bg_errors_;
}

const std::string DeleteScheduler::kTrashExtension = ".trash";
bool DeleteScheduler::IsTrashFile(const std::string& file_path) {
  return (file_path.size() >= kTrashExtension.size() &&
          file_path.rfind(kTrashExtension) ==
              file_path.size() - kTrashExtension.size());
}

Status DeleteScheduler::CleanupDirectory(Env* env, SstFileManagerImpl* sfm,
                                         const std::string& path) {
  Status s;
  // Check if there are any files marked as trash in this path
  std::vector<std::string> files_in_path;
  s = env->GetChildren(path, &files_in_path);
  if (!s.ok()) {
    return s;
  }
  for (const std::string& current_file : files_in_path) {
    if (!DeleteScheduler::IsTrashFile(current_file)) {
      // not a trash file, skip
      continue;
    }

    Status file_delete;
    std::string trash_file = path + "/" + current_file;
    if (sfm) {
      // We have an SstFileManager that will schedule the file delete
      s = sfm->OnAddFile(trash_file);
      file_delete = sfm->ScheduleFileDeletion(trash_file, path);
    } else {
      // Delete the file immediately
          //printf("i am deleted from delete_scheduler.cc 3\n");
      file_delete = env->DeleteFile(trash_file);
    }

    if (s.ok() && !file_delete.ok()) {
      s = file_delete;
    }
  }

  return s;
}

Status DeleteScheduler::MarkAsTrash(const std::string& file_path,
                                    std::string* trash_file) {
  // Sanity check of the path
  size_t idx = file_path.rfind("/");
  if (idx == std::string::npos || idx == file_path.size() - 1) {
    return Status::InvalidArgument("file_path is corrupted");
  }

  if (DeleteScheduler::IsTrashFile(file_path)) {
    // This is already a trash file
    *trash_file = file_path;
    return Status::OK();
  }

  *trash_file = file_path + kTrashExtension;
  // TODO(tec) : Implement Env::RenameFileIfNotExist and remove
  //             file_move_mu mutex.
  int cnt = 0;
  Status s;
  InstrumentedMutexLock l(&file_move_mu_);
  while (true) {
    s = fs_->FileExists(*trash_file, IOOptions(), nullptr);
    if (s.IsNotFound()) {
      // We found a path for our file in trash
      s = fs_->RenameFile(file_path, *trash_file, IOOptions(), nullptr);
      break;
    } else if (s.ok()) {
      // Name conflict, generate new random suffix
      *trash_file = file_path + std::to_string(cnt) + kTrashExtension;
    } else {
      // Error during FileExists call, we cannot continue
      break;
    }
    cnt++;
  }
  if (s.ok()) {
    s = sst_file_manager_->OnMoveFile(file_path, *trash_file);
  }
  return s;
}

void DeleteScheduler::BackgroundEmptyTrash() {
  TEST_SYNC_POINT("DeleteScheduler::BackgroundEmptyTrash");

  while (true) {
    InstrumentedMutexLock l(&mu_);
    while (queue_.empty() && !closing_) {
      cv_.Wait();
    }

    if (closing_) {
      return;
    }

    // Delete all files in queue_
    uint64_t start_time = clock_->NowMicros();
    uint64_t total_deleted_bytes = 0;
    int64_t current_delete_rate = rate_bytes_per_sec_.load();
    while (!queue_.empty() && !closing_) {
      if (current_delete_rate != rate_bytes_per_sec_.load()) {
        // User changed the delete rate
        current_delete_rate = rate_bytes_per_sec_.load();
        start_time = clock_->NowMicros();
        total_deleted_bytes = 0;
        ROCKS_LOG_INFO(info_log_, "rate_bytes_per_sec is changed to %" PRIi64,
                       current_delete_rate);
      }

      // Get new file to delete
      const FileAndDir& fad = queue_.front();
      std::string path_in_trash = fad.fname;

      // We don't need to hold the lock while deleting the file
      mu_.Unlock();
      uint64_t deleted_bytes = 0;
      bool is_complete = true;
      // Delete file from trash and update total_penlty value
      Status s =
          DeleteTrashFile(path_in_trash, fad.dir, &deleted_bytes, &is_complete);
      total_deleted_bytes += deleted_bytes;
      mu_.Lock();
      if (is_complete) {
        queue_.pop();
      }

      if (!s.ok()) {
        bg_errors_[path_in_trash] = s;
      }

      // Apply penalty if necessary
      uint64_t total_penalty;
      if (current_delete_rate > 0) {
        // rate limiting is enabled
        total_penalty =
            ((total_deleted_bytes * kMicrosInSecond) / current_delete_rate);
        ROCKS_LOG_INFO(info_log_,
                       "Rate limiting is enabled with penalty %" PRIu64
                       " after deleting file %s",
                       total_penalty, path_in_trash.c_str());
        while (!closing_ && !cv_.TimedWait(start_time + total_penalty)) {
        }
      } else {
        // rate limiting is disabled
        total_penalty = 0;
        ROCKS_LOG_INFO(info_log_,
                       "Rate limiting is disabled after deleting file %s",
                       path_in_trash.c_str());
      }
      TEST_SYNC_POINT_CALLBACK("DeleteScheduler::BackgroundEmptyTrash:Wait",
                               &total_penalty);

      if (is_complete) {
        pending_files_--;
      }
      if (pending_files_ == 0) {
        // Unblock WaitForEmptyTrash since there are no more files waiting
        // to be deleted
        cv_.SignalAll();
      }
    }
  }
}

Status DeleteScheduler::DeleteTrashFile(const std::string& path_in_trash,
                                        const std::string& dir_to_sync,
                                        uint64_t* deleted_bytes,
                                        bool* is_complete) {
  uint64_t file_size;
  Status s = fs_->GetFileSize(path_in_trash, IOOptions(), &file_size, nullptr);
  *is_complete = true;
  TEST_SYNC_POINT("DeleteScheduler::DeleteTrashFile:DeleteFile");
  if (s.ok()) {
    bool need_full_delete = true;
    if (bytes_max_delete_chunk_ != 0 && file_size > bytes_max_delete_chunk_) {
      uint64_t num_hard_links = 2;
      // We don't have to worry aobut data race between linking a new
      // file after the number of file link check and ftruncte because
      // the file is now in trash and no hardlink is supposed to create
      // to trash files by RocksDB.
      Status my_status = fs_->NumFileLinks(path_in_trash, IOOptions(),
                                           &num_hard_links, nullptr);
      if (my_status.ok()) {
        if (num_hard_links == 1) {
          std::unique_ptr<FSWritableFile> wf;
          my_status = fs_->ReopenWritableFile(path_in_trash, FileOptions(),
                                              &wf, nullptr);
          if (my_status.ok()) {
            my_status = wf->Truncate(file_size - bytes_max_delete_chunk_,
                                     IOOptions(), nullptr);
            if (my_status.ok()) {
              TEST_SYNC_POINT("DeleteScheduler::DeleteTrashFile:Fsync");
              my_status = wf->Fsync(IOOptions(), nullptr);
            }
          }
          if (my_status.ok()) {
            *deleted_bytes = bytes_max_delete_chunk_;
            need_full_delete = false;
            *is_complete = false;
          } else {
            ROCKS_LOG_WARN(info_log_,
                           "Failed to partially delete %s from trash -- %s",
                           path_in_trash.c_str(), my_status.ToString().c_str());
          }
        } else {
          ROCKS_LOG_INFO(info_log_,
                         "Cannot delete %s slowly through ftruncate from trash "
                         "as it has other links",
                         path_in_trash.c_str());
        }
      } else if (!num_link_error_printed_) {
        ROCKS_LOG_INFO(
            info_log_,
            "Cannot delete files slowly through ftruncate from trash "
            "as Env::NumFileLinks() returns error: %s",
            my_status.ToString().c_str());
        num_link_error_printed_ = true;
      }
    }

    if (need_full_delete) {
          //printf("i am deleted from delete_scheduler.cc 4\n");
      s = fs_->DeleteFile(path_in_trash, IOOptions(), nullptr);
      if (!dir_to_sync.empty()) {
        std::unique_ptr<FSDirectory> dir_obj;
        if (s.ok()) {
          s = fs_->NewDirectory(dir_to_sync, IOOptions(), &dir_obj, nullptr);
        }
        if (s.ok()) {
          s = dir_obj->Fsync(IOOptions(), nullptr);
          TEST_SYNC_POINT_CALLBACK(
              "DeleteScheduler::DeleteTrashFile::AfterSyncDir",
              reinterpret_cast<void*>(const_cast<std::string*>(&dir_to_sync)));
        }
      }
      if (s.ok()) {
        *deleted_bytes = file_size;
        s = sst_file_manager_->OnDeleteFile(path_in_trash);
      }
    }
  }
  if (!s.ok()) {
    // Error while getting file size or while deleting
    ROCKS_LOG_ERROR(info_log_, "Failed to delete %s from trash -- %s",
                    path_in_trash.c_str(), s.ToString().c_str());
    *deleted_bytes = 0;
  } else {
    total_trash_size_.fetch_sub(*deleted_bytes);
  }

  return s;
}

void DeleteScheduler::WaitForEmptyTrash() {
  InstrumentedMutexLock l(&mu_);
  while (pending_files_ > 0 && !closing_) {
    cv_.Wait();
  }
}

void DeleteScheduler::MaybeCreateBackgroundThread() {
  if (bg_thread_ == nullptr && rate_bytes_per_sec_.load() > 0) {
    bg_thread_.reset(
        new port::Thread(&DeleteScheduler::BackgroundEmptyTrash, this));
    ROCKS_LOG_INFO(info_log_,
                   "Created background thread for deletion scheduler with "
                   "rate_bytes_per_sec: %" PRIi64,
                   rate_bytes_per_sec_.load());
  }
}

}  // namespace ROCKSDB_NAMESPACE

#endif  // ROCKSDB_LITE
