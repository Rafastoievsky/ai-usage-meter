# SPEC 01 — Baseline reproducible de repositorios, firmware y hardware

> **Estado:** Approved
> **Depende de:** SPEC 00 — Arquitectura, alcance y seguridad (`Approved` y versionada antes de implementar SPEC 01)
> **Fecha:** 2026-07-20
> **Fuente base:** `docs/AI_USAGE_METER_ESP32_SPEC_DRIVEN_PLAN_V2.md`
> **Repositorio coordinador:** `ai-usage-meter`
> **Repositorio de firmware:** `clawd-meter`
> **Plataforma certificada:** macOS sobre Apple Silicon (`arm64`)
> **Objetivo:** Establecer y demostrar un baseline reproducible de los repositorios, el toolchain, los builds y un hardware CYD real antes de introducir funcionalidades nuevas.

## Modelo normativo de ejecución

SPEC 01 se implementa en dos fases acumulativas:

### Fase A — Repositorios, seguridad, toolchain y builds

Puede ejecutarse sin un CYD conectado e incluye:

- Preflight y clasificación del estado real.
- Higiene del repositorio coordinador.
- Reparación del submódulo y configuración de remotos.
- Gates de secretos sobre Git, fuentes y artefactos disponibles.
- Bootstrap reproducible.
- Lock de dependencias Python y paquetes internos de PlatformIO.
- Builds reproducibles de firmware y LittleFS.
- Publicación preliminar y prueba de clonación limpia.

La Fase A puede quedar completada aunque no exista hardware disponible. La ausencia del CYD no invalida ni revierte sus resultados.

### Fase B — Backup, flashing y verificación física

Requiere un CYD verificable e incluye:

- Identificación inequívoca del dispositivo.
- Backup sensible de los 4 MB.
- Revisión redactada y revocación de credenciales heredadas cuando aplique.
- Borrado completo de flash.
- Flashing y verificación de los artefactos.
- Baseline funcional, persistencia y evidencia manual.

La ausencia del CYD produce `BLOCKED` solamente para la Fase B e impide que SPEC 01 pase a `Implemented-Verified`.

### Clasificación de preflight y resultados

El preflight usa:

- `PASS`: la condición ya está satisfecha.
- `ACTION_REQUIRED`: la condición no está satisfecha, pero corregirla forma parte de SPEC 01.
- `BLOCKED`: no es seguro o no es posible continuar sin una decisión, permiso o remediación externa.

Los registros de ejecución usan únicamente:

- `PASS`.
- `FAIL`.
- `BLOCKED`.

`ACTION_REQUIRED` no es un resultado final ni un estado normativo del SPEC.

## Alcance

### Dentro de SPEC 01

#### Repositorios y topología Git

- Exigir que SPEC 00 esté `Approved`, versionada y disponible en la rama base.
- Configurar en el workspace de mantenimiento de `ai-usage-meter`:
  - `origin.url = git@github.com:Rafastoievsky/ai-usage-meter.git`.
  - URL pública de clonación: `https://github.com/Rafastoievsky/ai-usage-meter.git`.
  - Rama predeterminada: `main`.
- Confirmar la existencia y accesibilidad del repositorio coordinador antes del primer push; crearlo únicamente mediante una acción explícitamente autorizada si no existe.
- Clasificar el estado real de `clawd-meter/` antes de modificarlo:
  - gitlink existente sin `.gitmodules`;
  - repositorio embebido con directorio `.git/`;
  - directorio normal incorrectamente versionado.
- Reparar formalmente `clawd-meter/` como submódulo sin perder commits ni referencias locales.
- Crear y validar `.gitmodules`.
- Configurar en el workspace de mantenimiento de `clawd-meter`:
  - `origin.url = https://github.com/Rafastoievsky/clawd-meter.git`.
  - `origin.pushurl = git@github.com:Rafastoievsky/clawd-meter.git`.
  - `upstream.url = https://github.com/monsieurfux/clawd-meter.git`.
  - `upstream` sin `pushurl`.
- Usar `https://github.com/Rafastoievsky/clawd-meter.git` como URL pública del submódulo.
- Prohibir `branch = ...` en `.gitmodules`; la fuente de verdad es exclusivamente el gitlink.
- Registrar ramas predeterminadas, resultados de `git ls-remote`, SHA del gitlink y diferencia inicial entre `origin/main` y `upstream/main`.
- Medir la diferencia con:

  ```bash
  git rev-list --left-right --count upstream/main...origin/main
  ```

  donde el valor izquierdo corresponde a commits exclusivos de `upstream/main` y el derecho a commits exclusivos de `origin/main`.
- Aplicar una política de sincronización `fetch + rama dedicada + revisión/PR`, sin merges automáticos ni reescritura rutinaria de `origin/main`.
- Confirmar, después de `git fetch`, que el commit fijado como gitlink es ancestro de `origin/main` mediante `git merge-base --is-ancestor`.
- Validar desde un directorio temporal un clon nuevo mediante `git clone --recurse-submodules`.
- Registrar y preservar ramas, tags y commits exclusivamente locales antes de reparar la topología.

#### Higiene y configuración del coordinador

- Renombrar el directorio versionado `Docs/` a `docs/`.
- Retirar del índice `.DS_Store` y `.Rhistory`.
- Crear un `.gitignore` raíz para artefactos locales, herramientas, caches, backups y reportes sensibles.
- Validar y versionar `specs/.spec-config.yml`.
- Crear `specs/.spec-config.yml` con `AutoCreateBranch: true` si está ausente.
- Corregir `AutoCreateBranch` mediante un commit dedicado si existe con otro valor; no sobrescribir silenciosamente otras claves.

#### Toolchain y reproducibilidad

- Certificar macOS `arm64`; Linux, Windows y macOS Intel quedan fuera del baseline de SPEC 01.
- Fijar:
  - Python `3.14.6`.
  - uv `0.11.29`.
  - pip `26.1.2`.
  - PlatformIO Core `6.1.19`.
  - esptool `4.11.0`.
  - Gitleaks `8.30.1`.
- Crear un bootstrap repetible mediante:
  - `requirements-tools.txt`.
  - `requirements-tools.lock`.
  - `toolchain/bootstrap-checksums.txt`.
  - `toolchain/platformio-packages.lock.json`.
  - `toolchain/build-warnings-allowlist.yml`.
  - `scripts/bootstrap-tools.sh`.
- Obtener uv desde un artefacto oficial para macOS `arm64`, fijar su SHA-256 y rechazar cualquier versión distinta.
- Instalar Python `3.14.6` mediante el uv fijado o verificar una distribución ya instalada cuya versión, arquitectura, fuente e integridad queden documentadas.
- Crear `.venv-tools` mediante:

  ```bash
  uv venv --python 3.14.6 --seed .venv-tools
  ```

- Instalar `pip==26.1.2` desde el lock antes de ejecutar cualquier comando de PlatformIO.
- Validar explícitamente:

  ```bash
  .venv-tools/bin/python --version
  .venv-tools/bin/python -m pip --version
  .venv-tools/bin/pio --version
  .venv-tools/bin/pio system info
  .venv-tools/bin/esptool version
  .tools/gitleaks version
  ```

