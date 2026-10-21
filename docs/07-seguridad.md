# 07 — Seguridad

**Proyecto:** NANAI Miel Orgánica  
**Versión:** 1.0 (Fase 1 — Especificación)  
**Estado:** En revisión  
**Principio:** Seguridad desde el diseño, no como parche al final.

---

## 1. Modelo de amenazas

Método **STRIDE** aplicado a los flujos críticos del sistema.

| Flujo | Activo a proteger | Amenazas STRIDE relevantes |
|---|---|---|
| **Público → Catálogo** | Disponibilidad del sitio, datos de productos | *DoS* (flood), *Tampering* (manipular precios vía API) |
| **Público → Checkout** | Integridad de precios/stock | *Tampering* (precio falso), *Repudiation* (pedido sin rastro), *Elevation* (comprar sin stock) |
| **Público → Pago** | Datos de tarjeta (que **no** tenemos), integridad del cobro | *Spoofing* (webhook falso), *Tampering* (cambio de importe), *Repudiation* (doble cobro) |
| **Público → Rastreo por código** | Datos personales del cliente | *Information Disclosure* (enumerar pedidos), *Spoofing* (suplantar identidad con un código) |
| **Público → Recuperar contraseña** | Cuenta del administrador | *Elevation* (tomar el panel), *DoS* (bombardeo de correos) |
| **Vendedor → Panel** | Panel, datos de negocio | *Elevation* (rol insuficiente), *Tampering* (modificar stock/pedidos sin permiso) |
| **Vendedor → Inventario** | Exactitud del stock | *Tampering* (ajustes sin rastro), *Repudiation* (merma sin justificación) |
| **Sistema → Correo** | Credenciales SMTP, datos del cliente en el correo | *Information Disclosure* (PII en logs), *Spoofing* (correo suplantado) |
| **Sistema → Webhook externo** | Integridad del pago | *Spoofing* (firma inválida), *Repudiation* (procesar dos veces) |

---

## 2. Superficie de ataque y controles

### 2.1 Datos de tarjeta — **el control más importante**

| Aspecto | Decisión |
|---|---|
| **Dónde viven los datos** | Únicamente en el formulario del proveedor de pagos (iframe/SDK del tercero), dentro del navegador. |
| **Dónde NUNCA viven** | En nuestro frontend, nuestro backend, nuestra base de datos, nuestros logs. Ni un solo campo. |
| **Tokenización** | El proveedor devuelve un **token**; solo ese token viaja a nuestro backend. |
| **Nuestro almacenamiento** | Únicamente: `payments.referencia_externa`, `monto`, `estado`, `provider_event_id`. |
| **Requisito** | En el contrato con el proveedor: el SDK deberexistir de modo que los campos de tarjeta **nunca** se envíen a nuestro servidor (evitar implementarlos en nuestro HTML). |

> **Por qué esto importa:** Si el número de tarjeta pasara por nuestro servidor, seríamos un custodio de datos de tarjeta y tendríamos obligaciones de cumplimiento PCI DSS mucho más estrictas, además del riesgo de una filtración. Con la tokenización, **nunca** custodiamos datos de tarjeta.

### 2.2 Credenciales de terceros

| Credencial | Dónde vive | Quién la ve |
|---|---|---|
| `PAGOS_API_KEY` | `.env` | Solo backend. **Nunca** en el frontend. |
| `PAGOS_WEBHOOK_SECRET` | `.env` | Solo backend (validar firma). |
| `DNI_API_KEY` | `.env` | Solo backend. |
| `MAIL_PASS` | `.env` | Solo backend. |
| `DB_PASSWORD` | `.env` | Solo backend. |
| `SESSION_SECRET` | `.env` | Solo backend. |

**Regla de oro:** el frontend público es HTML/CSS/JS estático servido como archivos. **No hay build step ni credenciales inyectadas en el bundle**. Cualquier secreto que aparezca en el navegador es un incidente de seguridad.

### 2.3 Autenticación y sesión

