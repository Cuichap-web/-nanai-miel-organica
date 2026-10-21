# ADR-001 — Stack backend: Express 5 + ESM + Argon2id + Zod

**Estado:** Aprobado
**Fecha:** 2026-10-21
**Ámbito:** Backend

---

## Contexto

El proyecto requiere un backend en Node.js y Express con API REST, sin frameworks frontend en la v1. Necesitamos decidir: versión de Express, sistema de módulos, algoritmo de hashing de contraseñas y librería de validación.

## Decisión

| Elemento | Elección | Versión |
|---|---|---|
| Runtime | Node.js | 24 LTS |
| Framework HTTP | Express | 5.3 |
| Sistema de módulos | **ESM** (`"type": "module"`) | — |
| Hashing de contraseñas | `@node-rs/argon2` (Argon2id) | 2.2 |
| Validación | `zod` | 4.x |
| Acceso a datos | `mysql2/promise` | 3.x |

## Alternativas consideradas

### Express 4 vs Express 5

| | Express 4 | Express 5 (elegido) |
|---|---|---|
| Errores en handlers `async` | **No** se capturan automáticamente. Requiere wrapper `catchAsync` en cada ruta | **Sí**, se delegan al middleware de error |
| Estado | Mantenimiento (deprecated) | Actual (`latest` en npm desde 2024) |
| Requisitos de Node | ancient | 18+ |

**Motivo:** el requisito de "manejo centralizado de errores" es un pilar de la arquitectura. Express 5 lo resuelve **en el framework**, sin envolver cada handler. Eso elimina una categoría entera de errores silenciosos (un `await` sin `try/catch` en Express 4 deja la petición colgada hasta el timeout).

### Argon2 vs bcrypt vs bcryptjs

| | `@node-rs/argon2` | `bcrypt` | `bcryptjs` |
|---|---|---|---|
| Algoritmo | Argon2id | bcrypt | bcrypt (emulado) |
| Binario precompilado Win x64 | **Sí** | No garantizado | N/A (JS puro) |
| Requiere compilador C++ | No | **Posible** | No |
| Recomendado por OWASP | **Sí** (1ª opción) | Sí (2ª opción) | Sí (pero lento) |

**Motivo:** Argon2id es la primera recomendación de OWASP. `@node-rs/argon2` usa napi-rs, que publica binarios precompilados para `win32-x64-msvc`, `linux-x64-gnu`, `darwin-arm64` y más. **Verificado en esta máquina**: instala y funciona sin Visual Studio Build Tools. `bcrypt` habría requerido `node-gyp` y un compilador MSVC, que el proyecto no da por supuesto.

**Decisión de seguridad:** nunca se implementa "desencriptar contraseña". Argon2id es unidireccional por diseño. La comparación se hace con `argon2.verify()`, que es de tiempo constante.

### Zod vs express-validator vs Joi

| | Zod (elegido) | express-validator | Joi |
|---|---|---|---|
| Inferencia de tipos | **Nativa** | No | No |
| Reutilizable fuera de Express | **Sí** | No | Sí |
| Curva de aprendizaje | Media | Baja | Media |

**Motivo:** los esquemas Zod se pueden compartir entre la validación de entrada, la construcción de tipos de TypeScript y la documentación de la API. `express-validator` ata los esquemas al framework, lo que los hace reutilizables solo dentro de Express.

### CommonJS vs ESM

**Motivo:** ESM es el sistema de módulos nativo y ya estable en Node. `import`/`export` explícitos son más legibles que `require`/`module.exports`, y las importaciones son estáticas (más fácil de analizar). Con `"type": "module"` en `package.json`, todo el proyecto es consistente.

## Consecuencias

**Positivas**
- El manejo de errores es nativo del framework, no un patrón que cada devs pueda olvidar.
- Sin dependencia de compilador nativo: `npm install` funciona en cualquier máquina con Node.
- Los esquemas de validación son la **única** definición de la forma de un request, reutilizable y testeable.

**Negativas / costos**
- ESM es estrictamente más estricto que CommonJS: no hay `require` dinámico de rutas, y los imports deben incluir la extensión `.js`. Esto es disciplinario, no un problema.
- `@node-rs/argon2` es un binding nativo: hay que decidir su versión de SO y Node. Se documentará en `package.json` con `engines`.

**Impacto en el proyecto**
- Todo archivo JS usará `import`/`export`.
- Los handlers `async` no necesitarán `try/catch` para delegar errores.
- `.env` se validará con `zod` en `src/config/env.js`.
