# Imagen de Apache(Alpine)
FROM httpd:2.4-alpine

# Cambiamos el puerto por defecto a uno nuevo, en mi caso el 13
RUN sed -i 's/Listen 80/Listen 13/' /usr/local/apache2/conf/httpd.conf

# Decirle a Apache que lea los extra de vhosts.conf
RUN echo 'Include conf/extra/httpd-vhosts.conf' >> /usr/local/apache2/conf/httpd.conf
