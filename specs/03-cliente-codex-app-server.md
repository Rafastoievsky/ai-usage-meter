# SPEC 03 — Cliente Codex App Server

> **Estado:** Draft
> **Depende de:** SPEC 00 — Arquitectura, alcance y seguridad (`Approved`) y SPEC 02 — Base del bridge y configuración (`Approved` e `Implemented-Verified` antes de implementar SPEC 03)
> **Precondición heredada:** la corrección de consistencia de SPEC 01 a uv `0.11.29` debe estar aplicada y verificada
> **Fecha:** 2026-07-21
> **Fuente base:** `docs/AI_USAGE_METER_ESP32_SPEC_DRIVEN_PLAN_V2.md`
> **Fuente normativa externa:** [documentación de Codex App Server](https://github.com/openai/codex/blob/main/codex-rs/app-server/README.md) y esquema estable correspondientes a `codex-cli 0.144.6`, generado sin `--experimental`
> **Repositorio:** `ai-usage-meter`
> **Componente:** `bridge/`
> **Plataforma certificada:** macOS sobre Apple Silicon (`arm64`), Python `3.14.6`
> **Codex CLI fijado:** `codex-cli 0.144.6`
> **Objetivo:** Integrar en el bridge un cliente tipado, persistente, supervisado y degradable para Codex App Server mediante JSON-RPC sobre stdio, conservando en memoria únicamente la cuenta y las ventanas de límites necesarias, sin exponer el proceso a la red ni ampliar todavía la API del dispositivo.

## Condición de implementación

SPEC 03 puede revisarse y aprobarse antes de implementar SPEC 02.

La implementación de SPEC 03 queda bloqueada hasta que se cumplan simultáneamente estas condiciones:

- SPEC 02 tiene estado `Implemented-Verified`.
- La corrección de consistencia de SPEC 01 usa uv `0.11.29` en todas sus referencias coordinadas.
- El bootstrap reproducible de SPEC 01 y el proyecto instalable de SPEC 02 funcionan en macOS `arm64`.

Una precondición incumplida produce `BLOCKED`.

No autoriza adaptar `main.py` contra una interpretación provisional de SPEC 02.

## Alcance

**Incluye:**

- Fijar `codex-cli 0.144.6` para macOS `arm64`.
- Descargar el artefacto oficial mediante un bootstrap explícito.
- Validar el SHA-256 del archivo descargado y del ejecutable extraído.
- Instalar una copia controlada en `~/Library/Application Support/AIUsageMeter/tools/codex/0.144.6/codex`.
- Resolver el home desde el usuario efectivo.
- Ejecutar únicamente la ruta absoluta controlada.
- Rechazar `PATH`, shell, symlinks y autodetección del ejecutable.
- Validar antes de cada arranque el tipo de archivo, propietario, permisos, versión y SHA-256.
- Generar sin `--experimental` el JSON Schema estable correspondiente a `codex-cli 0.144.6`.
- Versionar el esquema combinado y comprobar su reproducción exacta.
- Ejecutar `codex app-server` como proceso hijo privado mediante stdin, stdout y stderr.
- Implementar JSON-RPC delimitado por líneas.
- Ejecutar el handshake obligatorio `initialize` → respuesta satisfactoria → `initialized`.
- Enviar `experimentalApi=false`.
- Limitar por construcción los métodos salientes a `initialize`, `initialized`, `account/read` y `account/rateLimits/read`.
- Enviar `account/read` con `refreshToken=false`.
- Aceptar únicamente respuestas correlacionadas y las notificaciones `account/updated` y `account/rateLimits/updated`.
- Implementar correlación concurrente, IDs monotónicos, serialización de escrituras, timeouts, cancelación, límite de línea, validación UTF-8 y tratamiento de EOF.
- Traducir las respuestas a DTOs tipados mínimos.
- Impedir que JSON crudo salga del límite del cliente.
- Mantener en memoria el último snapshot válido de cuenta y límites.
- Marcar el snapshot como `current` o `stale`.
- Supervisar un único proceso Codex con backoff `1, 2, 4, 8, 16, 30, 60` segundos.
- Aplicar jitter controlado y reiniciar el backoff tras 60 segundos saludables.
- Mantener el bridge operativo cuando Codex falle o resulte incompatible.
- Integrar el supervisor con el arranque y apagado coordinados definidos por SPEC 02.
- Preservar sin cambios los cuerpos y la semántica de `/healthz` y `/readyz`.
- Probar el cliente con un proceso falso controlado.
- Cubrir concurrencia, errores, timeouts, notificaciones, datos no reconocidos, cierre, reinicio y redacción.
- Registrar evidencia reproducible de versión, hashes, esquema, calidad y pruebas.

**Fuera de alcance — reservado para specs posteriores:**

- `/api/v1/usage` o cualquier endpoint nuevo.
- Exponer el estado de Codex mediante HTTP.
- Autenticación de la API del dispositivo.
- Persistencia, caché durable o recuperación del snapshot después de reiniciar el bridge.
- Normalización final del modelo público de uso.
- Integración con Claude.
- Aprovisionamiento o rotación de tokens.
- Gestión de cuentas, login, logout, consumo de créditos o modificación de límites.
- API experimental de Codex.
- Comunicación TCP, WebSocket o cualquier exposición de App Server a la red.
- Descubrimiento del ejecutable mediante `PATH`.
- Actualización automática de Codex.
- Recuperación mediante más de un supervisor o más de un proceso hijo.
- `launchd`, contenedores y workflows de CI.
- Soporte certificado para Linux, Windows o macOS Intel.

## Artefacto Codex fijado

El lock `toolchain/codex-app-server.lock.json` será la única fuente versionada para validar el artefacto y el esquema.

Debe registrar exactamente:

| Campo | Valor contractual |
|---|---|
| Versión | `0.144.6` |
| Plataforma | `darwin-arm64` |
| Release | `rust-v0.144.6` |
| URL | `https://github.com/openai/codex/releases/download/rust-v0.144.6/codex-aarch64-apple-darwin.tar.gz` |
| SHA-256 del archivo | `023590f828bc9507ac61132ee35e74d3c5d33fb5ba3e1ca4fc2e013a2f71a3d7` |
| SHA-256 del ejecutable | `80a3933d11a9d13ef806aa24f7bb8afc9169cfe4e9b09d6da6a92922cbde9cff` |
| Ruta relativa instalada | `AIUsageMeter/tools/codex/0.144.6/codex` bajo Application Support del usuario efectivo |
| Comando de esquema | `codex app-server generate-json-schema --out <TEMPORAL>` sin `--experimental` |
| Esquema combinado | `bridge/schemas/codex-app-server/0.144.6/codex_app_server_protocol.schemas.json` |
| SHA-256 del esquema combinado | `1a7e561efcc5a5fbb8f45bc79c24da70e948c0e6e02c3e1045307e236e595a98` |

El lock no contiene una ruta absoluta dependiente del usuario.

El bootstrap y el runtime construyen la ruta absoluta desde la identidad efectiva.

## Modelo de datos

Todos los modelos son internos, tipados e inmutables.

Las formas siguientes expresan el contrato que deben implementar los modelos Python.

```python
from enum import StrEnum


class CodexRuntimeState(StrEnum):
    STOPPED = "stopped"
    STARTING = "starting"
    HEALTHY = "healthy"
    DEGRADED = "degraded"
    STOPPING = "stopping"


class CodexFailureCode(StrEnum):
    BINARY_MISSING = "binary_missing"
    BINARY_INVALID = "binary_invalid"
    VERSION_MISMATCH = "version_mismatch"
    SCHEMA_MISMATCH = "schema_mismatch"
    STARTUP_FAILED = "startup_failed"
    PROTOCOL_ERROR = "protocol_error"
    REQUEST_TIMEOUT = "request_timeout"
    UNEXPECTED_EOF = "unexpected_eof"
    PROCESS_EXITED = "process_exited"


class AccountType(StrEnum):
    API_KEY = "api_key"
    CHATGPT = "chatgpt"
    AMAZON_BEDROCK = "amazon_bedrock"


class SnapshotFreshness(StrEnum):
    CURRENT = "current"
    STALE = "stale"
```

`PlanType` conserva exactamente estos valores conocidos por el esquema `0.144.6`:

```text
free
go
plus
pro
prolite
team
self_serve_business_usage_based
business
enterprise_cbp_usage_based
enterprise
edu
unknown
```

`RateLimitReachedType` conserva exactamente:

```text
rate_limit_reached
workspace_owner_credits_depleted
workspace_member_credits_depleted
workspace_owner_usage_limit_reached
workspace_member_usage_limit_reached
```

### Cuenta

```python
class CodexAccount:
    requires_openai_auth: bool
    account_type: AccountType | None
    plan_type: PlanType | None
```

Reglas:

- `account=null` es válido.
- `requires_openai_auth=true` representa Codex saludable sin autenticación OpenAI utilizable.
- `account_type` se deriva únicamente del tipo estable devuelto por `account/read`.
- `plan_type` conserva los valores conocidos, incluido `unknown`.
- Una cuenta `apiKey` no recibe un plan inventado.
- No se conservan email, fuente de credenciales, tokens ni otros metadatos de cuenta.
- El estado autenticado se deriva de estos campos.
- No se inventa ni persiste un indicador adicional.

### Ventanas

```python
class RateLimitWindow:
    used_percent: int
    window_duration_minutes: int | None
    resets_at: int | None
```

Reglas:

- `used_percent` debe estar entre 0 y 100.
- `window_duration_minutes`, cuando existe, debe ser positivo.
- `resets_at` se conserva como timestamp Unix de la fuente.
- Un valor ausente permanece `None`.
- No se inventan duración ni fecha de reinicio.
- Un valor fuera de contrato invalida la respuesta completa.
- No se trunca ni corrige silenciosamente.

### Buckets

```python
class RateLimitBucket:
    bucket_key: str
    limit_id: str | None
    limit_name: str | None
    plan_type: PlanType | None
    rate_limit_reached_type: RateLimitReachedType | None
    primary: RateLimitWindow | None
    secondary: RateLimitWindow | None
```

Reglas:

- Si `rateLimitsByLimitId` está presente, se conservan todos sus elementos.
- Los elementos se ordenan determinísticamente por clave.
- La clave del mapa y `limitId` se conservan por separado.
- La vista histórica `rateLimits` se usa solo como fallback.
- El fallback usa una clave interna estable.
- La vista histórica no se duplica cuando existe la vista multibucket.
- `primary` y `secondary` no se reinterpretan como cinco horas o semanal.
- La normalización por duración pertenece a SPEC 04.
- Se descartan créditos, reset credits, límites monetarios de gasto y campos desconocidos.

### Snapshot y estado del runtime

```python
class CodexSnapshot:
    account: CodexAccount
    buckets: tuple[RateLimitBucket, ...]
    freshness: SnapshotFreshness


class CodexRuntimeStatus:
    state: CodexRuntimeState
    failure_code: CodexFailureCode | None
    process_generation: int
    snapshot: CodexSnapshot | None
```

Reglas:

- El snapshot se reemplaza atómicamente solo cuando las respuestas requeridas son válidas.
- Durante una degradación, el último snapshot válido cambia a `stale`.
- Si todavía no existe un snapshot válido, el estado contiene `snapshot=None`.
- No se generan valores sintéticos.
- No se persisten snapshots, respuestas ni timestamps en disco.
- El estado no conserva mensajes originales de excepción.
- El estado no conserva rutas ni contenido de stderr.
- El JSON recibido solo existe durante parseo y despacho.
- El JSON crudo no entra en DTOs, logs ni excepciones consultables.

### Compatibilidad de datos

- Los campos JSON desconocidos se descartan.
- Un valor desconocido para un enum cerrado invalida la respuesta.
- Una forma incompatible invalida la respuesta.
- Un fallo de validación marca Codex como `DEGRADED`.
- El último snapshot válido se conserva como `stale`.
- Los métodos desconocidos nunca se convierten en datos.
- Los payloads parciales de notificaciones no se fusionan con el snapshot.

## Contrato de instalación

`scripts/bootstrap-codex.sh` es la única operación autorizada para descargar o instalar Codex.

Debe:

1. Comprobar macOS y arquitectura `arm64` antes de descargar.
2. Leer versión, URL y hashes desde `toolchain/codex-app-server.lock.json`.
3. Crear un directorio temporal seguro.
4. Descargar exclusivamente la URL fijada.
5. Validar el SHA-256 del archivo antes de extraer.
6. Extraer únicamente el ejecutable esperado.
7. Rechazar rutas absolutas, `..`, symlinks y entradas inesperadas del archivo.
8. Validar el SHA-256 del ejecutable extraído.
9. Ejecutar `codex --version` desde la ruta temporal y exigir `codex-cli 0.144.6`.
10. Crear la jerarquía destino con propietario efectivo y modo `0700`.
11. Escribir o mover un archivo temporal dentro del directorio destino.
12. Aplicar modo `0500` al ejecutable.
13. Sincronizar el archivo antes del renombrado final.
14. Instalar mediante renombrado atómico.
15. Verificar nuevamente tipo, propietario, modo, versión y hash del destino.
16. Eliminar el temporal sin imprimir rutas sensibles ni contenido del binario.

El bootstrap usa `umask 077` durante toda la operación.

Una ejecución repetida sobre una instalación válida termina exitosamente sin cambiarla.

Un destino inseguro o discrepante produce fallo.

El bootstrap no corrige permisos y no sobrescribe el destino silenciosamente.

El runtime nunca invoca el modo de instalación.

## Contrato del proceso hijo

La ruta runtime se forma como:

```text
<home del usuario efectivo>/Library/Application Support/AIUsageMeter/tools/codex/0.144.6/codex
```

Antes de cada spawn, el runtime valida mediante operaciones equivalentes a `lstat`:

- Cada directorio administrado es un directorio real.
- Ningún componente administrado es symlink.
- Cada directorio administrado pertenece al usuario efectivo.
- Cada directorio administrado tiene modo exacto `0700`.
- El destino es un archivo regular.
- El destino no es symlink.
- El destino pertenece al usuario efectivo.
- El destino tiene modo exacto `0500`.
- El SHA-256 coincide con el lock.
- `codex --version` devuelve exactamente `codex-cli 0.144.6`.

El proceso App Server se ejecuta con argv equivalente a:

```text
[<ruta absoluta validada>, "app-server"]
```

No se usa shell.

No se consulta `PATH`.

El proceso se crea en un grupo de procesos dedicado.

### Entorno permitido

El entorno hijo se construye desde cero.

Las únicas claves permitidas son:

```text
HOME
CODEX_HOME
LANG
LC_ALL
TMPDIR
HTTP_PROXY
HTTPS_PROXY
ALL_PROXY
NO_PROXY
http_proxy
https_proxy
all_proxy
no_proxy
SSL_CERT_FILE
SSL_CERT_DIR
```

Reglas:

- `HOME` procede de la identidad del usuario efectivo.
- `CODEX_HOME` es `<home efectivo>/.codex`.
- El bridge no lee, copia ni registra credenciales administradas por Codex.
- `TMPDIR` solo se hereda si es absoluto, pertenece al usuario efectivo y no es symlink.
- Las variables de proxy y certificados solo se heredan si pertenecen a la lista anterior.
- Una clave no enumerada no se hereda.
- `PATH` no se hereda.
- Variables de API keys, tokens y credenciales no se heredan.
- Las pruebas pueden inyectar el entorno mediante un seam interno.
- Ninguna clave nueva puede añadirse desde `bridge.env`, CLI o variables auxiliares.

## Contrato JSON-RPC

Codex App Server usa mensajes JSON-RPC delimitados por salto de línea.

La propiedad `jsonrpc` puede estar omitida en el wire según el protocolo de App Server fijado.

El cliente no depende de que esa propiedad exista.

### Timeouts internos

| Operación | Timeout |
|---|---:|
| Validación, spawn e inicialización completa | 15 segundos |
| Solicitud ordinaria | 10 segundos |
| Cierre normal | 5 segundos |

Estos valores son constantes internas.

No se configuran mediante `bridge.env`, entorno o CLI.

### Handshake

Cada generación del proceso ejecuta exactamente:

1. Enviar `initialize`.
2. Esperar una respuesta satisfactoria correlacionada.
3. Validar la respuesta.
4. Enviar `initialized`.
5. Iniciar las lecturas de cuenta y límites.

`initialize` contiene:

```json
{
  "clientInfo": {
    "name": "ai-usage-meter-bridge",
    "version": "<versión instalada del paquete bridge>"
  },
  "capabilities": {
    "experimentalApi": false
  }
}
```

No se envía `initialized` si `initialize` devuelve error, expira, produce EOF o no valida.

### Allowlist saliente

Después del handshake, el cliente solo puede producir:

| Tipo | Método | Parámetros |
|---|---|---|
| Request | `account/read` | `{"refreshToken": false}` |
| Request | `account/rateLimits/read` | sin parámetros funcionales |

`initialize` y `initialized` solo existen dentro del handshake.

No existe una función genérica pública que acepte un nombre de método arbitrario.

Todo método saliente no enumerado se rechaza por construcción.

### Allowlist entrante

El cliente procesa:

- Respuestas cuyo ID está pendiente en la generación actual.
- `account/updated`.
- `account/rateLimits/updated`.

Una notificación desconocida se descarta.

Una solicitud entrante con ID y método no soportado recibe un error JSON-RPC `-32601`.

Sus parámetros no se registran.

### Framing, correlación y límites

- Cada mensaje ocupa exactamente una línea UTF-8.
- Una línea debe decodificar a un objeto JSON.
- Las líneas vacías se ignoran con un evento seguro de nivel debug.
- El tamaño máximo de una línea stdout es `256 KiB`.
- Una línea excesiva es un fallo de protocolo.
- Cada generación inicia sus IDs enteros en 1.
- Los IDs aumentan monotónicamente.
- Los IDs no se reutilizan dentro de una generación.
- Existe una única tarea lectora de stdout.
- Existe un lock de escritura para stdin.
- Existe un mapa de solicitudes pendientes por ID.
- Las respuestas pueden llegar fuera de orden.
- Solo el ID determina la correlación.
- Una respuesta tardía o un ID desconocido se descarta.
- El contenido de una respuesta descartada no se registra.

JSON inválido, objeto inválido, línea excesiva, EOF inesperado y timeout de solicitud producen un fallo de sesión.

Un fallo de sesión:

1. Cambia Codex a `DEGRADED`.
2. Marca el snapshot anterior como `stale`.
3. Falla todas las solicitudes pendientes con una excepción tipada.
4. Solicita el cierre de la generación actual.
5. Recolecta sus tareas y proceso.
6. Entrega el reinicio al supervisor.

La cancelación de un consumidor retira únicamente su solicitud.

No reinicia el proceso por sí sola.

## stderr y redacción

stderr se drena en una tarea dedicada para impedir que el pipe se llene.

Su contenido nunca se copia literalmente a los logs.

La tarea:

- Lee con memoria acotada.
- Detecta y descarta líneas excesivas.
- Aplica redacción antes de cualquier clasificación.
- Emite únicamente códigos de evento seguros.
- No conserva el texto en el estado runtime.
- No incluye el texto en excepciones consultables.

Los eventos nuevos respetan el contrato de logging de SPEC 02.

Solo usan los campos `timestamp`, `level`, `event` y `request_id` cuando este último aplica.

Un error JSON-RPC se traduce a un código interno.

El mensaje de error remoto no se conserva ni se expone.

## Snapshot inicial y actualizaciones

Después de `initialized`, el supervisor inicia concurrentemente:

- `account/read` con `refreshToken=false`.
- `account/rateLimits/read`.

El primer snapshot se publica solo cuando ambas respuestas validan.

Una respuesta inválida impide publicar un estado parcial.

### Notificaciones

`account/updated` solicita nuevamente:

- cuenta;
- límites.

`account/rateLimits/updated` solicita nuevamente:

- límites.

Los payloads parciales de las notificaciones no se fusionan.

Las ráfagas se agrupan mediante single-flight.

Puede existir como máximo:

- una actualización en ejecución;
- una actualización adicional pendiente.

Un resultado completo válido reemplaza atómicamente el snapshot.

Un fallo conserva el snapshot anterior como `stale`.

SPEC 03 no añade polling periódico.

Las operaciones internas explícitas de actualización quedan disponibles para SPEC 04.

## Supervisor y degradación

Existe una sola tarea supervisora.

Existe como máximo un proceso App Server.

La secuencia base de backoff es:

```text
1, 2, 4, 8, 16, 30, 60 segundos
```

Cada espera real usa jitter uniforme entre el 50 % y el 100 % del escalón.

Ninguna espera supera 60 segundos.

La producción usa una fuente aleatoria interna.

Las pruebas inyectan reloj, espera y aleatoriedad deterministas.

El backoff vuelve al primer escalón después de 60 segundos continuos con:

- proceso vivo;
- handshake completado;
- snapshot válido;
- ninguna señal interna de fallo.

Un fallo del binario, versión, esquema, startup, protocolo, solicitud o proceso:

- cambia el estado a `DEGRADED`;
- conserva el bridge operativo;
- marca el snapshot anterior como `stale`;
- aplica el siguiente backoff;
- no crea un supervisor adicional.

## Integración con SPEC 02

El coordinador ejecuta este orden de arranque:

1. Cargar y validar la configuración de SPEC 02.
2. Arrancar y validar el listener de dispositivo.
3. Arrancar y validar el listener lifecycle.
4. Marcar el bridge ready según SPEC 02.
5. Arrancar el supervisor de Codex.

Un fallo de Codex no revierte el estado ready del bridge.

Los cuerpos continúan exactamente:

```text
GET /healthz
200
{"status":"ok"}

GET /readyz
200
{"status":"ready"}

GET /readyz
503
{"status":"not_ready"}
```

`/readyz` representa exclusivamente la disponibilidad del bridge definida por SPEC 02.

No incluye estado, razón ni campos de Codex.

El estado degradado de Codex permanece separado e interno en SPEC 03.

### Apagado

Ante SIGINT, SIGTERM o fallo coordinado de un listener:

1. SPEC 02 establece `shutting_down`.
2. El supervisor de Codex cambia a `STOPPING`.
3. Se rechazan nuevas operaciones internas de Codex.
4. Se cancela cualquier espera de backoff.
5. Se solicita el cierre normal del proceso hijo.
6. Se esperan hasta 5 segundos.
7. Si no termina, se envía terminación al grupo de procesos.
8. Si persiste, se mata el grupo como último recurso.
9. Se recolectan proceso, reader, stderr, futuros y tareas auxiliares.
10. Continúa el cierre coordinado de los listeners.

Una vez iniciado `STOPPING`, el supervisor no puede crear otra generación.

## Plan de implementación

1. Crear `scripts/bootstrap-codex.sh` y `toolchain/codex-app-server.lock.json` con la URL oficial, plataforma, versión y hashes fijados.
   - El primer modo funcional descarga a un directorio temporal.
   - Valida el archivo, extrae el ejecutable y valida su segundo hash sin instalarlo.
   - Verificación: ejecutar el modo de validación de fuente y comprobar que un hash alterado falla antes de instalar.
   - Complejidad: Media
   - Razonamiento recomendado: Alto
   - Razón: el código es acotado, pero protege la cadena de suministro y no debe aceptar rutas o artefactos ambiguos.

2. Extender el bootstrap con instalación atómica y verificación de la copia controlada.
   - Crear la jerarquía con modo `0700`.
   - Instalar el ejecutable regular con modo `0500`.
   - Comprobar propietario, versión y hash.
   - Verificación: probar instalación limpia, repetición, symlink, permisos incorrectos y contenido alterado.
   - Complejidad: Alta
   - Razonamiento recomendado: Alto
   - Razón: combina filesystem sensible, carreras, permisos y reemplazo seguro de ejecutables.

3. Generar y versionar el esquema estable de Codex App Server.
   - Añadir `bridge/schemas/codex-app-server/0.144.6/codex_app_server_protocol.schemas.json`.
   - Registrar en el lock el comando sin `--experimental` y el SHA-256 del esquema.
   - Añadir al bootstrap un modo que regenere en un temporal y compare exactamente.
   - Verificación: regeneración idéntica y fallo al modificar una copia del esquema.
   - Complejidad: Baja
   - Razonamiento recomendado: Bajo
   - Razón: es una generación mecánica con versión, comando y resultado determinados.

4. Crear `bridge/src/ai_usage_meter_bridge/codex_models.py` y sus pruebas.
   - Implementar enums y DTOs inmutables para cuenta, ventana, bucket, snapshot y estado runtime.
   - Implementar la extracción allowlist.
   - Implementar el fallback entre `rateLimitsByLimitId` y `rateLimits`.
   - Verificación: probar cuenta ausente, tipos de cuenta, planes, múltiples buckets, ventanas nulas, campos descartados y valores inválidos.
   - Complejidad: Media
   - Razonamiento recomendado: Medio
   - Razón: requiere transformar un contrato externo cerrado sin efectuar todavía normalización de producto.

5. Crear el núcleo JSON-RPC en `bridge/src/ai_usage_meter_bridge/codex_protocol.py`.
   - Implementar envelopes mínimos, codificación JSONL, UTF-8, límite de `256 KiB`, IDs y allowlists cerradas.
   - Implementar errores tipados sin retener payloads.
   - Verificación: probar frames válidos, líneas vacías, JSON inválido, objetos no válidos, línea excesiva, método saliente rechazado y respuesta con ID inválido.
   - Complejidad: Alta
   - Razonamiento recomendado: Alto
   - Razón: el framing y la clasificación exacta de mensajes son la frontera de confianza del cliente.

6. Crear en `bridge/src/ai_usage_meter_bridge/codex_client.py` la validación runtime y el arranque del proceso hijo.
   - Resolver el home desde el usuario efectivo.
   - Validar ruta, directorios, archivo, propietario, permisos, versión y hash.
   - Construir el entorno mínimo acordado.
   - Ejecutar directamente `codex app-server` sin shell ni `PATH`.
   - Completar `initialize` y emitir después `initialized`.
   - Verificación: probar binario inexistente, symlink, modo incorrecto, hash o versión incompatible, entorno filtrado y orden exacto del handshake.
   - Complejidad: Alta
   - Razonamiento recomendado: Alto
   - Razón: une validación de un ejecutable, subprocess y un protocolo con orden obligatorio.

7. Completar el cliente persistente y concurrente.
   - Añadir reader único, lock de escritura, mapa de pendientes y timeouts.
   - Fallar las solicitudes pendientes ante protocolo inválido, EOF o timeout.
   - Retirar solo la solicitud afectada cuando el consumidor la cancele.
   - Limitar, redactar y catalogar stderr.
   - Verificación: probar respuestas fuera de orden, concurrencia, cancelación, timeout, respuesta tardía, ID desconocido, EOF, salida inesperada y cierre forzado.
   - Complejidad: Alta
   - Razonamiento recomendado: Alto
   - Razón: la concurrencia y la limpieza completa de tareas y futuros tienen alto riesgo de carreras y bloqueos.

8. Añadir las operaciones tipadas y el despacho entrante.
   - Implementar exclusivamente `account/read` y `account/rateLimits/read`.
   - Aceptar las dos notificaciones acordadas.
   - Responder `-32601` a solicitudes entrantes no soportadas.
   - Descartar notificaciones desconocidas mediante eventos redactados.
   - Verificación: probar parámetros exactos, DTOs retornados, rechazo por construcción y ausencia de JSON crudo.
   - Complejidad: Media
   - Razonamiento recomendado: Medio
   - Razón: el conjunto de métodos está cerrado y se apoya en el transporte ya validado.

9. Crear `bridge/src/ai_usage_meter_bridge/codex_supervisor.py`.
   - Gestionar un único proceso y una única tarea supervisora.
   - Implementar backoff, jitter y reinicio tras 60 segundos saludables.
   - Construir el snapshot inicial mediante dos solicitudes concurrentes.
   - Agrupar notificaciones y refrescar mediante single-flight.
   - Conservar el snapshot anterior como `stale` durante fallos.
   - Verificación: usar reloj, eventos y aleatoriedad inyectables para comprobar secuencia, cap, reset, ráfagas y ausencia de procesos simultáneos.
   - Complejidad: Alta
   - Razonamiento recomendado: Alto
   - Razón: coordina estado, temporización, reintentos y consistencia atómica de datos.

10. Integrar el supervisor en `bridge/src/ai_usage_meter_bridge/main.py`.
    - Arrancarlo después de los dos listeners.
    - Mantener `/healthz` y `/readyz` sin cambios cuando Codex se degrade.
    - Detener nuevas operaciones de Codex al comenzar shutdown.
    - Esperar, terminar o matar el grupo del hijo dentro del contrato de cierre.
    - Recolectar todas las tareas.
    - Verificación: probar arranque degradado, recuperación, fallo runtime y shutdown sin tareas ni procesos huérfanos.
    - Complejidad: Alta
    - Razonamiento recomendado: Alto
    - Razón: modifica el coordinador principal y debe preservar exactamente los contratos de SPEC 02.

11. Completar la suite determinista con un App Server falso.
    - El fixture controla stdout, stdin, stderr, tiempos, respuestas, notificaciones y códigos de salida.
    - Cubrir handshake, concurrencia, incompatibilidad, payloads sensibles, tormenta de notificaciones, backoff y cierre.
    - No depender de credenciales reales, red o Codex instalado globalmente.
    - Complejidad: Media
    - Razonamiento recomendado: Alto
    - Razón: simular correctamente condiciones concurrentes y demostrar que no existen fugas requiere razonamiento elevado.

12. Añadir una prueba operacional separada contra la copia controlada real.
    - Validar versión, hash, generación de esquema, arranque, handshake y lecturas tipadas.
    - Omitirla explícitamente si el bootstrap no fue ejecutado.
    - No imprimir cuenta, límites, credenciales ni stderr crudo.
    - No incluirla en la suite determinista obligatoria.
    - Complejidad: Media
    - Razonamiento recomendado: Medio
    - Razón: verifica la integración real y reutiliza los componentes ya probados.

13. Registrar `docs/codex-app-server-verification.md`.
    - Incluir versión, hashes, esquema, plataforma, comandos, resultados y estado de la prueba operacional.
    - Excluir datos de cuenta, rutas sensibles, variables de entorno y respuestas JSON.
    - Ejecutar como cierre los comandos locked de calidad y pruebas.
    - Complejidad: Baja
    - Razonamiento recomendado: Bajo
    - Razón: consolida evidencia ya producida sin cambiar el comportamiento del sistema.

## Criterios de aceptación

### Precondiciones y artefacto fijado

- [ ] SPEC 02 está `Implemented-Verified` antes de iniciar la implementación.
- [ ] Las referencias coordinadas de uv usan exactamente `0.11.29`.
- [ ] La plataforma certificada es macOS `arm64`.
- [ ] `toolchain/codex-app-server.lock.json` fija `codex-cli 0.144.6`.
- [ ] El lock contiene la URL oficial del release `rust-v0.144.6`.
- [ ] El SHA-256 fijado para el archivo comprimido es `023590f828bc9507ac61132ee35e74d3c5d33fb5ba3e1ca4fc2e013a2f71a3d7`.
- [ ] El SHA-256 fijado para el ejecutable extraído es `80a3933d11a9d13ef806aa24f7bb8afc9169cfe4e9b09d6da6a92922cbde9cff`.
- [ ] El SHA-256 fijado para el esquema combinado es `1a7e561efcc5a5fbb8f45bc79c24da70e948c0e6e02c3e1045307e236e595a98`.
- [ ] Un host o artefacto de arquitectura diferente se rechaza.

### Bootstrap e instalación

- [ ] `scripts/bootstrap-codex.sh` valida ambos hashes antes de instalar.
- [ ] La descarga solo ocurre mediante una ejecución explícita del bootstrap.
- [ ] El runtime nunca descarga ni actualiza Codex.
- [ ] La copia controlada queda exactamente en `~/Library/Application Support/AIUsageMeter/tools/codex/0.144.6/codex`.
- [ ] `~` se resuelve desde la identidad del usuario efectivo y no desde `$HOME`.
- [ ] Los directorios administrados pertenecen al usuario efectivo y tienen modo `0700`.
- [ ] El ejecutable es un archivo regular, no un symlink, propiedad del usuario efectivo y con modo `0500`.
- [ ] La instalación usa un temporal seguro y renombrado atómico.
- [ ] Repetir el bootstrap sobre una instalación válida no altera el ejecutable.
- [ ] Un destino existente inseguro o discrepante produce fallo y no se corrige silenciosamente.
- [ ] La verificación runtime comprueba ruta, tipos, propietario, permisos, versión y hash antes de cada arranque.

### Esquema estable

- [ ] El esquema se genera con `codex app-server generate-json-schema` sin `--experimental`.
- [ ] El esquema combinado está versionado bajo `bridge/schemas/codex-app-server/0.144.6/`.
- [ ] El lock registra el comando y el SHA-256 del esquema.
- [ ] Regenerar el esquema con la copia fijada produce coincidencia exacta.
- [ ] Una discrepancia de versión, hash o esquema deja Codex `DEGRADED` sin terminar el bridge.

### Ejecución aislada

- [ ] El proceso se crea mediante ejecución directa y `shell=False`.
- [ ] Se usa exclusivamente la ruta absoluta controlada.
- [ ] No se consulta ni utiliza `PATH` para localizar Codex.
- [ ] App Server se comunica exclusivamente mediante stdin, stdout y stderr.
- [ ] App Server no abre un listener administrado por el bridge.
- [ ] El entorno hijo contiene únicamente la allowlist acordada.
- [ ] Variables de tokens, API keys y credenciales del entorno padre no se heredan.
- [ ] `HOME` y `CODEX_HOME` se construyen desde la identidad efectiva.
- [ ] Un `TMPDIR` inseguro, relativo o enlazado no se hereda.
- [ ] Las variables de proxy y certificados solo se heredan si pertenecen a la allowlist cerrada.
- [ ] El proceso se ejecuta en un grupo dedicado.

### Handshake y métodos

- [ ] El timeout completo de arranque e inicialización es 15 segundos.
- [ ] El primer mensaje es `initialize`.
- [ ] `clientInfo.name` es `ai-usage-meter-bridge`.
- [ ] `clientInfo.version` procede de la versión instalada del paquete bridge.
- [ ] `experimentalApi` se envía explícitamente como `false`.
- [ ] `initialized` solo se envía después de una respuesta satisfactoria de `initialize`.
- [ ] Una respuesta errónea o timeout de `initialize` impide emitir `initialized`.
- [ ] Después del handshake solo pueden emitirse `account/read` y `account/rateLimits/read`.
- [ ] `account/read` envía exactamente `refreshToken=false`.
- [ ] `account/rateLimits/read` no envía parámetros funcionales.
- [ ] Cualquier otro método saliente se rechaza por construcción.

### Transporte JSON-RPC

- [ ] Cada mensaje ocupa una línea UTF-8 y contiene un objeto JSON.
- [ ] Una línea de stdout mayor de `256 KiB` se considera fallo de protocolo.
- [ ] Los IDs son enteros monotónicos y reinician con cada generación del proceso hijo.
- [ ] Existe un único reader y las escrituras están serializadas.
- [ ] Respuestas concurrentes fuera de orden se correlacionan con la solicitud correcta.
- [ ] El timeout ordinario de solicitud es 10 segundos.
- [ ] Un timeout falla las solicitudes pendientes y reinicia el proceso hijo.
- [ ] Cancelar un consumidor retira solamente su solicitud.
- [ ] Una respuesta tardía o con ID desconocido se descarta sin exponer contenido.
- [ ] JSON inválido, objeto inválido, línea excesiva y EOF inesperado activan el reinicio supervisado.
- [ ] Todas las tareas y futuros pendientes terminan con éxito, error o cancelación.
- [ ] Ninguna tarea o futuro queda huérfano.
- [ ] Una solicitud entrante no soportada recibe un error JSON-RPC `-32601`.
- [ ] Una notificación desconocida se descarta y no produce respuesta.

### DTOs y snapshot

- [ ] El cliente devuelve DTOs tipados y nunca JSON crudo.
- [ ] Se conservan `requiresOpenaiAuth`, tipo de cuenta y plan.
- [ ] Se descartan email, tokens, rutas, `codexHome`, user agent y fuente de credenciales.
- [ ] Se conservan todos los buckets de `rateLimitsByLimitId`.
- [ ] `rateLimits` solo se usa cuando no existe la vista multibucket.
- [ ] No se duplica el bucket histórico.
- [ ] Se conservan `limitId`, `limitName`, plan y tipo de límite alcanzado.
- [ ] Cada ventana conserva `usedPercent`, `windowDurationMins` y `resetsAt`.
- [ ] `primary` o `secondary` ausentes permanecen `null`.
- [ ] No se asignan etiquetas de cinco horas o semanal.
- [ ] Se descartan créditos, reset credits y límites monetarios de gasto.
- [ ] Los campos desconocidos se descartan.
- [ ] Un enum desconocido o un valor fuera de contrato invalida la respuesta completa.
- [ ] Una cuenta ausente o que requiere autenticación es un resultado válido y no degrada el proceso.
- [ ] El snapshot inicial se publica atómicamente después de validar ambas lecturas.
- [ ] El último snapshot válido se conserva en memoria como `stale` durante degradaciones.
- [ ] Ningún snapshot se escribe en disco.

### Notificaciones y supervisión

- [ ] Solo se procesan `account/updated` y `account/rateLimits/updated`.
- [ ] Los payloads parciales de notificaciones no se fusionan directamente.
- [ ] `account/updated` provoca una nueva lectura de cuenta y límites.
- [ ] `account/rateLimits/updated` provoca una nueva lectura de límites.
- [ ] Una ráfaga de notificaciones se agrupa mediante single-flight.
- [ ] Existe como máximo una actualización en curso y otra pendiente.
- [ ] Solo existe una tarea supervisora y como máximo un proceso Codex.
- [ ] El backoff base sigue exactamente `1, 2, 4, 8, 16, 30, 60` segundos.
- [ ] Cada espera aplica jitter entre el 50 % y el 100 % de su escalón.
- [ ] Ninguna espera supera 60 segundos.
- [ ] Tras 60 segundos continuos saludables, el siguiente fallo vuelve al primer escalón.
- [ ] Reloj, espera y aleatoriedad son seams internos de prueba y no configuración de producción.

### Degradación e integración

- [ ] Los listeners de SPEC 02 arrancan antes del supervisor de Codex.
- [ ] Un fallo de Codex no termina los listeners.
- [ ] `/healthz` conserva exactamente `200 {"status":"ok"}`.
- [ ] `/readyz` continúa describiendo solamente la disponibilidad del bridge.
- [ ] `/readyz` no añade estado, motivo ni campos de Codex.
- [ ] El estado degradado de Codex permanece separado e interno en SPEC 03.
- [ ] Un snapshot no vuelve a `current` hasta completar una lectura válida.
- [ ] El apagado impide nuevas operaciones internas de Codex.
- [ ] El cierre normal del hijo dispone de 5 segundos.
- [ ] Si el cierre normal falla, el grupo se termina y después se mata como último recurso.
- [ ] El proceso hijo y todas sus tareas se recolectan antes de terminar el bridge.

### Logs y seguridad

- [ ] Ningún log contiene respuestas JSON, cuenta, email, límites, tokens, variables de entorno o rutas sensibles.
- [ ] stderr nunca se copia literalmente a los logs.
- [ ] El contenido de stderr se consume con límites de memoria y solo genera códigos de evento seguros.
- [ ] Una línea excesiva de stderr se descarta y produce un evento estable de truncamiento.
- [ ] Los errores JSON-RPC se traducen a códigos internos sin conservar su mensaje no confiable.
- [ ] Los nuevos logs respetan el formato y la allowlist de campos establecidos por SPEC 02.
- [ ] Los fixtures no contienen secretos reales.

### Verificación

- [ ] La suite determinista usa un proceso falso y no depende de red, credenciales ni una instalación global de Codex.
- [ ] Las pruebas cubren handshake, concurrencia, timeout, cancelación, stderr, EOF, salida inesperada y cierre forzado.
- [ ] Las pruebas cubren los dos métodos y las dos notificaciones permitidas.
- [ ] Las pruebas cubren métodos, campos, enums y frames desconocidos.
- [ ] Las pruebas cubren backoff, jitter, reset saludable y single-flight.
- [ ] La prueba operacional usa exclusivamente la copia controlada.
- [ ] La prueba operacional se omite explícitamente cuando esa copia no existe.
- [ ] La prueba operacional no imprime información de cuenta ni respuestas.
- [ ] `uv lock --check` termina correctamente.
- [ ] `uv sync --locked` termina correctamente.
- [ ] `uv run --locked pytest` termina correctamente.
- [ ] La suite operacional se ejecuta mediante un comando separado.
- [ ] `uv run --locked ruff check .` termina correctamente.
- [ ] `uv run --locked ruff format --check .` termina correctamente.
- [ ] `uv run --locked mypy src tests` termina correctamente.
- [ ] `docs/codex-app-server-verification.md` registra resultados reproducibles sin información sensible.

## Decisiones

### Toolchain y cadena de suministro

- **Sí:** fijar `codex-cli 0.144.6` porque el protocolo y el esquema se validan contra una versión concreta.
- **Sí:** validar por separado el SHA-256 del archivo oficial y del ejecutable extraído para no confiar únicamente en el contenedor descargado.
- **Sí:** certificar únicamente macOS `arm64` porque coincide con SPEC 01 y SPEC 02.
- **Sí:** instalar una copia regular y controlada bajo Application Support para no depender del estado de Homebrew.
- **No:** ejecutar directamente el symlink de Homebrew porque puede cambiar fuera del control del proyecto.
- **No:** buscar `codex` mediante `PATH` porque introduce ambigüedad y permite sustitución del ejecutable.
- **No:** descargar, actualizar o reparar Codex durante el arranque porque el runtime debe ser determinista.
- **Sí:** usar instalación temporal y renombrado atómico para evitar ejecutables parciales.
- **No:** sobrescribir silenciosamente una instalación discrepante porque requiere acción explícita del operador.

### Esquema y compatibilidad

- **Sí:** generar el JSON Schema sin `--experimental` porque SPEC 03 consume solo la superficie fijada.
- **Sí:** versionar un esquema combinado y su hash para simplificar la comparación reproducible.
- **Sí:** enviar `experimentalApi=false` explícitamente para no negociar métodos o campos experimentales.
- **No:** afirmar compatibilidad con otras versiones de Codex.
- **Sí:** tratar incompatibilidades como degradación de Codex para conservar disponible el bridge.

### Configuración y proceso hijo

- **Sí:** mantener `AI_METER_CONFIG_VERSION=1` porque SPEC 03 no necesita nuevas decisiones configurables.
- **Sí:** usar constantes internas para ruta relativa, versión y timeouts.
- **No:** agregar variables de entorno o argumentos CLI para cambiar binario, métodos, timeouts o backoff.
- **Sí:** ejecutar el proceso directamente con `shell=False`.
- **Sí:** construir un entorno hijo mediante allowlist.
- **No:** copiar el entorno completo y eliminar algunas claves mediante denylist.
- **Sí:** capturar stdout y stderr por separado porque solo stdout pertenece al protocolo.
- **No:** exponer Codex App Server mediante TCP, HTTP o WebSocket.

### Protocolo

- **Sí:** esperar el resultado satisfactorio de `initialize` antes de emitir `initialized`.
- **Sí:** usar IDs enteros monotónicos por generación.
- **Sí:** mantener un reader único y serializar escrituras.
- **Sí:** limitar stdout a `256 KiB` por línea.
- **Sí:** reiniciar el hijo ante timeout, framing inválido, EOF o salida inesperada.
- **No:** reiniciar el hijo cuando un consumidor cancela su propia espera.
- **Sí:** responder `-32601` a solicitudes entrantes no soportadas.
- **No:** registrar parámetros o mensajes de error recibidos.

### Métodos y datos

- **Sí:** cerrar la allowlist saliente a `account/read` y `account/rateLimits/read` después del handshake.
- **No:** implementar login, logout, refresh explícito, consumo de créditos o métodos de conversaciones.
- **Sí:** usar `refreshToken=false` para que la lectura no actualice deliberadamente credenciales.
- **Sí:** traducir inmediatamente las respuestas a DTOs mínimos.
- **Sí:** conservar todos los buckets multibucket.
- **Sí:** usar la vista histórica únicamente como fallback.
- **No:** clasificar todavía `primary` y `secondary` como ventanas de cinco horas o semanal.
- **No:** conservar email, rutas, user agent, `codexHome`, credenciales, créditos ni límites monetarios.
- **Sí:** descartar campos desconocidos para tolerar extensiones aditivas sin exponerlas.
- **No:** aceptar silenciosamente valores desconocidos de enums cerrados.
- **Sí:** considerar válida una cuenta ausente o no autenticada.

### Snapshot, notificaciones y recuperación

- **Sí:** conservar solo el último snapshot válido en memoria porque SPEC 04 será responsable de persistencia.
- **Sí:** marcar el snapshot anterior como `stale` durante una degradación.
- **Sí:** publicar el snapshot inicial solo después de ambas lecturas válidas.
- **Sí:** volver a leer datos completos tras las notificaciones admitidas.
- **No:** fusionar directamente notificaciones parciales.
- **Sí:** agrupar ráfagas mediante single-flight.
- **No:** agregar polling periódico.
- **Sí:** usar un solo supervisor y un solo proceso hijo.
- **Sí:** aplicar backoff acotado con jitter.
- **Sí:** reiniciar el backoff después de 60 segundos saludables.
- **No:** implementar recuperación con múltiples workers o procesos.

### Integración con el bridge

- **Sí:** arrancar los listeners antes de iniciar Codex.
- **Sí:** mantener `/healthz` y `/readyz` exactamente como en SPEC 02.
- **No:** añadir detalles de Codex a las respuestas lifecycle.
- **Sí:** cerrar Codex dentro del shutdown coordinado.
- **No:** implementar endpoints de observabilidad adicionales.

## Riesgos

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Codex App Server cambia entre releases | Métodos, DTOs o handshake dejan de ser compatibles | Fijar binario, hashes y esquema de `0.144.6`; rechazar cualquier versión diferente y degradar solo Codex. |
| La superficie evoluciona aunque `experimentalApi=false` | Una suposición de estabilidad amplia produce compatibilidad falsa | Certificar únicamente los métodos y formas presentes en el esquema generado para `0.144.6`. |
| El release oficial deja de estar disponible | Un host nuevo no puede ejecutar el bootstrap | Mantener URL y hashes en el lock; fallar sin utilizar mirrors o versiones alternativas no aprobadas. |
| Otra arquitectura usa hashes diferentes | Se intenta usar el lock `arm64` en Intel | Comprobar sistema operativo y arquitectura antes de descargar o ejecutar. |
| El binario cambia entre validación y `exec` | Podría ejecutarse contenido distinto al verificado | Exigir directorios `0700`, ejecutable `0500`, propietario efectivo y ausencia de symlinks; validar inmediatamente antes del spawn. El modelo no protege contra el mismo usuario efectivo actuando maliciosamente. |
| El proceso hijo crea descendientes | Terminar solo el PID principal deja procesos huérfanos | Crear App Server en un grupo de procesos dedicado y cerrar el grupo completo. |
| El hash completo retrasa cada reinicio | El startup supera 15 segundos en almacenamiento anormalmente lento | Medirlo en la plataforma certificada; una validación que excede el timeout degrada Codex y no omite el hash. |
| Una respuesta futura supera `256 KiB` | El cliente reinicia aunque el servidor sea funcional | Tratarlo como incompatibilidad explícita y conservar el snapshot anterior como `stale`. |
| stderr continuo llena el pipe | App Server se bloquea aunque stdout sea válido | Drenar stderr en una tarea dedicada, con lectura y memoria acotadas. |
| Red o credenciales de Codex no disponibles | Las lecturas fallan aunque el proceso arranque | Mantener bridge ready, degradar Codex, conservar el snapshot como `stale` y aplicar backoff. |
| La allowlist omite un proxy o certificado requerido | Codex no alcanza su backend en una red corporativa | Documentar la allowlist exacta y ampliarla solo mediante revisión contractual. |
| La redacción reduce información de diagnóstico | Un fallo es más difícil de investigar | Usar códigos de evento, generación del proceso y códigos de fallo cerrados sin contenido sensible. |
| La cuenta cambia entre dos lecturas concurrentes | Cuenta y límites proceden de instantes cercanos distintos | Publicar ambas de forma atómica y repetir la lectura completa ante una notificación de cuenta. El protocolo no ofrece una transacción común. |
| Una notificación se pierde | El snapshot puede permanecer `current` aunque el backend cambie | Exponer actualizaciones internas explícitas para SPEC 04 y no afirmar frescura indefinida. El polling queda fuera. |
| Una tormenta de notificaciones genera lecturas ilimitadas | Aumentan memoria, latencia y carga | Usar single-flight y conservar como máximo una actualización pendiente adicional. |
| Un timeout deja una respuesta tardía | La respuesta podría asociarse con estado nuevo | No reutilizar IDs dentro de la generación y descartar IDs que ya no estén pendientes. |
| El supervisor reinicia durante shutdown | Aparecen procesos nuevos durante la terminación | Marcar `STOPPING` antes de cerrar, cancelar el backoff y prohibir nuevos spawns. |
| El fixture falso omite una peculiaridad real | La suite determinista pasa y la integración falla | Añadir una prueba operacional separada contra la copia controlada. |
| La prueba operacional accede a una cuenta real | Datos sensibles terminan en salida o evidencias | Consumir DTOs solo en memoria, comprobar únicamente forma y estado y prohibir respuestas o stderr crudo. |
| SPEC 02 cambia antes de implementarse | La integración prevista deja de coincidir | Bloquear implementación hasta `Implemented-Verified` y comprobar sus contratos antes de modificar `main.py`. |

## Lo que **no** incluye esta spec

- Nuevos endpoints HTTP.
- Cambios en `/healthz` o `/readyz`.
- Exposición pública del estado degradado de Codex.
- Normalización de ventanas como cinco horas o semanal.
- Persistencia o caché durable.
- Lectura periódica automática.
- Login, logout o actualización deliberada de credenciales.
- Gestión o consumo de créditos.
- Métodos experimentales de Codex.
- Integración con Claude.
- API y autenticación del dispositivo.
- Aprovisionamiento del CYD.
- `launchd`, contenedores o CI.
- Actualización automática de Codex.
- Descubrimiento mediante `PATH`.
- Soporte para plataformas distintas de macOS `arm64`.

Cada ampliación deberá quedar definida en la spec posterior correspondiente.

## Resumen de complejidad y razonamiento

| Tipo | Alto/Alta | Medio/Media | Bajo/Baja |
|---|---:|---:|---:|
| Complejidad | 6 | 5 | 2 |
| Razonamiento recomendado | 8 | 3 | 2 |
