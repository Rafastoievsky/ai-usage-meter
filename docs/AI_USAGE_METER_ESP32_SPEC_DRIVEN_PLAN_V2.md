# AI Usage Meter para ESP32-2432S028R
## Plan maestro de implementación con Spec-Driven Design

> **Estado:** Propuesta base para convertir `clawd-meter` en un medidor local de consumo de Claude + Codex/ChatGPT Plus.  
> **Hardware objetivo:** ESP32-2432S028R, también conocido como Cheap Yellow Display (CYD), pantalla ILI9341 320×240 con touch resistivo.  
> **Organización del código:** repositorio principal `Medidor/` + fork `clawd-meter/` integrado como submódulo Git.  
> **Fecha de validación técnica:** 18 de julio de 2026.  
> **Uso previsto:** personal y educativo; no exponer servicios a Internet.

---

# 1. Resumen ejecutivo

El objetivo es crear un dispositivo de escritorio que muestre:

- Consumo de **Codex asociado a ChatGPT Plus**.
- Ventana principal de aproximadamente **5 horas**.
- Ventana secundaria **semanal**.
- Porcentaje utilizado y restante.
- Fecha/hora del próximo reinicio.
- Estado de conexión y antigüedad de los datos.
- Consumo de Claude en la misma interfaz.
- Animaciones existentes de Clawd, adaptadas para reaccionar a Claude, Codex o al límite más crítico.
- Navegación táctil y rotación automática entre pantallas.

La solución estará dividida en dos componentes:

1. **Firmware del ESP32**
   - Conserva pantalla, touch, canales, animaciones, reloj, clima y portal web del repositorio original.
   - Consulta un endpoint local.
   - Nunca almacena cookies de ChatGPT, tokens OAuth de Codex ni `~/.codex/auth.json`.

2. **Bridge local**
   - Corre en la Mac donde ya utilizas Codex CLI.
   - Inicia `codex app-server` mediante `stdio`.
   - Ejecuta `account/rateLimits/read`.
   - Normaliza los límites.
   - Expone al ESP32 únicamente porcentajes, reinicios y estado.
   - Posteriormente también consulta Claude, manteniendo la cookie fuera del ESP32.

La primera versión funcional debe priorizar **Codex**. Claude se integra después de cerrar el bridge, la seguridad y la comunicación con el display.

La solución tendrá dos componentes de ejecución, pero se administrará con **dos repositorios coordinados**:

1. **Repositorio principal `Medidor/`**
   - SPECs.
   - Bridge local.
   - Documentación.
   - Contratos compartidos.
   - Scripts operativos.
   - Coordinación de releases.

2. **Fork `Medidor/clawd-meter/`**
   - Firmware ESP32.
   - Recursos LittleFS.
   - Configuración PlatformIO.
   - Pantallas, touch, canales y animaciones.
   - Historial separado y sincronización independiente con el upstream original.

El fork se integrará preferentemente como **submódulo Git**. El repositorio principal fijará el commit exacto del firmware compatible con cada versión del bridge y del contrato HTTP.

---

# 2. Decisiones arquitectónicas confirmadas

## ADR-001 — Separación coordinada de bridge y firmware

**Estado:** Aceptado  
**Carácter:** Vinculante para SPEC 01–12

El proyecto se divide en dos repositorios con responsabilidades distintas:

1. **Repositorio principal `Medidor/`**
   - Contiene `specs/`, `docs/`, `bridge/`, scripts, contratos compartidos y coordinación de releases.
   - Es la fuente de verdad del producto completo.
   - Registra qué revisión del firmware es compatible con cada release.

2. **Fork `Medidor/clawd-meter/`**
   - Contiene exclusivamente el firmware, los recursos LittleFS y la configuración PlatformIO.
   - Conserva su propio historial Git.
   - Mantiene un remoto `upstream` hacia `monsierfux/clawd-meter`.
   - Recibe únicamente cambios propios del ESP32.

El fork se integrará preferentemente como **submódulo Git** del repositorio principal. El commit del submódulo será parte del contrato de release.

No se reescribirá el firmware desde cero. Se conservarán:

- `platformio.ini`.
- Configuración del entorno `cyd`.
- TFT_eSPI.
- XPT2046 Touchscreen.
- LittleFS.
- Sistema de canales.
- Navegación táctil.
- Rotación automática.
- Animaciones de `ch_clawd.cpp`.
- Reloj, clima, forecast e información del sistema.
- Web UI existente como base.

No se moverá el código original del firmware al repositorio principal y no se incorporará el bridge dentro del fork.

**Motivos:**

- Separar runtimes, dependencias y ciclos de despliegue.
- Facilitar la comparación del fork contra su upstream.
- Evitar mezclar Python/FastAPI con PlatformIO.
- Mantener licencias e historial del proyecto derivado claramente identificables.
- Permitir releases reproducibles mediante un commit exacto del submódulo.
- Evitar que los SPECs queden subordinados al repositorio heredado.

**Regla de cambio:** modificar esta decisión requiere un ADR nuevo que documente impacto, migración, compatibilidad y actualización de los SPECs afectados.

---

## ADR-002 — Codex App Server mediante `stdio`

El bridge ejecutará:

```bash
codex app-server
```

El transporte será:

```text
stdio → JSONL → JSON-RPC
```

No se abrirá directamente el WebSocket de App Server en la red.

Secuencia mínima:

```json
{"method":"initialize","id":1,"params":{"clientInfo":{"name":"ai_usage_meter_bridge","title":"AI Usage Meter Bridge","version":"0.1.0"}}}
{"method":"initialized","params":{}}
{"method":"account/rateLimits/read","id":2}
```

El bridge mantendrá un proceso persistente y asociará respuestas por `id`.

---

## ADR-003 — No colocar credenciales de ChatGPT en el ESP32

Queda prohibido guardar en el firmware o LittleFS:

- Cookies de `chatgpt.com`.
- Access token de ChatGPT.
- Refresh token.
- Contenido de `~/.codex/auth.json`.
- API key de OpenAI.
- Sesiones OAuth.
- Credenciales de administrador de una organización OpenAI.

El ESP32 solo almacenará:

- URL local del bridge.
- Identificador del dispositivo.
- Token de lectura revocable y de bajo alcance.
- Preferencias de interfaz.

---

## ADR-004 — Bridge local de solo lectura

El bridge no ejecutará tareas de Codex ni iniciará conversaciones.

Únicamente usará:

```text
account/read
account/rateLimits/read
account/rateLimits/updated
```

Para la V1, `account/rateLimits/updated` puede registrarse, pero la fuente autoritativa será una lectura completa periódica con `account/rateLimits/read`.

---

## ADR-005 — Mantener las animaciones

Las animaciones existentes se reutilizarán.

La expresión automática podrá tomar como fuente:

```text
claude
codex
critical
active_screen
```

Valor recomendado:

```text
critical
```

En modo `critical`, Clawd reaccionará al porcentaje utilizado más alto entre las ventanas principales disponibles.

---

## ADR-006 — Incremental antes que refactor masivo

En la primera etapa no se eliminará `ClaudeData`.

Se agregará un modelo paralelo:

```cpp
struct CodexData;
struct BridgeStatus;
```

Y `ChannelCtx` se ampliará:

```cpp
struct ChannelCtx {
    const Settings* settings;
    const ClaudeData* claude;
    const CodexData* codex;
    const BridgeStatus* bridge;
    uint32_t now_ms;
};
```

Después de comprobar Codex en hardware podrá evaluarse un modelo genérico multiproveedor.

---

# 3. Alcance del producto

## 3.1 Alcance de la V1.0

La V1.0 queda terminada cuando:

- El CYD inicia y se conecta al Wi-Fi.
- El bridge inicia automáticamente en macOS.
- El bridge detecta la cuenta ChatGPT usada por Codex.
- El bridge obtiene los límites actuales.
- El bridge identifica ventana de 5 horas y semanal.
- El ESP32 muestra Codex en una pantalla dedicada.
- El ESP32 muestra Claude y Codex en resumen.
- Clawd conserva parpadeos, movimiento y expresiones.
- Las animaciones pueden usar Codex como fuente.
- El dispositivo indica datos obsoletos.
- No se almacenan credenciales ChatGPT en el ESP32.
- Las rutas administrativas sensibles están protegidas.
- Existe un procedimiento reproducible de compilación, pruebas y flashing.

## 3.2 Fuera de alcance de la V1.0

- Publicar el bridge en Internet.
- Aplicación móvil.
- Dashboard histórico complejo.
- Base de datos.
- Multiusuario.
- Varios hogares.
- Venta o distribución comercial con la mascota o marcas actuales.
- Consumo de créditos adicionales.
- Ejecutar prompts de Codex desde la pantalla.
- Reiniciar límites o consumir reset credits.
- Administrar la cuenta ChatGPT.
- Reemplazar el CLI de Codex.

## 3.3 Futuras extensiones

- Historial local SQLite.
- Dashboard web de consumo.
- Gemini CLI.
- GLM/Z.ai.
- Antigravity, Cursor u otros proveedores.
- Métricas por modelo.
- MQTT/Home Assistant.
- HTTPS con CA privada y certificado fijado.
- Caja personalizada impresa en 3D.
- Indicador RGB externo.

