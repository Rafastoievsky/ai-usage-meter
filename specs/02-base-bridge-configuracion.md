# SPEC 02 — Base del bridge y configuración

> **Estado:** Draft
> **Depende de:** SPEC 00 — Arquitectura, alcance y seguridad (`Approved`) y SPEC 01 — Baseline reproducible de repositorios, firmware y hardware (`Implemented-Verified` antes de implementar SPEC 02)
> **Fecha:** 2026-07-20
> **Fuente base:** `docs/AI_USAGE_METER_ESP32_SPEC_DRIVEN_PLAN_V2.md`
> **Repositorio:** `ai-usage-meter`
> **Componente:** `bridge/`
> **Plataforma certificada:** macOS sobre Apple Silicon (`arm64`), Python `3.14.6`
> **Objetivo:** Establecer una base reproducible y segura del bridge con configuración local estricta, dos listeners coordinados, lifecycle mínimo, autenticación reutilizable interna y pruebas deterministas, sin integrar todavía fuentes de uso ni publicar la API del dispositivo.

## Alcance

**Incluye:**

- Crear el proyecto Python instalable bajo `bridge/`, con layout `src/`, Python `3.14.6`, dependencias directas fijadas exactamente, `uv.lock` y backend `uv_build==0.11.29`.
- Publicar los comandos `ai-usage-meter-bridge` y `ai-usage-meter-init` mediante entry points síncronos mínimos.
- Coordinar el bootstrap con SPEC 01 usando uv `0.11.29` y pip `26.1.2`.
- Cargar la configuración runtime exclusivamente desde `~/Library/Application Support/AIUsageMeter/bridge.env`, sin autodetección de archivos `.env` del repositorio ni precedencia del entorno del proceso.
- Validar el directorio y el archivo mediante `lstat`: propietario actual, tipos esperados, ausencia de symlinks y modos exactos `0700` y `0600`.
- Aplicar una whitelist estricta de claves, rechazar claves duplicadas, desconocidas, sin prefijo, vacías o sintácticamente inválidas y construir después un modelo Pydantic con `extra="forbid"`.
- Crear de forma atómica e idempotente el directorio y `bridge.env`, generar un token con al menos 256 bits de entropía y no exponerlo por stdout, stderr, logs, argumentos ni archivos versionados.
- Validar `AI_METER_DEVICE_HOST` como IPv4 RFC1918 literal asignada exactamente a una interfaz local con `isup=True`, usando `psutil`, sin intentar clasificar interfaces como VPN, Wi-Fi, Ethernet o túnel.
- Ejecutar dos listeners FastAPI/Uvicorn coordinados:
  - dispositivo en `AI_METER_DEVICE_HOST:8765`, sin rutas publicadas;
  - lifecycle exclusivamente en `127.0.0.1:8766`, con `GET /healthz` y `GET /readyz`.
- Desactivar OpenAPI, Swagger, ReDoc, access logs, proxy headers y las cabeceras `Server` y `Date` en ambos listeners.
- Proporcionar cuerpos JSON mínimos y estables para lifecycle y para errores HTTP 404, 405 y 500, sin revelar detalles internos.
- Supervisar ambos servidores de forma fail-closed: un error de validación o bind impide el arranque parcial; el fallo inesperado de un listener degrada readiness e inicia el apagado completo.
- Reevaluar `/readyz` en cada petición, sin polling adicional, comprobando configuración, estado del coordinador, tareas supervisoras y vigencia de la interfaz configurada.
- Coordinar SIGINT y SIGTERM sin aceptar trabajo nuevo, sin volver al estado ready y sin dejar tareas huérfanas.
- Implementar primitivas internas reutilizables para validar `DEVICE_ID`, generar y validar `DEVICE_TOKEN`, comparar secretos en tiempo constante y producir fallos de autenticación indistinguibles.
- Emitir logs JSON por stderr, con tiempo UTC y campos permitidos limitados a `timestamp`, `level`, `event` y `request_id`, aplicando redacción antes de serializar.
- Incluir únicamente módulos utilizados por SPEC 02, un `bridge/.env.example` con placeholders manifiestamente falsos y documentación operativa mínima.
- Probar de forma determinista configuración, filesystem, red, autenticación, HTTP, coordinación, errores y shutdown mediante seams internos no accesibles desde producción.
- Proporcionar una prueba `operational` separada para detectar una IPv4 RFC1918 real del Mac y efectuar el bind real, con omisión explícita cuando no exista una interfaz compatible.
- Verificar el proyecto con:
  - `uv lock --check`;
  - `uv sync --locked`;
  - `uv run --locked pytest`;
  - `uv run --locked ruff check .`;
  - `uv run --locked ruff format --check .`;
  - `uv run --locked mypy src tests`.

El manifiesto contractual usa exactamente:

```toml
[build-system]
requires = ["uv_build==0.11.29"]
build-backend = "uv_build"

[project]
requires-python = ">=3.14,<3.15"
dependencies = [
    "fastapi==0.139.2",
    "uvicorn==0.51.0",
    "pydantic==2.13.4",
    "pydantic-settings==2.14.2",
    "psutil==7.2.2",
]

[dependency-groups]
dev = [
    "pytest==9.1.1",
    "pytest-asyncio==1.4.0",
    "httpx==0.28.1",
    "ruff==0.15.22",
    "mypy==2.3.0",
]

[project.scripts]
ai-usage-meter-bridge = "ai_usage_meter_bridge.main:main"
ai-usage-meter-init = "ai_usage_meter_bridge.init_config:main"
```

uv `0.11.29` y pip `26.1.2` quedan fijados fuera de las dependencias del proyecto como herramientas del bootstrap coordinado con SPEC 01. Las transitivas se resuelven y fijan exclusivamente en `uv.lock`.

**Fuera de alcance — reservado para specs posteriores:**

- Integración con Codex App Server.
- Lectura, normalización o medición de uso.
- Caché, snapshots, métricas y endpoints de observabilidad adicionales.
- `/api/v1/usage` o cualquier otra ruta funcional del listener de dispositivo.
- Conexión de las primitivas de autenticación a endpoints HTTP.
- Integración o credenciales de Claude.
- Aprovisionamiento del dispositivo y transferencia del token al firmware.
- Rotación, recuperación o visualización de tokens.
- launchd, contenedores y workflows de CI.
- TLS o terminación HTTPS.
- Descubrimiento automático de red.
- Clasificación de interfaces como VPN o LAN a partir de su nombre o dirección.
- Recuperación o reinicio automático de un listener caído.
- Funcionalidad de firmware o pruebas sobre hardware CYD.

## Modelo de datos

### Formato persistido de `bridge.env`

El archivo será UTF-8 y admitirá únicamente líneas vacías, comentarios completos iniciados con `#` y asignaciones simples `CLAVE=VALOR`.

No admitirá `export`, interpolación, expansión de variables, valores multilínea, comillas, escapes, comentarios al final de una asignación, claves repetidas ni espacios alrededor de clave o valor.

