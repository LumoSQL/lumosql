mv all-lumosql-benchmark-data-combined.sqlite history.sqlite

wget https://lumosql.org/dist/benchmarks-to-date/all-lumosql-benchmark-data-combined.sqlite

Rscript edit_database.R

#sqlite3 all-lumosql-benchmark-data-combined.sqlite "create index key_index on run_data (key, value);"
