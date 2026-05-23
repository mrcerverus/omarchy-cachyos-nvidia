# Changelog

## 2026-05-22

### Fix: `chwd -r` flags incompatibles

- **`bin/nvidia.sh:72`**: `chwd -r` no acepta flags de autoconfiguración.
  Se corrigió a `chwd -r nvidia-open-dkms` para evitar el error
  `the argument '--remove <profile>' cannot be used with '--autoconfigure [<classid>]'.`

### Add: DNS check before `chwd -a`

- **`bin/nvidia.sh:75-89`**: Agregada validación inmediata de conectividad
  (ping 8.8.8.8) y resolución DNS (`getent hosts archlinux.org`) antes de ejecutar
  `chwd -a`/`pacman`, para fallar temprano con mensaje claro si la red está inestable.

### Add: Network/DNS pre-flight check

- **`bin/install-omarchy-on-cachyos.sh:15-31`**: Agregada validación al inicio del
  instalador que verifica conectividad a internet (ping 8.8.8.8) y resolución DNS
  (ping archlinux.org). Incluye mensajes de ayuda para el conflicto
  wpa_supplicant/iwd que causa `Could not resolve host`.

### Fix: remove de perfil NVIDIA idempotente

- **`bin/nvidia.sh:72-76`**: Ajustada la eliminación de perfil anterior para que no
  detenga ni ensucie el flujo cuando `nvidia-open-dkms` no está instalado.

### Improve: chequeo de red en `nvidia.sh` (tolerante)

- **`bin/nvidia.sh:78-121`**: El check previo a `chwd -a` ahora usa reintentos,
  intenta recuperación reiniciando `NetworkManager`, y si las sondas rápidas no
  confirman conectividad continúa de todas formas para que `chwd/pacman` valide
  conectividad real (evita falsos negativos).

### Fix: hardening de `network.sh` inyectado por instalador

- **`bin/install-omarchy-on-cachyos.sh:143-172`**: El parche a
  `install/config/hardware/network.sh` ahora es idempotente (marker
  `OMARCHY_CACHYOS_IWD_FIX`), desactiva `wpa_supplicant`, habilita/inicia `iwd`,
  configura `NetworkManager` con `wifi.backend=iwd`, reinicia NM y espera enlace
  con `nm-online` cuando está disponible.

## Contexto del error

Usuario con Lenovo Ideapad Gaming 3 15IMH05, GPU NVIDIA GTX 1650 Ti Mobile (ID 1f95),
instalando omarchy sobre CachyOS. El script nvidia.sh fallaba en:

1. `chwd -r nvidia-open-dkms --noconfirm` — flag inválido
2. `chwd -a` → `pacman -Syu` — todos los mirrors fallaban con
   `Could not resolve host` (problema de DNS, posible conflicto wpa_supplicant/iwd)

### Improve: hardening completo de `nvidia.sh` para migracion a 580xx

- **`bin/nvidia.sh`**: Se agrega `set -o pipefail` para no ocultar fallos de
  `chwd -a` cuando se captura salida con `tee`.
- **`bin/nvidia.sh`**: Nuevo flujo idempotente de limpieza de conflictos con
  funciones helper:
  `remove_pkg_if_installed`, `cleanup_open_nvidia_stack`,
  `cleanup_proprietary_nvidia_conflicts`, `ensure_kernel_headers_present` y
  `run_chwd_with_retry`.
- **`bin/nvidia.sh`**: Limpieza ampliada de conflictos entre ramas NVIDIA para
  transición 595 → 580xx, incluyendo:
  `nvidia-open-dkms`, `linux-cachyos-nvidia-open`,
  `linux-cachyos-lts-nvidia-open`, `nvidia-utils`, `nvidia-settings`,
  `lib32-nvidia-utils`, `opencl-nvidia`, `lib32-opencl-nvidia`.
- **`bin/nvidia.sh`**: Reintento automático de `chwd -a` cuando detecta
  conflictos como `NVIDIA-MODULE`, `nvidia-libgl`, conflictos OpenCL y mensajes
  `están in conflict/are in conflict`.
- **`bin/nvidia.sh`**: Verificación estricta post-`chwd` para exigir
  `nvidia-580xx-dkms` y `nvidia-580xx-utils` antes de continuar.
- **`bin/nvidia.sh`**: Instalación de `libva-utils` movida para ejecutarse solo
  si el stack NVIDIA propietario quedó instalado correctamente.

### Contexto actualizado del incidente

- El problema inicial de red/DNS quedó superado, pero aparecieron conflictos de
  dependencias al coexistir paquetes NVIDIA de ramas distintas (595 y 580xx).
- Conflictos reportados y cubiertos en el script:
  - `nvidia-580xx-dkms` vs `linux-cachyos-lts-nvidia-open` (`NVIDIA-MODULE`)
  - `nvidia-580xx-utils` vs `nvidia-utils` (`nvidia-libgl`)
  - `lib32-opencl-nvidia-580xx` vs `lib32-opencl-nvidia`
  - `nvidia-580xx-settings` vs `nvidia-settings`
- Objetivo operativo consolidado: mantener ambos kernels (`linux-cachyos` y
  `linux-cachyos-lts`) con un unico stack propietario coherente (580xx DKMS).
