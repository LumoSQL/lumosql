library(RSQLite)
library(DBI)

con <- dbConnect(drv=RSQLite::SQLite(), dbname= "all-lumosql-benchmark-data-combined.sqlite")



nnn <- dbGetQuery(con, paste0("select run_id from run_data where (key = 'tests-ok' and value = '17') "))


for (i in nnn[,1]){
  l = dbGetQuery(con, paste0("select value from run_data where key in ('backend-version') and run_id = '",i,"' "))
  if (length(l[,1]) == 0){
    line <- data.frame(i, 'backend-version', 'unmodified')
    colnames(line) <- list('run_id','key','value')
    
    dbAppendTable(con, "run_data", line)
  }
}

dbDisconnect(con)