- Prohibir la validación mediante binarios globales ambiguos como `python`, `pip`, `pio`, `esptool` o `gitleaks` sin ruta controlada.
- Generar `requirements-tools.lock` con un resolver fijado, hashes de todos los artefactos y marcadores compatibles con macOS `arm64`.
- Instalar el lock con validación de hashes y sin resolución transitiva adicional:

  ```bash
  .venv-tools/bin/python -m pip install \
    --require-hashes \
    --no-deps \
    -r requirements-tools.lock
  ```

- Fijar en `clawd-meter/platformio.ini`:
  - `platformio/espressif32@7.0.1`.
  - `bodmer/TFT_eSPI@2.5.43`.
  - `bblanchon/ArduinoJson@7.4.3`.
  - XPT2046 commit `f956c5d8ce3bf39169c7378416b89e7cfe70a034`.
- Resolver una vez, dentro de un `PLATFORMIO_CORE_DIR` aislado, todos los paquetes internos usados por el target `cyd`.
- Registrar en `toolchain/platformio-packages.lock.json` cada paquete efectivamente usado, incluyendo al menos:
  - framework Arduino ESP32;
  - toolchain Xtensa para ESP32;
  - `tool-esptoolpy`;
  - `tool-mklittlefs`;
  - cualquier paquete adicional mostrado por `pio pkg list`.
- Convertir las versiones resueltas en restricciones exactas de `platform_packages` antes del build final de aceptación.
- Registrar nombre, propietario, versión exacta, origen, checksum cuando esté disponible, host OS y arquitectura de cada paquete.
- Ejecutar la validación final con un `PLATFORMIO_CORE_DIR` vacío y aislado, sin reutilizar `~/.platformio`.
- Ejecutar la instalación Python final sin depender del cache global de pip.
- Crear una allowlist versionada de warnings con patrón exacto, herramienta, justificación, responsable y fecha de revisión.
- Compilar el firmware `cyd` y la imagen LittleFS.
- Registrar por separado bootloader, tabla de particiones, aplicación y LittleFS.
- Registrar toolchain, dependencias resueltas, almacenamiento de programa, RAM, particiones y hashes.
- No exigir binarios bit a bit idénticos en SPEC 01; sí exigir identidad de fuentes, commits, configuración, versiones y paquetes resueltos.

#### Seguridad, secretos y evidencias

- Inventariar secretos por nombre lógico, alias, propietario, consumidor, ubicación lógica y política de rotación, sin registrar valores ni fragmentos.
- Normalizar al menos estos conceptos:
  - `sessionKey`: tipo de credencial de sesión Claude.
  - `claudeKey`: nombre heredado del campo que puede almacenar una `sessionKey`.
  - `apiToken`: token de otras superficies del firmware.
- Verificar que cada repositorio tenga historia completa y referencias actualizadas antes de escanear:
  - `git rev-parse --is-shallow-repository`.
  - `git fetch --all --tags --prune`.
- Escanear dentro de los métodos documentados:
  - todas las referencias Git alcanzables;
  - árboles de trabajo;
  - fuentes;
  - contenido LittleFS extraído;
  - strings imprimibles de artefactos;
  - patrones conocidos del backup crudo.
- Redactar el 100 % de los valores.
- No mostrar strings del backup o de binarios en terminal.
- Crear temporales sensibles con `umask 077`, permisos restrictivos y eliminación mediante `trap`.
- Formular los resultados como:

  > Cero detecciones reales no resueltas dentro de los métodos y alcances documentados.

- No afirmar ausencia absoluta de secretos en datos binarios.
- Diferenciar la remediación:
  - Historia del coordinador aún no publicada: puede reescribirse de forma controlada después de revocar.
  - Historia pública existente: revocación obligatoria y decisión explícita entre reescritura coordinada, recreación del repositorio o aceptación documentada de un valor revocado en historia.
- Detener el flujo ante una credencial real activa hasta revocarla.
- Registrar evidencia redactada en:
  - `docs/reproducibility-baseline.md`.
  - `docs/hardware-test-checklist.md`.
- Permitir evidencia visual externa solo cuando:
  - no muestre SSID, IP sensible, credenciales o identificadores personales;
  - se eliminen metadatos sensibles;
  - se registre nombre lógico, SHA-256, custodio y política de retención.
- No versionar fotografías o videos por defecto.

#### Hardware, backup y flashing

- Detectar un CYD real y bloquear solamente la Fase B si no está disponible.
- Certificar una unidad ESP32-2432S028R compatible con el target `cyd`.
- Identificar antes de cualquier lectura o escritura:
  - puerto;
  - USB VID/PID;
  - serial USB cuando exista;
  - chip;
  - revisión;
  - tamaño de flash;
  - identificador de dispositivo redactado o hasheado.
- Exigir ESP32 y flash física de `4194304` bytes.
- Usar explícitamente el mismo puerto autorizado para backup, borrado, `upload` y `uploadfs`.
- Respaldar los 4 MB antes de cualquier escritura.
- Guardar el backup fuera de Git bajo:

  ```text
  ~/Library/Application Support/AIUsageMeter/backups/spec-01/
  ```

- Crear el directorio con modo `0700`, la imagen con modo `0600`, `umask 077`, creación exclusiva, rechazo de symlinks y sin sobrescritura.
- Usar un nombre físico único:

  ```text
  cyd-prebaseline-<UTC>-<device-id-redacted>.bin
  ```

- Registrar un nombre lógico estable sin ruta personal.
- Verificar tamaño y SHA-256.
- Tratar el backup como artefacto sensible y exigir almacenamiento cifrado en reposo.
- Conservarlo durante 30 días después del cierre de SPEC 01, salvo que exista una necesidad forense documentada.
- Destruirlo al terminar la retención y registrar fecha, responsable y método de eliminación.
- Definir el backup como preservación forense y recuperación excepcional, no como rollback normal.
- Prohibir su restauración sin autorización separada, porque puede reintroducir credenciales heredadas.
- Si aparece una `sessionKey` real, detenerse y exigir revocación antes de continuar.
- Después de validar el backup y completar revocaciones, ejecutar borrado completo de flash.
- Flashear desde artefactos limpios:
  - bootloader;
  - tabla de particiones;
  - aplicación;
  - LittleFS.
- Verificar código de salida, offsets, tamaños y resultado de verificación de escritura.
- Realizar readback y comparación hash de las regiones escritas cuando esptool/PlatformIO lo permitan sin alterar el dispositivo.
- No restaurar Wi-Fi, cookies, tokens o configuración anterior.

#### Baseline funcional

- Usar una red temporal o de invitados con aislamiento entre clientes.
- No conectar el CYD a la LAN productiva o a un segmento con dispositivos sensibles.
- Permitir únicamente configuración nueva de prueba:
  - Wi-Fi temporal;
  - zona horaria;
  - coordenadas públicas de prueba;
  - brillo;
  - canales habilitados;
  - intervalo de rotación.