| Clave | Tipo y contrato | Obligatoria |
|---|---|---:|
| `AI_METER_CONFIG_VERSION` | Literal textual `"1"` | Sí |
| `AI_METER_DEVICE_HOST` | IPv4 literal; la validación de red se realiza después | Sí |
| `AI_METER_DEVICE_ID` | `^[A-Za-z0-9][A-Za-z0-9._-]{2,63}$` | Sí |
| `AI_METER_DEVICE_TOKEN` | Base64URL sin padding, `^[A-Za-z0-9_-]{43,128}$` | Sí |
| `AI_METER_LOG_LEVEL` | `DEBUG`, `INFO`, `WARNING`, `ERROR` o `CRITICAL` | No; default `INFO` |

```python
import re
from enum import StrEnum
from ipaddress import IPv4Address
from typing import Annotated, Literal

from pydantic import Field, SecretStr, StringConstraints, field_validator
from pydantic_settings import (
    BaseSettings,
    PydanticBaseSettingsSource,
    SettingsConfigDict,
)


DeviceId = Annotated[
    str,
    StringConstraints(
        pattern=r"^[A-Za-z0-9][A-Za-z0-9._-]{2,63}$",
    ),
]

TOKEN_PATTERN = re.compile(r"^[A-Za-z0-9_-]{43,128}$")


class LogLevel(StrEnum):
    DEBUG = "DEBUG"
    INFO = "INFO"
    WARNING = "WARNING"
    ERROR = "ERROR"
    CRITICAL = "CRITICAL"


class BridgeSettings(BaseSettings):
    model_config = SettingsConfigDict(
        extra="forbid",
        frozen=True,
    )

    config_version: Literal["1"] = Field(
        alias="AI_METER_CONFIG_VERSION",
    )
    device_host: IPv4Address = Field(
        alias="AI_METER_DEVICE_HOST",
    )
    device_id: DeviceId = Field(
        alias="AI_METER_DEVICE_ID",
    )
    device_token: SecretStr = Field(
        alias="AI_METER_DEVICE_TOKEN",
    )
    log_level: LogLevel = Field(
        default=LogLevel.INFO,
        alias="AI_METER_LOG_LEVEL",
    )

    @classmethod
    def settings_customise_sources(
        cls,
        settings_cls: type[BaseSettings],
        init_settings: PydanticBaseSettingsSource,
        env_settings: PydanticBaseSettingsSource,
        dotenv_settings: PydanticBaseSettingsSource,
        file_secret_settings: PydanticBaseSettingsSource,
    ) -> tuple[PydanticBaseSettingsSource, ...]:
        del settings_cls, env_settings, dotenv_settings, file_secret_settings
        return (init_settings,)

    @field_validator("device_token")
    @classmethod
    def validate_device_token(cls, value: SecretStr) -> SecretStr:
        if TOKEN_PATTERN.fullmatch(value.get_secret_value()) is None:
            raise ValueError("invalid device token")
        return value
```

El cargador produce primero un `dict[str, str]` solo después de comprobar sintaxis, duplicados y whitelist. Después construye explícitamente `BridgeSettings` con ese diccionario; no se utilizan las fuentes automáticas de entorno, dotenv o secretos de `pydantic-settings`.

### Constantes no configurables

```python
from typing import Final


DEVICE_PORT: Final = 8765
HEALTH_HOST: Final = "127.0.0.1"
HEALTH_PORT: Final = 8766

CONFIG_DIRECTORY_NAME: Final = "AIUsageMeter"
CONFIG_FILE_NAME: Final = "bridge.env"

CONFIG_DIRECTORY_MODE: Final = 0o700
CONFIG_FILE_MODE: Final = 0o600
```

La ruta se resuelve desde el directorio home del usuario efectivo como:

```text
~/Library/Application Support/AIUsageMeter/bridge.env
```

No existe un campo runtime, variable de proceso o argumento CLI que permita sustituir esa ruta o los tres valores de red constantes.

### Inventario de interfaces

```python
from dataclasses import dataclass
from ipaddress import IPv4Address


@dataclass(frozen=True, slots=True)
class InterfaceRecord:
    name: str
    is_up: bool
    ipv4_addresses: frozenset[IPv4Address]
    broadcast_addresses: frozenset[IPv4Address]
```

El adaptador de producción construye estos registros con `psutil.net_if_addrs()` y `psutil.net_if_stats()`. La política acepta el host únicamente si:

- es una IPv4 RFC1918;
- aparece exactamente en `ipv4_addresses`;
- la interfaz correspondiente tiene `is_up=True`;
- no aparece como dirección broadcast;
- no es wildcard, loopback, link-local, CGNAT, multicast ni pública.

El nombre de la interfaz no participa en la decisión.

### Estado coordinado de los listeners

```python
import asyncio
from dataclasses import dataclass, field
from enum import StrEnum


class RuntimePhase(StrEnum):
    STARTING = "starting"
    READY = "ready"
    SHUTTING_DOWN = "shutting_down"
    FAILED = "failed"
    STOPPED = "stopped"


class ListenerRole(StrEnum):
    DEVICE = "device"
    LIFECYCLE = "lifecycle"


@dataclass(slots=True)
class ListenerRuntime:
    role: ListenerRole
    task: asyncio.Task[None] | None = None
    started: bool = False
    failure_event: str | None = None


@dataclass(slots=True)
class BridgeRuntime:
    settings: BridgeSettings
    phase: RuntimePhase = RuntimePhase.STARTING
    device: ListenerRuntime = field(
        default_factory=lambda: ListenerRuntime(ListenerRole.DEVICE)
    )
    lifecycle: ListenerRuntime = field(
        default_factory=lambda: ListenerRuntime(ListenerRole.LIFECYCLE)
    )
    shutdown_requested: asyncio.Event = field(
        default_factory=asyncio.Event
    )
```

`ready` no se almacena como un booleano independiente. Se calcula en cada petición a partir de:

- `phase is RuntimePhase.READY`;
- `shutdown_requested` no establecido;
- ambos listeners marcados como iniciados;
- ambas tareas existentes y no terminadas;
- ausencia de `failure_event`;
- `device_host` todavía asignado a una interfaz `isup=True`.

Esto evita que un valor de readiness quede obsoleto.

### Respuestas HTTP

```python
from typing import Literal

from pydantic import BaseModel, ConfigDict


class HealthResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")
    status: Literal["ok"] = "ok"


class ReadyResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")
    status: Literal["ready", "not_ready"]


class ErrorResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")
    detail: Literal[
        "not_found",
        "method_not_allowed",
        "internal_error",
    ]
```

Todas las respuestas usan `Content-Type: application/json`. Ningún modelo contiene versión, timestamp, IP, identificador de dispositivo, motivo de degradación ni nombres internos.

Cada petición recibe internamente un `request_id` generado por el bridge; no se confía en un identificador suministrado por el cliente y no se devuelve en el cuerpo.

### Primitivas internas de autenticación