---

# 4. Preparación física y respaldo

## Paso 1 — Confirmar el hardware

Verificar visualmente:

- Modelo: `ESP32-2432S028R`.
- Pantalla de 2.8 pulgadas.
- Resolución nominal 320×240.
- Touch resistivo.
- Conector USB de datos.
- Cable USB capaz de transferir datos.

## Paso 2 — Crear una red de desarrollo

Recomendado:

- Usar una red IoT o de invitados.
- Permitir comunicación entre la Mac y el ESP32.
- No exponer puertos del router.
- Crear una reserva DHCP para:
  - Mac.
  - ESP32.

Ejemplo:

```text
Mac bridge: 192.168.20.10
ESP32:      192.168.20.50
```

## Paso 3 — Identificar el puerto serial

En macOS:

```bash
ls /dev/cu.*
```

Posibles nombres:

```text
/dev/cu.usbserial-0001
/dev/cu.wchusbserial*
/dev/cu.SLAB_USBtoUART
```

## Paso 4 — Respaldar la memoria flash completa

Antes de modificar el dispositivo:

```bash
mkdir -p backups

python -m esptool \
  --chip esp32 \
  --port /dev/cu.usbserial-XXXX \
  read_flash 0x0 0x400000 backups/cyd-factory-4mb.bin
```

Validar:

```bash
ls -lh backups/cyd-factory-4mb.bin
shasum -a 256 backups/cyd-factory-4mb.bin
```

Guardar el hash en:

```text
backups/SHA256SUMS.txt
```

## Paso 5 — No ingresar todavía la cookie de Claude

La prueba inicial solo validará:

- Compilación.
- Pantalla.
- Touch.
- Wi-Fi.
- LittleFS.
- Animaciones.

No pegar `sessionKey` en el firmware original.

---

# 5. Preparación de herramientas en macOS

## 5.1 Herramientas necesarias

- Git.
- Python 3.12 o superior.
- `uv` o entorno virtual equivalente.
- PlatformIO CLI.
- Codex CLI actualizado y autenticado con ChatGPT.
- Un editor como VS Code.
- Opcional: `jq`, `curl`, `make`.

## 5.2 Verificaciones

```bash
git --version
python3 --version
pio --version
codex --version
codex --help
```

Confirmar que aparece:

```text
app-server
```

Confirmar que Codex reconoce la cuenta:

```bash
codex
```

Dentro de una sesión:

```text
/status
```

Registrar manualmente lo que muestra para compararlo después con el bridge.

## 5.3 Generar esquemas de la versión instalada de Codex

Crear una carpeta temporal:

```bash
mkdir -p bridge/schemas/codex
```

Ejecutar:

```bash
codex app-server generate-json-schema \
  --out bridge/schemas/codex
```

Opcionalmente:

```bash
codex app-server generate-ts \
  --out bridge/schemas/codex-ts
```

**Regla:** los esquemas generados corresponden a la versión instalada. Deben regenerarse cuando se actualice Codex y cambie el contrato.

---

# 6. Creación y coordinación de repositorios

## 6.1 Estructura Git objetivo

```text
Medidor/                         # repositorio principal
├── .git/
├── specs/
├── docs/
├── bridge/
├── scripts/
├── releases/
└── clawd-meter/                 # submódulo: fork del firmware
    └── .git                     # metadatos administrados por Git submodule
```

El workspace deja de ser una carpeta sin versionar: `Medidor/` se convierte en el repositorio principal del producto.

## 6.2 Crear el repositorio principal

Desde la carpeta existente:

```bash
cd Medidor

git init
git checkout -b main

mkdir -p \
  specs \
  docs \
  bridge \
  scripts \
  releases \
  backups
```

Crear un `.gitignore` mínimo:

```gitignore
# Secretos
.env
.env.*
!.env.example

# Python
.venv/
__pycache__/
.pytest_cache/
.mypy_cache/
.ruff_cache/

# Build y artefactos locales
dist/
build/
backups/*
!backups/.gitkeep

# macOS
.DS_Store

# PlatformIO pertenece al submódulo
clawd-meter/.pio/
```

Primer commit:

```bash
touch backups/.gitkeep

git add .gitignore CLAUDE.md specs docs bridge scripts releases backups/.gitkeep
git commit -m "chore: initialize AI usage meter workspace"
```

Si algunos directorios todavía están vacíos, agregar `.gitkeep` donde sea necesario.

## 6.3 Preparar el fork de firmware

Hacer fork de:

```text
monsierfux/clawd-meter
```

Nombre recomendado del fork:

```text
clawd-meter
```

Dentro del fork, conservar:

```text
origin   → git@github.com:TU_USUARIO/clawd-meter.git
upstream → https://github.com/monsierfux/clawd-meter.git
```

Verificación:

```bash
cd clawd-meter

git remote -v
git status
```

Agregar upstream si todavía no existe:

```bash
git remote add upstream https://github.com/monsierfux/clawd-meter.git
```

## 6.4 Integrar el fork como submódulo

### Caso A — `clawd-meter/` todavía no contiene cambios locales

Desde `Medidor/`:

```bash
git submodule add \
  git@github.com:TU_USUARIO/clawd-meter.git \
  clawd-meter

git commit -m "chore: add clawd-meter firmware submodule"
```

### Caso B — ya existe `Medidor/clawd-meter/` como clone independiente

Antes de convertirlo:

```bash
cd Medidor/clawd-meter

git status
git branch --show-current
git remote -v
```

Si hay cambios, deben comitearse y subirse al fork antes de continuar:

```bash
git add .
git commit -m "chore: preserve local firmware baseline"
git push -u origin HEAD
```

Después, desde la carpeta padre:

```bash
cd Medidor

mv clawd-meter ../clawd-meter-local-backup

git submodule add \
  git@github.com:TU_USUARIO/clawd-meter.git \
  clawd-meter
```

Comprobar que el submódulo apunta al commit esperado:

```bash
cd clawd-meter
git log -1 --oneline
cd ..
git status
```

Solo después de verificar que no falta ningún cambio puede eliminarse el backup local.

## 6.5 Clonar el proyecto completo en otra máquina

```bash
git clone --recurse-submodules \
  git@github.com:TU_USUARIO/ai-usage-meter.git \
  Medidor
```

Si ya se clonó sin submódulos:

```bash
git submodule update --init --recursive
```

## 6.6 Crear la estructura del código nuevo

Desde `Medidor/`:

```bash
mkdir -p \
  bridge/src/ai_meter_bridge/api \
  bridge/src/ai_meter_bridge/cache \
  bridge/src/ai_meter_bridge/clients \
  bridge/src/ai_meter_bridge/domain \
  bridge/src/ai_meter_bridge/providers \
  bridge/src/ai_meter_bridge/security \
  bridge/src/ai_meter_bridge/services \
  bridge/tests/unit \
  bridge/tests/integration \
  bridge/tests/fixtures \
  bridge/scripts \
  bridge/launchd \
  specs \
  docs \
  scripts \
  releases
```

## 6.7 Reglas de propiedad

| Ruta | Repositorio | Contenido |
|---|---|---|
| `specs/` | `Medidor` | Contratos de implementación |
| `docs/` | `Medidor` | Arquitectura, operación y evidencia |
| `bridge/` | `Medidor` | Servicio Python/FastAPI |
| `scripts/` | `Medidor` | Orquestación, backup y release |
| `releases/` | `Medidor` | Manifiestos de compatibilidad |
| `clawd-meter/` | fork/submódulo | Firmware y recursos del ESP32 |

El repositorio padre no debe absorber los archivos internos del firmware como archivos normales. Solo registra el commit del submódulo.

---

# 7. Estructura final propuesta

