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
## III. Fase 2 — Proxy Inverso Nginx con Terminación TLS

### 1. Arquitectura
Se ha desplegado **Nginx** como proxy inverso frontal (puertos 80 y 443) para gestionar la terminación TLS y reenviar el tráfico descifrado al backend **Apache** (`nimbusdocs01:13`). Apache ha quedado aislado en la red interna de Docker sin mapeo de puertos hacia el exterior.

### 2. Justificación Técnica
* **Redirección HTTP -> HTTPS (301):** Se utiliza `301 Moved Permanently` para que los clientes almacenen en caché la ubicación segura y eviten futuras peticiones HTTP inseguras.
* **Seguridad TLS y ECDSA:** Se restringe el uso a **TLS 1.2 y 1.3** (deshabilitando protocolos obsoletos) y se utiliza un certificado autosellado con la curva elíptica **`secp384r1` (ECDSA)** para garantizar Forward Secrecy y optimizar el rendimiento.
* **Cabecera `Host`:** Omitir `proxy_set_header Host $host;` hace que Nginx reenvíe la petición con el host interno (`nimbusdocs01:13`), provocando un error **403 Forbidden** en Apache al no coincidir con ningún VirtualHost. Su inclusión correcta permite responder con **200 OK**.

### 3. Evidencias de Verificación

#### Respuesta HTTP 200 OK (`curl`)
```bash
curl -k -I -H "Host: HRshadowbyte.local" https://localhost

HTTP/1.1 200 OK
Server: nginx/1.31.7
Date: Sun, 18 Oct 2026 19:07:02 GMT
Content-Type: text/html
Content-Length: 193
Connection: keep-alive
ETag: "c1-65d3c1121caa6"

```bash
openssl s_client -connect localhost:443 -servername HRjuandragontech.local < /dev/null

CONNECTED(00000003)
depth=0 CN = HRjuandragontech.local, O = IAW Lab, OU = Fase2
verify error:num=18:self-signed certificate
verify return:1
depth=0 CN = HRjuandragontech.local, O = IAW Lab, OU = Fase2
verify return:1
---
Certificate chain
 0 s:CN = HRjuandragontech.local, O = IAW Lab, OU = Fase2
   i:CN = HRjuandragontech.local, O = IAW Lab, OU = Fase2
   a:PKEY: id-ecPublicKey, 384 (bit); sigalg: ecdsa-with-SHA256
   v:NotBefore: Oct 18 18:53:44 2026 GMT; NotAfter: Oct 18 18:53:44 2027 GMT
