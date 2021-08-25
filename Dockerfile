FROM rocker/shiny-verse:latest

RUN apt-get update && apt-get install -y \
    libcurl4-gnutls-dev \
    libssl-dev

COPY murujuga_wind_shiny.R /srv/shiny-server/murujuga_weather/app.R
COPY data /srv/shiny-server/murujuga_weather/data