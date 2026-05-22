#!/bin/bash
set -e

# ─── Prerequisites check ───
for cmd in lspci sudo pacman; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "[!] Required command '$cmd' not found. Aborting."
        exit 1
    fi
done

# ─── Secure Boot check ───
if [ -d /sys/firmware/efi ] && command -v mokutil &>/dev/null; then
    if mokutil --sb-state 2>/dev/null | grep -qi "enabled"; then
        echo ""
        echo "╔══════════════════════════════════════════════════════════════════╗"
        echo "║  ⚠  Secure Boot está HABILITADO                              ║"
        echo "║                                                               ║"
        echo "║  El driver NVIDIA propietario NO cargará con Secure Boot      ║"
        echo "║  a menos que firmes el módulo del kernel con una MOK.         ║"
        echo "║                                                               ║"
        echo "║  Opciones:                                                    ║"
        echo "║  1) Deshabilitar Secure Boot en la BIOS                       ║"
        echo "║  2) Firmar el módulo con: mokutil --import MOK.der            ║"
        echo "║                                                               ║"
        echo "║  Continuar de todas formas podría resultar en:                ║"
        echo "║  - Pantalla negra al reiniciar                                ║"
        echo "║  - Fallo al cargar el módulo nvidia.ko                        ║"
        echo "╚══════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Presiona Enter para continuar de todas formas, o Ctrl+C para cancelar..."
        read -r
    fi
fi

# ─── 1. Get GPU ID ───
GPU_ID=$(lspci -nn -d 10de: | grep -E "VGA|3D" | head -n1 | grep -oP '(?<=\[10de:)[0-9a-fA-F]{4}(?=\])' || true)

if [[ -z "$GPU_ID" ]]; then
    echo "[*] No se encontró GPU NVIDIA. Omitiendo."
    exit 0
fi

echo "[*] GPU NVIDIA detectada — ID: $GPU_ID"

# ─── 2. Verify chwd ID file exists ───
CHWD_FILE="/var/lib/chwd/ids/nvidia-580.ids"
if [ ! -f "$CHWD_FILE" ]; then
    echo "[!] El archivo $CHWD_FILE no existe."
    echo "    Asegúrate de que CachyOS 'chwd' esté instalado."
    echo "    Ejecuta: sudo pacman -S cachyos-chwd"
    exit 1
fi

# ─── 3. Kill the conflicts ───
echo "[*] Eliminando paquetes conflictivos de driver open-source..."
sudo pacman -Rdd --noconfirm libxnvctrl linux-cachyos-nvidia-open linux-cachyos-lts-nvidia-open nvidia-open-dkms 2>/dev/null || true

# ─── 4. Patch the chwd ID list ───
if ! grep -q "$GPU_ID" "$CHWD_FILE"; then
    echo "[*] Agregando GPU ID $GPU_ID a la lista de chwd para 580xx..."
    if [ -n "$(tail -c1 "$CHWD_FILE")" ]; then
        sudo sh -c "echo >> $CHWD_FILE"
    fi
    sudo sed -i "\$a $GPU_ID" "$CHWD_FILE"
else
    echo "[*] GPU ID $GPU_ID ya está presente en la lista 580xx."
fi

# ─── 5. Remove old chwd profile ───
echo "[*] Eliminando perfil chwd anterior..."
if sudo chwd -r nvidia-open-dkms 2>/dev/null; then
    echo "[*] Perfil nvidia-open-dkms eliminado."
else
    echo "[*] Perfil nvidia-open-dkms no está instalado. Omitiendo remove."
fi

# ─── 5.5. Network/DNS check before chwd/pacman ───
echo "[*] Verificando conectividad y DNS antes de instalar perfil NVIDIA..."
NET_OK=0
for attempt in 1 2 3 4 5; do
    if getent hosts archlinux.org >/dev/null 2>&1; then
        NET_OK=1
        break
    fi

    if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 || ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        NET_OK=1
        break
    fi

    echo "[*] Red no lista aún (intento $attempt/5). Reintentando en 2s..."
    sleep 2
done

