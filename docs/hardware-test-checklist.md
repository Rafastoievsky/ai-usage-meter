# Checklist de pruebas de hardware — SPEC 01 (Fase B)

> Evidencia redactada. Prohibido registrar: contraseñas, cookies, tokens,
> SSID, IP sensibles, rutas personales completas. Fotografías o videos solo
> mediante `VisualEvidenceRecord`; no se versionan por defecto.
> Unidad certificada: ESP32-2432S028R (CYD), flash física de 4194304 bytes.

## Metadatos comunes

Todo registro contiene: `attempt_id`, `phase`, `recorded_at` (UTC RFC 3339),
`responsible`, `coordinator_commit`, `firmware_commit`, `result`
(`PASS`/`FAIL`/`BLOCKED`), `notes`.

## Estructuras de registro

- `BackupRecord`: logical_name, physical_artifact_id, size_bytes (exactamente
  4194304), sha256, created_at, tool, logical_path (redactada),
  encrypted_at_rest, directory_mode (`0700`), file_mode (`0600`),
  retention_until, destruction_status, destruction_recorded_at, purpose
  (preservación forense y recuperación excepcional; no rollback normal).
- `DeviceIdentityRecord`: authorized_port, usb_vid, usb_pid, usb_serial_hash,
  chip, chip_revision, physical_flash_bytes, device_id_hash,
  identity_recheck (antes de `erase`, `upload` y `uploadfs`).
- `HardwareTestRecord`: id, precondition, procedure, expected_result,
  threshold, observed_result, status, evidence, hardware,
  platformio_version (6.1.19), network_profile, notes.
- `VisualEvidenceRecord`: logical_name, sha256, custodian, metadata_removed,
  sensitive_content_reviewed, retention_until, linked_test_ids.

## Estado de la Fase B

| Registro | Estado |
| --- | --- |
| `DeviceIdentityRecord` | `DONE` — CYD identificado (intento `2026-07-21T21:10:57Z`) |
| `BackupRecord` | `DONE` — backup 4 MiB verificado (intento `2026-07-21T21:10:57Z`) |
| Flashing (paso 8) | `DONE` — borrado + 5 regiones verificadas (intento `2026-07-21T22:04:18Z`) |
| Checklist funcional (paso 9) | `PENDING` — pruebas manuales con umbrales |

Sin CYD verificable la Fase B queda `BLOCKED` y SPEC 01 no puede pasar a
`Implemented-Verified`. El paso 8 (`erase_flash`, escritura, reflasheo) se
completó y verificó. El paso 9 (checklist funcional con umbrales observables)
permanece pendiente.

### Registro de intento — Fase B (paso 7)

Los registros de intentos anteriores no se sobrescriben; este se añade al
final del historial.

| Campo | Valor |
| --- | --- |
| `attempt_id` | `spec-01-phase-b-2026-07-21T03:07:29Z` |
| `phase` | `phase-b` |
| `recorded_at` | `2026-07-21T03:07:29Z` |
| `responsible` | Rafastoievsky |
| `coordinator_commit` | `08f68b809dce0e078999b94fbb76ebb5267aefcb` |
| `firmware_commit` | `1594f42ca7573e47ead079d659c1b2c90d8c73ae` |
| `result` | `BLOCKED` |
| `notes` | No hay un CYD verificable conectado durante esta ejecución. No se ejecutó ninguna detección serial, identificación con esptool, lectura de flash, backup, borrado ni flashing. `DeviceIdentityRecord` y `BackupRecord` permanecen `PENDING`. Bloqueo limitado a la Fase B; la Fase A (pasos 1–6) permanece válida e íntegra. SPEC 01 no puede pasar a `Implemented-Verified` mientras persista este bloqueo. Retomar con un CYD conectado desde el paso 7. |

### Registro de intento — Fase B (paso 7, ejecución con CYD)

Se añade al historial; no sobrescribe el intento `BLOCKED` anterior.

