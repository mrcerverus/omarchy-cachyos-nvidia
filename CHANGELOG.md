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

## Contexto del error

Usuario con Lenovo Ideapad Gaming 3 15IMH05, GPU NVIDIA GTX 1650 Ti Mobile (ID 1f95),
instalando omarchy sobre CachyOS. El script nvidia.sh fallaba en:

1. `chwd -r nvidia-open-dkms --noconfirm` — flag inválido
2. `chwd -a` → `pacman -Syu` — todos los mirrors fallaban con
   `Could not resolve host` (problema de DNS, posible conflicto wpa_supplicant/iwd)
