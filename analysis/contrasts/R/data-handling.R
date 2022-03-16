#' Get the benchmark data set from a SQLite file
#'
#' @param dbName
#'
#' @return A data frame
#' @export
#'
#' @examples
get_dataframe <- function(dbName) {
  dbCon  <- DBI::dbConnect(RSQLite::SQLite(), dbName)
  on.exit(DBI::dbDisconnect(dbCon))

  runLDF <- data.table::setDT(DBI::dbGetQuery(dbCon, 'SELECT * FROM run_data'))
  runLDF[, keyLabel := label_key(key)]
  runWDF <- data.table::dcast(runLDF, run_id ~ keyLabel,
                              value.var = "value")

  resLDF <- data.table::setDT(DBI::dbGetQuery(dbCon, 'SELECT * FROM test_data'))
  resLDF[, keyLabel := label_key(key)]
  resLDF <- data.table::dcast(resLDF, run_id + test_number ~ keyLabel,
                              value.var = "value")

  benchDF <- merge(
    x   = runWDF,
    y   = resLDF,
    by  = "run_id",
    all = TRUE
  )

  return(type.convert(benchDF, as.is = FALSE))
}

# describe_column <- function(x) {
#   data.frame(
#     class   = class(x),
#     nTotal  = length(x),
#     nUnique = length(unique(x)),
#     nNA     = sum(is.na(x)),
#     min     = tryCatch(min(x, na.rm = TRUE), error = function(e) {NA}),
#     max     = tryCatch(max(x, na.rm = TRUE), error = function(e) {NA})
#   )
# }
#
# # as.data.frame(t(sapply(benchDF[, sapply(benchDF, is.numeric), with = FALSE],
# #                        describe_column)))
