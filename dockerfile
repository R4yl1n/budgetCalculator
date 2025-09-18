# Basisimage: Shiny Server
FROM rocker/shiny:latest

# Systemabhängige Abhängigkeiten für pdftools installieren
RUN apt-get update && apt-get install -y \
    libpoppler-cpp-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# R-Pakete installieren
RUN R -e "install.packages(c('shiny','pdftools','stringr','dplyr','ggplot2'), repos='https://cloud.r-project.org/')"

# ALLES im Shiny-Server-Ordner löschen
RUN rm -rf /srv/shiny-server/*

# Kopiere die App ins Shiny-Verzeichnis
COPY shinyUbsBudgetCalculator.R /srv/shiny-server/app.R

# Setze Berechtigungen
RUN chown -R shiny:shiny /srv/shiny-server

# Exponiere den Shiny-Port
EXPOSE 3838

# Setze den Benutzer auf shiny
USER shiny

# Startet den Shiny Server
CMD ["/usr/bin/shiny-server"]