- No configurar `claudeKey`, `sessionKey` ni `apiToken`.
- Verificar:
  - arranque;
  - landscape;
  - resolución;
  - colores;
  - backlight;
  - Wi-Fi;
  - portal inicial;
  - LittleFS;
  - touch;
  - avance y rotación de canales;
  - reloj y zona horaria;
  - clima y pronóstico;
  - pantalla de información;
  - Clawd blink;
  - Clawd look-around;
  - persistencia;
  - heap;
  - comportamiento degradado sin Claude.
- Medir heap por serial si la pantalla Info actual no lo muestra; no modificar C++ para añadirlo.
- Conservar `FW_VERSION` funcional existente y registrar la identidad del baseline mediante commit, hashes y locks; no introducir una versión ficticia sin cambio funcional.
- Dejar ambos repositorios limpios y el gitlink sincronizado con un commit explícito disponible en `origin/main`.

### Repositorios y rutas afectadas

**Repositorio `ai-usage-meter`:**

- `.gitmodules`.
- `.gitignore`.
- `requirements-tools.txt`.
- `requirements-tools.lock`.
- `toolchain/bootstrap-checksums.txt`.
- `toolchain/platformio-packages.lock.json`.
- `toolchain/build-warnings-allowlist.yml`.
- `scripts/bootstrap-tools.sh`.
- `Docs/AI_USAGE_METER_ESP32_SPEC_DRIVEN_PLAN_V2.md` → `docs/AI_USAGE_METER_ESP32_SPEC_DRIVEN_PLAN_V2.md`.
- `docs/reproducibility-baseline.md`.
- `docs/hardware-test-checklist.md`.
- `specs/.spec-config.yml`.
- `clawd-meter` — gitlink.
- Eliminación del índice de `.DS_Store` y `.Rhistory`.

**Repositorio `clawd-meter`:**

- `platformio.ini`.

No se modifica código C++, HTML, CSS o JavaScript ni contenido funcional del firmware.

### Fuera de alcance

- Implementar el bridge o cualquier endpoint Codex.
- Añadir pantallas, canales, animaciones o funcionalidades.
- Refactorizar firmware o web UI.
- Añadir heap a la pantalla Info si no existe actualmente.
- Cambiar `FW_VERSION` solamente para etiquetar el baseline.
- Corregir el almacenamiento heredado de `claudeKey`.
- Endurecer el portal, `/api/export`, OTA o Setup AP; corresponde a SPEC 09–10.
- Restaurar Wi-Fi, cookies, tokens o credenciales del firmware anterior.
- Usar el backup crudo como rollback normal.
- Versionar backups, temporales sensibles, logs sin redactar, reportes con valores, fotografías o videos.
- Publicar artefactos de release, crear tags o completar manifiestos de SPEC 12.
- Validar físicamente o flashear el target ESP8266 `nodemcuv2`.
- Certificar Linux, Windows o macOS Intel.
- Sustituir pruebas CYD por inferencias derivadas del build.
- Cerrar SPEC 01 mientras exista cualquier resultado `FAIL` o `BLOCKED`.

## Modelo documental

SPEC 01 no introduce estructuras de runtime ni cambia modelos persistidos del firmware. Introduce registros documentales versionados.

### Metadatos comunes

Todo registro debe contener:

| Campo | Contenido |
| --- | --- |
| `attempt_id` | Identificador estable de la ejecución |
| `phase` | `preflight`, `phase-a`, `phase-b` o `final` |
| `recorded_at` | Fecha y hora UTC RFC 3339 |
| `responsible` | Persona que ejecutó o verificó |
| `coordinator_commit` | SHA completo o `UNPUBLISHED` durante preflight |
| `firmware_commit` | SHA completo o `N/A` cuando no aplique |
| `result` | `PASS`, `FAIL` o `BLOCKED` |
| `notes` | Información redactada adicional |

Los registros de intentos anteriores no se sobrescriben.

### `RepositoryBaseline`

Se registra en `docs/reproducibility-baseline.md`.

| Campo | Contenido |
| --- | --- |
| `repository` | `ai-usage-meter` o `clawd-meter` |
| `remote` | `origin` o `upstream` |
| `fetch_url` | URL de lectura sin credenciales embebidas |
| `push_url` | URL de escritura o `NONE` |
| `submodule_url` | URL de `.gitmodules` o `N/A` |
| `default_branch` | Rama obtenida con `git ls-remote --symref <url> HEAD` |
| `commit_sha` | SHA completo de 40 caracteres |
| `ls_remote_result` | Resultado de conectividad |
| `ancestor_result` | Resultado de `merge-base --is-ancestor` o `N/A` |
| `origin_upstream_diff` | Conteos `upstream_only` y `origin_only` |
| `worktree_state` | Limpio o resumen redactado de cambios |
| `local_only_refs` | Conteo y referencia a preservación, sin datos sensibles |

### `ToolchainBaseline`

Se registra en `docs/reproducibility-baseline.md`.

| Campo | Contenido |
| --- | --- |
| `component` | Python, uv, pip, PlatformIO, esptool, Gitleaks, plataforma o paquete |
| `version` | Versión o commit exacto |
| `source` | Archivo, release o manifiesto que fija el componente |
| `integrity` | SHA-256 del artefacto cuando exista |
| `executable_path` | Ruta lógica controlada |
| `verification_command` | Comando reproducible y sin secretos |
| `host_os` | Versión de macOS |
| `host_arch` | `arm64` |
| `lock_sha256` | Hash del lock aplicable o `N/A` |

### `BuildArtifactRecord`

Se registra una fila por artefacto.

| Campo | Contenido |
| --- | --- |
| `target` | `bootloader`, `partition-table`, `application`, `littlefs` o `combined-image` |
| `command` | Comando ejecutado |
| `artifact_logical_path` | Ruta relativa o nombre lógico |
| `artifact_size_bytes` | Tamaño exacto |
| `artifact_sha256` | SHA-256 completo |
| `flash_offset` | Offset esperado o `N/A` |
| `partition_name` | Partición o `N/A` |
| `partition_size_bytes` | Tamaño de partición o `N/A` |
| `platformio_core_dir_id` | Identificador del entorno aislado |
| `platformio_lock_sha256` | SHA-256 del lock de paquetes |
| `warnings_allowlist_sha256` | SHA-256 de la allowlist |

### `BuildMetricsRecord`

Se registra para el target `cyd`.

| Campo | Contenido |
| --- | --- |
| `ram_used_bytes` | RAM usada reportada por PlatformIO |
| `ram_limit_bytes` | Límite reportado |
| `program_storage_used_bytes` | Almacenamiento de programa usado |
| `program_storage_limit_bytes` | Límite de la partición de aplicación |
| `physical_flash_bytes` | Debe ser `4194304` para la unidad certificada |
| `partition_table_sha256` | Hash de la tabla de particiones |
| `littlefs_partition_offset` | Offset de LittleFS |
| `littlefs_partition_size` | Tamaño de la partición LittleFS |
| `littlefs_image_size` | Tamaño de la imagen generada |
| `build_identity` | Commit firmware + hashes de locks |

Los campos que no apliquen se registran como `N/A`, nunca como cero.

