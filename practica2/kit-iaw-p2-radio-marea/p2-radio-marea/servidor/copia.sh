#!/bin/sh
# Copia de seguridad de la base de datos de Radio Marea (UD6, apartado 10). Se lanza con: ./practica.sh copia
# Corre en «admin», el ordenador del administrador: tu carpeta servidor/ es /srv/servidor y copias/ es /copias.
# En un servidor de verdad la lanzaría cron cada noche: 30 3 * * * /srv/servidor/copia.sh
# Este script va a Git: por eso NO lleva ninguna contraseña escrita.
set -e

# ✍️ C4 · Escribe el script, paso a paso:
#   1. Carga las variables de /srv/servidor/radio.env (así tienes $DB_HOST, $DB_NAME, $COPIAS_USER, $COPIAS_PASS…).
set -a
. /srv/servidor/radio.env
set +a
#   2. Una variable FECHA con la fecha y la hora, así: 20261123-033000.
FECHA="$(date +%Y%m%d-%H%M%S)"
#   3. La copia de la base $DB_NAME con mysqldump, entrando como el usuario de las copias (COPIAS_USER, no radio_web),
#      en /copias/radio-$FECHA.sql. Sin bloquear la web y sin pedir el permiso PROCESS.
MYSQL_PWD="$COPIAS_PASS" mysqldump -h "$DB_HOST" -u "$COPIAS_USER" --single-transaction --no-tablespaces "$DB_NAME" > "/copias/radio-$FECHA.sql"
#   4. Que no se acumulen: borra las copias radio-*.sql de más de 7 días.
find /copias -name 'radio-*.sql' -type f -mtime +7 -delete
#   5. Que diga qué fichero ha creado.
echo "/copias/radio-$FECHA.sql"
