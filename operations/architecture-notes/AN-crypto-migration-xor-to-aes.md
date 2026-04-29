# Architecture Note — Migración encriptación XOR (fw0a) → AES-256-GCM (fw1a)

date: 2026-04-29
owner_agent: Privacy Guardian
referenced_risk: R13
status: PLAN — pendiente de aprobación para sprint dedicado

## Contexto

`crypto.rs` soporta dos algoritmos:
- `fw0a` XOR (legacy, ofuscación trivial; key derivation determinística
  desde `app_data_dir`)
- `fw1a` AES-256-GCM (actual, pero la passphrase también es
  determinística desde `app_data_dir`)

`decrypt_any` rutea entre ambos. Datos antiguos siguen descifrables con
XOR aunque los nuevos vayan en AES.

Esto choca con la narrativa "privacidad verificable por diseño":
- XOR no es encriptación, es ofuscación
- la passphrase derivada de `app_data_dir.to_string_lossy()` no es secreto
  (cualquiera con acceso al binario y al sistema operativo puede derivarla)

## Riesgo (R13)

Cualquier release público con datos de usuario reales tiene una promesa
de privacidad que no se sostiene contra atacante con acceso al fichero
de la base de datos.

## Plan

### Fase 1 — Re-cifrado de datos existentes (XOR → AES)

1. Migración SQLCipher al arranque que detecta registros con magic `fw0a`
   en columnas `url` y `title`.
2. Por cada registro detectado: `decrypt(xor)` → `encrypt_aes` → UPDATE.
3. La migración es idempotente (registros `fw1a` se ignoran).
4. Test obligatorio: tabla con 1000 registros mixtos, post-migración no
   queda ningún `fw0a`, todos descifran correctamente.

### Fase 2 — Key management real (no determinismo)

Reemplazar `format!("fw-{}", app_data_dir)` por:

1. **Desktop:** keychain del OS (Windows Credential Manager / macOS
   Keychain / libsecret). En primer arranque se genera passphrase
   aleatoria de 32 bytes; se guarda en keychain; se deriva clave por
   PBKDF2-SHA256 con 600_000 iteraciones y salt persistente en disco.
2. **Android:** Android Keystore + EncryptedSharedPreferences.
3. Migración de datos existentes: re-cifrado en una sola pasada al
   detectar que la passphrase actual es la determinística antigua.

### Fase 3 — Eliminar XOR del código

1. Borrar `encrypt`, `decrypt`, `derive_key_xor`, `MAGIC_XOR` y la rama
   correspondiente de `decrypt_any`.
2. Borrar tests de XOR.
3. Verificar que ninguna base de datos en disco tiene `fw0a` antes de
   permitir el deploy de la versión sin XOR.

## Constraints

- D1: la privacidad es Nivel 1 (verificable). Esta migración hace que la
  promesa sea cumplible.
- D8: sin LLM. Sin cambios.
- migración debe ser irreversible solo cuando Fase 3 se ejecute. Hasta
  Fase 2 los datos pueden re-cifrarse en cualquier dirección si hace falta
  rollback.

## Criterio de cierre del sprint

1. `cargo test crypto` cubre los tres algoritmos: roundtrip XOR (legacy
   read-only), roundtrip AES, migración XOR→AES.
2. Demo en máquina nueva: primer arranque crea passphrase aleatoria, no
   determinística.
3. Auditoría confirma que no quedan registros `fw0a` en bases de datos
   migradas.
4. Privacy Dashboard muestra "encriptación: AES-256-GCM con key del
   keychain del sistema" en lugar de la cadena actual.

## Anti-objetivos

- no introducir crypto custom (rust-crypto auditado únicamente)
- no almacenar la passphrase en texto plano en disco
- no permitir downgrade automático a XOR
- no romper la galería móvil (la migración Android es paralela e
  independiente del desktop)