### `SecretInventoryEntry`

Se registra en `docs/reproducibility-baseline.md`.

| Campo | Contenido permitido |
| --- | --- |
| `name` | Nombre lógico del secreto |
| `aliases` | Nombres de campos o conceptos relacionados |
| `owner` | Propietario y autoridad de rotación |
| `logical_location` | Almacén permitido o ubicación lógica redactada |
| `consumer` | Componente autorizado |
| `rotation_policy` | Referencia al procedimiento aplicable |
| `scan_scope` | Fuente, referencias Git, artefacto o backup examinado |
| `scan_method` | Gitleaks, revisión dirigida, extracción LittleFS o strings protegidos |
| `finding_count` | Conteo sin valores |
| `resolution` | Revocado, eliminado, falso positivo o `N/A` |

Esta estructura prohíbe campos para valores, prefijos, sufijos o fragmentos del secreto.

### `BackupRecord`

Se registra en `docs/hardware-test-checklist.md`.

| Campo | Contenido |
| --- | --- |
| `logical_name` | `spec-01/cyd-prebaseline-4mb.bin` |
| `physical_artifact_id` | Nombre único derivado de UTC e identificador redactado |
| `size_bytes` | Debe ser exactamente `4194304` |
| `sha256` | SHA-256 completo |
| `created_at` | Fecha y hora UTC RFC 3339 |
| `tool` | `.venv-tools/bin/esptool 4.11.0` |
| `logical_path` | Ruta redactada, sin nombre de usuario |
| `encrypted_at_rest` | `YES` |
| `directory_mode` | `0700` |
| `file_mode` | `0600` |
| `retention_until` | Fecha UTC |
| `destruction_status` | `PENDING`, `DESTROYED` o excepción documentada |
| `destruction_recorded_at` | Fecha UTC o `N/A` |
| `purpose` | Preservación forense y recuperación excepcional |

### `DeviceIdentityRecord`

Se registra antes del backup y se reutiliza antes de cada escritura.

| Campo | Contenido |
| --- | --- |
| `authorized_port` | Puerto lógico seleccionado |
| `usb_vid` | VID observado |
| `usb_pid` | PID observado |
| `usb_serial_hash` | Hash o `N/A` |
| `chip` | Modelo identificado |
| `chip_revision` | Revisión reportada |
| `physical_flash_bytes` | Tamaño detectado |
| `device_id_hash` | Identificador redactado |
| `identity_recheck` | Resultado antes de `erase`, `upload` y `uploadfs` |

### `HardwareTestRecord`

Cada prueba de `docs/hardware-test-checklist.md` usa estos campos:

| Campo | Contenido |
| --- | --- |
| `id` | Identificador estable, por ejemplo `HW-BOOT-001` |
| `precondition` | Estado requerido antes de ejecutar |
| `procedure` | Pasos concretos |
| `expected_result` | Criterio observable y verificable |
| `threshold` | Tiempo, tolerancia, conteo o `N/A` |
| `observed_result` | Observación redactada |
| `status` | `PASS`, `FAIL` o `BLOCKED` |
| `evidence` | Extracto sanitizado, hash o referencia lógica |
| `hardware` | Modelo, placa y revisión observada |
| `platformio_version` | Debe ser `6.1.19` |
| `network_profile` | Nombre lógico de la red aislada |
| `notes` | Información adicional sin secretos |

### `VisualEvidenceRecord`

Se usa cuando una prueba necesita fotografía o video externo.

| Campo | Contenido |
| --- | --- |
| `logical_name` | Nombre lógico sin ruta personal |
| `sha256` | SHA-256 completo |
| `custodian` | Persona responsable |
| `metadata_removed` | `YES` |
| `sensitive_content_reviewed` | `YES` |
| `retention_until` | Fecha o política |
| `linked_test_ids` | Pruebas respaldadas |

## Plan de implementación

### Fase A — Repositorios, seguridad, toolchain y builds

1. **Ejecutar el preflight sin modificar el workspace.**
   - Confirmar que SPEC 00 está `Approved`, versionada y disponible en la rama base.
   - Registrar `git status --short`, ramas, tags, commits, remotos y SHA actuales.
   - Ejecutar sobre `clawd-meter/`:

     ```bash
     git ls-files -s clawd-meter
     git -C clawd-meter rev-parse --git-dir
     git -C clawd-meter status --short
     git -C clawd-meter show-ref
     ```

   - Identificar referencias exclusivamente locales y preservar cada una mediante push autorizado, bundle externo protegido o decisión explícita.
   - Verificar acceso autenticado a GitHub y consultar si `Rafastoievsky/ai-usage-meter` existe.
   - Clasificar cada desviación como `ACTION_REQUIRED` o `BLOCKED`.
   - Tratar como `ACTION_REQUIRED` la ausencia conocida de remoto, `.gitmodules`, PlatformIO o repositorio coordinador remoto.
   - Tratar como `BLOCKED` cambios locales en conflicto, permisos no resolubles, una referencia local que podría perderse o falta de autorización para crear el remoto.
   - **Complejidad:** Baja
   - **Razonamiento recomendado:** Bajo
   - **Razón:** inspecciona y clasifica el estado sin efectuar cambios.

2. **Crear higiene, locks y bootstrap reproducible.**
   - Renombrar `Docs/` a `docs/` mediante un movimiento Git seguro para filesystems case-insensitive.
   - Retirar del índice `.DS_Store` y `.Rhistory`.
   - Crear `.gitignore`.
   - Crear `requirements-tools.txt` con:

     ```text
     pip==26.1.2
     platformio==6.1.19
     esptool==4.11.0
     ```

   - Fijar uv `0.11.29` y los hashes de sus artefactos en `toolchain/bootstrap-checksums.txt`.
   - Crear `requirements-tools.lock` con todas las dependencias transitivas y hashes.
   - Crear `scripts/bootstrap-tools.sh`.
   - Hacer que el bootstrap:
     1. rechace una plataforma distinta de macOS `arm64`;
     2. obtenga o valide uv `0.11.29`;
     3. instale o seleccione Python `3.14.6`;
     4. cree `.venv-tools` con `uv venv --python 3.14.6 --seed`;
     5. instale el lock con `--require-hashes --no-deps`;
     6. valide `python -m pip --version` y exija `26.1.2`;
     7. no ejecute PlatformIO antes de esa validación;
     8. descargue Gitleaks `8.30.1`, valide SHA-256 y lo guarde en `.tools/`.
   - Validar rutas absolutas de ejecutables.
   - Validar y preparar `specs/.spec-config.yml`; si tiene un valor incorrecto, corregirlo mediante commit dedicado.
   - Crear los esqueletos documentales de evidencia.
   - **Complejidad:** Media
   - **Razonamiento recomendado:** Medio
   - **Razón:** crea el entorno reproducible y varias rutas controladas.

