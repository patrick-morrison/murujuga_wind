library(shiny)
library(tidyverse)
library(lubridate)
library(leaflet)
library(viridis)
theme_set(theme_minimal())

ui <- fluidPage(

    titlePanel("Murujuga Wind Data"),

    sidebarLayout(
        sidebarPanel(
          uiOutput('years_available'),
          verbatimTextOutput("info"),
          htmlOutput("image")
        ),

        mainPanel(
           plotOutput("wind_plot", height = '1200px', click = "plot_click")
        )
    )
)

server <- function(input, output) {
  
  wind_raw <- read_csv("data/HC06D_Data_004095_9999999910009138.csv")
  
  wind <- wind_raw %>% 
    mutate(date = make_datetime(
      year = as.numeric(Year),
      month = as.numeric(Month),
      day = as.numeric(Day),
      hour = as.numeric(Hour),
      min = as.numeric(`Minute in Local Standard Time`),
      tz = "Australia/Perth" 
    )) %>% select(date,
                  "speed" = `Wind speed measured in km/h`,
                  'speed_q' = `Quality of wind speed`,
                  'dir' = `Wind direction measured in degrees`,
                  'dir_q' = `Quality of wind direction`) %>% 
    filter(!is.na(date))



    output$wind_plot <- renderPlot({
      year <- input$year
      tidywind <- wind %>% 
        filter(year(date) == year) %>% 
        mutate(day = day(date),
               mhour = (day-1)*24 + hour(date),
               month = month(date, label = TRUE),
               speed = speed)
      
      c <- 3/5
      
      ggplot(tidywind) +
        geom_segment(aes(x = mhour,
                         y = 0,
                         xend = mhour - c*(
                           speed * 1 * -cos((90-dir) / 360 * 2 * pi)),
                         yend = (speed * sin((90-dir) / 360 * 2 * pi)),
                         colour=(dir<45|dir>325),
        )) +
        coord_fixed(c) +
        scale_x_continuous(breaks = (0:30)*24-1, labels = 1:31, minor_breaks=NULL) +
        facet_grid(row = vars(month)) + labs(x=NULL, y=NULL,
                                             title = paste0(year," 3-hourly wind speed (km/h), and direction (true °) for Legendre Island")) +
        scale_y_continuous(breaks = c(-20,0,20)) + scale_colour_manual(values=c('black', 'red')) +
        theme(legend.position = "none")
    })
    
    output$years_available = renderUI({
      years_available <- unique(year(wind$date))
      selectInput('year', 'Year', years_available, selected ="2017")
                  })
    
    output$info <- renderText({
      year <- as.numeric(input$year)
      month <- input$plot_click$panelvar1
      day <- floor(input$plot_click$x/24)+1
      hour <- floor(input$plot_click$x%%24)
      paste(year, month, day, hour, sep='_')
      sprintf("%04d-%s-%02d-%02d00", year,month,day,hour)
    })
    
    output$image <- renderText({
      options <- c(0,6,12,18)
      year <- as.numeric(input$year)
      month <- input$plot_click$panelvar1
      month_num <- which(month.abb == month)
      day <- floor(input$plot_click$x/24)+1
      hour <- floor(input$plot_click$x%%24)
      hour_round <- (which.min(abs(options - hour))-1)*6
      date_code <- sprintf("%04d%02d%02d%02d00", year,month_num,day,hour_round)
      
      url <- sprintf('http://www.bom.gov.au/archive/charts/%04d/%02d/IDX0102.%s.gif', year, month_num,date_code)
      c(
        '<img src="',url,'">'
      )
    })
}

shinyApp(ui = ui, server = server)