| Control | Implementación |
|---|---|
| **Algoritmo de hash** | Argon2id (`@node-rs/argon2`). Parámetros: `m=19456 KiB, t=2, p=1` (mínimos OWASP). Ajustables por `.env`. |
| **Nunca cifrado reversible** | No existe función de "desencriptar contraseña" en el código. Argon2id es unidireccional por diseño. |
| **Sal** | Automático e incorporado en el hash (formato `$argon2id$v=19$m=...`). Cada hash tiene sal propia. |
| **Comparación** | `argon2.verify()` en tiempo constante (resistente a timing attacks). |
| **Almacenamiento de sesión** | Tabla `sessions` en MySQL. La cookie solo lleva un identificador opaco. |
| **Cookie** | `httpOnly` (inaccesible a JS), `SameSite=Lax`, `Secure` en producción, `Path=/`, nombre no descriptivo. |
| **Expiración** | Por inactividad. Renovación (sliding) opcional. |
| **Revocación** | Eliminar la fila de `sessions` invalida el acceso inmediatamente. |
| **CSRF** | Token en sesión + verificación en POST/PUT/PATCH/DELETE del panel. |
| **Login** | Rate limit por IP y por email. Mensaje genérico en fallo ("correo o contraseña incorrectos"). No revela si el email existe. |

### 2.4 Recuperación de contraseña

| Aspecto | Regla |
|---|---|
| **Generación del código** | Aleatorio, criptográficamente seguro (crypto). |
| **Almacenamiento** | **Solo el hash** del código en `password_reset_codes.code_hash`. |
| **Expiración** | Corta (p. ej. 15 minutos). |
| **Un solo uso** | `used_at` se marca al usarlo. Segundo uso rechazado. |
| **Respuesta uniforme** | La API responde idéntico exista o no el correo. Evita enumeración de cuentas. |
| **Rate limit** | Por IP y por email. |
| **No se envía la contraseña** | Jamás. Solo el código temporal. |
| **Revocación de sesiones** | Al cambiar la contraseña se invalidan las sesiones activas del usuario. |

### 2.5 Rastreo de pedidos por código (superficie sensible)

El código `NAN-2026-000125` es la **única** credencial del cliente. Debilitamientos:

| Debililidad | Mitigación |
|---|---|
| Espacio de búsqueda reducido (6 dígitos/año) | Rate limiting estricto. Ventana de ~100k/año, pero el rate limit es la barrera real. |
| Email/teléfono expuestos en la respuesta | **Enmascarar**: `j***@example.com`, `9*****999`. |
| Distinguir "no existe" de "existe" | Respuesta genérica idéntica. No se revela información del propietario. |
| Enumeración masiva | Sin endpoint que permita listar. Solo lookup exacto. |
| Fuerza bruta distribuida | Rate limit por IP + por código. Considerar bloqueo temporal por código. |

### 2.6 Webhooks de pago

| Ataque | Mitigación |
|---|---|
| **Spoofing** (webhook falso) | Validación de **firma HMAC** con `PAGOS_WEBHOOK_SECRET`. Firma inválida → `401`, sin procesar. |
| **Tampering** (importe alterado) | El importe se compara contra el del **pedido** en la BD. Si no coincide → se rechaza y se alerta. |
| **Repudiation** (mismo webhook dos veces) | `provider_event_id` con `UNIQUE`. Si ya existe → `200` sin reprocesar. |
| **Confianza ingenua** | **Verificación cruzada**: tras recibir el webhook, se consulta el estado real a la pasarela. Solo si ambas coinciden se transiciona. |
| **Evento fuera de orden** | Se procesa la transición solo si es válida desde el estado actual; si no, se ignora con log. |
| **Reintentos agresivos** | Rate limiting en el endpoint. |

### 2.7 Inyección SQL

| Control | Aplicación |
|---|---|
| **Consultas parametrizadas** | Obligatorio. `?` en `mysql2` / named params en SP. |
| **Prohibido concatenar** | Nunca construir SQL con template strings y variables de usuario. |
| **Stored Procedures** | El acceso a datos crítico va por SP con parámetros de entrada tipados. |
| **Identificadores dinámicos** | Si un nombre de columna/tabla viene de fuera, debe pasar por una **lista blanca** en código, nunca interpolarse. |
| **Revisión** | Buscar `${` dentro de archivos SQL en cada revisión. |

### 2.8 XSS y CSRF

| Ataque | Mitigación |
|---|---|
| **XSS almacenado** | Contenido editable (productos, beneficios) se **escapa** al renderizar. No se usa `innerHTML` con datos de BD sin escapar. |
| **XSS reflejado** | Toda entrada se valida y se escapa. Plantillas con autoescapado. |
| **CSRF** | Token por sesión en operaciones de escritura del panel + `SameSite=Lax`. |
| **Clickjacking** | `X-Frame-Options` / `frame-ancestors` en CSP. |
| **CSP** | Política restrictiva. `script-src 'self'` (+ el dominio del proveedor de pagos si su SDK lo requiere,documentado). **Evitar `unsafe-inline`**. |