3. **Ejecutar el gate inicial de secretos.**
   - Confirmar que ambos repositorios no sean shallow o completar todas las referencias.
   - Escanear referencias Git, árboles y fuentes con Gitleaks redactado.
   - Revisar de forma dirigida `claudeKey`, `sessionKey`, `apiToken`, Wi-Fi, exports, fixtures y artefactos.
   - Clasificar falsos positivos sin copiar valores.
   - Aplicar la política diferenciada para historia no publicada e historia pública.
   - Completar el inventario y la tabla de alias.
   - Detener el flujo ante un secreto real activo hasta revocarlo.
   - **Complejidad:** Media
   - **Razonamiento recomendado:** Alto
   - **Razón:** una remediación incorrecta puede publicar o conservar credenciales.

4. **Clasificar y reparar la topología Git.**
   - Seleccionar el procedimiento según el estado detectado:
     - gitlink existente sin `.gitmodules`;
     - repositorio embebido;
     - directorio normal.
   - Configurar el `origin` del coordinador sin hacer push todavía.
   - Crear `.gitmodules` con URL HTTPS pública y sin `branch`.
   - Preservar commits, ramas y tags locales.
   - Configurar en firmware:
     - `origin.url` HTTPS;
     - `origin.pushurl` SSH;
     - `upstream.url` HTTPS;
     - ausencia de `upstream.pushurl`.
   - Obtener ramas predeterminadas mediante `git ls-remote --symref`.
   - Ejecutar `git fetch` y verificar el SHA inicial mediante `git merge-base --is-ancestor`.
   - Registrar `upstream_only` y `origin_only`.
   - Validar:
     - modo `160000`;
     - coincidencia entre índice, gitlink y HEAD del submódulo;
     - `git submodule status` con prefijo de espacio, nunca `-`, `+` o `U`;
     - detached HEAD sobre el gitlink en el clon de prueba.
   - **Complejidad:** Alta
   - **Razonamiento recomendado:** Alto
   - **Razón:** modifica la relación entre dos historiales y debe preservar referencias locales.

5. **Fijar PlatformIO y construir el baseline sin hardware.**
   - Configurar `platformio.ini` con plataforma, bibliotecas y commit exactos.
   - Crear un `PLATFORMIO_CORE_DIR` temporal, vacío y aislado.
   - Ejecutar una resolución controlada inicial y capturar `pio pkg list`.
   - Completar `toolchain/platformio-packages.lock.json`.
   - Convertir todos los paquetes usados por `cyd` a versiones exactas en `platform_packages`.
   - Descartar el primer core dir.
   - Crear un segundo `PLATFORMIO_CORE_DIR` vacío.
   - Ejecutar:

     ```bash
     .venv-tools/bin/pio run -e cyd
     .venv-tools/bin/pio run -e cyd -t buildfs
     ```

   - Verificar que no se resuelvan versiones distintas del lock.
   - Registrar bootloader, particiones, aplicación, LittleFS, métricas y hashes.
   - Registrar warnings; cualquier warning no allowlisted produce `FAIL`.
   - Confirmar que el heap se medirá sin añadir funcionalidad.
   - **Complejidad:** Alta
   - **Razonamiento recomendado:** Alto
   - **Razón:** transforma una resolución flotante en un baseline reproducible verificable.

6. **Publicar el baseline coordinador preliminar y probar clonación.**
   - Si el repositorio remoto no existe, obtener autorización explícita y crearlo.
   - Confirmar `main` como rama predeterminada.
   - Comitear únicamente archivos aprobados y escaneados.
   - Hacer push al remoto canónico.
   - Clonar anónimamente en un directorio temporal con `--recurse-submodules`.
   - Confirmar que:
     - el coordinador clonado usa HTTPS por haber sido clonado anónimamente;
     - el submódulo clonado usa la URL HTTPS de `.gitmodules`;
     - el workspace de mantenimiento conserva los `pushurl` SSH definidos;
     - el gitlink no depende del `.git` original.
   - Ejecutar el bootstrap y ambos builds desde el clon limpio.
   - **Complejidad:** Media
   - **Razonamiento recomendado:** Alto
   - **Razón:** publica por primera vez y valida la frontera coordinador–submódulo.

### Fase B — Backup, flashing y hardware

7. **Identificar el CYD y crear el backup sensible.**
   - Detectar candidatos seriales.
   - Crear un `DeviceIdentityRecord`.
   - Exigir coincidencia de identidad antes de toda operación.
   - Identificar chip, revisión y 4 MB mediante esptool `4.11.0`.
   - Crear el directorio cifrado y restringido.
   - Leer exactamente `0x400000` bytes antes de cualquier escritura.
   - Usar nombre físico único, creación exclusiva y rechazo de symlinks.
   - Verificar tamaño y SHA-256.
   - Examinar el backup con temporales protegidos, sin imprimir strings.
   - Registrar solamente conteos, clasificación y resultado redactado.
   - Revocar cualquier `sessionKey` activa antes de continuar.
   - Establecer retención de 30 días y propósito forense.
   - Si no hay CYD verificable, registrar `BLOCKED` para Fase B y detener solamente esta fase.
   - **Complejidad:** Alta
   - **Razonamiento recomendado:** Alto
   - **Razón:** maneja hardware real y un artefacto altamente sensible.

8. **Borrar, flashear y verificar los artefactos.**
   - Revalidar identidad y puerto.
   - Ejecutar borrado completo de flash.
   - Revalidar identidad después del reset.
   - Flashear firmware y LittleFS usando explícitamente el puerto autorizado.
   - Registrar códigos de salida, offsets y tamaños.
   - Verificar escritura y realizar readback cuando sea soportado.
   - Comparar hashes por región o registrar la limitación técnica.
   - Reiniciar y abrir serial a `115200`.
   - Confirmar arranque y montaje de LittleFS.
   - No restaurar la imagen cruda.
   - **Complejidad:** Alta
   - **Razonamiento recomendado:** Alto
   - **Razón:** escribe todas las regiones relevantes y debe prevenir flashing sobre otro dispositivo.

9. **Ejecutar el checklist funcional y de persistencia.**
   - Usar red temporal aislada.
   - Configurar solo parámetros nuevos permitidos.
   - Aplicar como mínimo estos umbrales:
     - arranque inicial completo en un máximo de 60 segundos;
     - observación de 10 minutos sin boot loop, watchdog o reinicio inesperado;
     - reloj con desviación máxima de 60 segundos después de NTP;
     - rotación automática dentro de ±2 segundos del intervalo configurado;
     - 10 toques consecutivos válidos, cada uno con un solo avance;
     - observar al menos un blink y un look-around en una ventana de 5 minutos;
     - timeout de 60 segundos para NTP y 90 segundos para clima;
     - heap registrado al arrancar y después de 10 minutos, sin caída sostenida que indique fuga durante la ventana.
   - Probar pantalla, colores, backlight, LittleFS, portal, Wi-Fi, touch, canales, reloj, clima, Clawd y persistencia.
   - Medir heap por serial si Info no lo muestra.
   - Registrar evidencia visual externa solo bajo `VisualEvidenceRecord`.
   - Documentar `/api/export` y `claudeKey` como deuda de SPEC 09–10.
   - **Complejidad:** Media
   - **Razonamiento recomendado:** Medio
   - **Razón:** son pruebas manuales numerosas con criterios ya cerrados.