---
Server certificate
-----BEGIN CERTIFICATE-----
MIICGTCCAZ6gAwIBAgIUME3uBHPGsqkepmaqsfOggD3FtKowCgYIKoZIzj0EAwIw
QzEfMB0GA1UEAwwWSFJqdWFuZHJhZ29udGVjaC5sb2NhbDEQMA4GA1UECgwHSUFX
IExhYjEOMAwGA1UECwwFRmFzZTIwHhcNMjYxMDE4MTg1MzQ0WhcNMjcxMDE4MTg1
MzQ0WjBDMR8wHQYDVQQDDBZIUmp1YW5kcmFnb250ZWNoLmxvY2FsMRAwDgYDVQQK
DAdJQVcgTGFiMQ4wDAYDVQQLDAVGYXNlMjB2MBAGByqGSM49AgEGBSuBBAAiA2IA
BNfpdgr2NEKdHKSpbSTFvbswX4r42zvnMOt+tnx5Qv4AYY9un00ShZTW/Y2UiU47
x+xphYt3pe8Elx74tZkU2Az56KFGqrppS+nlNjYo9FMLKq1RtsgVFS88s+cJ3Oeh
96NTMFEwHQYDVR0OBBYEFN2PzD+SZxiZTLtDSrqyQOeVWzkWMB8GA1UdIwQYMBaA
FN2PzD+SZxiZTLtDSrqyQOeVWzkWMA8GA1UdEwEB/wQFMAMBAf8wCgYIKoZIzj0E
AwIDaQAwZgIxAP0uhrZ2dklrSaAE5qDT1TuoQN9d3b/eG6gWI3qIbtT+2nfwNP7M
OKTwrktZFIp7mwIxAPIkPY1Xpf3veR8KNpuEIa9LWDyUe76GY+jl/90/ndlHLVT2
jp/mnnIdH+5GQfYpdw==
-----END CERTIFICATE-----
subject=CN = HRjuandragontech.local, O = IAW Lab, OU = Fase2
issuer=CN = HRjuandragontech.local, O = IAW Lab, OU = Fase2
---
No client certificate CA names sent
Peer signing digest: SHA384
Peer signature type: ECDSA
Server Temp Key: X25519, 253 bits
---
SSL handshake has read 970 bytes and written 404 bytes
Verification error: self-signed certificate
---
New, TLSv1.3, Cipher is TLS_AES_256_GCM_SHA384
Server public key is 384 bit
Secure Renegotiation IS NOT supported
Compression: NONE
Expansion: NONE
No ALPN negotiated
Early data was not sent
Verify return code: 18 (self-signed certificate)
---
---
Post-Handshake New Session Ticket arrived:
SSL-Session:
    Protocol  : TLSv1.3
    Cipher    : TLS_AES_256_GCM_SHA384
    Session-ID: 04EE628B1FC6A8C831C7B23573E0215DD6DB7BD995E6DD2E61B706B5F5430B3E
    Session-ID-ctx: 
    Resumption PSK: 1032BEB882F7FDDE2B3E5FA5B1087D26CC01D15876EFD6ED0A4E009D0A0BE3328E07781EBD975BD91AE8518F94A81068
    PSK identity: None
    PSK identity hint: None
    SRP username: None
    TLS session ticket lifetime hint: 300 (seconds)
    TLS session ticket:
    0000 - f2 15 c4 d0 31 1f 0c 6c-65 d9 d5 fc 7a b0 a4 49   ....1..le...z..I
    0010 - cc df a5 9b e2 31 6d a2-02 b2 25 02 12 93 73 b3   .....1m...%...s.
    0020 - a6 6d 67 43 1c 0d ef 85-1a 78 93 04 4e c8 55 aa   .mgC.....x..N.U.
    0030 - 5e 8c df ee dd 80 82 40-b2 77 fc 8a 27 54 3d 47   ^......@.w..'T=G
    0040 - 72 6a e1 a5 fb 4b 51 20-a1 19 76 a9 c1 a2 c7 27   rj...KQ ..v....'
    0050 - 14 d4 76 7b 37 c5 20 41-df a2 2b 6e 21 02 12 6b   ..v{7. A..+n!..k
    0060 - d0 37 d2 01 b7 7c bb 5f-40 ab 00 45 08 54 3f 6c   .7...|._@..E.T?l
    0070 - 9b 65 9a 45 71 7f f9 09-ee b9 01 f5 52 f7 22 66   .e.Eq.......R."f
    0080 - b6 66 9c d7 42 ba ce b2-16 f2 36 f8 f4 4e c6 5f   .f..B.....6..N._
    0090 - a4 85 ab e7 72 d3 d2 04-a3 c1 52 9d 3b 7b b0 fe   ....r.....R.;{..
    00a0 - 9a ff 5a b2 a3 e7 d1 a4-f8 62 8c af 42 72 d9 54   ..Z......b..Br.T
    00b0 - 15 e3 b2 08 cd a2 e6 34-83 6e 5d 14 bb 5d 86 8d   .......4.n]..]..
    00c0 - 18 98 10 3e bc 7c 73 33-10 25 e3 ca a7 93 b1 3f   ...>.|s3.%.....?
    00d0 - 98 e9 77 87 17 21 11 de-09 7a 7c 84 16 5e dd 4b   ..w..!...z|..^.K
    00e0 - da 3d 3d 1a e1 63 4d ba-a1 85 45 83 22 65 f8 79   .==..cM...E."e.y
    00f0 - 4f a9 a8 40 0b 52 c8 82-39 e5 6d 77 9e 22 31 a7   O..@.R..9.mw."1.

    Start Time: 1792350874
    Timeout   : 7200 (sec)
    Verify return code: 18 (self-signed certificate)
    Extended master secret: no
    Max Early Data: 0