```text
Medidor/
├── .git/
├── .gitmodules
├── .gitignore
├── README.md
├── CLAUDE.md
├── Makefile
│
├── .github/
│   └── workflows/
│       ├── bridge-tests.yml
│       ├── workspace-validation.yml
│       └── release-manifest.yml
│
├── specs/
│   ├── 00-arquitectura-alcance-seguridad.md
│   ├── 01-baseline-firmware-hardware.md
│   ├── 02-bridge-base-configuracion.md
│   ├── 03-cliente-codex-app-server.md
│   ├── 04-normalizacion-limites-cache.md
│   ├── 05-api-dispositivo-autenticacion.md
│   ├── 06-firmware-cliente-bridge-modelos.md
│   ├── 07-canal-codex-interfaz.md
│   ├── 08-clawd-animaciones-multiproveedor.md
│   ├── 09-web-ui-seguridad-configuracion.md
│   ├── 10-claude-migracion-al-bridge.md
│   ├── 11-resiliencia-observabilidad-servicio.md
│   └── 12-release-flashing-runbook.md
│
├── docs/
│   ├── architecture.md
│   ├── api-contract.md
│   ├── threat-model.md
│   ├── hardware-test-checklist.md
│   ├── compatibility-matrix.md
│   └── troubleshooting.md
│
├── bridge/
│   ├── pyproject.toml
│   ├── uv.lock
│   ├── README.md
│   ├── .env.example
│   ├── schemas/
│   │   └── codex/
│   ├── launchd/
│   │   └── com.local.ai-usage-meter-bridge.plist.example
│   ├── scripts/
│   │   ├── probe_codex.py
│   │   └── generate_device_token.py
│   ├── src/
│   │   └── ai_meter_bridge/
│   │       ├── __init__.py
│   │       ├── main.py
│   │       ├── config.py
│   │       ├── logging_config.py
│   │       ├── lifecycle.py
│   │       ├── api/
│   │       │   ├── __init__.py
│   │       │   ├── dependencies.py
│   │       │   ├── health.py
│   │       │   └── usage.py
│   │       ├── cache/
│   │       │   ├── __init__.py
│   │       │   └── memory.py
│   │       ├── clients/
│   │       │   ├── __init__.py
│   │       │   ├── jsonrpc.py
│   │       │   └── codex_app_server.py
│   │       ├── domain/
│   │       │   ├── __init__.py
│   │       │   ├── enums.py
│   │       │   └── models.py
│   │       ├── providers/
│   │       │   ├── __init__.py
│   │       │   ├── base.py
│   │       │   ├── codex.py
│   │       │   └── claude.py
│   │       ├── security/
│   │       │   ├── __init__.py
│   │       │   ├── auth.py
│   │       │   └── redaction.py
│   │       └── services/
│   │           ├── __init__.py
│   │           └── usage_service.py
│   └── tests/
│       ├── fixtures/
│       ├── unit/
│       └── integration/
│
├── scripts/
│   ├── backup_flash.sh
│   ├── restore_flash.sh
│   ├── flash_firmware.sh
│   ├── monitor_serial.sh
│   └── verify_workspace.sh
│
├── releases/
│   ├── README.md
│   └── manifests/
│       └── .gitkeep
│
├── backups/
│   └── .gitkeep
│
└── clawd-meter/                     # submódulo Git
    ├── .git
    ├── .github/
    │   └── workflows/
    │       └── firmware-build.yml
    ├── data/
    │   ├── web/
    │   ├── fonts/
    │   └── ...
    ├── images/
    ├── tools/
    ├── platformio.ini
    └── src/
        ├── channels/
        │   ├── ch_claude.cpp
        │   ├── ch_clawd.cpp
        │   ├── ch_codex.cpp
        │   ├── ch_ai_summary.cpp
        │   ├── ch_clock.cpp
        │   ├── ch_forecast.cpp
        │   ├── ch_home.cpp
        │   ├── ch_info.cpp
        │   ├── ch_push.cpp
        │   ├── ch_weather.cpp
        │   └── channel.h
        ├── core/
        │   ├── compat.h
        │   ├── config.h
        │   ├── display.cpp
        │   ├── display.h
        │   ├── layout.h
        │   ├── storage.cpp
        │   ├── storage.h
        │   ├── theme.h
        │   ├── web.cpp
        │   └── web.h
        ├── data/
        │   ├── api.cpp
        │   ├── api.h
        │   ├── bridge_api.cpp
        │   ├── bridge_api.h
        │   ├── usage_models.h
        │   ├── weather.cpp
        │   └── weather.h
        ├── ui/
        └── main.cpp
```

## 7.1 Fronteras de modificación

- Los cambios en `bridge/`, `specs/`, `docs/`, `scripts/` y `releases/` se comitean en `Medidor`.
- Los cambios en `clawd-meter/src/`, `clawd-meter/data/` o `clawd-meter/platformio.ini` se comitean dentro del fork.
- Después de subir un commit nuevo del firmware, `Medidor` debe actualizar y comitear el puntero del submódulo.
- Un SPEC puede coordinar ambos repositorios, pero cada cambio debe quedar en el historial correspondiente.

## 7.2 Contrato de rutas en los SPECs

Para eliminar ambigüedad, los SPECs utilizarán rutas calificadas desde `Medidor/`:

```text
bridge/src/ai_meter_bridge/clients/codex_app_server.py
clawd-meter/src/data/bridge_api.cpp
clawd-meter/src/channels/ch_codex.cpp
specs/07-canal-codex-interfaz.md
docs/api-contract.md
```

No se usarán rutas como `src/...` sin indicar que pertenecen al submódulo.

---

# 8. Contrato de datos del bridge

## 8.1 Endpoint principal

```http
GET /api/v1/usage
Authorization: Bearer <DEVICE_TOKEN>
X-Device-Id: cyd-desk-01
Accept: application/json
```

## 8.2 Respuesta normal

```json
{
  "schema_version": 1,
  "generated_at": "2026-07-18T19:42:00-07:00",
  "stale_after_seconds": 300,
  "providers": {
    "codex": {
      "status": "ok",
      "source": "codex_app_server",
      "plan": "plus",
      "fetched_at": "2026-07-18T19:41:57-07:00",
      "five_hour": {
        "available": true,
        "used_percent": 32.0,
        "remaining_percent": 68.0,
        "window_minutes": 300,
        "resets_at": 1784436840
      },
      "weekly": {
        "available": true,
        "used_percent": 63.0,
        "remaining_percent": 37.0,
        "window_minutes": 10080,
        "resets_at": 1784712600
      },
      "other_windows": []
    },
    "claude": {
      "status": "disabled",
      "source": "bridge",
      "plan": null,
      "fetched_at": null,
      "five_hour": null,
      "weekly": null,
      "other_windows": []
    }
  },
  "bridge": {
    "version": "0.1.0",
    "uptime_seconds": 18420,
    "codex_process": "running"
  }
}
```

## 8.3 Estados permitidos

```text
ok
stale
disabled
unavailable
auth_required
invalid_response
rate_limited
internal_error
```

## 8.4 Reglas de normalización

- `used_percent` debe quedar entre `0` y `100`.
- `remaining_percent = 100 - used_percent`.
- No asumir que `primary` siempre es 5 horas.
- Clasificar por `windowDurationMins`.
- Ventana de 5 horas:
  - Preferir exactamente `300`.
  - Aceptar temporalmente `240–360` solo como compatibilidad.
- Ventana semanal:
  - Preferir exactamente `10080`.
  - Aceptar `8640–11520` solo como compatibilidad.
- Conservar ventanas desconocidas en `other_windows`.
- `resetsAt` se conserva como Unix timestamp en segundos.
- Si `secondary` es `null`, no inventar un límite semanal.
- Si el contrato contiene `rateLimitsByLimitId`, priorizar el objeto con `limitId == "codex"`.
- Si no existe, usar `rateLimits` cuando represente el límite Codex.
- No interpretar créditos API como límites ChatGPT.
- No calcular consumo por cantidad de mensajes.
- No estimar tokens cuando existe un dato autoritativo.

---

# 9. Modelo de dominio del bridge

```python
from datetime import datetime
from enum import StrEnum
from pydantic import BaseModel, Field


class ProviderStatus(StrEnum):
    OK = "ok"
    STALE = "stale"
    DISABLED = "disabled"
    UNAVAILABLE = "unavailable"
    AUTH_REQUIRED = "auth_required"
    INVALID_RESPONSE = "invalid_response"
    RATE_LIMITED = "rate_limited"
    INTERNAL_ERROR = "internal_error"


class UsageWindow(BaseModel):
    available: bool = True
    used_percent: float = Field(ge=0, le=100)
    remaining_percent: float = Field(ge=0, le=100)
    window_minutes: int = Field(gt=0)
    resets_at: int | None = None


class ProviderUsage(BaseModel):
    status: ProviderStatus
    source: str
    plan: str | None = None
    fetched_at: datetime | None = None
    five_hour: UsageWindow | None = None
    weekly: UsageWindow | None = None
    other_windows: list[UsageWindow] = []


class BridgeMetadata(BaseModel):
    version: str
    uptime_seconds: int
    codex_process: str


class UsageResponse(BaseModel):
    schema_version: int = 1
    generated_at: datetime
    stale_after_seconds: int
    providers: dict[str, ProviderUsage]
    bridge: BridgeMetadata
```

**Nota de implementación:** usar `Field(default_factory=list)` en el código real para listas mutables.

---

# 10. Configuración del bridge

## 10.1 `.env.example`

```dotenv
AI_METER_ENVIRONMENT=development
AI_METER_HOST=0.0.0.0
AI_METER_PORT=8765
AI_METER_LOG_LEVEL=INFO

AI_METER_DEVICE_TOKEN=replace-with-generated-token
AI_METER_ALLOWED_DEVICE_IDS=cyd-desk-01

CODEX_COMMAND=/opt/homebrew/bin/codex
CODEX_REQUEST_TIMEOUT_SECONDS=10
CODEX_STARTUP_TIMEOUT_SECONDS=15
CODEX_POLL_SECONDS=60
CODEX_STALE_AFTER_SECONDS=300
CODEX_RESTART_MAX_BACKOFF_SECONDS=60

CLAUDE_ENABLED=false
```

## 10.2 Generación del token

```python
import secrets

print(secrets.token_urlsafe(32))
```

No imprimir el token en logs.

## 10.3 Configuración Pydantic