### 2.9 Denegación de servicio y abuso

| Recurso | Control |
|---|---|
| **Login** | Rate limit por IP + por email. |
| **Recuperación de contraseña** | Rate limit por IP + por email. Límite diario por email. |
| **Crear pedido** | Rate limit por IP. Evita spam de pedidos y agotamiento de stock. |
| **Checkout / DNI** | Rate limit por IP. Un flood a la API de DNI consumiría créditos. |
| **Webhook** | Rate limit tolerante (el proveedor manda varios) + idempotencia. |
| **Consulta de stock (admin)** | Rate limit suave. |
| **Global** | Límite base por IP para todas las rutas. |

### 2.10 Datos personales (Ley N.º 29733)

| Principio | Aplicación |
|---|---|
| **Minimización** | Solo se recoge lo necesario para entregar el pedido. El DNI es opcional. |
| **Finalidad** | Solo para gestionar el pedido y la entrega. No se comparte con terceros. |
| **Confidencialidad** | Cifrado en tránsito (HTTPS). En reposo, depende del motor de BD. |
| **Acceso restringido** | Solo el vendedor (y en el futuro, roles autorizados). |
| **Registro de auditoría** | `order_status_history` + `inventory_movements` registran quién hizo qué. |
| **Eliminación** | Política a definir con el negocio (retención para efectos fiscales/contables). **Pendiente de decisión.** |

> **Pendiente de decisión (no bloquea la v1):** periodo de conservación de datos de clientes y procedimiento de baja/eliminación. Requiere criterio del negocio y, posiblemente, del asesor contable.

---

## 3. Gestión de secretos

| Regla | Detalle |
|---|---|
| **`.env` nunca en Git** | Bloqueado por `.gitignore` desde el commit 1. |
| **`.env.example` sí en Git** | Plantilla con **todos los nombres** de variable y valores de ejemplo sin secretos. |
| **Un solo origen** | `src/config/env.js` lee y valida `.env`. Nadie más lee `process.env` directamente para config. |
| **Validación al arrancar** | Si falta una variable obligatoria, la app **falla rápido** con un mensaje claro, no con un error confuso en runtime. |
| **Rotación** | En caso de sospecha de exposición: rotar la credencial, actualizar `.env`, **nunca** hacer commit del nuevo valor. |
| **Producción** | Variables de entorno del sistema/hosting, no archivo `.env` en disco si es posible. |
| **Buenas prácticas con el `.env`** | El README documenta que si se comparte pantalla o se graba, el `.env` no debe estar visible. |

---

## 4. Errores y logging

| Regla | Detalle |
|---|---|
| **Producción** | Respuesta genérica. Sin stack, sin SQL, sin rutas internas, sin credenciales. |
| **Desarrollo** | Stack completo para depurar. |
| **Logging** | `pino` con JSON estructurado. Nivel configurable. |
| **PII en logs** | **Enmascarar** DNI, teléfono, correo, códigos de recuperación. Nunca registrar contraseñas, tokens, cookies ni claves. |
| **Request ID** | Cada petición recibe un ID único. Se incluye en el log y en los errores, para correlación. |
| **Auditoría de negocio** | Separada del log técnico: `order_status_history` e `inventory_movements` son la evidencia. |
| **Webhook** | Log de cada webhook: `provider_event_id`, resultado, si fue duplicado. **Sin** el cuerpo si contiene datos sensibles. |

---

## 5. Cabeceras HTTP (Helmet)

