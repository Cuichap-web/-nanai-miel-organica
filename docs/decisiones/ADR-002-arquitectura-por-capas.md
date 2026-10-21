# ADR-002 — Arquitectura por capas (MVC extendido)

**Estado:** Aprobado
**Fecha:** 2026-10-21
**Ámbito:** Backend

---

## Contexto

El flujo exigido es:

```
Frontend → API REST → Routes → Controllers → Services → Models → Stored Procedures → MySQL
```

El riesgo clásico de este flujo es que en la práctica los controladores terminan haciendo consultas SQL y los servicios se convierten en pasamanos vacíos. Eso produce un sistema difícil de mantener: cambiar una regla de negocio obliga a tocar controladores, y una consulta SQL queda incrustada en la capa HTTP.

## Decisión

Adoptar **MVC por capas** con **reglas de dependencia estrictas** (las flechas solo apuntan hacia adentro):

```
Rutas → Middlewares → Controladores → Servicios → Modelos → Stored Procedures → MySQL
                              ↓              ↓
                        Integraciones    Jobs
```

| Capa | Puede llamar a | **No puede** llamar a |
|---|---|---|
| Rutas | Middlewares, Controladores | Servicios, Modelos, BD |
| Middlewares | Utilidades, Config | Lógica de negocio |
| Controladores | Servicios | Modelos, SQL, Integraciones |
| Servicios | Servicios, Modelos, Integraciones, Utilidades | Controladores, Rutas |
| Modelos | Stored Procedures, BD | Servicios, Controladores |
| Integraciones | APIs externas | Servicios, Controladores |
| Jobs | Servicios | Controladores |

**Reglas innegociables:**
1. Cero SQL en controladores.
2. Cero lógica de negocio en rutas y controladores.
3. Cero lógica de envío de correo en controladores (va al servicio de notificaciones).
4. Cero lógica de Excel en controladores (va al servicio de reportes).
5. Las transacciones se abren en la **capa de servicio**, nunca en el modelo.

## Alternativas consideradas

### MVC clásico de 3 capas (Model-View-Controller)

Descartado. "Modelo" en el sentido clásico de Active Record mezcla datos y comportamiento. Con un monolito modular y MySQL, esa mezcla hace imposible aplicar la regla "el stock se descuenta siempre dentro de una transacción con su movimiento" de forma consistente, porque el comportamiento se reparte entre el modelo y el controlador.

### Capa de repositorios adicional (Model → Repository → DB)

Considerado y **descartado por ahora**. Tendría valor si el acceso a datos tuviera más de una fuente (API, caché, BD). Hoy la única fuente es MySQL y los SP ya encapsulan el acceso. Añadir una capa intermedia sería sobreingeniería. **Se revisa** si aparece una segunda fuente de datos.

### Servicios de dominiovs. servicios de aplicación

Se usa una **única** capa `services/`. Distinguir dominio/aplicación es una distinción de DDD (Domain-Driven Design) valuable en sistemas grandes con reglas complejas. En este proyecto, con un monolito y un dominio de complejidad media, dos capas de servicios generarían más ceremonia que valor. El tamaño de cada archivo de servicio y la cohesión interna bastan.

## Consecuencias

**Positivas**
- La lógica de negocio es **testeable sin HTTP**: se llama al servicio directamente.
- Cambiar la pasarela de pagos no toca controladores ni servicios de negocio (ADR-007).
- El SQL está en un solo lugar, lo que hace posible cambiar MySQL por otro motor en el futuro.

**Negativas / costos**
- Más archivos y más indirección. Un `GET /products` cruza 4 capas. **Es el precio de la testeabilidad**, y se asume conscientemente.
- Riesgo de capas vacías ("servicio que solo delega al modelo"). Se evita exigiendo que los servicios contengan *algo* de lógica: validación, orquestación, transacción o decisión.
- Requiere disciplina del equipo para no saltarse capas por comodidad. Se mitiga con revisión de código.

**Impacto en el proyecto**
- `src/app.js` crea la app; `src/server.js` la arranca. Permite testear sin abrir puertos.
- Los servicios de negocio reciben dependencias por parámetro o por módulo importado, para poder inyectar dobles en las pruebas.
