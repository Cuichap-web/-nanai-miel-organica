# NANAI Miel Orgánica

Plataforma web de comercio electrónico y gestión interna para **NANAI Miel Orgánica**,
emprendimiento de miel orgánica con clientes iniciales en Chiclayo (Lambayeque, Perú).

> **Estado del proyecto:** Fase 1 — Especificación y diseño.
> La base de código empieza en la Fase 2. Este repositorio documenta el proceso.

---

## Propósito del repositorio

El proyecto tiene dos objetivos simultáneos:

1. **Funcional:** dar soporte real al negocio — catálogo, pedidos, pagos, inventario,
   ventas presenciales, comprobantes y seguimiento.
2. **Académico:** servir como proyecto universitario para aprender desarrollo web,
   arquitectura de software, bases de datos, seguridad y buenas prácticas.

Por eso el código y la documentación avanzan **por etapas**: cada decisión técnica
importante queda registrada como un *Architectural Decision Record* (ADR) en
`docs/decisiones/`, con sus alternativas descartadas y sus consecuencias.

---

## Stack tecnológico

| Capa | Tecnología | Nota |
|---|---|---|
| Frontend | HTML5, CSS3, JavaScript (módulos ES nativos) | Sin frameworks en la v1 |
| Backend | Node.js 24 · Express 5.3 | Manejo de errores async integrado |
| Base de datos | MySQL 8.0 · procedimientos almacenados | `DECIMAL(10,2)` para importes |
| Patrón | MVC por capas: rutas → controladores → servicios → modelos → BD | Dependencias hacia adentro |
| API | REST versionada `/api/v1` | Contrato independiente del canal |
| Seguridad | Argon2id · sesiones en servidor · Helmet · rate limiting · CSP | Sin secretos en el repositorio |
| Control de versiones | Git + GitHub | Commits pequeños y descriptivos |

Decisiones con su justificación completa: [`docs/decisiones/`](docs/decisiones/).

---

## Documentación

| Documento | Contenido |
|---|---|
| [`01-requisitos.md`](docs/01-requisitos.md) | Alcance, RF-001…RF-067, RNF-001…RNF-045, restricciones, supuestos |
| [`02-actores-y-casos-de-uso.md`](docs/02-actores-y-casos-de-uso.md) | Actores, CU-01…CU-38, matriz de permisos |
| [`03-reglas-de-negocio.md`](docs/03-reglas-de-negocio.md) | RN-01…RN-16, máquina de estados, reglas de stock y reserva |
| [`04-arquitectura.md`](docs/04-arquitectura.md) | Capas, estructura de carpetas, flujo de una petición |
| [`05-modelo-de-datos.md`](docs/05-modelo-de-datos.md) | Modelo Entidad-Relacional, DDL, índices, procedimientos |
| [`06-api.md`](docs/06-api.md) | Endpoints, contratos, catálogo de errores |
| [`07-seguridad.md`](docs/07-seguridad.md) | Modelo de amenazas STRIDE y controles |
| [`08-instalacion.md`](docs/08-instalacion.md) | Requisitos y puesta en marcha |

### Decisiones registradas (ADR)

| ADR | Decisión |
|---|---|
| [ADR-001](docs/decisiones/ADR-001-stack-backend.md) | Stack backend: Express 5 + ESM + Argon2id + Zod |
| [ADR-002](docs/decisiones/ADR-002-arquitectura-por-capas.md) | Arquitectura por capas (MVC extendido) |
| [ADR-003](docs/decisiones/ADR-003-autenticacion-sesiones.md) | Autenticación por sesiones en servidor |
| [ADR-004](docs/decisiones/ADR-004-motor-de-precios.md) | Motor de precios con IGV incluido y extensible |
| [ADR-005](docs/decisiones/ADR-005-stock-por-regla.md) | Stock por regla: dos libros y punto único de consumo |
| [ADR-006](docs/decisiones/ADR-006-maquina-de-estados-por-datos.md) | Máquina de estados por datos |
| [ADR-007](docs/decisiones/ADR-007-adaptadores.md) | Adaptadores para integraciones externas |
| [ADR-008](docs/decisiones/ADR-008-stored-procedures.md) | Stored Procedures como vía de acceso a datos |
| [ADR-009](docs/decisiones/ADR-009-registro-npm-y-proxy-fortinet.md) | Registro npm por mirror y proxy Fortinet |
| [ADR-010](docs/decisiones/ADR-010-checkout-invitado.md) | Checkout como invitado y consulta por código |
| [ADR-011](docs/decisiones/ADR-011-medios-de-pago.md) | Medios de pago v1: tarjeta y pago móvil verificado |

---

## Estructura prevista

```
miel nanai/
├─ docs/          Documentación y ADRs
├─ db/            schema.sql · seed.sql · procedures/ · migrations/
├─ src/           config · routes · controllers · services · models
│                 middleware · validators · utils · integrations · jobs
├─ public/        Frontend público y panel administrativo
├─ storage/       Imágenes en desarrollo (ignorado por Git)
└─ tests/         Pruebas con el runner nativo de Node
```

---

## Puesta en marcha

La instalación completa se documenta en [`docs/08-instalacion.md`](docs/08-instalacion.md).

```bash
npm install
cp .env.example .env     # y completar con las credenciales reales
npm run db:migrate       # crea el esquema y los procedimientos
npm run dev              # http://localhost:3000
```

---

## Estructura de commits

```
feat:   nueva funcionalidad
fix:    corrección de error
refactor: reorganización sin cambio de comportamiento
docs:   documentación
chore:  configuración, dependencias, andamiaje
```

Los secretos (`.env`) nunca se versionan. Ver `.gitignore` y `docs/07-seguridad.md`.

---

## Licencia

Proyecto académico y de negocio propio. Uso educativo y comercial por el titular
de NANAI Miel Orgánica.