```python
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    environment: str = "development"
    host: str = "0.0.0.0"
    port: int = 8765
    log_level: str = "INFO"

    device_token: str
    allowed_device_ids: str = "cyd-desk-01"

    codex_command: str = "codex"
    codex_request_timeout_seconds: float = 10
    codex_startup_timeout_seconds: float = 15
    codex_poll_seconds: int = 60
    codex_stale_after_seconds: int = 300
    codex_restart_max_backoff_seconds: int = 60

    claude_enabled: bool = False

    model_config = SettingsConfigDict(
        env_file=".env",
        env_prefix="AI_METER_",
        extra="ignore",
    )
```

En la implementación real puede separarse el prefijo general de las variables `CODEX_*`; el SPEC 02 debe elegir un único convenio y documentarlo.

---

# 11. Cliente JSON-RPC de Codex

## 11.1 Responsabilidades

`CodexAppServerClient` debe:

- Iniciar un proceso hijo.
- Mantener `stdin`, `stdout` y `stderr`.
- Leer JSONL línea por línea.
- Enviar `initialize`.
- Esperar respuesta de inicialización.
- Enviar `initialized`.
- Ejecutar solicitudes con ID incremental.
- Resolver respuestas por ID.
- Procesar notificaciones sin ID.
- Aplicar timeout.
- Detectar EOF.
- Reiniciar el proceso.
- Cancelar futures pendientes al cerrar.
- No escribir secretos en logs.

## 11.2 Interfaz sugerida

```python
class CodexAppServerClient:
    async def start(self) -> None: ...
    async def stop(self) -> None: ...
    async def restart(self) -> None: ...

    async def request(
        self,
        method: str,
        params: dict | None = None,
        *,
        timeout: float | None = None,
    ) -> dict: ...

    async def read_account(self) -> dict: ...
    async def read_rate_limits(self) -> dict: ...

    @property
    def is_running(self) -> bool: ...
```

## 11.3 Secuencia de inicio

```text
spawn codex app-server
    ↓
start stdout reader
    ↓
send initialize(id=1)
    ↓
await initialize result
    ↓
send initialized notification
    ↓
send account/read
    ↓
send account/rateLimits/read
    ↓
mark ready
```

## 11.4 Manejo de notificaciones

V1:

```text
account/rateLimits/updated
account/updated
```

Comportamiento:

- `account/rateLimits/updated`: marcar caché como candidata a refresco.
- `account/updated`: refrescar cuenta y límites.
- Otras notificaciones: ignorar con log `DEBUG`.
- Nunca fallar por una notificación desconocida.

## 11.5 Reinicio

Backoff:

```text
1 s → 2 s → 4 s → 8 s → 16 s → 30 s → 60 s
```

Reiniciar el contador después de una ejecución estable.

---

# 12. API HTTP del bridge

## 12.1 Endpoints

```text
GET /healthz
GET /readyz
GET /api/v1/usage
POST /api/v1/refresh
```

`POST /api/v1/refresh` es opcional para V1 y requiere token.

## 12.2 `/healthz`

No consulta Codex.

```json
{
  "status": "ok",
  "service": "ai-usage-meter-bridge",
  "version": "0.1.0"
}
```

## 12.3 `/readyz`

Devuelve `200` solo si:

- Aplicación inició.
- Caché existe o el proveedor está explícitamente deshabilitado.
- El servidor puede responder.

No exigir que Codex esté siempre disponible para considerar vivo el bridge.

## 12.4 Autenticación

Para `/api/v1/*`:

```http
Authorization: Bearer <DEVICE_TOKEN>
X-Device-Id: cyd-desk-01
```

Comparación del token:

```python
secrets.compare_digest(received, expected)
```

Errores:

```json
{"detail":"unauthorized"}
```

No revelar si falló token o Device ID.

## 12.5 Restricción de red

En macOS:

- Reservar IP del ESP32.
- Permitir puerto `8765` solamente en la red local.
- No crear port forwarding.
- No usar túneles públicos.
- No publicar en Cloudflare Tunnel, ngrok o VPS.

---

# 13. Modelos del firmware

Crear en el submódulo de firmware:

```text
clawd-meter/src/data/usage_models.h
```

Contenido base:

```cpp
#pragma once

#include <Arduino.h>
#include <time.h>

enum class ProviderState : uint8_t {
    Disabled,
    Ok,
    Stale,
    Unavailable,
    AuthRequired,
    InvalidResponse,
    InternalError
};

struct UsageWindowData {
    float usedPct = -1.0f;
    float remainingPct = -1.0f;
    uint32_t windowMinutes = 0;
    time_t resetsAt = 0;
    bool available = false;
};

struct CodexData {
    UsageWindowData fiveHour;
    UsageWindowData weekly;
    ProviderState state = ProviderState::Unavailable;
    char plan[16] = "";
    time_t fetchedAt = 0;
    bool valid = false;
    char err[32] = "";
};

struct BridgeStatus {
    bool reachable = false;
    bool authenticated = false;
    bool stale = true;
    time_t generatedAt = 0;
    uint32_t staleAfterSeconds = 300;
    char version[16] = "";
    char err[32] = "";
};
```

Reglas:

- Evitar `String` dentro de snapshots consultados frecuentemente cuando sea viable.
- Acotar tamaños de buffers.
- No almacenar el JSON completo.
- Deserializar solo campos necesarios.
- Reutilizar `JsonDocument` con capacidad controlada.
- No bloquear el loop más de lo necesario.

---

# 14. Cliente HTTP del firmware

Crear en el submódulo de firmware:

```text
clawd-meter/src/data/bridge_api.h
clawd-meter/src/data/bridge_api.cpp
```

## 14.1 Interfaz

```cpp
namespace BridgeApi {
    bool fetchUsage(
        const Settings& settings,
        CodexData& codex,
        ClaudeData& claude,
        BridgeStatus& bridge
    );

    int connectionFailures();
}
```

## 14.2 Request

```http
GET http://192.168.20.10:8765/api/v1/usage
Authorization: Bearer <token>
X-Device-Id: cyd-desk-01
```

## 14.3 Timeouts

```text
connect timeout: 3 s
read timeout:    5 s
total máximo:    8 s
```

## 14.4 Respuestas

- `200`: parsear snapshot.
- `401`: `authenticated=false`, no reintentar agresivamente.
- `404`: contrato incorrecto.
- `429`: respetar actualización normal, no loop.
- `5xx`: conservar último dato válido como stale.
- Error TCP: conservar último dato válido y marcar bridge no disponible.
- JSON inválido: no reemplazar snapshot válido por basura.
- `schema_version != 1`: mostrar incompatibilidad.

## 14.5 Frecuencia

Recomendación:

```text
refresh bridge: 60 s
reintento tras fallo: 15 s, 30 s, 60 s, luego intervalo normal
```

No consultar cada segundo.

---

# 15. Nuevos ajustes del firmware

En `Settings`:

```cpp
String bridgeUrl;
String bridgeToken;
String bridgeDeviceId = "cyd-desk-01";

bool showCodex = true;
bool showAiSummary = true;

String clawdAutoSource = "critical";
// claude | codex | critical | active

bool allowLegacyDirectClaude = false;
```

Persistencia:

```json
{
  "bridge_url": "http://192.168.20.10:8765",
  "bridge_token": "...",
  "bridge_device_id": "cyd-desk-01",
  "show_codex": true,
  "show_ai_summary": true,
  "clawd_auto_source": "critical",
  "allow_legacy_direct_claude": false
}
```

Reglas de seguridad:

- `/api/settings` devuelve token enmascarado.
- Un valor `"***"` no reemplaza el token existente.
- Export normal no incluye:
  - `wifi_pass`.
  - `bridge_token`.
  - `claude_key`.
  - `api_token`.
- No registrar esos campos en serial.
- El modo directo Claude queda deshabilitado por defecto.

---

# 16. Diseño de pantallas

## 16.1 Canal Codex

Archivo del submódulo:

```text
clawd-meter/src/channels/ch_codex.cpp
```

Contenido:

```text
CODEX · PLUS

5 HORAS
██████░░░░  68% disponible
Reinicia en 02:14

SEMANAL
████░░░░░░  37% disponible
Reinicia lun 09:30
```

Estados:

- `ok`: valores normales.
- `stale`: icono o texto `DATOS ANTIGUOS`.
- `unavailable`: `MAC SIN CONEXIÓN`.
- `auth_required`: `ABRE CODEX Y VUELVE A INICIAR SESIÓN`.
- `disabled`: canal oculto.
- sin ventana semanal: mostrar `NO DISPONIBLE`, no `0%`.

## 16.2 Resumen AI

Archivo del submódulo:

```text
clawd-meter/src/channels/ch_ai_summary.cpp
```

Diseño:

```text
AI USAGE

CLAUDE
5 h       51% usado
Semana    63% usado

CODEX
5 h       32% usado
Semana    63% usado
```

Debe respetar:

```text
usageShowConsumed=true  → usado
usageShowConsumed=false → restante
```

## 16.3 Clawd multiproveedor

Modificar en el submódulo:

```text
clawd-meter/src/channels/ch_clawd.cpp
```

Nueva resolución:

```cpp
static float resolveAutoUsage(const ChannelCtx& ctx);
```

Lógica:

```text
claude:
  usar Claude 5h

codex:
  usar Codex 5h

critical:
  usar el mayor porcentaje utilizado válido

active_screen:
  usar proveedor de la pantalla activa;
  si no aplica, usar critical
```

Umbrales conservados:

