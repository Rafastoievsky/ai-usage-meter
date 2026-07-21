# Baseline de reproducibilidad — SPEC 01

> Evidencia redactada. Prohibido registrar: valores o fragmentos de secretos,
> rutas personales completas, SSID, IP sensibles, strings de binarios o backups.
> Los registros de intentos anteriores no se sobrescriben.

## Metadatos comunes

Todo registro contiene: `attempt_id`, `phase` (`preflight`, `phase-a`,
`phase-b`, `final`), `recorded_at` (UTC RFC 3339), `responsible`,
`coordinator_commit`, `firmware_commit`, `result` (`PASS`/`FAIL`/`BLOCKED`),
`notes`.

## Estructuras de registro

- `RepositoryBaseline`: repository, remote, fetch_url, push_url, submodule_url,
  default_branch, commit_sha, ls_remote_result, ancestor_result,
  origin_upstream_diff, worktree_state, local_only_refs.
- `ToolchainBaseline`: component, version, source, integrity, executable_path,
  verification_command, host_os, host_arch, lock_sha256.
- `BuildArtifactRecord`: target, command, artifact_logical_path,
  artifact_size_bytes, artifact_sha256, flash_offset, partition_name,
  partition_size_bytes, platformio_core_dir_id, platformio_lock_sha256,
  warnings_allowlist_sha256.
- `BuildMetricsRecord`: ram_used_bytes, ram_limit_bytes,
  program_storage_used_bytes, program_storage_limit_bytes,
  physical_flash_bytes, partition_table_sha256, littlefs_partition_offset,
  littlefs_partition_size, littlefs_image_size, build_identity.
  Los campos que no apliquen se registran como `N/A`, nunca como cero.
- `SecretInventoryEntry`: name, aliases, owner, logical_location, consumer,
  rotation_policy, scan_scope, scan_method, finding_count, resolution.
  Prohíbe campos para valores, prefijos, sufijos o fragmentos.

## Intentos

### PREFLIGHT-001

| Campo | Valor |
| --- | --- |
| `attempt_id` | PREFLIGHT-001 |
| `phase` | `preflight` |
| `recorded_at` | 2026-07-21T01:49:22Z (registro; ejecución en la misma sesión) |
| `responsible` | operador local |
| `coordinator_commit` | `efe759931c1d3c5c7abf1e731484ffdf112bddd0` |
| `firmware_commit` | `1f29bf30ea9e7d1e09979a5760d47b1e361fdf32` |
| `result` | `PASS` (sin `BLOCKED`; desviaciones clasificadas `ACTION_REQUIRED`) |
| `notes` | Inspección read-only; workspace sin modificar |

**PASS:** SPEC 00 `Approved` y versionada en rama base; plataforma macOS
arm64; ambos repos no-shallow con worktrees limpios; HEAD del firmware igual
al gitlink; `main` del firmware igual a `origin/main`; cero referencias
locales exclusivas en `clawd-meter`; remotos `Rafastoievsky/clawd-meter` y
`monsieurfux/clawd-meter` accesibles con rama predeterminada `main`;
autenticación GitHub por SSH verificada.

**ACTION_REQUIRED:** coordinador sin remoto `origin`; `.gitmodules` ausente
con gitlink existente; referencias exclusivamente locales del coordinador
(`main`, `spec-00-*`, `spec-01-*`, commits `7535350` y `efe7599`) con
preservación decidida mediante push autorizado al remoto canónico;
`Rafastoievsky/ai-usage-meter` inexistente (creación solo con autorización
explícita); firmware sin `upstream` y con `origin` SSH como fetch URL;
PlatformIO/esptool/gitleaks ausentes y uv global sin fijar; `.DS_Store` y
`.Rhistory` versionados; `Docs/` con mayúscula.

**BLOCKED:** ninguno.

### BOOT-A-001

| Campo | Valor |
| --- | --- |
| `attempt_id` | BOOT-A-001 |
| `phase` | `phase-a` |
| `recorded_at` | 2026-07-21T01:49:22Z |
| `responsible` | operador local |
| `coordinator_commit` | `492289c8ce2f0b6eb5a0ffbe396b30bc31f4b981` |
| `firmware_commit` | `N/A` |
| `result` | `PASS` |
| `notes` | Higiene Git aplicada (`docs/`, índice sin `.DS_Store`/`.Rhistory`); bootstrap ejecutado con validación por rutas controladas |