| Cabecera | Configuración |
|---|---|
| `Content-Security-Policy` | `default-src 'self'`; `script-src 'self'`; `style-src 'self'`; `img-src 'self' data: blob:`; `connect-src 'self'` + origen del proveedor de pagos; `frame-src` proveedor de pagos; `object-src 'none'`; `base-uri 'self'`; `form-action 'self'` |
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `DENY` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` (**solo en producción, con HTTPS**) |
| `X-DNS-Prefetch-Control` | `off` |
| `Cross-Origin-Opener-Policy` | `same-origin` |
| `Permissions-Policy` | Restringir geolocalización, cámara, micrófono. |

---

## 6. Base de datos

| Control | Detalle |
|---|---|
| **Usuario de aplicación** | `nanai_app` con **privilegios mínimos**: `SELECT, INSERT, UPDATE, DELETE, EXECUTE`. **Sin** `DROP`, `ALTER`, `CREATE`, `GRANT`, `FILE`, `SUPER`. |
| **Root** | Solo para migraciones/operaciones administrativas. **La app nunca conecta como root.** |
| **Conexión** | `caching_sha2_password` (default MySQL 8). Conexión por TCP a localhost, no por socket en producción. |
| **Bind address** | `bind-address = 127.0.0.1` en producción si MySQL está en el mismo servidor. |
| **Consultas** | Parametrizadas. Sin concatenación. |
| **Transacciones** | Toda operación multi-escritura en transacción con `COMMIT`/`ROLLBACK`. |
| **Backups** | Procedimiento documentado (dump periódico + rotación). **Pendiente de definir periodicidad.** |

---

## 7. HTTPS

| Entorno | Requisito |
|---|---|
| **Producción** | **Obligatorio.** Certificado válido (Let's Encrypt o similar, sin costo recurrente obligatorio). |
| **Desarrollo** | HTTP local es aceptable. Si se prueba desde otro dispositivo, usar un túnel con TLS. |
| **Configuración** | `cookie.secure = true` en producción. HSTS con `max-age` largo. Redirección HTTP→HTTPS. |

---

## 8. Checklist de hardening (Fase 11)

```text
[ ] .env ausente de Git y del historial (verificar con: git log --all -- .env)
[ ] .env.example presente y sin secretos reales
[ ] Sin contraseñas en texto plano en el código
[ ] Helmet con CSP sin 'unsafe-inline' en scripts
[ ] Rate limiting activo en login, recuperar, orders, webhook
[ ] CSRF activo en todas las escrituras del panel
[ ] Cookies: httpOnly, SameSite, Secure (prod)
[ ] Sesiones en MySQL, con expiración y revocación
[ ] Consultas 100% parametrizadas (revisar que no haya concatenación)
[ ] Validación Zod en todas las entradas mutables
[ ] Webhook: firma + verificación cruzada + idempotencia
[ ] Usuario MySQL con privilegios mínimos (no root)
[ ] Errores de producción sin stack/SQL/rutas
[ ] PII enmascarada en logs
[ ] HTTPS con HSTS en producción
[ ] Backups automáticos probados (restauración probada al menos 1 vez)
[ ] Dependencias auditadas (npm audit) sin vulnerabilidades altas
[ ] Límite de tamaño de archivo en la subida de imágenes
[ ] Validación del tipo MIME real de las imágenes subidas
```

---

## 9. Riesgos residuales aceptados en la v1

| Riesgo | Impacto | Mitigación / decisión |
|---|---|---|
| **Proxy TLS de la red university (Fortinet)** | Las credenciales de terceros (pasarela, DNI) son inspeccionables por el proxy de la red | En desarrollo es aceptable. **En producción, el servidor debe estar fuera de esa red** o tras VPN. Rotar claves. **Pendiente de documentar en el despliegue.** |
| **Código de pedido como única credencial** | Un atacante con muchos intentos podría adivinar códigos | Rate limiting + enmascarado de PII + respuestas genéricas. Riesgo aceptado para el volumen actual. **Revisar si el volumen crece.** |
| **Boleta interna no es comprobante SUNAT** | No cumple obligación fiscal formal | Declarado en alcance. Módulo `integrations/sunat/` planificado. **Debeolversolverse antes de vender a empresas que requieran factura.** |
| **Pago manual no automatizado** | El vendedor debe verificar Yape/Plin a mano | Es la realidad de un emprendimiento pequeño. Escala futura: pasarela que soporte Yape/Plin con webhook. |
| **Sin 2FA en el panel** | Una contraseña filtrada da acceso total | Rate limiting + Session + política de contraseñas. **2FA es una mejora prioritaria post-v1.** |
| **Una sola base de datos** | Un error grave afecta todo | Aceptado: el volumen no justifica réplicas ni particionado. **Se revisa si el negocio crece.** |

---

## 10. Procedimientos operativos

| Procedimiento | Frecuencia | Responsable |
|---|---|---|
| **Rotación de credenciales** | Cada 6 meses o ante sospecha | Vendedor |
| **Copia de seguridad de BD** | Diaria (ver §"Pendiente de definir") | Automático + verificación mensual |
| **Revisión de `npm audit`** | Mensual | Desarrollo |
| **Revisión de accesos** (quién tiene rol) | Trimestral | Vendedor |
| **Pruebas de restauración de backup** | Trimestral | Desarrollo |
| **Revisión de logs por anomalías** | Semanal | Vendedor |

---

> **Siguiente paso:** `08-instalacion.md` con los pasos para levantar el proyecto en limpio, y luego los ADR con el detalle de cada decisión técnica.
