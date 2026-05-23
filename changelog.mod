# Changelog (mod)

## 2026-05-22

### Harden: migracion automatica de NVIDIA a 580xx DKMS en CachyOS

- **`bin/nvidia.sh`**: Se agrega `set -o pipefail` para que el script no continue
  si `chwd -a` falla cuando se usa pipeline con `tee`.
- **`bin/nvidia.sh`**: Se agregan helpers idempotentes para limpieza de conflictos:
  `remove_pkg_if_installed`, `cleanup_open_nvidia_stack`,
  `cleanup_proprietary_nvidia_conflicts` y `run_chwd_with_retry`.
- **`bin/nvidia.sh`**: Limpieza previa y durante reintento de conflictos de ramas
  NVIDIA (open y propietaria), incluyendo:
  `nvidia-open-dkms`, `linux-cachyos-nvidia-open`,
  `linux-cachyos-lts-nvidia-open`, `nvidia-utils`, `nvidia-settings`,
  `lib32-nvidia-utils`, `opencl-nvidia`, `lib32-opencl-nvidia`.
- **`bin/nvidia.sh`**: Reintento inteligente de `chwd -a` cuando se detectan
  conflictos en logs (`NVIDIA-MODULE`, `nvidia-libgl`, `opencl`,
  `lib32-opencl-nvidia`, `nvidia-580xx-utils`, `nvidia-utils`,
  y mensajes de "están/are in conflict").
- **`bin/nvidia.sh`**: Verificaciones estrictas post-instalacion para exigir
  `nvidia-580xx-dkms` y `nvidia-580xx-utils` antes de continuar.
- **`bin/nvidia.sh`**: `libva-utils` ahora se instala solo tras validar que el
  stack NVIDIA 580xx quedo instalado correctamente.

### Contexto del incidente resuelto

- Error original al conectar notebook por cable evoluciono de DNS inestable a
  conflictos de paquetes al pasar de stack 595 a 580xx.
- Conflictos abordados durante la sesion:
  - `nvidia-580xx-utils` vs `nvidia-utils` (`nvidia-libgl`)
  - `lib32-opencl-nvidia-580xx` vs `lib32-opencl-nvidia`
  - `nvidia-580xx-settings` vs `nvidia-settings`
- Resultado: flujo mas robusto para mantener ambos kernels
  (`linux-cachyos` y `linux-cachyos-lts`) con stack propietario consistente.