#### ToolchainBaseline (BOOT-A-001)

| component | version | source | integrity | executable_path | verification_command | host_os | host_arch | lock_sha256 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| uv | 0.11.29 | `toolchain/bootstrap-checksums.txt` | sha256:61c04acc52a33ef0f331e494bdfbedcdb6c26c6970c022ed3699e5860f8930e3 | `.tools/uv-0.11.29/uv` | `.tools/uv-0.11.29/uv --version` | macOS 26.5.2 | arm64 | `N/A` |
| Python | 3.14.6 | uv-managed CPython | `N/A` | `.venv-tools/bin/python` | `.venv-tools/bin/python --version` | macOS 26.5.2 | arm64 | ver nota |
| pip | 26.1.2 | `requirements-tools.lock` | hashes por artefacto en lock | `.venv-tools/bin/pip` | `.venv-tools/bin/python -m pip --version` | macOS 26.5.2 | arm64 | ver nota |
| PlatformIO | 6.1.19 | `requirements-tools.lock` | hashes por artefacto en lock | `.venv-tools/bin/pio` | `.venv-tools/bin/pio --version` | macOS 26.5.2 | arm64 | ver nota |
| esptool | 4.11.0 | `requirements-tools.lock` | hashes por artefacto en lock | `.venv-tools/bin/esptool.py` | `.venv-tools/bin/esptool.py version` | macOS 26.5.2 | arm64 | ver nota |
| Gitleaks | 8.30.1 | `toolchain/bootstrap-checksums.txt` | sha256:b40ab0ae55c505963e365f271a8d3846efbc170aa17f2607f13df610a9aeb6a5 | `.tools/gitleaks-8.30.1/gitleaks` | `.tools/gitleaks-8.30.1/gitleaks version` | macOS 26.5.2 | arm64 | `N/A` |

Nota: `lock_sha256` de `requirements-tools.lock` se completa al cerrar la
Fase A (el archivo puede recibir correcciones editoriales hasta entonces).

Desviación registrada: esptool 4.11.0 instala el binario como `esptool.py`;
la validación usa `.venv-tools/bin/esptool.py`. El criterio de aceptación que
menciona la ruta literal `bin/esptool` queda documentado para `/spec-check`.

#### SecretInventoryEntry (inventario inicial; escaneo en pasos 3 y 11)

| name | aliases | owner | logical_location | consumer | rotation_policy | scan_scope | scan_method | finding_count | resolution |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Claude sessionKey | `sessionKey`, `claudeKey` | usuario de la cuenta | almacén gestionado por el proveedor (fuera del ESP32 en V1) | futuro `ClaudeProvider` | SPEC 00 §8.7 | fuente, refs Git, LittleFS, artefactos | pendiente (pasos 3/11) | pendiente | pendiente |
| `apiToken` | `apiToken` | operador local | LittleFS del dispositivo | superficies autenticadas del firmware | rotación manual | fuente, refs Git, artefactos | pendiente (pasos 3/11) | pendiente | pendiente |
| Wi-Fi password | credencial de red | propietario de la red | LittleFS del dispositivo | subsistema Wi-Fi | según red | backup crudo (Fase B) | pendiente | pendiente | pendiente |

### SECRETS-A-001

| Campo | Valor |
| --- | --- |
| `attempt_id` | SECRETS-A-001 |
| `phase` | `phase-a` |
| `recorded_at` | 2026-07-21T02:06:14Z |
| `responsible` | operador local |
| `coordinator_commit` | `bcfa5435a0f09f083987d71596d7f48cb5c7355b` |
| `firmware_commit` | `1f29bf30ea9e7d1e09979a5760d47b1e361fdf32` |
| `result` | `PASS` |
| `notes` | Gate inicial de secretos (Step 3). Escaneo redactado; sin exponer valores ni strings de binarios. |

**Método y alcance (Gitleaks 8.30.1, `--redact`):**