if [ "$NET_OK" -ne 1 ]; then
    echo "[*] Intentando recuperar red reiniciando NetworkManager..."
    sudo systemctl restart NetworkManager || true
    sleep 4

    for attempt in 1 2 3; do
        if getent hosts archlinux.org >/dev/null 2>&1; then
            NET_OK=1
            break
        fi

        if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1 || ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
            NET_OK=1
            break
        fi

        echo "[*] Red aún no disponible tras reinicio (intento $attempt/3)."
        sleep 2
    done
fi

if [ "$NET_OK" -ne 1 ]; then
    echo "[!] No se pudo confirmar red/DNS con las sondas rápidas."
    echo "    Se continuará de todas formas y chwd/pacman validará conectividad real."
    echo "    Si falla, revisa: systemctl status NetworkManager iwd wpa_supplicant --no-pager"
fi

# ─── 6. Install new profile ───
echo "[*] Instalando perfil propietario 580xx via chwd..."
if ! sudo chwd -a; then
    echo "[!] chwd -a falló. Revisa los logs en /var/log/chwd/"
    echo "    Posibles causas: GPU no soportada por driver 580xx, o conflicto de dependencias."
    exit 1
fi

# ─── 7. Install VA-API utils ───
echo "[*] Instalando libva-utils..."
sudo pacman -S --needed --noconfirm libva-utils

# ─── 8. Configurar parámetros del kernel GRUB ───
echo "[*] Configurando parámetros del kernel para NVIDIA..."
GRUB_FILE="/etc/default/grub"
KERNEL_PARAMS="nvidia_drm.modeset=1 nvidia_drm.fbdev=1"
if [ -f "$GRUB_FILE" ]; then
    if ! grep -q "nvidia_drm.modeset=1" "$GRUB_FILE"; then
        sudo sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 $KERNEL_PARAMS\"/" "$GRUB_FILE"
        echo "[*] Parámetros del kernel agregados a GRUB. Se regenerará grub.cfg..."
        if command -v grub-mkconfig &>/dev/null; then
            sudo grub-mkconfig -o /boot/grub/grub.cfg
        fi
    else
        echo "[*] Parámetros del kernel ya están configurados."
    fi
else
    echo "[!] $GRUB_FILE no existe. Agrega manualmente: $KERNEL_PARAMS"
fi

# ─── 9. Agregar NVIDIA a los módulos de initramfs ───
echo "[*] Agregando módulos NVIDIA al initramfs..."
MKINITCPIO_FILE="/etc/mkinitcpio.conf"
if [ -f "$MKINITCPIO_FILE" ]; then
    if ! grep -q "nvidia" "$MKINITCPIO_FILE" 2>/dev/null; then
        sudo sed -i 's/^MODULES=([^)]*)/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "$MKINITCPIO_FILE"
        echo "[*] Regenerando initramfs..."
        if command -v mkinitcpio &>/dev/null; then
            sudo mkinitcpio -P
        fi
    else
        echo "[*] Módulos NVIDIA ya están en initramfs."
    fi
fi

# ─── 10. Crear directorio UWSM si no existe ───
UWSM_ENV_DIR="$HOME/.config/uwsm"
mkdir -p "$UWSM_ENV_DIR"

# ─── 11. Add NVIDIA environment variables for UWSM ───
if [ -f "$UWSM_ENV_DIR/env" ] && grep -q "LIBVA_DRIVER_NAME=nvidia" "$UWSM_ENV_DIR/env" 2>/dev/null; then
    echo "[*] Variables de entorno NVIDIA ya están configuradas en UWSM."
else
    echo "[*] Configurando variables de entorno NVIDIA en UWSM..."
    cat >>"$UWSM_ENV_DIR/env" <<'EOF'

# NVIDIA
export LIBVA_DRIVER_NAME=nvidia
export GBM_BACKEND=nvidia-drm
export __GLX_VENDOR_LIBRARY_NAME=nvidia
export NVD_BACKEND=direct
export MOZ_DISABLE_RDD_SANDBOX=1
export CUDA_DISABLE_PERF_BOOST=1
EOF
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║  ✅ NVIDIA 580xx configurado correctamente                     ║"
echo "║                                                               ║"
echo "║  ⚡ Es RECOMENDABLE reiniciar para que los cambios surtan     ║"
echo "║     efecto.                                                   ║"
echo "║                                                               ║"
echo "║  Después de reiniciar, verifica con:                           ║"
echo "║    nvidia-smi                                                  ║"
echo "║    lsmod | grep nvidia                                         ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