```text
<20%     excited
20–40%   happy
40–60%   normal
60–80%   stressed
80–95%   squish
>=95%    dizzy
sin dato sleepy
```

Debe conservar:

- Blink.
- Double blink.
- Look around.
- Wiggle.
- Animación de squish.
- Dibujado parcial.
- Colores.
- Velocidad.
- Modo manual.
- Footer opcional.

## 16.4 Clawd desconectado

Opcional para V1.1:

- Si bridge está offline y el snapshot está vencido:
  - expresión sleepy.
  - footer `BRIDGE OFFLINE`.
- Si Codex requiere login:
  - expresión code.
  - footer `CODEX LOGIN`.

---

# 17. Modificaciones en `clawd-meter/src/main.cpp`

## 17.1 Estado global

Agregar:

```cpp
static CodexData g_codex;
static BridgeStatus g_bridge;
```

## 17.2 Contexto

Actualizar todos los `ChannelCtx`:

```cpp
ChannelCtx ctx {
    .settings = &g_settings,
    .claude = &g_claude,
    .codex = &g_codex,
    .bridge = &g_bridge,
    .now_ms = millis()
};
```

## 17.3 Tabla de canales

Agregar:

```text
Clawd
AI Summary
Codex
Claude
Home
Clock
Weather
Forecast
Info
```

Orden recomendado:

```text
Clawd → AI Summary → Codex → Claude → Home → Clock → Weather → Forecast → Info
```

## 17.4 Refresh

Fase Codex:

```cpp
if (!g_settings.bridgeUrl.isEmpty()) {
    BridgeApi::fetchUsage(
        g_settings,
        g_codex,
        g_claude,
        g_bridge
    );
}
```

Después:

```cpp
if (
    g_settings.allowLegacyDirectClaude &&
    !g_settings.claudeKey.isEmpty()
) {
    Api::fetchClaude(g_settings, g_claude);
}
```

Regla final:

- Una vez implementado SPEC 10, eliminar la necesidad de `claudeKey` en el ESP32.
- El bridge pasa a ser la fuente preferida de ambos proveedores.

---

# 18. Seguridad del portal web del ESP32

El repositorio base debe endurecerse.

## 18.1 Rutas que requieren autenticación

```text
GET  /api/settings
POST /api/settings
GET  /api/export
POST /api/import
POST /api/factory-reset
POST /api/reboot
POST /api/refresh
POST /update
```

## 18.2 Exportación

`GET /api/export` debe ser una exportación segura:

```json
{
  "wifi_ssid": "IoT",
  "wifi_pass": null,
  "bridge_url": "http://192.168.20.10:8765",
  "bridge_token": null,
  "claude_key": null,
  "api_token": null
}
```

No debe existir exportación completa de secretos por HTTP en V1.

## 18.3 Setup AP

Objetivo endurecido:

- SSID:
  ```text
  ai-meter-<chip-suffix>
  ```
- Password aleatoria o derivada de un secreto único.
- Mostrar password temporal en la pantalla.
- Caducar AP después de configurar.
- No mantener AP abierto si el dispositivo ya está conectado.
- No ingresar cookies de Claude durante setup.

Si esto retrasa demasiado la V1, usar una red aislada durante desarrollo y cerrar el hallazgo antes del release final.

---

# 19. Integración de Claude

## 19.1 Estrategia

No usar la cookie desde el ESP32.

El bridge consulta Claude y devuelve el mismo contrato normalizado.

## 19.2 Secretos

Guardar `sessionKey` en:

- macOS Keychain mediante `keyring`, o
- archivo con permisos `0600` fuera del repositorio como alternativa temporal.

Nunca en:

- Git.
- `.env.example`.
- Logs.
- Respuesta API.
- Configuración exportable del ESP32.

## 19.3 Riesgo explícito

La integración Claude usa un endpoint web interno no documentado. Por tanto:

- Puede romperse.
- Puede requerir actualizar el parser.
- Debe quedar detrás de una interfaz `ClaudeProvider`.
- No debe impedir que Codex siga funcionando.
- Su fallo no debe reiniciar todo el bridge.
- Debe poder deshabilitarse con configuración.

## 19.4 Resultado

El bridge devuelve:

```json
"claude": {
  "status": "ok",
  "source": "claude_internal",
  "plan": null,
  "fetched_at": "...",
  "five_hour": { "...": "..." },
  "weekly": { "...": "..." },
  "other_windows": []
}
```

---

# 20. Servicio automático en macOS

Crear:

```text
bridge/launchd/com.local.ai-usage-meter-bridge.plist.example
```

Ejemplo conceptual:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.local.ai-usage-meter-bridge</string>

  <key>ProgramArguments</key>
  <array>
    <string>/ABSOLUTE/PATH/.venv/bin/uvicorn</string>
    <string>ai_meter_bridge.main:app</string>
    <string>--host</string>
    <string>0.0.0.0</string>
    <string>--port</string>
    <string>8765</string>
  </array>

  <key>WorkingDirectory</key>
  <string>/ABSOLUTE/PATH/bridge</string>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <true/>

  <key>StandardOutPath</key>
  <string>/tmp/ai-meter-bridge.out.log</string>

  <key>StandardErrorPath</key>
  <string>/tmp/ai-meter-bridge.err.log</string>
</dict>
</plist>
```

No copiar este archivo sin reemplazar rutas absolutas.

Instalación:

```bash
mkdir -p ~/Library/LaunchAgents

cp bridge/launchd/com.local.ai-usage-meter-bridge.plist \
  ~/Library/LaunchAgents/

launchctl bootstrap gui/$(id -u) \
  ~/Library/LaunchAgents/com.local.ai-usage-meter-bridge.plist
```

Diagnóstico:

```bash
launchctl print gui/$(id -u)/com.local.ai-usage-meter-bridge
tail -f /tmp/ai-meter-bridge.err.log
```

---

# 21. Makefile sugerido

El `Makefile` vive en la raíz de `Medidor/` y orquesta ambos componentes sin mezclar sus repositorios.

```makefile
.PHONY: bridge-install bridge-dev bridge-test bridge-lint \
        firmware-build firmware-buildfs firmware-upload \
        firmware-uploadfs firmware-monitor \
        submodule-status workspace-verify

bridge-install:
	cd bridge && uv sync --dev

bridge-dev:
	cd bridge && uv run uvicorn ai_meter_bridge.main:app \
		--host 0.0.0.0 --port 8765 --reload

bridge-test:
	cd bridge && uv run pytest

bridge-lint:
	cd bridge && uv run ruff check .
	cd bridge && uv run mypy src

firmware-build:
	cd clawd-meter && pio run -e cyd

firmware-buildfs:
	cd clawd-meter && pio run -e cyd -t buildfs

firmware-upload:
	cd clawd-meter && pio run -e cyd -t upload

firmware-uploadfs:
	cd clawd-meter && pio run -e cyd -t uploadfs

firmware-monitor:
	cd clawd-meter && pio device monitor -b 115200

submodule-status:
	git submodule status
	cd clawd-meter && git status --short

workspace-verify:
	./scripts/verify_workspace.sh