```python
from dataclasses import dataclass

from pydantic import SecretStr


@dataclass(frozen=True, slots=True)
class DeviceCredentials:
    device_id: str
    device_token: SecretStr


class AuthenticationFailed(Exception):
    """Fallo genérico sin distinguir identificador y token."""
```

La generación usa `secrets.token_urlsafe(32)`. La comparación extrae los valores únicamente en el punto de comparación y utiliza `secrets.compare_digest`.

Identificador inexistente, token ausente, token malformado y token incorrecto producen la misma excepción y el mismo evento sanitizado. Estas primitivas no están conectadas a rutas en SPEC 02.

### Inicialización

`ai-usage-meter-init` recibe únicamente los valores no secretos `device_host`, `device_id` y, opcionalmente, `log_level`. El token se genera dentro del proceso y se escribe directamente en el archivo.

La solicitud interna se representa como:

```python
from dataclasses import dataclass
from ipaddress import IPv4Address


@dataclass(frozen=True, slots=True)
class InitConfigRequest:
    device_host: IPv4Address
    device_id: str
    log_level: LogLevel = LogLevel.INFO
```

El token nunca forma parte de `InitConfigRequest`, argumentos CLI, resultados públicos ni mensajes. Si ya existe una configuración segura, el inicializador devuelve un resultado idempotente sin leer ni reescribir su contenido:

```python
class InitResult(StrEnum):
    CREATED = "created"
    ALREADY_EXISTS = "already_exists"
```

Los errores de propietario, tipo, symlink o permisos no producen un tercer estado exitoso: terminan con código distinto de cero y un evento sanitizado.

## Plan de implementación

**Precondición:** SPEC 01 debe estar `Implemented-Verified`. Si no lo está, `/spec-impl` debe declarar SPEC 02 `Blocked` antes de modificar `bridge/`.

1. **Crear el proyecto Python reproducible.**
   - Crear `bridge/pyproject.toml`, `bridge/.python-version`, `bridge/uv.lock`, el paquete `bridge/src/ai_usage_meter_bridge/` y la estructura de pruebas.
   - Fijar Python `>=3.14,<3.15`, `uv_build==0.11.29`, todas las dependencias directas aprobadas y los grupos de desarrollo.
   - Configurar pytest, pytest-asyncio, Ruff y mypy en `pyproject.toml`.
   - No crear directorios ni módulos para clientes, cachés o proveedores futuros.
   - Verificación: `uv lock --check`, `uv sync --locked` e importación del paquete.
   - **Complejidad:** Baja
   - **Razonamiento recomendado:** Bajo
   - **Razón:** sigue un layout y un conjunto de versiones completamente definidos.

2. **Implementar el parser estricto de `bridge.env`.**
   - Crear un parser UTF-8 que admita solo líneas vacías, comentarios completos y asignaciones `CLAVE=VALOR`.
   - Rechazar BOM, bytes NUL, claves duplicadas, claves desconocidas, claves sin prefijo, valores vacíos, espacios no permitidos, `export`, comillas, escapes, expansión, multilinea y comentarios inline.
   - Devolver un `dict[str, str]` únicamente cuando el archivo completo sea válido.
   - Añadir pruebas unitarias positivas y una prueba por cada categoría rechazada.
   - Verificación: ejecutar las pruebas enfocadas del parser.
   - **Complejidad:** Media
   - **Razonamiento recomendado:** Medio
   - **Razón:** la gramática es pequeña, pero debe diferenciar errores sin aceptar sintaxis implícita.

3. **Implementar el modelo Pydantic sin fuentes implícitas.**
   - Crear `BridgeSettings` sobre `BaseSettings`.
   - Limitar `settings_customise_sources()` a `init_settings`.
   - Aplicar aliases, `extra="forbid"`, modelo inmutable, versión literal, enums cerrados y validadores de identificador y token.
   - Probar que variables `AI_METER_*` del proceso, archivos `.env` del repositorio y fuentes de secretos de Pydantic no alteran el modelo.
   - Verificación: ejecutar las pruebas enfocadas del modelo y el type check del módulo.
   - **Complejidad:** Media
   - **Razonamiento recomendado:** Alto
   - **Razón:** un error de precedencia podría reintroducir configuración o secretos desde fuentes prohibidas.

4. **Validar de forma segura la ruta runtime.**
   - Resolver la ruta fija desde el home del usuario efectivo.
   - Inspeccionar con `lstat` el directorio `AIUsageMeter/` y `bridge.env`.
   - Exigir propietario `st_uid == os.getuid()`, directorio real `0700`, archivo regular `0600` y ausencia de symlinks.
   - Leer el archivo solo después de completar las validaciones de metadata.
   - Clasificar errores sin incluir ruta personal completa, contenido ni valores en mensajes o logs.
   - Verificación: pruebas con archivos temporales para symlinks, propietarios simulados, tipos y permisos válidos e inválidos.
   - **Complejidad:** Alta
   - **Razonamiento recomendado:** Alto
   - **Razón:** combina seguridad filesystem, carreras locales y protección de secretos.

5. **Implementar el inicializador atómico e idempotente.**
   - Crear el directorio con modo `0700` bajo `umask 0o077`.
   - Crear `bridge.env` mediante apertura exclusiva con modo `0600`.
   - Generar el token con `secrets.token_urlsafe(32)` y escribirlo directamente sin exponerlo.
   - Si la configuración segura ya existe, devolver éxito sin leerla, modificarla ni rotarla.
   - Si existe de forma insegura, fallar sin corregirla silenciosamente.
   - Limpiar únicamente un archivo nuevo e incompleto creado por la misma ejecución si falla la escritura.
   - Verificación: pruebas de primera creación, repetición, carrera de creación, fallo parcial y configuración insegura.
   - **Complejidad:** Alta
   - **Razonamiento recomendado:** Alto
   - **Razón:** la creación del secreto debe ser atómica y no destructiva bajo fallos concurrentes.

6. **Implementar la política de interfaces de red.**
   - Adaptar `psutil.net_if_addrs()` y `psutil.net_if_stats()` a `InterfaceRecord`.
   - Validar IPv4 RFC1918, asignación exacta, `isup=True` y exclusión explícita de wildcard, loopback, link-local, CGNAT, multicast, broadcast y direcciones públicas.
   - No usar el nombre de interfaz ni inferir VPN, Wi-Fi, Ethernet o túnel.
   - Añadir inventarios simulados para todos los casos aprobados y rechazados.
   - Verificación: ejecutar las pruebas enfocadas de política de red.
   - **Complejidad:** Media
   - **Razonamiento recomendado:** Alto
   - **Razón:** la clasificación incorrecta ampliaría o bloquearía la superficie LAN.

7. **Implementar las primitivas internas de autenticación.**
   - Validar `DEVICE_ID` y `DEVICE_TOKEN`.
   - Generar tokens con al menos 256 bits de entropía.
   - Comparar con `secrets.compare_digest`.
   - Convertir token ausente, malformado o incorrecto e identificador desconocido en `AuthenticationFailed`, sin diferencias observables.
   - Mantener las primitivas desconectadas de FastAPI.
   - Verificación: pruebas de formato, generación, comparación válida y fallos indistinguibles.
   - **Complejidad:** Media
   - **Razonamiento recomendado:** Alto
   - **Razón:** aunque todavía no se publique autenticación, estas funciones serán una frontera de seguridad reutilizada por SPEC 05.