- Historia completa confirmada: ambos repos `git rev-parse --is-shallow-repository = false`; `git fetch --all --tags --prune` sin referencias faltantes.
- `gitleaks git . --log-opts="--all"` sobre el coordinador (todas las referencias alcanzables).
- `gitleaks git clawd-meter --log-opts="--all"` sobre el firmware (todas las referencias alcanzables, incluyendo `origin`/`upstream`).
- `gitleaks dir` sobre árboles de trabajo: `docs/`, `scripts/`, `toolchain/`, `specs/`, `clawd-meter/src`, `clawd-meter/data`.
- Revisión dirigida de `claudeKey`, `sessionKey`, `apiToken`, Wi-Fi, exports y fixtures: no existen `config.json`, `*.config.json`, `secrets.h`, `.env` ni volcados de export en el árbol; los nombres de campo aparecen solo como identificadores en fuente (0 asignaciones de valor literal).
- Reportes JSON redactados en un temporal `mktemp -d` con `umask 077`, modo `0700` y borrado por `trap`. No se imprimieron strings de binarios ni de backups.

**Resultado formal:**

> Cero detecciones reales no resueltas dentro de los métodos y alcances documentados.

Este gate cubre referencias Git, árboles de trabajo y fuentes. El contenido
LittleFS extraído, los strings imprimibles de artefactos y los patrones del
backup crudo se examinan en Fase B / Step 11. No se afirma ausencia absoluta de
secretos en datos binarios.

**Política de remediación aplicada:**

- Coordinador: historia aún `UNPUBLISHED` (sin remoto `origin`). Cero hallazgos ⇒ sin reescritura pendiente; de existir, se reescribiría de forma controlada antes del primer push (Step 6).
- Firmware: `origin` y `upstream` públicos. Cero hallazgos ⇒ sin revocación ni reescritura coordinada requerida.
- No se encontró credencial activa; el flujo no se detuvo.

#### SecretInventoryEntry (SECRETS-A-001 — gate inicial, Step 3)

| name | aliases | owner | logical_location | consumer | rotation_policy | scan_scope | scan_method | finding_count | resolution |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Claude sessionKey | `sessionKey`, `claudeKey` | usuario de la cuenta | almacén gestionado por el proveedor (fuera del ESP32 en V1) | futuro `ClaudeProvider` | SPEC 00 §8.7 | refs Git (coordinador+firmware, `--all`), árboles, fuentes | Gitleaks 8.30.1 redactado + revisión dirigida | 0 | `N/A` (LittleFS/artefactos/backup en Step 11) |
| `apiToken` | `apiToken` | operador local | LittleFS del dispositivo (`/config.json`, no versionado) | superficies autenticadas del firmware | rotación manual | refs Git, árboles, fuentes | Gitleaks 8.30.1 redactado + revisión dirigida | 0 | `N/A` (artefactos/backup en Step 11) |
| Wi-Fi password | credencial de red | propietario de la red | LittleFS del dispositivo (`/config.json`, no versionado) | subsistema Wi-Fi | según red | refs Git, árboles, fuentes | Gitleaks 8.30.1 redactado + revisión dirigida | 0 | `N/A` (backup crudo en Fase B / Step 11) |

Los intentos anteriores (inventario inicial) no se sobrescriben. Este bloque
registra el resultado del escaneo del Step 3; el gate final consolidado se
registra en Step 11.

### TOPO-A-001

| Campo | Valor |
| --- | --- |
| `attempt_id` | TOPO-A-001 |
| `phase` | `phase-a` |
| `recorded_at` | 2026-07-21T02:06:14Z |
| `responsible` | operador local |
| `coordinator_commit` | tip local `UNPUBLISHED` (avanza con el commit de este paso) |
| `firmware_commit` | `1f29bf30ea9e7d1e09979a5760d47b1e361fdf32` |
| `result` | `PASS` |
| `notes` | Estado detectado: gitlink existente sin `.gitmodules`. Reparado sin absorber gitdirs, sin perder refs (firmware con 0 refs locales exclusivas). |

**Acciones aplicadas:**

- Coordinador `origin` configurado en SSH (`git@github.com:Rafastoievsky/ai-usage-meter.git`) **sin push** (creación/publicación autorizada en Step 6).
- `.gitmodules` creado con URL HTTPS pública y **sin `branch`** (fuente de verdad = gitlink).
- Firmware: `origin.url` HTTPS, `origin.pushurl` SSH, `upstream.url` HTTPS y **sin `remote.upstream.pushurl`** (verificado por `git config`).
- `git submodule init` registró la URL; índice en modo `160000`; `git submodule status` con prefijo espacio y SHA igual al índice y al HEAD del submódulo (`1f29bf30…`, tag `v1.1.4`).

La verificación de detached HEAD sobre el gitlink corresponde al clon de prueba (Step 6).