```

El `Makefile` no debe ejecutar `git commit`, `git push` ni actualizar automáticamente el puntero del submódulo.

---

# 22. Catálogo de SPECs

Todos los archivos de SPEC viven en:

```text
Medidor/specs/
```

Los SPECs se redactarán en **español**. Se mantendrán en inglés únicamente nombres técnicos, endpoints, símbolos de código, campos de contratos y comandos.

Cada SPEC será un archivo Markdown autocontenido. Cuando un diagrama aporte claridad se usará Mermaid acompañado de una descripción textual que preserve el contrato si el render no está disponible.

El repositorio afectado se declara explícitamente en cada SPEC.

| SPEC | Ubicación del documento | Código principal afectado |
|---|---|---|
| 00 | `Medidor/specs/` | Arquitectura global |
| 01 | `Medidor/specs/` | `clawd-meter/` + evidencia en `docs/` |
| 02 | `Medidor/specs/` | `bridge/` |
| 03 | `Medidor/specs/` | `bridge/` |
| 04 | `Medidor/specs/` | `bridge/` |
| 05 | `Medidor/specs/` | `bridge/` |
| 06 | `Medidor/specs/` | `clawd-meter/` |
| 07 | `Medidor/specs/` | `clawd-meter/` |
| 08 | `Medidor/specs/` | `clawd-meter/` |
| 09 | `Medidor/specs/` | `clawd-meter/` |
| 10 | `Medidor/specs/` | `bridge/` + `clawd-meter/` |
| 11 | `Medidor/specs/` | ambos repositorios |
| 12 | `Medidor/specs/` | release coordinado |

Cada SPEC debe incluir un apartado `Repositorios y rutas afectadas`. Las rutas se expresarán desde la raíz de `Medidor/`.

---


## SPEC 00 — Arquitectura, alcance y seguridad

**Ubicación:** `Medidor/specs/00-arquitectura-alcance-seguridad.md`  
**Forma del entregable:** un único archivo Markdown autocontenido.  
**Idioma:** español.  
**Diagrama:** Mermaid + descripción textual.

### Objetivo

Fijar las decisiones que no deben reinterpretarse durante la implementación y describir la arquitectura objetivo completa: repositorio principal, submódulo de firmware, bridge, Codex App Server, ESP32 y futura migración de Claude al bridge.

### Debe contener

- Objetivo del producto.
- Alcance y no alcance.
- Diagrama de componentes.
- Flujo de credenciales.
- Threat model.
- Contratos de confianza.
- Decisiones ADR:
  - ADR-001 actualizado para la separación coordinada de repositorios.
  - ADR-002 a ADR-006 reafirmados como aceptados y vinculantes.
- Reglas de propiedad de rutas y repositorios.
- Flujo para actualizar el puntero del submódulo.
- Definition of Done global.
- Política de secretos.
- Restricción de red local.

### Criterios de aceptación

- No hay contradicción entre diagrama y texto.
- Se declara que el ESP32 no almacena sesión ChatGPT.
- Se declara que App Server no se expone a la LAN.
- Se define quién guarda cada secreto.
- Se define comportamiento con Mac apagada.
- Se define que el sistema es read-only.
- Se declara que `Medidor/specs/` es la fuente de verdad de los contratos.
- Se define que `clawd-meter/` es un submódulo y no una carpeta absorbida por el repositorio principal.
- Se define cómo se registra la compatibilidad entre bridge, firmware y `schema_version`.

---

## SPEC 01 — Baseline de firmware y hardware

### Objetivo

Demostrar que el fork compila y que pantalla, touch, LittleFS y animaciones funcionan antes de introducir cambios.

### Tareas

1. Verificar el fork y sus remotos `origin`/`upstream`.
2. Verificar que `clawd-meter/` esté registrado como submódulo.
3. Respaldar flash.
4. Compilar `cyd` dentro de `clawd-meter/`.
5. Compilar LittleFS.
6. Flashear.
7. Abrir serial.
8. Verificar rotación.
9. Verificar touch.
10. Verificar Clawd sin credenciales.
11. Documentar consumo de flash y RAM en `docs/hardware-test-checklist.md`.
12. Registrar en el repositorio principal el commit baseline del submódulo.

### Criterios de aceptación

- `cd clawd-meter && pio run -e cyd` termina con éxito.
- `cd clawd-meter && pio run -e cyd -t buildfs` termina con éxito.
- El display inicia en landscape.
- No hay colores invertidos.
- Touch avanza de canal.
- Clawd parpadea y mira alrededor.
- El firmware no necesita cookie Claude para arrancar.
- Existe evidencia en `docs/hardware-test-checklist.md`.

### No alcance

- Bridge.
- Codex.
- Cambios visuales.
- Seguridad final.

---

## SPEC 02 — Base del bridge y configuración

**Repositorio de implementación:** `Medidor` (`bridge/`).

### Objetivo

Crear el servicio FastAPI sin integrar todavía Codex.

### Tareas

- Crear proyecto Python.
- Configuración con Pydantic.
- Logging.
- Lifespan.
- `/healthz`.
- `/readyz`.
- Autenticación bearer.
- Pruebas.
- `.env.example`.
- Redacción de secretos.

### Criterios de aceptación

- `uv run pytest` pasa.
- `GET /healthz` devuelve 200 sin token.
- `GET /api/v1/usage` devuelve 401 sin token.
- Token correcto devuelve fixture temporal.
- Logs no contienen token.
- El servicio puede detenerse limpiamente.

---

## SPEC 03 — Cliente Codex App Server

**Repositorio de implementación:** `Medidor` (`bridge/`).

### Objetivo

Implementar un cliente JSON-RPC robusto sobre `stdio`.

### Tareas

- Subproceso asíncrono.
- Inicialización.
- Correlación por ID.
- Reader task.
- Timeouts.
- Errores JSON.
- EOF.
- Reinicio.
- `account/read`.
- `account/rateLimits/read`.
- Soporte de notificaciones desconocidas.

### Criterios de aceptación

- Se completa handshake.
- Una solicitud concurrente recibe su respuesta correcta.
- Respuesta de error se convierte a excepción tipada.
- EOF cancela requests pendientes.
- Stop termina proceso hijo.
- No quedan procesos huérfanos.
- Las pruebas usan un proceso fake; no dependen de una cuenta real.
- Existe script manual `probe_codex.py`.

---

## SPEC 04 — Normalización de límites y caché

**Repositorio de implementación:** `Medidor` (`bridge/`).

### Objetivo

Convertir la respuesta variable de Codex al contrato estable del dispositivo.

### Casos obligatorios

- Plus normal con 5h + semana.
- Solo ventana principal.
- `secondary=null`.
- `rateLimitsByLimitId`.
- Duraciones inesperadas.
- `usedPercent=0`.
- `usedPercent=100`.
- Porcentaje fuera de rango.
- Sin `resetsAt`.
- Cuenta sin autenticación.
- Proceso Codex caído.
- Última lectura válida disponible.
- Caché vencida.

### Criterios de aceptación

- No se inventa una ventana.
- Se conserva último dato válido.
- Estado pasa a `stale` al vencer TTL.
- Una respuesta inválida no destruye la caché.
- Existe timestamp de lectura.
- Clasificador de ventanas está aislado y probado.

---

## SPEC 05 — API de dispositivo y autenticación

**Repositorio de implementación:** `Medidor` (`bridge/`).

### Objetivo

Exponer un contrato pequeño y seguro para el CYD.

### Tareas

- `/api/v1/usage`.
- `/api/v1/refresh`.
- Device ID.
- Bearer token.
- Respuesta Pydantic.
- Versionado de schema.
- Cabeceras de caché.
- Rate limiting local básico.
- Allowlist opcional de IP.

### Criterios de aceptación

- Contrato coincide con `docs/api-contract.md`.
- JSON de fixture valida con schema.
- Unauthorized no revela detalles.
- Token se compara en tiempo constante.
- Endpoint no devuelve correo de la cuenta.
- Endpoint no devuelve ningún token.
- Endpoint no devuelve rutas de archivos locales.

---

## SPEC 06 — Cliente bridge en firmware

**Repositorio de implementación:** fork/submódulo `clawd-meter/`.

### Objetivo

Consumir el endpoint desde ESP32 sin romper los canales existentes.

### Tareas

- Agregar settings.
- Agregar `CodexData`.
- Agregar `BridgeStatus`.
- Implementar request HTTP.
- Parsear JSON.
- Mantener último snapshot.
- Integrar refresh.
- Agregar estado a `/api/state`.
- Enmascarar token.

### Criterios de aceptación

- Firmware compila.
- Con bridge disponible, datos válidos.
- Con bridge apagado, firmware no se congela.
- Con 401, muestra auth error.
- JSON inválido no reinicia dispositivo.
- No hay token en serial.
- Uso de heap se mantiene estable durante prueba prolongada.
- No se llama al endpoint más de una vez por intervalo.

---

## SPEC 07 — Canal Codex e interfaz

**Repositorio de implementación:** fork/submódulo `clawd-meter/`.

### Objetivo

Mostrar claramente las ventanas de Codex.

### Criterios visuales

- Texto legible a 320×240.
- Sin desbordamientos.
- Barras consistentes con tema.
- Reinicios legibles.
- Estado stale visible.
- Touch y auto-rotate conservados.
- `used/remaining` respeta ajuste global.

### Pruebas manuales

- 0%.
- 19%.
- 20%.
- 40%.
- 60%.
- 80%.
- 95%.
- 100%.
- sin weekly.
- offline.
- stale.
- auth required.

---

## SPEC 08 — Animaciones Clawd multiproveedor

**Repositorio de implementación:** fork/submódulo `clawd-meter/`.

### Objetivo

Mantener todas las animaciones y hacer que reaccionen a Codex o al proveedor crítico.

### Criterios de aceptación

- No se elimina ninguna expresión.
- Blink continúa.
- Look around continúa.
- Partial redraw continúa.
- `manual` ignora métricas.
- `codex` usa 5h Codex.
- `claude` usa 5h Claude.
- `critical` usa máximo válido.
- Sin datos produce sleepy.
- Cambiar fuente desde web UI no requiere reflashear.
- Footer identifica origen cuando se muestra estadística.

---

## SPEC 09 — Web UI y endurecimiento

**Repositorio de implementación:** fork/submódulo `clawd-meter/`.

### Objetivo

Configurar bridge y canales sin dejar rutas sensibles abiertas.

### Tareas

- Sección Bridge.
- URL.
- Device ID.
- Token enmascarado.
- Test connection.
- Toggle Codex.
- Toggle AI Summary.
- Selector fuente Clawd.
- Autenticación en rutas administrativas.
- Export redactado.
- OTA protegida.
- Setup AP endurecido.

### Criterios de aceptación

- Ningún secreto aparece en GET settings.
- Ningún secreto aparece en export.
- POST sin auth devuelve 401.
- Token `"***"` conserva valor.
- Factory reset requiere auth.
- OTA requiere auth.
- Se puede configurar bridge sin serial.

---

## SPEC 10 — Migración de Claude al bridge

**Repositorios de implementación:** `Medidor/bridge/` y `Medidor/clawd-meter/`.

### Objetivo

Eliminar la cookie Claude del ESP32.

### Tareas

- `ClaudeProvider`.
- Secret store.
- Parser.
- Caché independiente.
- Respuesta combinada.
- Desactivar llamada directa.
- Migración de config.
- Borrar `claude_key` de LittleFS.
- Actualizar UI.

### Criterios de aceptación

- `claude_key` ya no existe en export/config nueva.
- El bridge puede fallar Claude sin afectar Codex.
- Claude aparece en resumen.
- Clawd puede usar Claude.
- Cookie no aparece en logs.
- Cookie no viaja al ESP32.
- Existe procedimiento de revocación.

---

## SPEC 11 — Resiliencia, observabilidad y servicio

**Repositorios de implementación:** `Medidor` y `clawd-meter/` según el caso.

### Objetivo

Mantener el sistema estable durante uso diario.

### Tareas

- launchd.
- Health checks.
- Backoff.
- Logs rotables.
- Métricas mínimas.
- Stale state.
- Watchdog razonable.
- Reconexión Wi-Fi.
- Reinicio controlado solo ante fallos persistentes.
- Prueba soak.

### Criterios de aceptación

- Bridge vuelve tras crash.
- Codex App Server vuelve tras crash.
- ESP32 recupera conexión.
- Mac dormida no corrompe datos.
- Al despertar, actualiza automáticamente.
- Prueba de 24 horas sin fuga evidente.
- No hay bucle de reinicios.

---

## SPEC 12 — Release, flashing y runbook

**Repositorio coordinador:** `Medidor`.

### Objetivo

Producir una versión instalable y documentada.

### Entregables

- Binario firmware.
- Imagen LittleFS.
- Checksums.
- Changelog.
- Backup/restore.
- Guía de instalación.
- Guía de rollback.
- Troubleshooting.
- Manifiesto coordinado en `Medidor/releases/manifests/`.
- Matriz de versiones:
  - commit del repositorio principal.
  - versión del bridge.
  - commit/tag del submódulo de firmware.
  - `schema_version` de la API.
  - versión de Codex CLI probada.
- Etiqueta Git.

Ejemplo de manifiesto:

```yaml
release: 1.0.0
workspace:
  repository: ai-usage-meter
  commit: "<commit-medidor>"
