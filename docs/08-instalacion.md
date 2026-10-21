# 08 — Instalación y Puesta en Marcha

**Proyecto:** NANAI Miel Orgánica  
**Versión:** 1.0 (Fase 1 — Especificación)  
**Estado:** En revisión  
**Plataforma de desarrollo verificada:** Windows 11 · Node.js 24.21.0 · MySQL 8.0.46

---

## 1. Requisitos previos

| Componente | Versión mínima | Verificado en | Notas |
|---|---|---|---|
| **Node.js** | 20.x (LTS) | 24.21.0 | Se recomienda 24 LTS. `node --version` |
| **npm** | 10.x | 11.19.0 | Se distribuye con Node |
| **MySQL Server** | 8.0 | 8.0.46 | Se requieren 8.0+ por el soporte de `JSON`, `CTE` y `SKIP LOCKED` |
| **Git** | 2.30+ | 2.56.0 | |
| **VS Code** | Cualquiera | 1.142.0 | Extensiones recomendadas abajo |

**Extensiones recomendadas de VS Code:**

| Extensión | Para qué |
|---|---|
| ESLint | Errores de estilo y bugs comunes |
| Prettier | Formato consistente |
| MySQL (Weijan Zhu / MySQL Workbench) | Explorar la BD |
| Thunder Client / REST Client | Probar la API desde el editor |
| DotENV | Ver las variables sin abrir el archivo |

---

## 2. Pasos de instalación

### 2.1 Clonar el repositorio

```bash
git clone <url-del-repo> miel-nanai
cd miel-nanai
```

### 2.2 Configurar el registro de npm (entorno university)

> **Contexto:** En la red university hay un proxy **Fortinet** que intercepta TLS hacia `registry.npmjs.org`. Node no confía en el certificado de ese proxy, por lo que `npm install` falla con:
>
> ```
> npm error code: UNABLE_TO_VERIFY_LEAF_SIGNATURE
> ```
>
> **Solución aplicada (temporal, a nivel de usuario, NO en el repositorio):**
>
> ```bash
> npm config set registry https://registry.npmmirror.com --location=user
> ```
>
> Este mirror **sí** presenta un certificado válido, por lo que las instalaciones funcionan. Está configurado en tu usuario, así que el repositorio queda limpio y portable.

**Solución definitiva (recomendada):** pedir al administrador de red el certificado raíz (CA) del proxy Fortinet e instalarlo en Windows.

1. Descargar el CA desde el portal del FortiGate (habitualmente `http://<ip-del-fortigate>/` → *Certificate* / *Fortinet Root CA*).
2. Instalarlo: doble clic → **Instalar Certificado** → *Almacén de Entidades de Certificación Raíz de Confianza* → *Entidades de Emisión de Certificados Raíz de Confianza*.
3. Verificar con:
   ```bash
   npm config delete registry --location=user
   npm ping
   ```
   Si responde `PONG` sin errores, ya puedes usar el registro oficial.

### 2.3 Instalar dependencias

```bash
npm install
```

### 2.4 Configurar el entorno

```bash
cp .env.example .env      # Linux/macOS/Git Bash
copy .env.example .env    # Windows CMD
```

Editar `.env` con las credenciales reales. **Nunca** versionar este archivo.

### 2.5 Preparar la base de datos

**Crear la base y un usuario con privilegios mínimos** (ejecutar como `root`):

```sql
CREATE DATABASE nanai_miel
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

-- Usuario de aplicación: NO root, NO con DROP/ALTER/CREATE/GRANT
CREATE USER 'nanai_app'@'localhost' IDENTIFIED BY '<CONTRASEÑA_FUERTE>';
GRANT SELECT, INSERT, UPDATE, DELETE, EXECUTE
  ON nanai_miel.* TO 'nanai_app'@'localhost';
FLUSH PRIVILEGES;
```

> **Por qué no usar `root` en la aplicación:** si el sistema llegara a ejecutar un `DROP TABLE` o una consulta malformada, con `root` el daño sería **total e irreversible**. Con privilegios mínimos, el peor caso se limita a los datos de la aplicación. Esta es la diferencia entre un incidente recuperable y uno que obliga a restaurar toda la base.

**Cargar el esquema:**

```bash
npm run db:migrate    # ejecuta db/schema.sql + db/procedures/*.sql
npm run db:seed       # inserta estados, transiciones, settings, admin inicial
```

### 2.6 Arrancar

```bash
npm run dev           # desarrollo, con recarga automática (node --watch)
npm start             # producción
```

Abrir `http://localhost:3000`.

---

## 3. Variables de entorno

