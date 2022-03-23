library(RSQLite)
library(DBI)
library(shiny)
library(shinythemes)
library(ggiraph)


con <- dbConnect(drv=RSQLite::SQLite(), dbname= "/srv/shiny-server/lumo-apps/all-lumosql-benchmark-data-combined.sqlite")



ds_list <- dbGetQuery(con, paste0("select distinct value from run_data where key = 'option-datasize' order by value") )[,1]
os_list <- dbGetQuery(con, paste0("select distinct value from run_data where key = 'os-version' order by value") )[,1]
be_list <- dbGetQuery(con, paste0("select distinct value from run_data where key = 'backend-version' order by value") )[,1]



shinyUI(fluidPage(
  theme = shinytheme("cyborg"),
  headerPanel(title = "LumoSQL Benchmark Filter"),
  sidebarLayout(
    
    sidebarPanel(
      selectInput("ds",
		  "Datasize",
		  ds_list,
		  ds_list[1]
		  ),
      checkboxGroupInput(inputId = "os",
                   label = "Operating System Version",
                   choices = os_list,
                   selected = '5.15.23' ),
      checkboxGroupInput("be",
                         "Backend Version",
                         be_list,
                         '0.9.29' ),
      width = 3
    ),
    
    mainPanel(
      textOutput("thetext"),
      ggiraphOutput("theplot"),
      plotOutput("thelegend")
      )
  )
))