---
read R BLOCK
---
Post-Handshake New Session Ticket arrived:
SSL-Session:
    Protocol  : TLSv1.3
    Cipher    : TLS_AES_256_GCM_SHA384
    Session-ID: FCD31A35A60D189650E980E3FC44297D66F879F0381C317919DAED768D999C95
    Session-ID-ctx: 
    Resumption PSK: A99952EB1C905066A014CDC0917ECE702AFD9EFD452D9D5A6194744071B25CE4C2C93B98436EE637A3D06D30AF8A9289
    PSK identity: None
    PSK identity hint: None
    SRP username: None
    TLS session ticket lifetime hint: 300 (seconds)
    TLS session ticket:
    0000 - f2 15 c4 d0 31 1f 0c 6c-65 d9 d5 fc 7a b0 a4 49   ....1..le...z..I
    0010 - 31 0b 49 59 25 b5 87 3a-90 4c 72 57 ab 78 71 d0   1.IY%..:.LrW.xq.
    0020 - cf 2e 15 5c f0 cf 25 25-c3 63 8d 2b dd 32 ce de   ...\..%%.c.+.2..
    0030 - 6d 7c 54 25 dd 7d f2 41-01 79 56 c1 e9 af 19 a1   m|T%.}.A.yV.....
    0040 - 41 eb 5a f0 7f 8e 55 9a-6c 91 61 aa fd 3f b7 8e   A.Z...U.l.a..?..
    0050 - 01 4e 51 3b 5e af d4 34-6f 3d 8c c6 45 32 e2 a1   .NQ;^..4o=..E2..
    0060 - ff e2 97 18 30 1b dc 15-1a aa 0c 9e 63 ed 70 bf   ....0.......c.p.
    0070 - ce 3e f1 4c 50 5a df 8e-2f cc 1f 0a b5 f6 09 33   .>.LPZ../......3
    0080 - 71 a6 4c 23 d0 51 59 5c-01 1a b5 c6 dd 78 c2 e0   q.L#.QY\.....x..
    0090 - 60 c1 27 cf aa 10 e2 a9-ec d7 77 d0 07 ff 30 b9   `.'.......w...0.
    00a0 - 78 b8 94 8f ec 6c da 37-6c f1 86 e1 48 32 57 8f   x....l.7l...H2W.
    00b0 - 73 ff dd c1 c1 50 e4 ec-e9 92 b5 3b 11 88 bc 9c   s....P.....;....
    00c0 - 13 9f 2d 6b cc 12 3f e2-09 eb 02 76 d1 7f 78 22   ..-k..?....v..x"
    00d0 - 39 ef f9 24 85 d1 c6 74-10 37 af d2 f7 46 ec 69   9..$...t.7...F.i
    00e0 - 49 86 52 8a 0c a9 69 2d-28 4a 12 c4 54 ea de 33   I.R...i-(J..T..3

    Start Time: 1792350874
    Timeout   : 7200 (sec)
    Verify return code: 18 (self-signed certificate)
    Extended master secret: no
    Max Early Data: 0
---
read R BLOCK
DONE



---
Certificate chain
 0 s:CN = HRjuandragontech.local, O = IAW Lab, OU = Fase2
   i:CN = HRjuandragontech.local, O = IAW Lab, OU = Fase2
   a:PKEY: id-ecPublicKey, 384 (bit); sigalg: ecdsa-with-SHA256
---
New, TLSv1.3, Cipher is TLS_AES_256_GCM_SHA384
Server public key is 384 bit
Verify return code: 18 (self-signed certificate)



## IV. Fase 2 — Seguridad y Límite de Peticiones

### 1. Cabeceras de Seguridad Perimetral
Se han incorporado las siguientes cabeceras HTTP dentro del bloque `server` HTTPS en Nginx para mitigar vectores de ataque comunes:
- **`Strict-Transport-Security` (`max-age=31536000; includeSubDomains`):** Fuerza a los navegadores a conectarse únicamente mediante HTTPS durante un año, previniendo ataques de tipo Man-in-the-Middle y Downgrade HTTP.
- **`X-Content-Type-Options` (`nosniff`):** Desactiva el *MIME-sniffing* en los navegadores, obligando a respetar el tipo MIME declarado en la cabecera `Content-Type` y mitigando ataques de inyección de archivos maliciosos.
- **`X-Frame-Options` (`SAMEORIGIN`):** Protege la aplicación frente a ataques de **Clickjacking**, impidiendo que los sitios web de las marcas sean incrustados dentro de un `<frame>`, `<iframe>` o `<object>` desde dominios externos no autorizados.

---

### 2. Cálculo y Justificación del Rate Limiting

#### A. Análisis del Escenario
El tráfico legítimo de NimbusDocs genera hasta $3\text{ pet/seg}$ continuas, con picos esporádicos de $6\text{ pet/seg}$. El patrón de scraping detectado supera las $20\text{ pet/seg}$.

#### B. Directivas Configurada en Nginx
- **Directiva de Zona:** `limit_req_zone $binary_remote_addr zone=req_limit_per_ip:10m rate=3r/s;`
  - Utiliza `$binary_remote_addr` para optimizar el uso de memoria (64 bytes por IP en lugar de texto).
  - Define una tasa media máxima de $3\text{ pet/seg}$ por cliente.
- **Directiva de Ubicación:** `limit_req zone=req_limit_per_ip burst=5 nodelay;`
  - **`burst=5`:** Permite picos repentinos de hasta $3 + 5 = 8\text{ pet/seg}$ sin bloquear al usuario legítimo.
  - **`nodelay`:** Procesa las peticiones permitidas de forma inmediata sin introducir latencia artificial, y rechaza el exceso inmediatamente devolviendo un error HTTP 503.

---

### 3. Evidencias de Verificación (Bloqueo de Ráfaga)

Se ejecutó un bucle de 15 peticiones concurrentes para simular el comportamiento del script de scraping:

```bash
for i in {1..15}; do curl -k -s -o /dev/null -w "%{http_code}\n" -H "Host: HRshadowbyte.local" https://localhost; done

