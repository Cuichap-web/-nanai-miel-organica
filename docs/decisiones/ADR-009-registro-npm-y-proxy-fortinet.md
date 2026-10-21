# ADR-009 — Registro npm por mirror y gestión del proxy Fortinet

**Estado:** Aprobado
**Fecha:** 2026-10-21
**Ámbito:** Entorno de desarrollo / Operación

---

## Contexto

En la red del proyecto, un proxy **Fortinet** intercepta el tráfico TLS hacia `registry.npmjs.org`. El certificado que presenta no está en la cadena de confianza de Node, por lo que cualquier instalación falla:

```
npm error code: UNABLE_TO_VERIFY_LEAF_SIGNATURE
npm error errno UNABLE_TO_VERIFY_LEAF_SIGNATURE
npm error certificate has expired
```

**Causa raíz:** la inspección TLS del proxy rompe la cadena de confianza. No es un problema de npm, ni de Node, ni del proyecto. Y **no se debe "arreglar" desactivando la verificación de TLS**, porque eso abriría la puerta a ataques de intermediario en las dependencias.

## Decisión

### Medida inmediata (operativa, a nivel de usuario)

```bash
npm config set registry https://registry.npmmirror.com --location=user
```

| Aspecto | Decisión |
|---|---|
| Dónde se configura | **Nivel usuario** (`~/.npmrc`), **no** en el repositorio |
| Motivo | Es una particularidad de **esta red**, no del proyecto. Un `.npmrc` versionado obligaría a todos los/usuarios de la red (incluidos los que están fuera del proxy) a usar el mirror |
| Verificación de integridad | `npm` sigue verificando el `integrity` (hash SHA-512) de cada paquete contra el `package-lock.json`. El mirror no puede entregar un paquete alterado sin que la instalación falle |
| Riesgo residual | El mirror es un tercero. Se mitiga con `npm audit` y con el `package-lock.json` versionado |

**Verificado en esta máquina:** `express` + `mysql2` → 75 paquetes en 9 s. `@node-rs/argon2` → prebuild `win32-x64-msvc` instalado correctamente, `hash`/`verify` funcionando.

### Medida definitiva (pendiente del administrador de red)

Obtener el **certificado raíz (CA) del proxy Fortinet** e instalarlo en el almacén de confianza del sistema operativo:

1. Descargar el CA desde el portal de administración del FortiGate.
2. Doble clic → *Instalar Certificado* → *Entidades de Emisión de Certificados Raíz de Confianza*.
3. `npm config delete registry --location=user` y `npm ping` para confirmar.

Con el CA instalado, se vuelve al registro oficial y la inspección TLS del proxy deja de ser un problema.

## Alternativas consideradas

### `npm config set strict-ssl false`

**Descartado.** Desactiva la verificación del certificado TLS: el navegador de contenidos de `npm install` aceptaría **cualquier** certificado, incluyendo uno de un atacante en la red. Es la peor respuesta posible: convierte un error visible y ruidoso en un fallo silencioso y peligroso. **Nunca debe usarse**, ni siquiera temporalmente.

### Usar `NODE_TLS_REJECT_UNAUTHORIZED=0`

Descartado por la misma razón, con el añadido de que afecta a **todas** las conexiones TLS del proceso Node, no solo a npm.

### Vendorizar las dependencias (`npm pack` y commitear `vendor/`)

Descartado. Infla el repositorio, complica las actualizaciones y no elimina el riesgo: los paquetes seguirían viniendo de la red en algún momento.

### Cambiar de gestor de paquetes (pnpm, yarn)

Descartado. El problema es **TLS**, no el cliente HTTP. `pnpm` y `yarn` usan el mismo almacén de Node y fallarían igual.

### Pedir un certificado firmado por una CA pública en el proxy

Es la solución ideal del lado del admin de red, pero depende de la política corporativa y **no está bajo control del proyecto**.

## Consecuencias

**Positivas**
- `npm install` funciona en la red university sin intervención del admin de red.
- El repositorio queda limpio: nada de `.npmrc` con un mirror que no aplica a todos.
- La seguridad de la cadena de suministro se mantiene: `package-lock.json` versionado + verificación de `integrity`.

**Negativas / costos**
- Dependencia de un tercero (el mirror) mientras el CA no esté instalado. Mitigado por la verificación de integridad.
- El `package-lock.json` generado con el mirror puede diferir del generado con el registro oficial en el campo `resolved` (URL). **Esto no afecta la instalación ni la seguridad**, pero genera ruido en los diffs. Se normaliza si el CA se instala.
- Depende de la disponibilidad del mirror.

**Impacto en el proyecto**
- `docs/08-instalacion.md` §2.2 documenta el procedimiento completo, para que cualquier persona del equipo lo reproduzca.
- `package-lock.json` **sí** se versiona: es la garantía de que todos instalan exactamente las mismas versiones.
- Se ejecuta `npm audit` periódicamente.
