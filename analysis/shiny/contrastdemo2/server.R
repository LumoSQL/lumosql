#library(RSQLite)
library(cowplot)
library(DBI)
library(shiny)
library(ggplot2)
library(shinythemes)
library(ggiraph)

con <- dbConnect(drv=RSQLite::SQLite(), dbname= "/srv/shiny-server/lumo-apps/all-lumosql-benchmark-data-combined.sqlite")

shinyServer(function(input,output) {
       
   
    
  globaldf <- reactive({
    
    #-----find runs with selected criteria
    for(j in input$ds){
      idees <- data.frame('run_id')
      colnames(idees) <- c('run_id')
      for(k in input$os){
        for (i in input$be){
          iii <- dbGetQuery(con, paste0("select run_id from run_data where (key = 'tests-ok' and value = '17')
                                      intersect select run_id from run_data where (key = 'backend-version' and value = '",i,"')
                                      intersect select run_id from run_data where (key = 'option-datasize' and value = '",j,"')
                                      intersect select run_id from run_data where (key = 'os-version' and value = '",k,"')
                                      "))
          
          idees <- rbind(idees, iii)
        }}}
    
    #-----error message when no data found
    if (length(idees[,1]) == 1){
      validate(
        need(length(idees[,1]) == 0, "No data in this selection")
      )
      
    }
    
    
    #---- collect info about the runs
    mat <- matrix(ncol = 4)
    df <- as.data.frame(mat)
    colnames(df) <- list('run_id', 'time', 'sqlite_version' , 'pointer')
    
    
    idees <- idees[-1,]
    
    for (h in idees){
      lll <- dbGetQuery(con, paste0("select value from run_data where key in ('sqlite-version') and run_id = '",h,"' "))
      if (as.character(lll) == ''){
        lll <- c('3.18.2')
        lll <- as.data.frame(lll)
      }
      
      bbb <- dbGetQuery(con, paste0("select value from run_data where key in ('os-version','backend-name', 'backend-version','cpu-type', 'cpu-comment', 'disk-comment','word-size') and run_id = '",h,"' "))
      timez <- dbGetQuery(con, paste0("select value from test_data where run_id = '",h,"' and key in ('real-time') ") )
      duration <- sum(as.numeric(timez[,1]) )
      pointer <- paste(as.character(bbb[,1]),collapse = ' ')
      
      darow <- data.frame(h, duration, lll[,1], pointer  )
      
      colnames(darow) <- colnames(df)
      df <- rbind(df, darow)
      
    }
    
    df <- df[-1,]
    
    df <- df[order(df$sqlite_version),]

    if ("3.6.10" %in%  as.list(df$sqlite_version)){
  
        n=match('3.6.10',df$sqlite_version)
        op <- df[1:n-1,]
        ol <- df[n:length(df[,1]), ]
        df <- rbind(ol,op)
     }

    return(df)

  })

   output$thetext <- renderText({
     paste0("Current number of benchmark runs : ",  length(dbGetQuery(con, paste0("select distinct run_id from run_data where (key = 'tests-ok' and value = '17') "))[,1]), ". Database last updated ", file.info("/srv/shiny-server/lumo-apps/all-lumosql-benchmark-data-combined.sqlite")$ctime )   
      }) 
   

  output$theplot <- renderggiraph({
     gg <-  ggplot(data=globaldf(), aes(x=sqlite_version, y=time, group=pointer, colour=pointer )) +
    # geom_line()+
      geom_line_interactive(aes(tooltip = pointer, data_id = pointer), size = 0.5)+
    # geom_point()+
      geom_point_interactive(aes(tooltip = paste0(globaldf()$time,"-", pointer), data_id = pointer), size = 1)+
      scale_x_discrete(limits=globaldf()$sqlite_version)+
      theme_dark()+
      theme(axis.text.x = element_text(colour="white"),
	    axis.text.y = element_text(colour="white"),
            axis.title.x=element_text(colour="white"),
            axis.title.y=element_text(colour="white"))+
      theme(panel.background = element_rect(fill = "#262626"))+	
      theme(plot.background = element_rect(fill = "black"))+
      #theme(panel.border = element_rect(
      #fill = "#00000000", color = "#FFFFFFFF", size = 1)
      #)+
      theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))+
      theme(legend.position="none")
    
   #  gg    

     girafe(ggobj = gg, width_svg = 8, height_svg = 6,
       options = list(
         opts_hover_inv(css = "opacity:0.1;"),
         opts_hover(css = "stroke-width:2;")
       ))
    
    
  })



  output$thelegend <- renderPlot({
      pleg <- ggplot(data=globaldf(), aes(x=sqlite_version, y=time, group=pointer, colour=pointer )) +
      geom_point()+
      #theme(panel.border = element_rect(
      #fill = "#00000000", color = "#FFFFFFFF", size = 1)
      #)+
      #theme_dark()+
      theme(plot.background = element_rect(fill = "black"))+
      theme(legend.position="top")+
      theme(legend.background = element_rect(fill="black"))+
      theme(legend.text=element_text(color="white"))+
      theme(legend.key = element_rect(fill="black"))+
      guides(col = guide_legend(ncol=1))
      legend <-get_legend(pleg)
      
      ggdraw(legend)+
      #theme_dark()+
      theme(plot.background = element_rect(fill = "black"))
      #theme(legend.background = element_rect(fill="lightblue"))

      
      
  })


})
