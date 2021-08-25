FROM rocker/shiny-verse:latest

RUN apt-get update -qq && apt-get -y --no-install-recommends install \
    libxml2-dev \
    libcairo2-dev \
    libsqlite3-dev \
   libmariadbd-dev \
    libpq-dev \
    libssh2-1-dev \
    unixodbc-dev \
    libcurl4-openssl-dev \
    libssl-dev

RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get clean

COPY murujuga_wind_shiny.R /srv/shiny-server/murujuga_weather/
COPY data /srv/shiny-server/murujuga_weather/data

CMD ["/usr/bin/shiny-server"]