8. **Implementar logging JSON y redacción.**
   - Emitir una línea JSON por evento a stderr con tiempo UTC.
   - Limitar el esquema a `timestamp`, `level`, `event` y `request_id`.
   - Generar internamente cada `request_id` y no confiar en valores entrantes.
   - Impedir que excepciones, configuración, tokens, identificadores, direcciones o rutas personales se interpolen en `event`.
   - Aplicar redacción antes de serializar y desactivar logging de acceso.
   - Verificación: capturar stderr y comprobar esquema, UTC, JSON válido y ausencia de secretos en eventos normales y excepcionales.
   - **Complejidad:** Media
   - **Razonamiento recomendado:** Alto
   - **Razón:** los logs atraviesan múltiples rutas de error y no pueden convertirse en un canal lateral.

9. **Crear la aplicación lifecycle y sus handlers estables.**
   - Crear una factoría FastAPI sin OpenAPI, Swagger ni ReDoc.
   - Publicar exclusivamente `GET /healthz` y `GET /readyz`.
   - Instalar handlers explícitos para 404, 405 y excepciones no controladas.
   - Fijar `Content-Type: application/json` y los cuerpos exactos aprobados.
   - No incluir detalles de estado en las respuestas.
   - Verificación: pruebas HTTP de métodos, rutas, cuerpos, status codes, content type y ausencia de endpoints de documentación.
   - **Complejidad:** Media
   - **Razonamiento recomendado:** Medio
   - **Razón:** la superficie es pequeña y sus respuestas están completamente especificadas.

10. **Crear la aplicación vacía del listener de dispositivo.**
    - Crear una factoría FastAPI independiente sin rutas funcionales ni documentación.
    - Aplicar los mismos handlers genéricos.
    - Garantizar que cualquier ruta y método devuelvan 404, no 405.
    - Verificación: recorrer métodos HTTP representativos sobre rutas arbitrarias y comprobar el cuerpo exacto.
    - **Complejidad:** Baja
    - **Razonamiento recomendado:** Bajo
    - **Razón:** es una superficie deliberadamente vacía con comportamiento uniforme.

11. **Implementar el arranque atómico de ambos listeners.**
    - Validar configuración, filesystem e interfaz antes de crear listeners.
    - Crear y conservar los sockets autoritativos; no realizar un bind provisional.
    - Enlazar dispositivo a `DEVICE_HOST:8765` y lifecycle a `127.0.0.1:8766`.
    - No comenzar a servir hasta que ambos sockets estén disponibles.
    - Si falla el segundo bind o el arranque de cualquier servidor, cerrar recursos adquiridos y terminar con error.
    - Configurar Uvicorn con `server_header=False`, `date_header=False`, `access_log=False` y `proxy_headers=False`.
    - Verificación: pruebas con socket factory inyectado para ambos órdenes de fallo y coordinación real sobre loopback y puertos efímeros.
    - **Complejidad:** Alta
    - **Razonamiento recomendado:** Alto
    - **Razón:** coordina sockets y tareas asíncronas sin permitir un servicio parcial ni una carrera de pre-bind.

12. **Conectar readiness calculada bajo demanda.**
    - Implementar `RuntimePhase` y los handles de ambos listeners.
    - Calcular readiness sin almacenar un booleano independiente.
    - Reevaluar tareas, fallos, shutdown y pertenencia actual de `DEVICE_HOST` en cada petición.
    - Mantener `/healthz` en 200 cuando la interfaz desaparezca y cambiar `/readyz` a 503.
    - No realizar polling ni peticiones HTTP del servidor hacia sí mismo.
    - Verificación: pruebas de cada transición y de pérdida o caída simulada de interfaz.
    - **Complejidad:** Media
    - **Razonamiento recomendado:** Alto
    - **Razón:** combina estado concurrente y red dinámica sin introducir tareas adicionales.

13. **Implementar supervisión de fallos y shutdown coordinado.**
    - Al terminar inesperadamente cualquier tarea, marcar el runtime como fallido y comenzar el cierre completo.
    - Ante SIGINT o SIGTERM, fijar inmediatamente `SHUTTING_DOWN` y no volver a ready.
    - Solicitar el cierre de ambos servidores, esperar terminación normal, cancelar solo tareas pendientes y recolectarlas.
    - No aceptar trabajo nuevo desde el inicio del shutdown.
    - Tratar la interrupción controlada como terminación exitosa y evitar tracebacks de consola.
    - Verificación: pruebas de señal simulada, fallo de cada listener, cancelación tardía y ausencia de tareas pendientes.
    - **Complejidad:** Alta
    - **Razonamiento recomendado:** Alto
    - **Razón:** un error dejaría procesos parciales, tareas huérfanas o estados de lifecycle incorrectos.

14. **Publicar los entry points y códigos de salida.**
    - Implementar `ai-usage-meter-bridge` y `ai-usage-meter-init` como funciones síncronas pequeñas.
    - El inicializador acepta únicamente `--device-host`, `--device-id` y `--log-level`; no acepta token, ruta ni puertos.
    - El comando del bridge no acepta overrides de configuración o red.
    - Fijar:
      - `0`: éxito, configuración segura ya existente o shutdown controlado;
      - `1`: fallo interno inesperado;
      - `2`: uso inválido o configuración semántica inválida;
      - `3`: filesystem inseguro;
      - `4`: política de red, bind o arranque fallido.
    - No imprimir tracebacks ni valores sensibles para errores conocidos.
    - Verificación: pruebas de entry points, argumentos prohibidos y códigos de salida.
    - **Complejidad:** Media
    - **Razonamiento recomendado:** Medio
    - **Razón:** traduce componentes ya probados a una interfaz operativa pequeña y estable.

15. **Añadir documentación y prueba operativa separada.**
    - Crear `bridge/.env.example` con placeholders falsos e inválidos como secretos reales.
    - Documentar bootstrap, inicialización, ejecución, lifecycle, restricciones de red, reparación manual segura y comandos de calidad.
    - Configurar `tests/unit/` y `tests/integration/` como suite determinista predeterminada.
    - Añadir `tests/operational/` con marker `operational`, detección de una IPv4 RFC1918 real y bind autoritativo.
    - La prueba operativa informa `SKIPPED` con motivo cuando no existe una interfaz compatible y se ejecuta mediante un comando separado.
    - Verificación:
      - `uv run --locked pytest`;
      - `uv run --locked pytest tests/operational -m operational`.
    - **Complejidad:** Media
    - **Razonamiento recomendado:** Medio
    - **Razón:** documenta el contrato operativo y separa una dependencia real del host de la suite reproducible.

## Criterios de aceptación

### Precondiciones y reproducibilidad