#### RepositoryBaseline (TOPO-A-001)

| repository | remote | fetch_url | push_url | submodule_url | default_branch | commit_sha | ls_remote_result | ancestor_result | origin_upstream_diff | worktree_state | local_only_refs |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| ai-usage-meter | origin | `git@github.com:Rafastoievsky/ai-usage-meter.git` | `git@github.com:Rafastoievsky/ai-usage-meter.git` | `N/A` | `main` (previsto) | tip local `UNPUBLISHED` | `Repository not found` (ACTION_REQUIRED; creación en Step 6) | `N/A` | `N/A` | limpio (tras commit) | preservadas por push autorizado (Step 6): `main`, `spec-00-*`, `spec-01-*` |
| clawd-meter | origin | `https://github.com/Rafastoievsky/clawd-meter.git` | `git@github.com:Rafastoievsky/clawd-meter.git` | `https://github.com/Rafastoievsky/clawd-meter.git` | `main` (`ls-remote --symref` HEAD→`refs/heads/main`) | `1f29bf30ea9e7d1e09979a5760d47b1e361fdf32` | OK (HEAD→`main`) | gitlink es ancestro de `origin/main` (`merge-base --is-ancestor` exit 0) | `upstream_only=0`, `origin_only=0` | limpio | 0 (preflight) |
| clawd-meter | upstream | `https://github.com/monsieurfux/clawd-meter.git` | `NONE` | `N/A` | `main` (`ls-remote --symref` HEAD→`refs/heads/main`) | `1f29bf30ea9e7d1e09979a5760d47b1e361fdf32` | OK (HEAD→`main`) | `N/A` | `upstream_only=0`, `origin_only=0` (dirección: izquierda=upstream_only, derecha=origin_only) | `N/A` | `N/A` |

### BUILD-A-001

| Campo | Valor |
| --- | --- |
| `attempt_id` | BUILD-A-001 |
| `phase` | `phase-a` |
| `recorded_at` | 2026-07-20T19:25:00Z |
| `responsible` | operador local |
| `coordinator_commit` | tip local `UNPUBLISHED` |
| `firmware_commit` | `1f29bf30ea9e7d1e09979a5760d47b1e361fdf32` |
| `result` | `PASS` |
| `notes` | Dependencias fijadas, toolchain lock generado. Baseline construido sin hardware con cero warnings no allowlisted. |

#### BuildArtifactRecord (BUILD-A-001)

| target | command | artifact_logical_path | artifact_size_bytes | artifact_sha256 | flash_offset | partition_name | partition_size_bytes | platformio_core_dir_id | platformio_lock_sha256 | warnings_allowlist_sha256 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| bootloader | `pio run -e cyd` | `bootloader.bin` | 17536 | 3d234a7471f67b013686dabd4dee7c1fa915c9928463616a94bc9297acf1abf8 | `N/A` | `N/A` | `N/A` | core aislado 2 | `N/A` | `N/A` |
| partitions | `pio run -e cyd` | `partitions.bin` | 3072 | aaae2888c5a6a348004b5b436f47abb25ae32e72d9003902955a998eda723edd | `N/A` | `N/A` | `N/A` | core aislado 2 | `N/A` | `N/A` |
| application | `pio run -e cyd` | `firmware.bin` | 1194688 | f43fe777b60d03aa9c6eb934b4794a6040bec94c8dd04f36c234ac87c2c5a1c4 | `N/A` | app0 | 3145728 | core aislado 2 | `N/A` | `N/A` |
| littlefs | `pio run -e cyd -t buildfs` | `littlefs.bin` | 917504 | 7fb9b109447e84d051d4c7480062be1fb65a9eea172383bf7531d734b995e43d | `N/A` | spiffs | `N/A` | core aislado 2 | `N/A` | `N/A` |

#### BuildMetricsRecord (BUILD-A-001)

| ram_used_bytes | ram_limit_bytes | program_storage_used_bytes | program_storage_limit_bytes | physical_flash_bytes | partition_table_sha256 | littlefs_partition_offset | littlefs_partition_size | littlefs_image_size | build_identity |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 52504 | 327680 | 1188113 | 3145728 | 4194304 | aaae2888c5a6a348004b5b436f47abb25ae32e72d9003902955a998eda723edd | `N/A` | `N/A` | 917504 | `1f29bf30ea9e7d1e09979a5760d47b1e361fdf32` |
