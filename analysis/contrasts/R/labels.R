label_as_factor <- function(key, value) {
  factor(key, value, value)
}

label_key <- function(x) {
  l <- list(
    # table keys
    `run_id`                  = "runId",
    # `run_data` table
    `backend`                 = "backendKey",
    `backend-date`            = "backendDate",
    `backend-id`              = "backendId",
    `backend-name`            = "backendName",
    `backend-version`         = "backendVersion",
    `byte-order`              = "byteOrder",
    `cpu-comment`             = "cpuComment",
    `cpu-type`                = "cpuType",
    `disk-comment`            = "diskComment",
    `disk-read-time`          = "diskReadTime",
    `disk-write-time`         = "diskWriteTime",
    `end-run`                 = "endRun",
    `notforking-date`         = "notforkingDate",
    `notforking-id`           = "notforkingId",
    `option-datasize`         = "optionDatasize",
    `option-debug`            = "optionDebug",
    `option-lmdb_debug`       = "optionLmdb_debug",
    `option-lmdb_fixed_rowid` = "optionLmdb_fixed_rowid",
    `option-lmdb_transaction` = "optionLmdb_transaction",
    `option-rowsum`           = "optionRowsum",
    `option-rowsum_algorithm` = "optionRowsumAlgorithm",
    `option-sqlite3_journal`  = "optionSqlite3Journal",
    `os-type`                 = "osType",
    `os-version`              = "osVersion",
    `sqlite-date`             = "sqliteDate",
    `sqlite-id`               = "sqliteId",
    `sqlite-name`             = "sqliteName",
    `sqlite-version`          = "sqliteVersion",
    `target`                  = "target",
    `tests-fail`              = "testsFail",
    `tests-intr`              = "testsIntr",
    `tests-ok`                = "testsOk",
    `title`                   = "title",
    `when-run`                = "whenRun",
    `word-size`               = "wordSize",
    # `test_data` table
    `test-number`             = "benchNumber",
    `test-name`               = "benchName",
    `status`                  = "benchStatus",
    `user-cpu-time`           = "benchUserCPUTime",
    `system-cpu-time`         = "benchSystemCPUTime",
    `real-time`               = "benchRealTime"
  )

  label_as_factor(unlist(l[x]), unlist(l))
}