bridge:
  version: 1.0.0
firmware:
  repository: clawd-meter
  commit: "<commit-submodulo>"
  tag: v1.0.0
api:
  schema_version: 1
codex:
  tested_cli_version: "<version>"
```

### Criterios de aceptación

- Instalación desde cero reproducible.
- Rollback probado.
- Configuración documentada.
- No se publica ningún secreto.
- Release notes declaran integración Claude no oficial.
- Se conserva atribución de licencias.

---

# 23. Orden estricto de implementación

```text
SPEC 00
   ↓
SPEC 01
   ↓
SPEC 02
   ↓
SPEC 03
   ↓
SPEC 04
   ↓
SPEC 05
   ↓
SPEC 06
   ↓
SPEC 07
   ↓
SPEC 08
   ↓
SPEC 09
   ↓
SPEC 10
   ↓
SPEC 11
   ↓
SPEC 12
```

No implementar Claude antes de cerrar SPEC 09.

---

# 24. Flujo Spec-Driven Design

Para cada SPEC:

## 24.1 Crear el documento

Cada SPEC debe incluir:

```text
1. Metadata
2. Repositorios y rutas afectadas
3. Contexto
4. Problema
5. Objetivo
6. No objetivos
7. Dependencias
8. Estado actual del código
9. Decisiones confirmadas
10. Diseño técnico
11. Contratos
12. Modelo de datos
13. Flujo principal
14. Flujos de error
15. Seguridad
16. Observabilidad
17. Archivos a crear/modificar
18. Plan de implementación por pasos
19. Pruebas
20. Criterios de aceptación
21. Definition of Done
22. Riesgos
23. Rollback
24. Preguntas abiertas
```

## 24.2 Revisar exhaustivamente

Prompt sugerido:

```text
Revisa exhaustivamente el SPEC adjunto antes de implementarlo.

Busca en una sola pasada:

- contradicciones internas;
- supuestos no confirmados;
- contratos incompletos;
- estados y ramas de error ausentes;
- incompatibilidades con el código actual;
- problemas de seguridad;
- problemas de concurrencia;
- problemas de lifecycle;
- problemas de compatibilidad;
- criterios de aceptación ambiguos;
- pruebas faltantes;
- riesgos de rework.

Enumera todos los hallazgos con:
ID, severidad, sección, problema, impacto y corrección recomendada.

No implementes todavía.
```

## 24.3 Corregir el SPEC

Prompt sugerido:

```text
Aplica directamente al documento todas las correcciones de los hallazgos
confirmados. Mantén las decisiones arquitectónicas del SPEC 00 y elimina
cualquier contradicción. El resultado debe quedar listo para implementación.
```

## 24.4 Implementar

Prompt sugerido:

```text
Implementa únicamente el SPEC XX aprobado.

Reglas:

- No amplíes el alcance.
- Respeta contratos y criterios de aceptación.
- Trabaja por pasos pequeños.
- Ejecuta las pruebas indicadas después de cada bloque.
- No introduzcas secretos.
- No cambies archivos fuera de alcance sin justificarlo.
- Al finalizar, entrega:
  1. archivos modificados;
  2. decisiones tomadas;
  3. pruebas ejecutadas;
  4. resultados;
  5. desviaciones del SPEC;
  6. riesgos pendientes.
```

## 24.5 Verificar implementación

Prompt sugerido:

```text
Verifica la implementación contra el SPEC XX, no contra la intención general.

Revisa:

- cada criterio de aceptación;
- archivos esperados;
- ramas de error;
- seguridad;
- pruebas;
- compatibilidad;
- regresiones;
- desviaciones no documentadas.

Clasifica:
PASS, PARTIAL o FAIL.

No corrijas código en esta pasada.
```

## 24.6 Cerrar

Solo cerrar cuando:

- Todos los criterios están PASS.
- No existen hallazgos Critical o High.
- Hallazgos Medium tienen decisión explícita.
- Tests pasan.
- Documentación fue actualizada.
- Commit y tag interno existen.
- Los cambios están comiteados en el repositorio correcto.
- Si cambió el firmware, el commit fue subido al fork y el puntero del submódulo fue actualizado en `Medidor`.
- La matriz de compatibilidad refleja bridge, firmware y `schema_version`.

---

# 25. Estrategia de ramas, commits y submódulo

## 25.1 Repositorio principal `Medidor`

Las ramas de arquitectura, bridge, documentación y coordinación viven aquí:

```text
spec/00-arquitectura-seguridad
spec/01-baseline-firmware
feat/02-bridge-base
feat/03-codex-app-server
feat/04-rate-limit-normalization
feat/05-device-api
coord/06-firmware-bridge-client
coord/07-codex-channel
coord/08-clawd-multiprovider
coord/09-web-security
feat/10-claude-bridge
feat/11-resilience
release/1.0.0
```

Los prefijos `coord/` indican que la implementación principal sucede en el submódulo, pero el repositorio padre recibe actualización de SPEC, evidencia y puntero de firmware.

## 25.2 Fork `clawd-meter`

Las ramas del firmware viven dentro del submódulo:

```text
feat/01-baseline-validation
feat/06-bridge-client
feat/07-codex-channel
feat/08-clawd-multiprovider
feat/09-web-security
feat/10-claude-bridge-migration
feat/11-firmware-resilience
release/1.0.0
```

## 25.3 Commits del repositorio principal

Ejemplos:

```text
spec(03): define codex app-server lifecycle
feat(03): add async JSON-RPC process client
test(03): cover EOF and request timeout
docs(03): document manual probe
coord(07): record Codex channel firmware revision
release: add compatibility manifest for v1.0.0
```

## 25.4 Commits del firmware

Ejemplos:

```text
feat(06): add authenticated bridge client
feat(07): add Codex usage channel
feat(08): support multiprovider Clawd expressions
fix(09): protect settings and OTA routes
test(11): add long-run firmware diagnostics
```

## 25.5 Flujo para un SPEC de firmware

```bash
# 1. Crear rama en el fork
cd Medidor/clawd-meter
git checkout -b feat/07-codex-channel

# 2. Implementar, probar y comitear
git add src data platformio.ini
git commit -m "feat(07): add Codex usage channel"
git push -u origin feat/07-codex-channel

# 3. Integrar la rama en el fork según el flujo elegido
# 4. Volver al repositorio principal
cd ..