| Variable | Obligatoria | Ejemplo | Descripción |
|---|:---:|---|---|
| `NODE_ENV` | Sí | `development` | `development` \| `production` |
| `PORT` | Sí | `3000` | Puerto HTTP |
| `APP_URL` | Sí | `http://localhost:3000` | URL base (enlaces de correo, CORS) |
| `DB_HOST` | Sí | `127.0.0.1` | |
| `DB_PORT` | Sí | `3306` | |
| `DB_USER` | Sí | `nanai_app` | **No** root |
| `DB_PASSWORD` | Sí | `...` | |
| `DB_NAME` | Sí | `nanai_miel` | |
| `SESSION_SECRET` | Sí | `<64 chars aleatorios>` | Mínimo 32 caracteres |
| `SESSION_NAME` | Sí | `nanai.sid` | Nombre de la cookie |
| `RESERVA_TTL_MINUTOS` | No | `30` | TTL de la reserva de stock |
| `LOG_LEVEL` | No | `info` | `debug`\|`info`\|`warn`\|`error` |
| `RATE_LIMIT_WINDOW_MS` | No | `900000` | Ventana de rate limit (15 min) |
| `MAIL_HOST` | No | `smtp.host.com` | SMTP |
| `MAIL_PORT` | No | `587` | |
| `MAIL_USER` | No | `...` | |
| `MAIL_PASS` | No | `...` | |
| `MAIL_FROM` | No | `no-reply@nanai.pe` | |
| `STORAGE_TYPE` | No | `local` | `local` \| `cloud` |
| `STORAGE_PATH` | No | `./storage` | Donde se guardan imágenes (dev) |
| `PAGOS_PROVEEDOR` | No | `test` | `test`\|`culqi`\|`izipay` |
| `PAGOS_API_KEY` | No | `...` | **Solo backend** |
| `PAGOS_WEBHOOK_SECRET` | No | `...` | **Solo backend** |
| `DNI_PROVEEDOR` | No | `jsonpe` | Adaptador de DNI |
| `DNI_API_KEY` | No | `...` | **Solo backend** |

**Generar un `SESSION_SECRET` seguro:**

```bash
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
```

### Contrato de la configuración

`src/config/env.js` valida **todas** las variables con Zod al arrancar. Si falta una obligatoria, la aplicación **falla de inmediato** con un mensaje explícito:

```
✖ Error de configuración: DB_PASSWORD es obligatoria (ver docs/08-instalacion.md)
```

Es intencional: es preferible que la app no arranque a que arranque a medias y falle de forma confusa en producción.

---

## 4. Comandos disponibles

| Comando | Descripción |
|---|---|
| `npm run dev` | Servidor de desarrollo con recarga automática |
| `npm start` | Servidor de producción |
| `npm run db:migrate` | Crea el esquema y los procedimientos almacenados |
| `npm run db:seed` | Inserta datos iniciales (estados, transiciones, settings, admin) |
| `npm run db:reset` | ⚠️ **DESTRUCTIVO.** Borra y recrea todo. Solo en desarrollo. |
| `npm run db:backup` | Genera un dump SQL en `backups/` |
| `npm run test` | Ejecuta las pruebas con el runner nativo de Node |
| `npm run lint` | ESLint |
| `npm run format` | Prettier |

---

## 5. Verificación de la instalación

```bash
# 1. La API responde
curl http://localhost:3000/api/v1/health
# {"success":true,"data":{"status":"ok","db":"up",...}}

# 2. La base de datos responde
npm run test
```

---

## 6. Problemas frecuentes

| Síntoma | Causa probable | Solución |
|---|---|---|
| `UNABLE_TO_VERIFY_LEAF_SIGNATURE` en `npm install` | Proxy Fortinet interceptando TLS | Ver §2.2. Usar `registry.npmmirror.com` o instalar el CA raíz. |
| `ECONNREFUSED 127.0.0.1:3306` | MySQL no está corriendo | Iniciar el servicio: `net start MySQL80` (Windows) o `sudo systemctl start mysql`. |
| `ER_ACCESS_DENIED_ERROR` | Usuario/contraseña incorrectos, o el usuario no existe | Verificar `.env` y que el usuario se haya creado con `GRANT`. |
| `ER_DBACCESS_DENIED_ERROR` al ejecutar SP | Al usuario le falta `EXECUTE` | `GRANT EXECUTE ON nanai_miel.* TO 'nanai_app'@'localhost';` |
| `ER_TABLEACCESS_DENIED_ERROR` | Falta `CREATE` para el usuario | Normal en `db:migrate`: la migración debe ejecutarse **como root** o con un usuario temporal con permisos de esquema. |
| La app arranca y responde `db: down` | Pool de BD sin conexión | Revisar credenciales y que MySQL esté activo. |
| `PORT already in use` | Otro proceso en el puerto | `netstat -ano | findstr :3000` y cerrar, o cambiar `PORT`. |
| Falla la CSP en el navegador | El SDK de la pasarela necesita un origen permitido | Revisar `connect-src`/`script-src`/`frame-src` en la CSP y añadir **solo** el dominio del proveedor. |
| Cambió la estructura de `products` | Se editó a mano | `npm run db:reset` (solo desarrollo) y volver a sembrar. |

---

## 7. Copias de seguridad

```bash
npm run db:backup
```

Genera `backups/nanai_miel_YYYY-MM-DD_HH-mm.sql`. **No está versionado en Git.**

Procedimiento recomendado:

| Tarea | Frecuencia |
|---|---|
| Dump automático | Diaria |
| Copia externa (disco o nube) | Semanal |
| **Prueba de restauración** | Trimestral (una restauración sin verificar no es un respaldo) |

---

## 8. Despliegue (Fase 12 — pendiente)

Esquema general previsto:

| Componente | Opción sin costo mensual obligatorio |
|---|---|
| Servidor | VPS pequeño o máquina existente |
| Reverse proxy | Nginx |
| Proceso Node | `systemd` (Linux) o PM2 |
| HTTPS | Let's Encrypt (gratuito) + renovación automática |
| Base de datos | MySQL en el mismo servidor (o gestionada si el negocio lo asume) |
| Archivos | Disco local para la v1; `STORAGE_TYPE=cloud` si más adelante hace falta |
| Correo | SMTP con plan gratuito o el correo del negocio |

> **Pendiente de decisión:** hosting concreto y periodicidad de backups (RNF-039, §10 de `07-seguridad.md`).

---

> **Siguiente paso:** los ADR en `docs/decisiones/`, que registran formalmente cada decisión técnica con su contexto, alternativas descartadas y consecuencias.