### Cierre coordinado

10. **Cerrar el baseline del firmware y sincronizar el gitlink.**
    - Ejecutar escaneo final redactado sobre fuentes y artefactos.
    - Comitear `platformio.ini` en `feat/01-baseline-validation`.
    - Hacer push mediante `origin.pushurl`.
    - Integrar mediante revisión/PR, sin rebase de historia publicada.
    - Ejecutar `git fetch origin`.
    - Confirmar que el commit resultante es ancestro de `origin/main`.
    - Actualizar el gitlink del coordinador a ese SHA.
    - Confirmar que el commit está disponible mediante clonación anónima.
    - Conservar `FW_VERSION` funcional existente y registrar `build_identity`.
    - **Complejidad:** Alta
    - **Razonamiento recomendado:** Alto
    - **Razón:** coordina commits de dos repositorios sin atomicidad compartida.

11. **Completar evidencia y gate final de secretos.**
    - Completar ambos documentos con metadatos comunes.
    - Validar que no existan rutas personales, SSID, IP sensibles, valores o fragmentos.
    - Verificar temporales y backups fuera de Git.
    - Registrar evidencia visual por hash cuando exista.
    - Confirmar cero detecciones reales no resueltas dentro del alcance documentado.
    - Registrar la retención pendiente del backup.
    - Comitear y publicar evidencia redactada.
    - **Complejidad:** Media
    - **Razonamiento recomendado:** Alto
    - **Razón:** la evidencia misma puede convertirse en un canal de filtración.

12. **Validar el estado final desde cero.**
    - Crear un directorio temporal vacío.
    - Aislar caches de pip y PlatformIO.
    - Ejecutar clon anónimo con submódulos.
    - Ejecutar el bootstrap fijado.
    - Verificar Python, uv, pip, PlatformIO, esptool y Gitleaks.
    - Verificar remotos, `.gitmodules`, ausencia de branch tracking, gitlink y ancestro en `origin/main`.
    - Volver a ejecutar ambos builds.
    - Comparar fuentes, locks, paquetes, estructura y métricas.
    - Confirmar worktrees limpios.
    - Confirmar que el backup y temporales no existen en árbol ni historia.
    - Registrar resultado final.
    - **Complejidad:** Media
    - **Razonamiento recomendado:** Medio
    - **Razón:** integra todos los entregables mediante un procedimiento cerrado.

### Resumen del plan

| Tipo | Alto/Alta | Medio/Media | Bajo/Baja |
| --- | ---: | ---: | ---: |
| Complejidad | 5 | 6 | 1 |
| Razonamiento recomendado | 8 | 3 | 1 |

## Criterios de aceptación

### Fases y preflight

- [ ] La Fase A puede ejecutarse y quedar completada sin CYD.
- [ ] La falta del CYD bloquea solamente la Fase B y el cierre `Implemented-Verified`.
- [ ] El preflight distingue `ACTION_REQUIRED` de `BLOCKED`.
- [ ] La ausencia conocida de remoto, `.gitmodules`, PlatformIO o repositorio coordinador remoto se trata como `ACTION_REQUIRED`.
- [ ] Ningún cambio local, commit o referencia exclusivamente local se pierde.
- [ ] SPEC 00 está `Approved`, versionada y disponible en la historia del coordinador.

### Repositorios y submódulo

- [ ] El workspace de mantenimiento de `ai-usage-meter` tiene `origin.url = git@github.com:Rafastoievsky/ai-usage-meter.git`.
- [ ] La clonación pública del coordinador usa `https://github.com/Rafastoievsky/ai-usage-meter.git`.
- [ ] `Rafastoievsky/ai-usage-meter` es público y su rama predeterminada es `main`.
- [ ] `.gitmodules` registra `clawd-meter` con URL HTTPS pública y no contiene `branch`.
- [ ] El workspace de mantenimiento de firmware tiene `origin.url` HTTPS y `origin.pushurl` SSH.
- [ ] `upstream.url` es `https://github.com/monsieurfux/clawd-meter.git` y no tiene `pushurl`.
- [ ] `git ls-remote --symref <url> HEAD` documenta la rama predeterminada de cada remoto.
- [ ] El estado inicial de `clawd-meter/` fue clasificado antes de repararlo.
- [ ] Las referencias exclusivamente locales fueron preservadas o resueltas explícitamente.
- [ ] El índice registra `clawd-meter` con modo `160000`.
- [ ] El SHA del gitlink tiene 40 caracteres.
- [ ] Después de fetch, `git merge-base --is-ancestor <gitlink> origin/main` termina con código `0`.
- [ ] `git submodule status` empieza con espacio y no con `-`, `+` o `U`.
- [ ] El SHA de `git submodule status` coincide con el índice y el HEAD del submódulo.
- [ ] La diferencia `upstream_only`/`origin_only` está documentada con dirección inequívoca.
- [ ] Un clon anónimo recursivo termina con código `0`.
- [ ] El submódulo del clon queda en detached HEAD exactamente sobre el gitlink.
- [ ] Los worktrees finales están limpios.

### Higiene y documentación

- [ ] Git registra `docs/` y no registra `Docs/`.
- [ ] `git ls-files` no devuelve `.DS_Store` ni `.Rhistory`.
- [ ] `.gitignore` excluye `.venv-tools/`, `.tools/`, caches, backups, temporales sensibles y artefactos locales.
- [ ] `specs/.spec-config.yml` existe y conserva `AutoCreateBranch: true`.
- [ ] Una corrección de `.spec-config.yml`, si fue necesaria, quedó en commit dedicado.
- [ ] Existen ambos documentos de evidencia.
- [ ] Todo registro contiene metadatos comunes.
- [ ] Los intentos anteriores no fueron sobrescritos.
- [ ] Ninguna evidencia contiene rutas personales completas, SSID, IP sensible, credenciales o fragmentos.
- [ ] Toda evidencia visual externa cumple `VisualEvidenceRecord`.

### Python, uv, pip y herramientas

- [ ] El baseline certifica macOS `arm64`.
- [ ] uv reporta `0.11.29` y su artefacto coincide con el SHA-256 fijado.
- [ ] Python reporta exactamente `3.14.6`.
- [ ] `.venv-tools` fue creado con `uv venv --python 3.14.6 --seed`.
- [ ] `requirements-tools.txt` fija `pip==26.1.2`, `platformio==6.1.19` y `esptool==4.11.0`.
- [ ] `requirements-tools.lock` incluye pip y todas las dependencias transitivas con hashes.
- [ ] El lock registra resolver, versión, Python, OS y arquitectura.
- [ ] La instalación usa `--require-hashes --no-deps`.
- [ ] `.venv-tools/bin/python -m pip --version` reporta `26.1.2`.
- [ ] Ningún comando PlatformIO se ejecutó antes de validar pip `26.1.2`.
- [ ] `.venv-tools/bin/pio --version` reporta `6.1.19`.
- [ ] `.venv-tools/bin/pio system info` reporta Python `3.14.6`.
- [ ] `.venv-tools/bin/esptool version` reporta `4.11.0`.
- [ ] `.tools/gitleaks version` reporta `8.30.1`.
- [ ] Todos los ejecutables se validan mediante rutas controladas.
- [ ] Gitleaks y uv coinciden con los SHA-256 fijados.