# 5. Registrar SPEC, evidencia y nuevo commit del submódulo
git add clawd-meter specs/07-canal-codex-interfaz.md docs/
git commit -m "coord(07): update compatible firmware revision"
```

## 25.6 Regla de atomicidad coordinada

Un cambio que modifica el contrato bridge↔firmware puede requerir:

1. Commit compatible del bridge en `Medidor`.
2. Commit compatible del firmware en `clawd-meter`.
3. Actualización del puntero del submódulo.
4. Pruebas integradas.
5. Un commit coordinador en `Medidor`.

No es posible crear un único commit atómico entre dos repositorios. La atomicidad del producto se expresa mediante:

- `schema_version`.
- Commit del repositorio principal.
- Commit del submódulo.
- Manifiesto de release.
- Matriz de compatibilidad.

No mezclar dos SPECs en un mismo commit salvo cambios mecánicos inevitables.

---

# 26. Estrategia de pruebas

## 26.1 Bridge unitarias

- Parser.
- Clasificador.
- Caché.
- Autenticación.
- Redacción.
- JSON-RPC.
- Backoff.
- Configuración.

## 26.2 Bridge integración

- FastAPI TestClient/HTTPX.
- Proceso fake JSONL.
- Timeout real.
- Cancelación.
- Restart.
- Snapshot stale.
- 401.

## 26.3 Firmware build

```bash
cd clawd-meter
pio run -e cyd
pio run -e cyd -t buildfs
```

## 26.4 Hardware manual

Checklist:

```text
[ ] arranque
[ ] Wi-Fi
[ ] touch
[ ] rotación
[ ] Clawd blink
[ ] Clawd look
[ ] Clawd thresholds
[ ] Codex 5h
[ ] Codex weekly
[ ] reset countdown
[ ] bridge offline
[ ] bridge stale
[ ] bridge 401
[ ] Mac sleep/wake
[ ] reboot ESP32
[ ] reboot bridge
[ ] configuración persistente
```

## 26.5 Soak test

Duración mínima:

```text
24 horas
```

Observar:

- Heap libre.
- Número de reconexiones.
- Reinicios.
- Respuestas fallidas.
- Antigüedad de datos.
- Consistencia de animaciones.
- Uso de CPU del bridge.
- Procesos `codex app-server` huérfanos.

---

# 27. Matriz de errores

| Condición | Bridge | ESP32 | UI |
|---|---|---|---|
| Codex no instalado | unavailable | conserva caché | `CODEX NO INSTALADO` |
| Codex sin login | auth_required | conserva caché | `INICIA SESIÓN` |
| App Server cae | restart/backoff | stale | `REINTENTANDO` |
| Mac apagada | sin respuesta | stale | `BRIDGE OFFLINE` |
| Token incorrecto | 401 | auth false | `TOKEN INVÁLIDO` |
| JSON incompatible | invalid_response | conserva snapshot | `ACTUALIZA FIRMWARE` |
| Weekly ausente | weekly null | no inventa | `NO DISPONIBLE` |
| Reset timestamp ausente | valor null | sin countdown | `REINICIO —` |
| Claude expira | auth_required Claude | Codex sigue | solo Claude afectado |
| Wi-Fi cae | bridge no consultado | reconecta | icono offline |

---

# 28. Definition of Done global

El proyecto está listo cuando:

- Firmware compila sin warnings críticos.
- Bridge pasa lint, type-check y tests.
- Codex muestra los mismos porcentajes que `/status`, aceptando pequeñas diferencias temporales por caché.
- Ventana 5h y semanal se muestran correctamente.
- Clawd conserva sus animaciones.
- Clawd reacciona a Codex.
- Claude y Codex coexisten.
- Mac sleep/wake se recupera.
- ESP32 no contiene credenciales ChatGPT.
- Claude cookie no está en el ESP32.
- Rutas administrativas están protegidas.
- Exportaciones redactan secretos.
- No existe exposición pública.
- Existe rollback.
- Existe release reproducible.
- Existe checklist de hardware completo.
- `Medidor` registra el commit exacto del submódulo validado.
- El manifiesto de release identifica versión de bridge, commit de firmware y versión del contrato.
- Documentación identifica claramente integraciones oficiales y no oficiales.

---

# 29. Riesgos principales

## R-001 — Cambios en Codex App Server

Mitigación:

- Generar schemas por versión.
- Encapsular cliente.
- Versionar parser.
- Fixtures.
- `schema_version` propio estable.

## R-002 — Cambio de duración de límites

Mitigación:

- No depender solo de `primary/secondary`.
- Clasificar por duración.
- Conservar `other_windows`.
- Mostrar `no disponible` antes que inventar.

## R-003 — Mac apagada o dormida

Mitigación:

- Caché en ESP32.
- Estado stale.
- launchd.
- Recuperación automática al despertar.

## R-004 — Heap del ESP32

Mitigación:

- JSON acotado.
- Sin guardar payload completo.
- Buffers fijos.
- Refresh espaciado.
- Soak test.

## R-005 — Seguridad de portal original

Mitigación:

- SPEC 09 obligatorio antes de release.
- Red aislada durante desarrollo.
- Nunca colocar sesión ChatGPT en dispositivo.

## R-006 — Claude no oficial

Mitigación:

- Provider aislado.
- Feature flag.
- Fallo independiente.
- Secretos en Mac.
- Disclaimer.
- Codex sigue funcionando sin Claude.

## R-007 — Mascota y uso comercial

Mitigación:

- Proyecto personal.
- Mantener atribuciones.
- Para venta, diseñar mascota e identidad propias y revisar licencias/marcas.

## R-008 — Desalineación del submódulo

Mitigación:

- Actualizar el puntero solo después de subir el commit del firmware.
- Validar `git submodule status` en CI.
- Guardar manifiesto de compatibilidad por release.
- No depender de ramas flotantes del submódulo.
- Probar clones con `--recurse-submodules`.

---

# 30. Checklist inmediato: qué hacer ahora

## Fase A — Hardware

```text
[ ] Confirmar modelo ESP32-2432S028R
[ ] Conseguir cable USB de datos
[ ] Identificar puerto serial
[ ] Respaldar 4 MB de flash
[ ] Crear red IoT/invitados
```

## Fase B — Repositorios

```text
[ ] Inicializar Medidor/ como repositorio Git principal
[ ] Crear specs/, docs/, bridge/, scripts/ y releases/
[ ] Verificar o crear el fork clawd-meter
[ ] Confirmar origin y upstream del fork
[ ] Comitear/subir cualquier cambio local existente
[ ] Integrar clawd-meter/ como submódulo
[ ] Confirmar git submodule status
[ ] Crear commit baseline en Medidor
```

## Fase C — Baseline

```text
[ ] Instalar PlatformIO
[ ] Entrar a Medidor/clawd-meter/
[ ] Compilar firmware
[ ] Compilar LittleFS
[ ] Flashear
[ ] Probar touch
[ ] Probar animaciones
[ ] No ingresar Claude sessionKey
```

## Fase D — SDD

```text
[ ] Crear Medidor/specs/00-arquitectura-alcance-seguridad.md
[ ] Revisar SPEC 00
[ ] Crear SPEC 01
[ ] Implementar SPEC 01
[ ] Continuar en orden estricto
```

## Fase E — Codex

```text
[ ] Verificar codex /status
[ ] Generar JSON schemas
[ ] Crear probe
[ ] Implementar cliente
[ ] Normalizar límites
[ ] Exponer endpoint
[ ] Comparar endpoint vs /status
```

## Fase F — Display

```text
[ ] Agregar bridge settings
[ ] Agregar cliente HTTP
[ ] Agregar canal Codex
[ ] Agregar AI Summary
[ ] Adaptar Clawd
[ ] Probar estados de error
```

## Fase G — Claude seguro

```text
[ ] Endurecer Web UI
[ ] Crear ClaudeProvider en bridge
[ ] Guardar cookie en Mac
[ ] Eliminar cookie del ESP32
[ ] Probar independencia Claude/Codex
```

## Fase H — Release

```text
[ ] Soak test 24 h
[ ] Backup y rollback
[ ] Build final
[ ] Checksums
[ ] Documentación
[ ] Tag v1.0.0
```

---

# 31. Fuentes técnicas verificadas

1. Repositorio base `monsierfux/clawd-meter`.
2. README del repositorio y guía de compilación para entorno `cyd`.
3. Código fuente:
   - `platformio.ini`.
   - `src/channels/ch_clawd.cpp`.
   - `src/channels/channel.h`.
   - `src/core/storage.h`.
   - `src/core/storage.cpp`.
   - `src/core/web.cpp`.
   - `src/data/api.h`.
   - `src/main.cpp`.
4. Documentación oficial de Codex App Server:
   - transporte JSONL por `stdio`;
   - handshake `initialize` + `initialized`;
   - `account/read`;
   - `account/rateLimits/read`;
   - `account/rateLimits/updated`;
   - campos `usedPercent`, `windowDurationMins`, `resetsAt`.
5. Documentación oficial de límites de Codex y comando `/status`.

URLs de referencia:

```text
https://github.com/monsierfux/clawd-meter
https://developers.openai.com/codex/app-server
https://developers.openai.com/codex/pricing
https://github.com/openai/codex/tree/main/codex-rs/app-server
```

---

# 32. Nota final de implementación

La primera entrega no debe intentar resolver todo de una vez.

El punto de control correcto es:

```text
Codex App Server
       ↓
Bridge local probado
       ↓
GET /api/v1/usage
       ↓
ESP32 muestra 5h + semanal
       ↓
Clawd reacciona a Codex
```

Solo después se debe mover Claude al bridge y cerrar el endurecimiento completo del portal.

Esta secuencia reduce el rework, conserva las animaciones existentes y evita que una sesión sensible termine almacenada en un microcontrolador accesible desde la red.

La separación de repositorios es parte del diseño: `Medidor` coordina el producto y `clawd-meter` conserva el firmware derivado. El submódulo conecta ambos sin mezclar sus historiales.
