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