- [ ] SPEC 00 continúa en estado `Approved`.
- [ ] SPEC 01 está `Implemented-Verified` antes de modificar `bridge/`; en caso contrario, SPEC 02 queda `Blocked`.
- [ ] `bridge/.python-version` fija exactamente Python `3.14.6`.
- [ ] `bridge/pyproject.toml` declara `requires-python = ">=3.14,<3.15"`.
- [ ] `uv_build==0.11.29` es el único backend de construcción.
- [ ] Todas las dependencias directas aprobadas usan `==` con la versión exacta.
- [ ] uv no aparece como dependencia del proyecto.
- [ ] Las dependencias transitivas están fijadas por `bridge/uv.lock`, no copiadas manualmente a `pyproject.toml`.
- [ ] `uv --version` reporta `0.11.29`.
- [ ] `uv lock --check` termina con código cero.
- [ ] `uv sync --locked` instala el paquete y termina con código cero.
- [ ] `uv run --locked python --version` reporta exactamente `3.14.6`.
- [ ] Los entry points `ai-usage-meter-bridge` y `ai-usage-meter-init` quedan instalados.
- [ ] No existen módulos o directorios vacíos para clientes, cachés, providers o funcionalidades futuras.

### Configuración runtime

- [ ] El bridge carga configuración únicamente desde `~/Library/Application Support/AIUsageMeter/bridge.env`.
- [ ] No existe opción de archivo de configuración por CLI.
- [ ] No existe variable de entorno que cambie la ruta, los puertos o `HEALTH_HOST`.
- [ ] Un `.env` en el repositorio o directorio de trabajo no modifica la configuración.
- [ ] Variables `AI_METER_*` del proceso no agregan, sustituyen ni eliminan valores de `bridge.env`.
- [ ] `BridgeSettings.settings_customise_sources()` devuelve únicamente `init_settings`.
- [ ] El parser acepta UTF-8 válido, líneas vacías, comentarios completos y las cinco claves autorizadas.
- [ ] `AI_METER_LOG_LEVEL` ausente produce `INFO`.
- [ ] Solo se aceptan `DEBUG`, `INFO`, `WARNING`, `ERROR` y `CRITICAL`.
- [ ] Se rechazan claves desconocidas, repetidas, sin prefijo y valores vacíos.
- [ ] Se rechazan BOM, bytes NUL, `export`, comillas, escapes, interpolación, multilinea, espacios no permitidos y comentarios inline.
- [ ] Solo se acepta `AI_METER_CONFIG_VERSION=1`.
- [ ] `DEVICE_ID` cumple `^[A-Za-z0-9][A-Za-z0-9._-]{2,63}$`.
- [ ] `DEVICE_TOKEN` cumple `^[A-Za-z0-9_-]{43,128}$`.
- [ ] El token se almacena como `SecretStr` y su representación normal no revela el valor.
- [ ] Ningún error de configuración incluye valores recibidos ni contenido del archivo.

### Seguridad del filesystem e inicialización

- [ ] El bridge usa `lstat` antes de leer el directorio dedicado y `bridge.env`.
- [ ] El directorio dedicado es real, pertenece al usuario efectivo y tiene modo exacto `0700`.
- [ ] `bridge.env` es regular, pertenece al usuario efectivo y tiene modo exacto `0600`.
- [ ] Un symlink en `AIUsageMeter/` o `bridge.env` impide el arranque antes de crear listeners.
- [ ] Un propietario, tipo o modo incorrecto impide el arranque antes de leer el archivo.
- [ ] `ai-usage-meter-init` establece temporalmente `umask 0o077`.
- [ ] El inicializador crea el directorio con `0700`.
- [ ] El inicializador crea `bridge.env` mediante creación exclusiva y modo `0600`.
- [ ] El inicializador valida host, identificador y nivel antes de escribir un archivo nuevo.
- [ ] El token generado por el inicializador contiene al menos 256 bits de entropía.
- [ ] El token no aparece en stdout, stderr, logs, argumentos, excepciones ni resultados.
- [ ] Una segunda ejecución sobre una configuración existente y segura termina con código cero sin leerla, modificarla ni rotar el token.
- [ ] Una configuración existente con metadata insegura produce fallo sin sobrescritura ni reparación automática.
- [ ] Un fallo durante la primera escritura limpia únicamente el archivo incompleto creado por esa ejecución.
- [ ] Dos inicializadores concurrentes no sobrescriben ni mezclan configuraciones.
- [ ] `bridge/.env.example` contiene solo placeholders falsos y ningún token aceptable como secreto real.
- [ ] El inventario creado por SPEC 01 registra `AI_METER_DEVICE_TOKEN` como alias o nombre lógico, propietario, consumidor, ubicación lógica y política de rotación, sin valor ni fragmento.

### Política de red

- [ ] `DEVICE_PORT` es la constante `8765`.
- [ ] `HEALTH_HOST` es la constante `127.0.0.1`.
- [ ] `HEALTH_PORT` es la constante `8766`.
- [ ] Ninguna de estas constantes puede cambiarse mediante archivo, entorno o CLI.
- [ ] Se acepta una IPv4 RFC1918 asignada exactamente a una interfaz con `isup=True`.
- [ ] Se rechaza una IPv4 RFC1918 no asignada al host.
- [ ] Se rechaza una IPv4 RFC1918 asignada a una interfaz con `isup=False`.
- [ ] Se rechazan wildcard, loopback, link-local, CGNAT, multicast, broadcast, IPv6 y direcciones públicas.
- [ ] La decisión no depende del nombre de la interfaz.
- [ ] El código y la documentación no afirman detectar todas las VPN.
- [ ] No se abre y cierra un socket provisional para probar disponibilidad.
- [ ] El socket enlazado es el socket autoritativo posteriormente entregado al servidor real.

### Superficie HTTP

- [ ] El listener de dispositivo enlaza únicamente la IPv4 configurada y el puerto `8765`.
- [ ] El listener lifecycle enlaza únicamente `127.0.0.1:8766`.
- [ ] OpenAPI, Swagger y ReDoc están desactivados en ambas aplicaciones.
- [ ] Uvicorn usa `server_header=False`, `date_header=False`, `access_log=False` y `proxy_headers=False`.
- [ ] `GET /healthz` devuelve 200 y exactamente `{"status":"ok"}`.
- [ ] `GET /readyz` devuelve 200 y exactamente `{"status":"ready"}` cuando todas las condiciones son válidas.
- [ ] `GET /readyz` devuelve 503 y exactamente `{"status":"not_ready"}` cuando falla cualquier condición.
- [ ] Las tres respuestas anteriores usan `Content-Type: application/json`.
- [ ] Ninguna respuesta lifecycle añade versión, timestamp, IP, identificador, motivo interno o nombre de componente.
- [ ] `POST /healthz` y `POST /readyz` devuelven 405 y exactamente `{"detail":"method_not_allowed"}`.
- [ ] Una ruta lifecycle inexistente devuelve 404 y exactamente `{"detail":"not_found"}`.
- [ ] Una excepción no controlada devuelve 500 y exactamente `{"detail":"internal_error"}`.
- [ ] El cuerpo 500 no contiene el mensaje original ni traceback.
- [ ] Cualquier método contra cualquier ruta del listener de dispositivo devuelve 404 y exactamente `{"detail":"not_found"}`.
- [ ] El listener de dispositivo no contiene rutas funcionales, de prueba, provisionales, de autenticación ni documentación.

