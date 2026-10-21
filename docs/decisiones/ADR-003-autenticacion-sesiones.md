# ADR-003 — Autenticación del panel por sesiones en servidor

**Estado:** Aprobado
**Fecha:** 2026-10-21
**Ámbito:** Backend / Seguridad

---

## Contexto

El panel administrativo debe estar protegido. El diseño debe admitir **varios administradores con roles distintos** en el futuro, aunque hoy haya uno solo. El cliente público, en cambio, **no** se autentica: compra como invitado y consulta su pedido con un código único.

## Decisión

Usar **sesiones en servidor** (`express-session`) con store en **MySQL**, y una cookie de sesión opaca `httpOnly`.

| Aspecto | Decisión |
|---|---|
| Mecanismo | `express-session` + `express-mysql-session` |
| Almacenamiento | Tabla `sessions` en MySQL |
| Cookie | `httpOnly`, `SameSite=Lax`, `Secure` (producción), nombre no descriptivo, `Path=/` |
| Hashing de contraseñas | Argon2id (`@node-rs/argon2`) — ver ADR-001 |
| Expiración | Por inactividad, con renovación opcional |
| Revocación | Eliminación de la fila en `sessions` → invalidación inmediata |
| Autorización | Middleware por ruta + roles/permisos (`roles`, `role_permissions`, `user_roles`) |
| Cliente público | **Sin** autenticación. Acceso por código de pedido. |
| CSRF | Token de sesión en operaciones de escritura del panel |

## Alternativas consideradas

### JWT en cookie `httpOnly`

| A favor | En contra |
|---|---|
| Sin estado en el servidor: escala horizontalmente sin sesiones pegadas | **No revocable** antes de expirar sin una lista negra |
| Verificable sin consultar la BD en cada petición | La lista negra es, de hecho, una tabla de sesiones: se reinventa el problema |
| Compacto | Si la clave se filtra, el atacante puede firmar tokens hasta que expire |
| — | Difícil de "cerrar sesión en todos los dispositivos" |

**Descartado** porque el caso de uso real es "el vendedor quiere poder cerrar la sesión en su celular si pierde el teléfono". Con JWT eso exige una lista negra, que es exactamente una tabla de sesiones. El beneficio (stateless) no se materializa con **un** administrador.

### Token opaco propio (hash SHA-256 en tabla `sessions`)

| A favor | En contra |
|---|---|
| Control total, sin dependencias | Se reimplementa un estándar: riesgo de errores sutiles (timing attacks, expiración, rotación) |
| Formato mínimo | `express-session` ya resuelve esto, bien auditado |

**Descartado**: reimplementar criptografía de sesiones es exactamente el tipo de sobreingeniería que el proyecto quiere evitar.

### Contraseña hasheada + sesión en memoria (`MemoryStore`)

Descartado: `MemoryStore` no escala a más de un proceso y **se pierde al reiniciar** (el vendedor tendría que iniciar sesión cada vez que se despliegue). Además no permite reiniciar la app sin invalidar sesiones.

## Consecuencias

**Positivas**
- **Revocación inmediata y trivial**: borrar la fila de sesión.
- Se puede ver quién tiene sesión activa (auditoría útil para un negocio real).
- Compatible con "cerrar sesión en todos los dispositivos".
- La cookie no es accesible desde JavaScript (`httpOnly`), lo que neutraliza XSS-based session theft.
- El store en MySQL sobrevive reinicios y despliegues.

**Negativas / costos**
- **Cada petición autenticada consulta la BD** (verificar la sesión). Con un vendedor y tráfico bajo, es irrelevante. Si el tráfico creciera, se puede cachear la verificación en memoria con invalidación por escritura.
- Requiere que la tabla `sessions` esté en la base de datos y se limpie de sesiones expiradas (job o `ON DELETE` por barrido).
- El estado de la sesión consume espacio en la BD (hoy: `email` y `roles`; después de `express-mysql-session` en JSON).

**Impacto en el proyecto**
- Se añade `express-session` y `express-mysql-session` a las dependencias.
- El middleware `auth.js` valida la sesión y adjunta `req.user` y `req.userRoles`.
- Las rutas del panel se montan **bajo un router separado** (`/api/v1/admin`), con el middleware aplicado a todo el router. Un error de montaje no expone las rutas públicas.
- El logout destruye la sesión en servidor **y** borra la cookie.
- El cambio de contraseña invalida las sesiones activas del usuario.
