library(shiny)
library(tidyverse)
library(lubridate)
library(leaflet)
library(viridis)
theme_set(theme_minimal())

ui <- fluidPage(

    titlePanel("Murujuga Weather Data"),

    sidebarLayout(
        sidebarPanel(
          uiOutput('years_available'),
          verbatimTextOutput("info"),
          htmlOutput("synoptic"),
          selectInput('band', 'Band', c('VS', "IR", "WB", 'RG'), selected ="IR"),
          htmlOutput(('satellite'))
        ),

        mainPanel(
           plotOutput("plot", height = '1200px', click = "plot_click")
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
  
  rain_raw <- read_csv("data/IDCJAC0009_005061_1800_Data.csv")
  
  rain <- rain_raw %>%  
    mutate(date = make_date(
      year = as.numeric(Year),
      month = as.numeric(Month),
      day = as.numeric(Day)
    )) %>% 
    select(date, 'rain' = `Rainfall amount (millimetres)`/`Period over which rainfall was measured (days)`)


    output$plot <- renderPlot({
      year <- input$year
      
      
      tidywind <- wind %>% 
        filter(year(date) == year) %>% 
        mutate(day = day(date),
               mhour = (day-1)*24 + hour(date),
               month = month(date, label = TRUE),
               speed = speed)
      
      tidyrain <- rain %>% 
        filter(year(date) == year) %>% 
        mutate(day = day(date),
               mhour = (day-1)*24 + 12,
               month = month(date, label = TRUE))
      
      c <- 3/5
      
      ggplot(tidywind) +
        geom_segment(aes(x = mhour,
                         y = 0,
                         xend = mhour - c*(
                           speed * 1 * -cos((90-dir) / 360 * 2 * pi)),
                         yend = (speed * sin((90-dir) / 360 * 2 * pi)),
                         colour=(dir<45|dir>325),
        )) +
        geom_bar(data = tidyrain, aes(x = mhour,y=rain/3), stat='identity', fill='navyblue', alpha=0.7) +
        coord_fixed(c) +
        scale_x_continuous(breaks = (0:30)*24-1, labels = 1:31, minor_breaks=NULL) +
        facet_grid(row = vars(month)) + labs(x=NULL,
                                             title = paste0(year," 3-hourly wind speed (km/h), and direction (true °) for Legendre Island")) +
        scale_y_continuous(name = 'Wind (km/h)', breaks = c(0,20),  sec.axis = sec_axis( trans=~.*3, name="Rainfall (mm)", breaks =c(0,50))) +
        scale_colour_manual(values=c('black', 'red')) +
        theme(legend.position = "none")
      
    })
    
    output$years_available = renderUI({
      years_available <- unique(year(wind$date))
      selectInput('year', 'Year', years_available, selected ="2017")
                  })

    
    date_utc <- reactive({
      year <- as.numeric(input$year)
      month <- input$plot_click$panelvar1
      month_num <- which(month.abb == month)
      day <- floor(input$plot_click$x/24)+1
      hour <- floor(input$plot_click$x%%24)
      
      #Convert to UTC
      make_datetime(year, month_num, day, hour, tz = "Australia/Perth") %>% with_tz("UTC")
    })
    
    output$info <- renderText({
      date_utc() %>% with_tz("Australia/Perth") %>% format()
    })
    
    output$synoptic <- renderText({
      options <- c(0,6,12,18)
      utc_round <- (which.min(abs(options - hour(date_utc())))-1)*6
      
      date_code <- sprintf("%04d%02d%02d%02d00", year(date_utc()),month(date_utc()),day(date_utc()),utc_round)
      
      url <- sprintf('http://www.bom.gov.au/archive/charts/%04d/%02d/IDX0102.%s.gif', year(date_utc()), month(date_utc()),date_code)
      c(
        '<img src="',url,'">'
      )
    })
    
    output$satellite <- renderText({
      options <- c(0,3,6,9,12,15,18,21)
      utc_round <- (which.min(abs(options - hour(date_utc())))-1)*3
      
      mts1 <- interval(ymd_h("2005-10-01-00"), ymd_h("2010-06-20-23"))
      mts2 <- interval(ymd_h("2010-07-01-00"), ymd_h("2015-07-06-23"))
      him8 <- interval(ymd_h("2015-07-07-00"), ymd_h("2021-09-01-00"))
      
      sat <- case_when(
          date_utc() %within% mts1 ~ "MTS-1",
          date_utc() %within% mts2 ~ "MTS-2",
          date_utc() %within% him8 ~ "HIM-8",
        )
      
      band <- input$band
    
      url <- sprintf('https://www.ncdc.noaa.gov/gibbs/image/%s/%s/%04d-%02d-%02d-%02d', sat, band, year(date_utc()), month(date_utc()), day(date_utc()), utc_round)
      c(
        '<img src="',url,'", width=\'600px\'>'
      )
    })
}

shinyApp(ui = ui, server = server)