### Coordinación, readiness y shutdown

- [ ] La configuración, filesystem e interfaz se validan antes de crear listeners.
- [ ] El proceso no comienza a servir hasta conservar los dos sockets enlazados.
- [ ] Un fallo de bind o arranque cierra todo recurso adquirido y termina con código distinto de cero.
- [ ] Nunca queda expuesto únicamente uno de los dos listeners después de un fallo de arranque.
- [ ] Readiness se calcula en cada petición y no se almacena como booleano independiente.
- [ ] Readiness comprueba fase, shutdown, estado de ambos listeners, tareas supervisoras, fallos internos e interfaz actual.
- [ ] `/readyz` no realiza una petición HTTP hacia el mismo servidor.
- [ ] No existe una tarea periódica de polling de readiness.
- [ ] Al perder la interfaz configurada, `/healthz` conserva 200 y `/readyz` cambia a 503 en la siguiente consulta.
- [ ] Si termina inesperadamente el listener de dispositivo, readiness deja de ser válido y comienza el apagado completo.
- [ ] Si termina inesperadamente el listener lifecycle, comienza el apagado completo.
- [ ] SIGINT y SIGTERM establecen `SHUTTING_DOWN` antes de solicitar el cierre de los servidores.
- [ ] Una vez iniciado el shutdown, readiness nunca vuelve a `ready`.
- [ ] Ambos servidores reciben solicitud de cierre.
- [ ] Solo se cancelan tareas que no terminaron mediante el flujo normal.
- [ ] Toda tarea cancelada es esperada y recolectada.
- [ ] Al finalizar no quedan tareas huérfanas del bridge.
- [ ] Un shutdown controlado termina sin traceback y con código cero.

### Autenticación interna

- [ ] La generación usa `secrets.token_urlsafe(32)`.
- [ ] La comparación usa `secrets.compare_digest`.
- [ ] Identificador ausente o desconocido y token ausente, malformado o incorrecto producen la misma clase y mensaje de error.
- [ ] Ninguna primitiva registra identificador, token ni causa diferenciada.
- [ ] Ninguna ruta FastAPI depende todavía de estas primitivas.
- [ ] No existe `/api/v1/usage` ni otro endpoint de dispositivo.

### Logging y secretos

- [ ] Cada línea emitida por el bridge en stderr es JSON válido.
- [ ] Cada evento contiene únicamente `timestamp`, `level`, `event` y, cuando corresponda, `request_id`.
- [ ] Los timestamps están expresados en UTC.
- [ ] Los request IDs son generados por el bridge.
- [ ] Un request ID enviado por un cliente no se adopta como identificador interno.
- [ ] Los eventos no contienen tokens, contenido de configuración, identificadores, direcciones, rutas personales ni excepciones crudas.
- [ ] Los health checks no producen access logs.
- [ ] Un error 500 genera un evento interno sanitizado sin exponer el mensaje original.
- [ ] Las pruebas negativas confirman que un token conocido no aparece en stdout, stderr ni logs capturados.
- [ ] El escaneo redactado de secretos termina sin detecciones reales no resueltas.
- [ ] Ningún `bridge.env` real, backup, token o fixture con formato válido queda versionado.

### Verificación automatizada y operativa

- [ ] `uv run --locked pytest` termina con código cero y ejecuta únicamente las suites deterministas predeterminadas.
- [ ] Las pruebas deterministas ejercitan dos listeners reales sobre loopback y puertos efímeros.
- [ ] Las políticas RFC1918 se prueban con inventarios inyectados, no dependen de la red del equipo.
- [ ] Los fallos de bind se prueban mediante seams internos.
- [ ] Ningún seam puede activarse mediante archivo, entorno, CLI o HTTP.
- [ ] `uv run --locked pytest tests/operational -m operational` ejecuta separadamente la prueba de interfaz real.
- [ ] La prueba operational realiza un bind real cuando detecta una IPv4 RFC1918 compatible.
- [ ] Si no existe una interfaz compatible, la prueba operational registra `SKIPPED` con motivo explícito.
- [ ] `uv run --locked ruff check .` termina con código cero.
- [ ] `uv run --locked ruff format --check .` termina con código cero.
- [ ] `uv run --locked mypy src tests` termina con código cero.
- [ ] `git diff --check` termina con código cero.
- [ ] El árbol final no incorpora Codex App Server, caché, métricas, Claude, launchd, contenedores, CI, TLS ni aprovisionamiento de firmware.

## Decisiones

### Toolchain y empaquetado

- **Sí:** Python `3.14.6`, uv `0.11.29`, pip `26.1.2` y `uv_build==0.11.29`; mantienen SPEC 01 y SPEC 02 sobre el mismo bootstrap.
- **No:** uv `0.11.30`; no corresponde a la versión coordinada y fue corregido en SPEC 01 como inconsistencia.
- **Sí:** dependencias directas con `==` en `pyproject.toml`; el bridge es una aplicación desplegable.
- **Sí:** dependencias transitivas resueltas exactamente en `uv.lock`; evita duplicarlas manualmente en el manifiesto.
- **No:** agregar uv como dependencia del proyecto; es una herramienta externa de bootstrap.
- **Sí:** `uv lock --check`, `uv sync --locked` y `uv run --locked`; comprueban que el manifiesto y el lock todavía coinciden.
- **No:** usar `--frozen` como criterio principal; consume el lock sin comprobar su correspondencia con `pyproject.toml`.
- **Sí:** layout `src/`, paquete `ai_usage_meter_bridge` y entry points instalables.
- **No:** crear esqueletos vacíos para integraciones futuras; cada módulo de SPEC 02 debe tener un consumidor real.

### Configuración y filesystem

- **Sí:** `bridge.env` es la única fuente runtime autoritativa.
- **No:** autodetectar `.env` desde el repositorio, el cwd o directorios padre.
- **No:** permitir que variables del proceso sobrescriban el archivo; una variable heredada no debe cambiar silenciosamente el servicio.
- **Sí:** usar `BaseSettings` con `settings_customise_sources()` limitado a `init_settings`; conserva Pydantic Settings sin activar fuentes implícitas.
- **Sí:** analizar primero el archivo con un parser estricto y construir después el modelo Pydantic.
- **No:** confiar únicamente en `extra="forbid"`; no detecta por sí solo duplicados ni toda la sintaxis prohibida.
- **No:** usar la semántica flexible de dotenv para `export`, expansión, comillas, escapes o multilinea; el formato deliberadamente pequeño reduce ambigüedad.
- **Sí:** ruta fija bajo `~/Library/Application Support/AIUsageMeter/`.
- **No:** configurar esa ruta mediante archivo, entorno o CLI.
- **Sí:** exigir modos exactos `0700` y `0600`, propietario efectivo, tipos esperados y ausencia de symlinks.
- **No:** corregir permisos, propietario o tipos automáticamente; una reparación silenciosa puede ocultar manipulación local.
- **Sí:** validar metadata con `lstat` antes de leer contenido.
- **Sí:** permitir `DEBUG`, pero solo mediante el archivo autoritativo y sin ampliar el esquema permitido de logs.