| Campo | Valor |
| --- | --- |
| `attempt_id` | `spec-01-phase-b-2026-07-21T21:10:57Z` |
| `phase` | `phase-b` |
| `recorded_at` | `2026-07-21T21:10:57Z` |
| `responsible` | Rafastoievsky |
| `coordinator_commit` | `08c3099363528144ceae74f8f348e9faa8b5219c` |
| `firmware_commit` | `1f29bf30ea9e7d1e09979a5760d47b1e361fdf32` (gitlink del coordinador) |
| `result` | `PASS` (alcance ejecutado: identificación fuerte + backup 4 MiB + escaneo redactado) |
| `notes` | CYD conectado y verificado. Solo se autorizaron operaciones de solo lectura del paso 7: `chip_id`, `flash_id`, identificación de chip/revisión/tamaño y lectura completa de `0x400000` bytes. No se ejecutó `erase_flash`, escritura ni reflasheo (paso 8 pendiente, sin autorización en esta sesión). El backup se examinó con temporales protegidos (`umask 077`, `trap`); no se imprimieron strings. Cero credenciales Claude detectadas; sin `sessionKey` activa que revocar. El paso 9 (checklist funcional) permanece `PENDING` porque requiere el flasheo del baseline limpio. |

#### `DeviceIdentityRecord` (paso 7)

| Campo | Valor |
| --- | --- |
| `authorized_port` | `/dev/cu.usbserial-1120` |
| `usb_vid` | `0x1A86` (QinHeng CH340) |
| `usb_pid` | `0x7523` |
| `usb_serial_hash` | `27d6fbbe5c7d230a` (SHA-256[0:16] de serial USB genérico del CH340) |
| `chip` | `ESP32-D0WD-V3` |
| `chip_revision` | `v3.1` |
| `physical_flash_bytes` | `4194304` |
| `device_id_hash` | `32f1e4a090ce` (SHA-256[0:12] de la MAC) |
| `identity_recheck` | `N/A` — `erase`/`upload`/`uploadfs` no autorizados en esta sesión (paso 8 pendiente) |

Verificación: `esptool.py 4.11.0` reportó `ESP32-D0WD-V3 (revision v3.1)` y
`Detected flash size: 4MB`, cumpliendo las precondiciones de ESP32 y flash
física de `4194304` bytes.

#### `BackupRecord` (paso 7)

| Campo | Valor |
| --- | --- |
| `logical_name` | `spec-01/cyd-prebaseline-4mb.bin` |
| `physical_artifact_id` | `cyd-prebaseline-20260721T210155Z-32f1e4a090ce.bin` |
| `size_bytes` | `4194304` |
| `sha256` | `66e9710bb285805e090585dfec02645b64a72000bad3636fcf3be60f1eca6135` |
| `created_at` | `2026-07-21T21:01:55Z` |
| `tool` | `.venv-tools/bin/esptool 4.11.0` (`read_flash`, 16 × 256 KiB con reintento por chunk @115200) |
| `logical_path` | `<APP_SUPPORT>/AIUsageMeter/backups/spec-01/` (redactada, sin usuario) |
| `encrypted_at_rest` | `YES` (FileVault activo) |
| `directory_mode` | `0700` |
| `file_mode` | `0600` |
| `retention_until` | `2026-08-20T21:10:57Z` |
| `destruction_status` | `PENDING` |
| `destruction_recorded_at` | `N/A` |
| `purpose` | Preservación forense y recuperación excepcional; no rollback normal. |

El SHA-256 coincide byte a byte con una lectura previa del mismo dispositivo
(mismo `device_id_hash`), lo que confirma la integridad de la lectura. La
restauración de este backup requiere autorización separada porque podría
reintroducir credenciales heredadas.

#### Escaneo redactado del backup (solo conteos)

Método: `strings -n 6` sobre el binario en temporal protegido (`umask 077`,
eliminado con `trap`); nunca se imprimieron valores.

| Patrón | Conteo | Clasificación |
| --- | ---: | --- |
| `sk-ant-` (prefijo de clave Claude) | 0 | — |
| `sessionKey` | 0 | — |
| `claudeKey` | 0 | — |
| `apiToken` | 0 | — |
| `config.json` (config persistida) | 0 | Sin configuración de usuario almacenada |
| `ssid`/`passw`/`wifiPass` | 69 | Falsos positivos: cadenas del firmware/portal (etiquetas de formulario, símbolos de la librería WiFi) |
| `Bearer`/`Authorization:` | 2 | Falsos positivos: cadenas del manejador `/mcp` del firmware |