### PlatformIO y builds

- [ ] `platformio.ini` fija `platformio/espressif32@7.0.1`.
- [ ] `platformio.ini` fija TFT_eSPI `2.5.43`.
- [ ] `platformio.ini` fija ArduinoJson `7.4.3`.
- [ ] `platformio.ini` fija XPT2046 al commit `f956c5d8ce3bf39169c7378416b89e7cfe70a034`.
- [ ] `platformio.ini` no contiene rangos de biblioteca ni ramas Git flotantes para `cyd`.
- [ ] `platform_packages` fija exactamente todos los paquetes usados por `cyd`.
- [ ] `toolchain/platformio-packages.lock.json` registra todos los paquetes mostrados por `pio pkg list`.
- [ ] El lock registra nombre, propietario, versión, origen, arquitectura e integridad cuando esté disponible.
- [ ] El build final usa un `PLATFORMIO_CORE_DIR` vacío y aislado.
- [ ] La validación final no depende de `~/.platformio` ni del cache global de pip.
- [ ] `pio run -e cyd` termina con código `0`.
- [ ] `pio run -e cyd -t buildfs` termina con código `0`.
- [ ] No existe ningún warning fuera de la allowlist.
- [ ] Cada warning permitido tiene patrón, herramienta, justificación, responsable y fecha de revisión.
- [ ] Se registran hashes y tamaños de bootloader, tabla de particiones, aplicación y LittleFS.
- [ ] Se registran offsets y tamaños de partición.
- [ ] Se registran RAM y almacenamiento de programa con nombres correctos.
- [ ] Se registra flash física por separado del límite de programa.
- [ ] El build limpio resuelve exactamente los paquetes documentados.
- [ ] La reproducción no exige igualdad binaria bit a bit, pero cualquier diferencia de hash queda registrada y explicada.
- [ ] `FW_VERSION` no se modifica solo para etiquetar SPEC 01.
- [ ] La identidad del baseline deriva de commits y hashes de locks.

### Secretos

- [ ] Ambos repositorios fueron escaneados con historia y referencias completas.
- [ ] El inventario distingue `sessionKey`, `claudeKey` y `apiToken`.
- [ ] Ningún inventario o reporte contiene valores o fragmentos.
- [ ] Los temporales sensibles usan `umask 077` y se eliminan al terminar.
- [ ] Las strings de binarios y backup no se imprimen en terminal.
- [ ] Existe cero detecciones reales no resueltas dentro de los métodos y alcances documentados.
- [ ] El documento no afirma ausencia absoluta de secretos en binarios.
- [ ] Cualquier credencial activa encontrada fue revocada.
- [ ] Un secreto en historia no publicada se remedió antes del primer push.
- [ ] Un secreto en historia pública siguió una decisión explícita de reescritura, recreación o aceptación del valor revocado.
- [ ] Un valor borrado de HEAD pero presente en historia no se considera eliminado.

### Backup y dispositivo

- [ ] El CYD se identifica mediante `DeviceIdentityRecord`.
- [ ] Se verifica ESP32 y flash de `4194304` bytes.
- [ ] La identidad y el puerto se revalidan antes de backup, erase, upload y uploadfs.
- [ ] Todos los comandos físicos reciben explícitamente el puerto autorizado.
- [ ] El backup se creó antes de cualquier escritura.
- [ ] El backup mide exactamente `4194304` bytes y tiene SHA-256 completo.
- [ ] El nombre físico del backup es único y no sobrescribe ejecuciones anteriores.
- [ ] La creación rechaza symlinks y usa permisos `0700`/`0600`.
- [ ] El backup está cifrado en reposo.
- [ ] La evidencia registra solo nombre lógico y metadatos redactados.
- [ ] El backup se define como preservación forense, no rollback normal.
- [ ] Restaurarlo requiere autorización separada.
- [ ] La retención es de 30 días salvo excepción documentada.
- [ ] La destrucción se registra al vencer la retención.
- [ ] Git, clon limpio e historia no contienen backup ni strings temporales.

### Flashing

- [ ] La evidencia demuestra el orden: identidad, backup, validación, revocación, erase, firmware, LittleFS, reinicio y baseline.
- [ ] Se ejecutó borrado completo después del backup y antes del flashing.
- [ ] Se registran códigos de salida, offsets y tamaños.
- [ ] La escritura fue verificada por herramienta o readback.
- [ ] Los hashes de readback coinciden o la limitación técnica está documentada.
- [ ] No se restauró la imagen cruda ni configuración anterior.

### Hardware y comportamiento

- [ ] Las pruebas usan una red temporal o de invitados aislada.
- [ ] No se conectó el CYD a la LAN productiva.
- [ ] Solo se configuraron valores nuevos permitidos.
- [ ] No se configuró `claudeKey`, `sessionKey` ni `apiToken`.
- [ ] El arranque completa en un máximo de 60 segundos.
- [ ] El dispositivo permanece 10 minutos sin boot loop, watchdog o reinicio inesperado.
- [ ] La pantalla funciona en landscape a 320×240.
- [ ] Los colores, polaridad y backlight son correctos.
- [ ] LittleFS monta y sus fuentes y archivos web pueden leerse.
- [ ] El portal inicial permite configurar Wi-Fi temporal sin imprimir la contraseña.
- [ ] Diez toques consecutivos producen exactamente un avance cada uno.
- [ ] La rotación ocurre dentro de ±2 segundos del intervalo.
- [ ] El reloj queda dentro de 60 segundos de tolerancia después de NTP.
- [ ] NTP responde dentro de 60 segundos o la prueba queda `FAIL`/`BLOCKED` con causa externa demostrada.
- [ ] Clima y pronóstico responden dentro de 90 segundos bajo conectividad verificada.
- [ ] Se observa al menos un blink y un look-around en 5 minutos.
- [ ] La configuración nueva permitida persiste tras reinicio.
- [ ] El dispositivo arranca sin credenciales Claude.
- [ ] El canal Claude no muestra porcentajes falsos sin configuración.
- [ ] Clawd y canales locales continúan funcionando sin Claude.
- [ ] El heap se registra al arranque y después de 10 minutos.
- [ ] Si Info no muestra heap, se mide por serial sin modificar firmware.
- [ ] No se observa caída sostenida de heap durante la ventana.
- [ ] La evidencia no expone contraseña, cookie, token, SSID o IP sensible.
- [ ] `/api/export` y `claudeKey` quedan documentados como deuda de SPEC 09–10.
- [ ] Cada prueba contiene todos los campos obligatorios.
- [ ] No queda ningún resultado `FAIL` o `BLOCKED` al cerrar SPEC 01.
- [ ] Sin CYD, SPEC 01 no puede pasar a `Implemented-Verified`.

## Decisiones tomadas y descartadas

- **Sí:** una sola SPEC cubre repositorios, toolchain, builds y CYD, organizada en Fase A y Fase B.
- **No:** bloquear trabajo de repositorio y builds solamente porque no haya hardware.