### Inicialización y secretos

- **Sí:** `ai-usage-meter-init` crea la configuración de forma exclusiva, atómica e idempotente.
- **Sí:** el inicializador acepta host, identificador y nivel de log como datos no secretos.
- **No:** aceptar el token por argumento, stdin, entorno o copy/paste.
- **Sí:** generar el token dentro del proceso con `secrets.token_urlsafe(32)` y escribirlo directamente.
- **No:** mostrar el token una sola vez; el aprovisionamiento posterior deberá leerlo por un canal protegido.
- **Sí:** una configuración existente y segura produce éxito sin lectura, modificación ni rotación.
- **No:** ofrecer `--force`; la rotación y el reemplazo quedan fuera de SPEC 02.
- **Sí:** `bridge/.env.example` usa placeholders manifiestamente falsos.
- **No:** incluir un token sintácticamente válido en ejemplos o fixtures versionados.
- **Sí:** registrar `AI_METER_DEVICE_TOKEN` en el inventario sin valor ni fragmento.
- **No:** afirmar ausencia absoluta de secretos; se exige cero detecciones reales no resueltas dentro del alcance y método documentados.

### Red

- **Sí:** `psutil==7.2.2` para obtener direcciones y estado `isup` de interfaces.
- **Sí:** aceptar únicamente una IPv4 RFC1918 explícita, asignada exactamente y activa.
- **No:** aceptar wildcard, loopback, link-local, CGNAT, multicast, broadcast, IPv6 o IP pública.
- **No:** decidir por nombres como `en0`, `utun`, `bridge` o equivalentes; no forman parte del contrato.
- **No:** afirmar detección general de VPN; la dirección por sí sola no permite esa garantía.
- **Sí:** puertos `8765` y `8766` y host lifecycle `127.0.0.1` como constantes internas.
- **No:** permitir overrides de red por CLI, entorno o archivo.
- **Sí:** usar como prueba definitiva el bind del socket que conservará el listener.
- **No:** realizar un bind provisional que abra una carrera antes del arranque real.
- **No:** descubrimiento automático de la IP del dispositivo; el operador debe fijar explícitamente `DEVICE_HOST`.

### HTTP y autenticación

- **Sí:** dos aplicaciones FastAPI y dos listeners separados; aíslan lifecycle de la superficie LAN.
- **Sí:** lifecycle accesible únicamente por loopback.
- **Sí:** publicar solo `GET /healthz` y `GET /readyz` en SPEC 02.
- **Sí:** dejar el listener de dispositivo sin rutas; valida la frontera de red sin adelantar SPEC 05.
- **No:** publicar `/api/v1/usage`, endpoints provisionales o rutas de autenticación.
- **Sí:** implementar y probar primitivas internas de autenticación ahora; reduce riesgo al integrarlas en SPEC 05.
- **No:** conectar esas primitivas a dependencias FastAPI todavía.
- **Sí:** `secrets.compare_digest` y un único fallo genérico de autenticación.
- **No:** distinguir externamente identificador desconocido, token ausente, malformado o incorrecto.
- **Sí:** desactivar OpenAPI, Swagger y ReDoc en ambas aplicaciones.
- **Sí:** desactivar cabeceras `Server` y `Date`, access logs y proxy headers.
- **No:** confiar en cabeceras reenviadas; no existe un proxy confiable en esta arquitectura.
- **Sí:** fijar cuerpos JSON mínimos para 200, 404, 405, 500 y 503.
- **No:** incluir versión, timestamp, IP, identificador, motivo interno o nombres de componentes.
- **Sí:** devolver 405 solo cuando la ruta existe y el método es incorrecto.
- **Sí:** devolver siempre 404 en el listener de dispositivo, porque no tiene rutas.
- **No:** exponer mensajes o tracebacks originales en respuestas 500.

### Coordinación y lifecycle

- **Sí:** validar configuración, filesystem e interfaz antes de enlazar sockets.
- **Sí:** conservar ambos sockets autoritativos antes de empezar a servir.
- **No:** mantener un listener parcial si falla el otro.
- **Sí:** calcular readiness en cada petición.
- **No:** almacenar un booleano independiente que pueda quedar obsoleto.
- **No:** agregar polling periódico; no aporta información adicional para este baseline.
- **No:** efectuar self-check HTTP del lifecycle listener; una petición recibida ya demuestra parcialmente su disponibilidad.
- **Sí:** reevaluar la interfaz con `psutil` en cada `/readyz`.
- **Sí:** mantener `/healthz` en 200 cuando la interfaz cae y degradar `/readyz` a 503.
- **Sí:** apagar el proceso completo si termina inesperadamente cualquiera de las tareas supervisoras.
- **No:** recuperación automática de listeners; queda fuera y podría ocultar un fallo persistente.
- **Sí:** shutdown coordinado, cancelación solo como último recurso y recolección de todas las tareas.
- **Sí:** tratar SIGINT y SIGTERM controlados como salida limpia.
- **No:** volver a ready después de comenzar la terminación.

### Logging y pruebas

- **Sí:** JSON por stderr usando un esquema cerrado y eventos sanitizados.
- **No:** añadir `structlog` u otra dependencia de logging; la biblioteca estándar cubre el contrato mínimo.
- **Sí:** generar request IDs internamente.
- **No:** confiar en request IDs suministrados por clientes.
- **No:** incluir excepciones crudas o datos dinámicos sensibles en `event`.
- **Sí:** seams internos para interfaces, sockets, servidores, señales, reloj y eventos.
- **No:** activar seams mediante archivo, entorno, CLI, HTTP o flags ocultos.
- **Sí:** listeners reales sobre loopback y puertos efímeros en la suite determinista.
- **Sí:** inventarios de red simulados para probar exhaustivamente la política RFC1918.
- **Sí:** una prueba `operational` separada para la interfaz real del Mac.
- **Sí:** permitir `SKIPPED` explícito cuando no exista una interfaz compatible.
- **No:** convertir la red física del host en prerrequisito de la suite determinista.
- **No:** crear un workflow de CI en SPEC 02; se fijan comandos reproducibles, pero su automatización queda fuera.
- **No:** integrar Codex App Server, uso, caché, métricas, Claude, launchd, contenedores, TLS o firmware.

## Riesgos