Resultado: cero detecciones reales no resueltas dentro de los métodos y
alcances documentados. No se afirma ausencia absoluta de secretos en datos
binarios. No se encontró credencial Claude activa; no se requirió revocación.

Nota operativa: existe en disco un backup previo fuera de Git con el mismo
SHA-256 (`cyd-prebaseline-20260721T200341Z-32f1e4a090ce.bin`), creado fuera de
banda antes de este registro. No se versiona, no se sobrescribió y queda sujeto
a la misma política de retención.

### Registro de intento — Fase B (paso 8, borrado + flashing + verificación)

Se añade al historial; no sobrescribe intentos anteriores.

| Campo | Valor |
| --- | --- |
| `attempt_id` | `spec-01-phase-b-2026-07-21T22:04:18Z` |
| `phase` | `phase-b` |
| `recorded_at` | `2026-07-21T22:04:18Z` |
| `responsible` | Rafastoievsky |
| `coordinator_commit` | `b32542da8495f34f1b3f2d36b4d08311c7f13ba9` |
| `firmware_commit` | `1594f42ca7573e47ead079d659c1b2c90d8c73ae` (worktree con `platformio.ini` fijado de SPEC 01; el gitlink `1f29bf3` se sincroniza en el paso 10) |
| `result` | `PASS` |
| `notes` | Autorización explícita de escritura otorgada. Identidad revalidada antes y después del `erase_flash`. Borrado completo, flasheo de las 5 regiones por el puerto autorizado a 115200, verificación de escritura por hash on-chip y `verify_flash` de readback independiente en las 5 regiones. Arranque confirmado (`=== SmallTV v1.1.4-clawd-meter ===`, un solo boot, sin loop) y LittleFS montado. No se restauró la imagen cruda. El checklist funcional completo (paso 9) permanece `PENDING`. |

#### Orden de operaciones (evidencia)

Identidad → backup (paso 7) → escaneo/validación → sin revocación necesaria →
`erase_flash` → revalidación de identidad → firmware → LittleFS → reinicio →
baseline. El backup del paso 7 precede a toda escritura.

#### `HardwareTestRecord` — flashing (paso 8)

| id | Procedimiento | Resultado observado | status |
| --- | --- | --- | --- |
| HW-ID-002 | Revalidar identidad antes de `erase` | `ESP32-D0WD-V3 rev v3.1`, MAC hash `32f1e4a090ce`, coincide | `PASS` |
| HW-ERASE-001 | `esptool 4.11.0 --port /dev/cu.usbserial-1120 erase_flash` | Chip erase completado en 5.7 s; exit `0` | `PASS` |
| HW-ID-003 | Revalidar identidad tras `erase` | Coincide; sin cambio de dispositivo | `PASS` |
| HW-FLASH-001 | `write_flash` de 5 regiones (dio/40m/detect) | Todas: «Hash of data verified»; exit `0` | `PASS` |
| HW-VERIFY-001 | `verify_flash` de readback on-chip por región | 5/5 `verify OK` | `PASS` |
| HW-BOOT-002 | Reinicio + serial 115200 | Banner de arranque, un solo boot, sin loop; LittleFS montado | `PASS` |

#### Regiones flasheadas (offsets, tamaños, hashes)

| Región | Offset | Tamaño (bytes) | SHA-256 | write verify | readback `verify_flash` |
| --- | --- | ---: | --- | --- | --- |
| bootloader | `0x1000` | 17536 | `3d234a7471f67b013686dabd4dee7c1fa915c9928463616a94bc9297acf1abf8` | OK | OK |
| partition-table | `0x8000` | 3072 | `aaae2888c5a6a348004b5b436f47abb25ae32e72d9003902955a998eda723edd` | OK | OK |
| boot_app0 (otadata) | `0xe000` | 8192 | `f94c5d786a7a8fab06ac5d10e33bf37711a6697636dc037559ea19cc410a17f0` | OK | OK |
| application | `0x10000` | 1193616 | `7f088f4775cf8ac9a4ac32045a551cfc2fd7e27655111abd745caec89836e9f9` | OK | OK |
| littlefs | `0x310000` | 917504 | `811f0ba31a81b59dd950da140cd92365804fe669e335ccbd38561dca8f53d0ff` | OK | OK |