200
200
200
200
200
200
503
503
503
503
503
503
503
200
503

---


# V. Fase 3 — Diagnóstico Provocado

Para demostrar las capacidades de diagnóstico y análisis frente a fallos de configuración conceptuales, se han simulado y documentado dos escenarios de error en los distintos bloques de la arquitectura:

## 1. Fallo en Backend Apache (Precedencia de VirtualHosts)

| Síntoma observado | Hipótesis inicial | Comando de diagnóstico usado | Causa real y solución |
| :--- | :--- | :--- | :--- |
| Petición con cabecera `Host: dominiofalso.local` responde con `HTTP/1.1 200 OK` mostrando la web de Marca 1, en lugar del error `403 Forbidden` esperado. | El bloque de VirtualHost por defecto (`default.local`) se ha borrado o la directiva `Require all denied` no está funcionando. | `curl -i -k -H "Host: dominiofalso.local" https://localhost` | **Causa:** En Apache, la selección del *Default VirtualHost* ante peticiones no reconocidas depende del orden de lectura de los ficheros de configuración. Al mover la definición del bloque `default.local` al final de `vhosts.conf`, el primer bloque cargado pasa a ser `HRjuandragontech.local`.<br><br>**Solución:** Colocar siempre el VirtualHost por defecto en la primera posición del archivo de configuración. |

---

## 2. Fallo en Frontal Nginx (Omisión de cabecera `Host` hacia el Proxy)

| Síntoma observado | Hipótesis inicial | Comando de diagnóstico usado | Causa real y solución |
| :--- | :--- | :--- | :--- |
| Acceso por HTTPS a dominios válidos (ej. `HRshadowbyte.local`) devuelve un error `HTTP/1.1 403 Forbidden`. | El servicio Apache en el backend se ha caído o las directivas de acceso deniegan las peticiones perimetrales. | `curl -i -k -H "Host: HRshadowbyte.local" https://localhost`<br>`docker logs nginx_proxy` | **Causa:** Nginx fue configurado omitiendo la directiva `proxy_set_header Host $host;`. Por defecto, Nginx reenvía las peticiones a Apache usando el nombre interno del contenedor (`nimbusdocs01:13`) como cabecera `Host`. Como esta no coincide con ningún VirtualHost de marca, Apache asigna la petición al bloque por defecto (`default.local`), respondiendo `403 Forbidden`.<br><br>**Solución:** Incluir la directiva `proxy_set_header Host $host;` dentro de la localización del proxy en `default.conf`. |