| Riesgo | Impacto | Mitigación obligatoria |
|---|---|---|
| Carrera entre `lstat` y la apertura de `bridge.env` | Un atacante local podría sustituir el archivo validado por un symlink u otro inode | Abrir con `O_NOFOLLOW` cuando esté disponible, ejecutar `fstat` sobre el descriptor abierto y comprobar nuevamente tipo, propietario, modo, dispositivo e inode antes de leer. |
| Resolver `~` mediante un `$HOME` manipulado | El bridge podría leer o crear configuración fuera del home del usuario efectivo | Resolver el home con la identidad del usuario efectivo —por ejemplo, `pwd.getpwuid(os.getuid()).pw_dir` en macOS— y no desde variables de proceso. |
| Fuentes implícitas reintroducidas por Pydantic Settings | Variables del proceso o archivos dotenv podrían sobrescribir la configuración autoritativa | Conservar exclusivamente `init_settings` y probar con entorno y archivos señuelo. |
| Parser demasiado permisivo | Sintaxis ambigua, interpolación o claves duplicadas podrían alterar el significado del archivo | Gramática cerrada, whitelist previa a Pydantic y pruebas negativas por cada forma prohibida. |
| Parser demasiado estricto sin documentación | Un operador podría crear manualmente un archivo aparentemente razonable pero inválido | Documentar la gramática exacta y recomendar siempre `ai-usage-meter-init`. |
| Exposición del token durante generación o validación | Compromiso de la API de dispositivo futura | Generación dentro del proceso, `SecretStr`, esquema cerrado de logs, ausencia de token en argumentos y pruebas de no exposición. |
| Archivo parcialmente escrito por interrupción | El siguiente arranque encuentra una configuración segura por metadata pero inválida por contenido | Escritura completa comprobada, `fsync`, cierre controlado y eliminación únicamente del archivo nuevo creado por la ejecución fallida. |
| Dos inicializadores concurrentes | Sobrescritura o mezcla de tokens y configuración | Creación exclusiva con `O_CREAT | O_EXCL`; una sola ejecución crea y la otra termina idempotentemente sin modificar. |
| Fixture versionado con apariencia de token real | Falso positivo del scanner o copia accidental como credencial | Construir tokens de prueba en runtime y mantener placeholders versionados deliberadamente inválidos. |
| Nivel `DEBUG` revela datos adicionales | Secretos o información de red podrían aparecer al diagnosticar | Mantener el mismo esquema y catálogo sanitizado en todos los niveles; DEBUG no habilita payloads ni excepciones crudas. |
| Una interfaz VPN usa una IPv4 RFC1918 válida | El bridge puede enlazarse a una interfaz que el operador no considera LAN | No prometer clasificación VPN; exigir host explícito, documentar la limitación y no decidir por nombre de interfaz. |
| La interfaz cambia después de responder ready | Existe una carrera inevitable entre la comprobación y el siguiente evento de red | Reevaluar en cada `/readyz`, degradar inmediatamente en la siguiente consulta y apagar ante fallo efectivo del listener. |
| Superficie LAN sin TLS | Tráfico futuro podría ser observado dentro de la red local | En SPEC 02 el listener no publica rutas; autenticación, rate limiting y decisiones de transporte se resuelven antes de publicar `/api/v1/usage`. |
| Colisión en los puertos fijos | El bridge no puede iniciar | Fallar cerrado con código conocido, cerrar el otro socket y documentar cómo identificar el proceso en conflicto sin cambiar puertos. |
| Fallo del segundo bind después de enlazar el primero | Queda un listener parcial o un descriptor abierto | No empezar a servir hasta conservar ambos sockets y cerrar todos los descriptores adquiridos ante cualquier fallo. |
| Fallo inesperado de una tarea Uvicorn | El proceso conserva solo lifecycle o solo dispositivo | Supervisor común que marca fallo, degrada readiness e inicia el cierre completo. |
| Shutdown lento o tarea resistente a cancelación | Proceso colgado o tareas huérfanas | Cierre cooperativo primero, cancelación limitada después, recolección de todas las tareas y pruebas de timeout controlado. |
| La ventana de readiness 503 durante shutdown es demasiado breve para observarla externamente | Una prueba exclusivamente HTTP podría no demostrar la transición | Verificar el estado interno y la imposibilidad de volver a ready, además de probar HTTP mientras el listener aún acepta la petición. |
| La prueba operational se omite por falta de interfaz RFC1918 | No queda evidencia de bind real en ese host | Registrar `SKIPPED` explícito y ejecutar la prueba en el Mac objetivo antes de usar el servicio sobre LAN. |
| `psutil` no dispone de wheel o comportamiento compatible en macOS arm64/Python 3.14 | El entorno no instala o el inventario difiere | Fijar `psutil==7.2.2` en el lock y comprobar instalación, importación e inventario en la plataforma certificada. |
| Deriva entre `pyproject.toml` y `uv.lock` | Una instalación usa dependencias distintas de las revisadas | Exigir `uv lock --check` y todos los comandos con `--locked`. |
| Un pin queda vulnerable u obsoleto | El lock reproducible conserva una dependencia con un problema conocido | Actualizar mediante una spec o revisión explícita, regenerar el lock y repetir toda la aceptación; nunca actualizar dinámicamente al arrancar. |
| Un handler 500 captura o imprime una excepción cruda | Filtración de rutas, configuración o secretos | Respuesta fija, evento sanitizado y pruebas con excepciones que contienen un token señuelo. |
| El request ID del cliente se reutiliza | Manipulación o correlación engañosa de logs | Ignorar identificadores entrantes y generar uno nuevo dentro del bridge. |
| Los seams de prueba llegan a producción | Podrían eludir la política de red o cambiar puertos | Inyección únicamente por constructores o callables internos; pruebas que demuestren ausencia de flags, variables, claves y endpoints de activación. |
| La ausencia de CI permite omitir verificaciones | Cambios posteriores podrían romper el contrato sin señal automática | Mantener comandos reproducibles como gates obligatorios de `/spec-check`; automatizar CI solo en una spec posterior. |

## Qué no incluye esta spec

- Codex App Server ni ningún cliente, transporte o sesión asociado.
- Lectura, cálculo, normalización o exposición de uso.
- Caché, snapshots, métricas o endpoints adicionales de observabilidad.
- `/api/v1/usage` ni ninguna ruta funcional del listener de dispositivo.
- Autenticación conectada a FastAPI; SPEC 02 entrega solo las primitivas internas.
- Integración con Claude o manejo de sus credenciales.
- Aprovisionamiento del dispositivo o transferencia del token al firmware.
- Rotación, recuperación, importación o visualización de tokens.
- launchd, contenedores o workflows de CI.
- TLS o terminación HTTPS.
- Descubrimiento automático de red.
- Clasificación de interfaces como VPN, LAN, Wi-Fi, Ethernet o túnel.
- Recuperación o reinicio automático de listeners.
- Cambios de firmware o pruebas sobre hardware CYD.

Cualquiera de estas capacidades requiere su spec correspondiente y no puede incorporarse incidentalmente durante `/spec-impl`.

## Resumen de complejidad y razonamiento

| Tipo | Alto/Alta | Medio/Media | Bajo/Baja |
|---|---:|---:|---:|
| Complejidad | 4 | 9 | 2 |
| Razonamiento recomendado | 9 | 4 | 2 |