- **Sí:** el preflight distingue desviaciones corregibles de bloqueos reales.
- **No:** tratar la ausencia de elementos que SPEC 01 debe crear como un fallo fatal.

- **Sí:** el coordinador usa SSH en el workspace de mantenimiento y HTTPS para clonación pública.
- **Sí:** el firmware usa HTTPS como fetch URL y SSH como `pushurl`.
- **No:** exigir que un clon anónimo conserve URLs SSH que Git no transporta desde el workspace original.

- **Sí:** `.gitmodules` usa HTTPS y no sigue ramas.
- **No:** usar SSH o `branch = main` en `.gitmodules`.

- **Sí:** el estado de `clawd-meter/` se clasifica antes de repararlo.
- **No:** aplicar una conversión genérica a estados Git distintos.

- **Sí:** ramas, tags y commits locales se preservan explícitamente.
- **No:** afirmar “sin perder historial” sin inventariar referencias locales.

- **Sí:** Python `3.14.6`, uv `0.11.29`, pip `26.1.2`, PlatformIO `6.1.19` y esptool `4.11.0` quedan fijados.
- **No:** usar versiones flotantes o depender de herramientas globales.

- **Sí:** uv crea el entorno con `--seed` y pip se fija antes de cualquier ejecución de PlatformIO.
- **No:** usar `uv venv` sin pip disponible.

- **Sí:** el lock Python incluye hashes y se instala con `--require-hashes --no-deps`.
- **No:** confiar solo en el hash del archivo lock.

- **Sí:** PlatformIO usa un lock de paquetes internos y `platform_packages` exactos.
- **No:** asumir que fijar únicamente `espressif32@7.0.1` fija framework, toolchain y herramientas.

- **Sí:** los builds finales usan caches aislados.
- **No:** aceptar como clon limpio un build que reutiliza silenciosamente `~/.platformio`.

- **Sí:** los escaneos declaran alcance y método.
- **No:** prometer ausencia absoluta de secretos en imágenes binarias.

- **Sí:** la remediación de historia pública y no publicada sigue políticas distintas.
- **No:** considerar eliminado un secreto que continúa en commits históricos.

- **Sí:** el backup usa nombre único, cifrado, retención y destrucción.
- **No:** conservar indefinidamente una imagen con credenciales heredadas.

- **Sí:** el backup sirve para preservación forense y recuperación excepcional.
- **No:** restaurarlo como rollback normal.

- **Sí:** se ejecuta `erase_flash` después del backup y revocación.
- **No:** dejar sectores heredados fuera de las regiones reescritas.

- **Sí:** el dispositivo se identifica de forma fuerte y cada comando usa el puerto autorizado.
- **No:** confiar únicamente en “primer puerto serial ESP32 encontrado”.

- **Sí:** las pruebas usan una red aislada y configuración no sensible nueva.
- **No:** conectar el firmware heredado a una LAN productiva.

- **Sí:** las pruebas tienen umbrales observables.
- **No:** aceptar criterios subjetivos sin ventana, tolerancia o conteo.

- **Sí:** heap se mide por serial si la UI no lo expone.
- **No:** introducir una funcionalidad nueva para completar el baseline.

- **Sí:** se conserva el `FW_VERSION` funcional existente.
- **No:** cambiarlo sin una modificación funcional.

- **Sí:** la evidencia visual externa usa hash, sanitización y retención.
- **No:** versionar fotografías o videos por defecto.

- **Sí:** SPEC 01 certifica macOS `arm64` y el target `cyd`.
- **No:** declarar soporte no probado para otros hosts o `nodemcuv2`.

## Riesgos identificados

| Riesgo | Impacto | Mitigación |
| --- | --- | --- |
| Publicar un secreto | Compromiso de cuentas, red o dispositivo | Gates antes de push, historia completa, redacción, revocación y política diferenciada de remediación. |
| Falsa garantía de “cero secretos” binarios | Confianza de seguridad injustificada | Declarar métodos y alcance; registrar cero detecciones reales no resueltas, no ausencia absoluta. |
| Perder referencias locales al reparar el submódulo | Pérdida de trabajo | Inventariar refs, preservarlas mediante push o bundle protegido y bloquear ante ambigüedad. |
| Gitlink no integrado | Clon recursivo irreproducible | Verificar ancestro de `origin/main` después de fetch. |
| URLs SSH/HTTPS inconsistentes | Criterios imposibles en clon anónimo | Separar fetch URL, push URL y submodule URL. |
| Cambio no atómico entre repositorios | Coordinador apunta temporalmente a una revisión incorrecta | Publicar firmware, confirmar ancestro, actualizar gitlink y repetir clon limpio. |
| Lock Python sin hashes efectivos | Sustitución o cambio de paquetes | `--require-hashes --no-deps`, resolver fijado y checksums. |
| `uv venv` sin pip | PlatformIO no puede instalar paquetes | `uv venv --seed`, instalar pip `26.1.2` y validarlo antes de PlatformIO. |
| Paquetes internos PlatformIO flotantes | Builds distintos con el mismo `platformio.ini` | `platform_packages` exactos, lock JSON y core dir aislado. |
| Cache global contamina reproducción | Falso resultado reproducible | Aislar `PLATFORMIO_CORE_DIR` y cache de pip. |
| Warning nuevo ignorado | Regresión oculta | Allowlist estructurada y fallo ante cualquier warning no previsto. |
| Backup contiene credenciales | Exposición grave | Cifrado, permisos, retención de 30 días, destrucción y acceso restringido. |
| Nombre de backup sobrescrito | Pérdida de evidencia | Nombre único, creación exclusiva y rechazo de symlinks. |
| Restauración reintroduce secretos | Reactivación de credenciales | Restauración prohibida sin autorización separada. |
| Sectores heredados sobreviven al flashing | Persistencia de datos anteriores | Borrado completo antes de escribir artefactos limpios. |
| Flashing sobre otro ESP32 | Daño a hardware ajeno | Identidad fuerte y puerto explícito en cada comando. |
| Escritura incompleta | Firmware o filesystem corrupto | Verificación de escritura, readback y hashes por región. |
| Red heredada insegura | Exposición del dispositivo y LAN | Red temporal aislada y prohibición de LAN productiva. |
| NTP o clima externos fallan | Falso diagnóstico de firmware | Timeouts, conectividad registrada y causa externa demostrable. |
| Variante física del CYD | Diferencias de display/touch | Registrar modelo y revisión; certificar solo la unidad probada. |
| Métricas de flash mal interpretadas | Comparaciones inválidas | Separar flash física, almacenamiento de programa y particiones. |
| Evidencia visual filtra datos | Exposición indirecta | Eliminar metadatos, sanitizar, hashear y aplicar retención. |
| Fecha de cierre con backup aún retenido | Artefacto sensible olvidado | Registrar `retention_until` y tarea obligatoria de destrucción. |
| Archivos locales sobrescritos | Pérdida de trabajo del usuario | Preflight, lista de rutas aprobadas y bloqueo ante solapamiento. |