Tabla de particiones flasheada (huge_app): `nvs` `0x9000`/`0x5000`,
`otadata` `0xe000`/`0x2000`, `app0` `0x10000`/`0x300000`, `spiffs`(LittleFS)
`0x310000`/`0xe0000`, `coredump` `0x3f0000`/`0x10000`.

#### Confirmación de arranque y LittleFS

- Un único reinicio `POWERON_RESET`, `mode:DIO`; sin boot loop.
- Banner de firmware: `=== SmallTV v1.1.4-clawd-meter ===` (`FW_VERSION`
  funcional conservado; no se introdujo versión ficticia).
- LittleFS montado: el acceso a `/littlefs/config.json` resuelve la ruta
  (inexistente por dispositivo recién borrado; sin credenciales previas).
- Los mensajes tempranos «File system is not mounted» / «Font not found» en
  ~375 ms son de la pantalla de splash previa al montaje (comportamiento
  preexistente del firmware), no un defecto de flasheo.
- Contenido del filesystem verificado a partir de la imagen flasheada
  (idéntica en el dispositivo por `verify_flash`): fuentes `DMMono-11/12/14/16`,
  `Jersey25-32/44/64/86` y UI web (`index.html`, `css/`, `js/`).

Limitación técnica registrada: el enlace USB-serial (CH340) es ruidoso a
baudios altos; las lecturas masivas contiguas se corrompen. Se mitigó con
lecturas por chunks (backup) y con verificación por hash on-chip
(`write_flash`/`verify_flash`), que no depende de transferir el contenido por
el enlace.

## Checklist funcional (umbrales cerrados)

| id | Prueba | Umbral | status |
| --- | --- | --- | --- |
| HW-BOOT-001 | Arranque inicial completo | máx. 60 s | `PENDING` |
| HW-STAB-001 | Observación continua | 10 min sin boot loop, watchdog ni reinicio | `PENDING` |
| HW-DISP-001 | Pantalla landscape 320×240, colores, polaridad, backlight | correcto a simple vista | `PENDING` |
| HW-LFS-001 | LittleFS monta; fuentes y web legibles | lectura correcta | `PENDING` |
| HW-WIFI-001 | Portal inicial + Wi-Fi temporal sin imprimir contraseña | conexión exitosa | `PENDING` |
| HW-TOUCH-001 | 10 toques consecutivos | exactamente un avance por toque | `PENDING` |
| HW-ROT-001 | Rotación automática | ±2 s del intervalo configurado | `PENDING` |
| HW-NTP-001 | Reloj tras NTP | desviación máx. 60 s; timeout NTP 60 s | `PENDING` |
| HW-WX-001 | Clima y pronóstico | respuesta en máx. 90 s con conectividad verificada | `PENDING` |
| HW-CLAWD-001 | Blink y look-around | al menos uno de cada uno en 5 min | `PENDING` |
| HW-PERS-001 | Persistencia de configuración permitida tras reinicio | valores conservados | `PENDING` |
| HW-DEG-001 | Arranque sin credenciales Claude; canal Claude sin porcentajes falsos; canales locales operan | comportamiento degradado correcto | `PENDING` |
| HW-HEAP-001 | Heap al arranque y tras 10 min (por serial si Info no lo muestra) | sin caída sostenida | `PENDING` |

Condiciones de red: red temporal o de invitados con aislamiento entre
clientes; prohibida la LAN productiva. Solo configuración nueva permitida;
no se configura `claudeKey`, `sessionKey` ni `apiToken`.

Deuda registrada: `/api/export` y `claudeKey` heredados se documentan como
deuda de SPEC 09–10; no se corrigen en SPEC 01.
