# 1. Diseño y requisitos

## Dominios elegidos

Para hacer la práctica se han elegido dos dominios ficticios, uno para cada marca:

* **Marca 1:** `HRjuandragontech.local`
* **Marca 2:** `HRshadowbyte.local`

Los dos dominios son inventados y se utilizarán para diferenciar las dos marcas, aunque ambas estarán alojadas en el mismo servidor.

## 2. MPM de Apache elegido

El MPM que se va a utilizar en Apache es **event**.

He elegido este MPM porque está pensado para trabajar con bastantes conexiones al mismo tiempo y permite aprovechar mejor los recursos del servidor. También funciona bien con conexiones persistentes, ya que no es necesario mantener un proceso ocupado mientras la conexión está esperando.

Por este motivo, `event` resulta adecuado para el servidor que se plantea en esta práctica.

## 3. Arquitectura inicial

En la primera fase se utilizará un único servidor Apache para alojar las dos marcas. Para separarlas se utilizarán **Virtual Hosts**.

Cada dominio tendrá su propio Virtual Host y también tendrá un directorio independiente donde estarán sus archivos.

La estructura inicial sería la siguiente:

```text
Cliente
   |
   |--- HRjuandragontech.local
   |
   |--- HRshadowbyte.local
            |
            |
      Servidor Apache
            |
     -------------------
     |                 |
     |                 |
HRjuandragontech   HRshadowbyte
```

De esta forma, las dos marcas estarán en el mismo servidor, pero cada una tendrá su propia configuración y sus propios archivos.

## 4. Fase 1 - Configuracion y Pruebas

### Configuración de Virtual Hosts y Seguridad

1. **VirtualHost por defecto (`default.local`):** 
   Se ha definido un VirtualHost en primera posición del fichero `vhosts.conf` configurado con `Require all denied`. Cuando una petición llega con una cabecera `Host` no reconocida (o no configurada), cae en este bloque y Apache responde inmediatamente con un estado `403 Forbidden` en lugar de responder con un sitio arbitrario.

2. **Protección de recursos:**
   - Desactivación del listado de directorios global mediante la directiva `Options -Indexes`.
   - Protección del fichero sensible `configurar.php` dentro de la marca interna `HRshadowbyte.local` denegando el acceso explícito mediante `<Files "configurar.php"> Require all denied </Files>`.

3. **Logs por marca:**
   Cada marca gestiona sus registros en ficheros independientes (`ErrorLog` y `CustomLog combined`).

### Pruebas de validación (`curl`)

Se han ejecutado las siguientes comprobaciones para validar el correcto funcionamiento del servidor Apache en el puerto 8080:

1. **Petición correcta a Marca 1:**
   ```bash
   
   curl -H "Host: HRjuandragontech.local" http://localhost:8080
   # Respuesta: 200 OK (Muestra el HTML de HRjuandragontech)
   
   curl -H "Host: HRshadowbyte.local" http://localhost:8080
   # Respuesta: 200 OK (Muestra el HTML de HRshadowbyte)	

   curl -i -H "Host: HRshadowbyte.local" http://localhost:8080/configurar.php
   # Respuesta: HTTP/1.1 403 Forbidden

   curl -i -H "Host: falso.local" http://localhost:8080
   # Respuesta: HTTP/1.1 403 Forbidden
   ```


