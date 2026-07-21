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
| `DeviceIdentityRecord` | `PENDING` — requiere CYD conectado |
| `BackupRecord` | `PENDING` — requiere CYD conectado |
| Checklist funcional | `PENDING` — requiere CYD conectado |

Sin CYD verificable la Fase B queda `BLOCKED` y SPEC 01 no puede pasar a
`Implemented-Verified`.

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
