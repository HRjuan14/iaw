FROM httpd:2.4-alpine

# Copiar el contenido web al DocumentRoot
COPY web/ /var/www/html/

# Copiar las configuraciones
COPY apache/sites-available/ /usr/local/apache2/conf/extra/sites-available/
COPY apache/sites-enabled/ /usr/local/apache2/conf/extra/sites-enabled/

# Incluir las configuraciones activas en el httpd.conf principal
RUN echo "IncludeOptional conf/extra/sites-enabled/*.conf" >> /usr/local/apache2/conf/httpd.conf

EXPOSE 80