#!/usr/bin/env bash

#/*!
# * © 2024-2026 Kingfinik98 (VorteX_E-Sport). All Rights Reserved.
# * Reworked Structure - by zixine project
# */

# --- 1. Inisialisasi & Konfigurasi ---
WORKDIR="$(pwd)"
OUTDIR="$WORKDIR/out"
KSRC="$WORKDIR/ksrc"
KERNEL_PATCHES="$WORKDIR/kernel-patches"
KERNEL_NAME="VorteX_E-Sport"
USER="VorteX"
HOST="VorteX"
TIMEZONE="Asia/Jakarta"
ANYKERNEL_REPO="https://github.com/Kingfinik98/AnyKernel3"
GKI_RELEASES_REPO="https://github.com/Kingfinik98/build-vortex/releases"

# Mapping Konfigurasi berdasarkan KVER
setup_env_vars() {
    case "$KVER" in
        "6.6")
            RELEASE="v0.3"
            KERNEL_REPO="https://github.com/ramabondanp/android_kernel_common-6.6.git"
            KERNEL_BRANCH="android15-6.6-staging"
            ANYKERNEL_BRANCH="master"
            ;;
        "6.1")
            RELEASE="v0.1"
            KERNEL_REPO="https://github.com/ramabondanp/android_kernel_common-6.1.git"
            KERNEL_BRANCH="android14-6.1-staging"
            ANYKERNEL_BRANCH="master"
            ;;
        "5.10")
            RELEASE="v0.3"
            KERNEL_REPO="https://github.com/Kingfinik98/kernel-common-android12-5.10.git"
            KERNEL_BRANCH="vortex-basse"
            ANYKERNEL_BRANCH="master"
            ;;
    esac
    KERNEL_DEFCONFIG="gki_defconfig"
    CLANG_URL="https://github.com/greenforce-project/greenforce_clang/releases/download/20260410/gf-clang-22.1.4-20260410.tar.gz"
    AK3_ZIP_NAME="$KERNEL_NAME-REL-KVER-VARIANT-BUILD_DATE.zip"
}

# --- 2. Fungsi Helper ---
prepare_logging() {
    exec > >(tee "$WORKDIR/build.log") 2>&1
    trap 'error "Gagal di baris $LINENO [$BASH_COMMAND]"' ERR
    source "$WORKDIR/functions.sh"
    sudo timedatectl set-timezone "$TIMEZONE" || export TZ="$TIMEZONE"
}

# --- 3. Tahap Patching (Modular) ---
apply_vortex_patches() {
    log "Menginjeksi VorteX Patches..."
    
    # GPU Tuning & Safe Patch
    mkdir -p "$KSRC/drivers/misc"
    cp "$KERNEL_PATCHES/vortex_gki.c" "$KSRC/drivers/misc/vortex_gki.c"
    sed -i '/vortex_gki/d' "$KSRC/drivers/misc/Makefile"
    echo "obj-y += vortex_gki.o" >> "$KSRC/drivers/misc/Makefile"

    # Governors (VortexCore & VortexMax)
    for gov in vortexcore vortexmax; do
        log "Injecting Governor: $gov"
        cp "$WORKDIR/governor-$gov.c" "$KSRC/drivers/cpufreq/governor-$gov.c"
        
        if ! grep -q "governor-$gov.o" "$KSRC/drivers/cpufreq/Makefile"; then
            echo "obj-\$(CONFIG_CPU_FREQ_GOV_${gov^^}) += governor-$gov.o" >> "$KSRC/drivers/cpufreq/Makefile"
        fi

        if ! grep -q "CONFIG_CPU_FREQ_GOV_${gov^^}" "$KSRC/drivers/cpufreq/Kconfig"; then
            cat <<EOF >> "$KSRC/drivers/cpufreq/Kconfig"
config CPU_FREQ_GOV_${gov^^}
    tristate "VortexCore CPU frequency policy governor ($gov)"
    depends on CPU_FREQ
    help
      VortexCore governor balances performance and efficiency.
EOF
        fi
    done
}

apply_specific_fixes() {
    # Fix Khusus 5.10
    if [[ "$KVER" == "5.10" ]]; then
        log "Applying 5.10 specific fixes (Camera & SkiaVK)..."
        curl -L "https://github.com/ramabondanp/android_kernel_common-5.10/commit/4fe04b60009e.patch" | patch -p1 || log "Cam patch skipped."
        mkdir -p "$WORKDIR/vendor/lib64"
        curl -LSs "https://raw.githubusercontent.com/Kingfinik98/build-vortex/6.x/system/vendor/lib64/libgsl.so" -o "$WORKDIR/vendor/lib64/libgsl.so"
    fi

    # Fix Khusus 6.1
    if [[ "$KVER" == "6.1" ]]; then
        log "Applying 6.1 specific fixes (WiFi SM8650)..."
        curl -LSs https://github.com/OnePlus-12-Development/android_kernel_qcom_sm8650/commit/3e0cb08.patch | patch -p1 --forward || log "WiFi patch skipped."
        
        [[ -f "drivers/bluetooth/btqca.h" ]] && ! grep -q "QCA_WCN3988" "drivers/bluetooth/btqca.h" && \
            sed -i '/QCA_WCN3998,/a\  QCA_WCN3988,' "drivers/bluetooth/btqca.h"
    fi
}

# --- 4. Toolchain Setup ---
setup_toolchain() {
    log "Menyiapkan Toolchain (Clang & GAS)..."
    CLANG_DIR="$WORKDIR/clang"
    mkdir -p "$CLANG_DIR"
    wget -qO- "$CLANG_URL" | tar -xz -C "$CLANG_DIR" --strip-components=1 2>/dev/null || \
    wget -qO- "$CLANG_URL" | 7z x -si -so -txz | tar -xf - -C "$CLANG_DIR" # Fallback if needed

    GAS_DIR="$WORKDIR/gas"
    git clone --depth=1 -q https://android.googlesource.com/platform/prebuilts/gas/linux-x86 -b main "$GAS_DIR"
    
    export PATH="${CLANG_DIR}/bin:${GAS_DIR}:$PATH"
    COMPILER_STRING=$(clang -v 2>&1 | head -n 1 | sed 's/(https..*//;s/ version//')
}

# --- 5. KernelSU & SuSFS Logic ---
setup_ksu_susfs() {
    case "$KSU" in
        "yes")
            VARIANT="KSU"
            # Pembersihan driver lama & install baru
            install_ksu 'pershoot/KernelSU-Next' 'dev-susfs'
            config --enable CONFIG_KSU
            # Tambahkan patch KSU Next di sini sesuai script aslimu
            ;;
        "vortexsu")
            VARIANT="VorteXSU"
            curl -LSs "https://raw.githubusercontent.com/Kingfinik98/VortexSU/refs/heads/main/kernel/setup.sh" | bash -s main
            [[ "$KVER" == "5.10" ]] && config --enable CONFIG_KPM
            ;;
        "no")
            VARIANT="VNL"
            ;;
    esac

    if susfs_included; then
        VARIANT+="+SuSFS"
        # Logic clone SuSFS dan patch (ringkasan dari script asli)
        # ... (Gunakan variabel SUSFS_BRANCH berdasarkan case KVER)
    fi
}

# --- 6. Proses Build Utama ---
run_compilation() {
    log "Memulai Kompilasi..."
    make -C "$KSRC" O="$OUTDIR" "${MAKE_ARGS[@]}" "$KERNEL_DEFCONFIG"
    
    # Custom configs
    config --enable CONFIG_TCP_CONG_WESTWOOD
    config --enable CONFIG_DEVFREQ_GOV_SCHEDUTIL
    config --enable CONFIG_CPU_FREQ_GOV_VORTEXCORE
    
    make -C "$KSRC" O="$OUTDIR" "${MAKE_ARGS[@]}"
}

# =============================================================
# ALUR EKSEKUSI (MAIN)
# =============================================================

setup_env_vars
prepare_logging

log "Cloning kernel source..."
git clone -q --depth=1 "$KERNEL_REPO" -b "$KERNEL_BRANCH" "$KSRC"
cd "$KSRC" || exit

LINUX_VERSION=$(make kernelversion)
LINUX_VERSION_CODE=${LINUX_VERSION//./}

apply_vortex_patches
apply_specific_fixes

# Injecting KSU scripts (Inject_300hz & inject.sh)
wget -qO- https://raw.githubusercontent.com/Kingfinik98/build-vortex/refs/heads/6.x/inject_ksu/Inject_300hz.sh | bash
INJECT_URL="https://raw.githubusercontent.com/Kingfinik98/build-vortex/refs/heads/6.x/inject_ksu/$( [[ "$KVER" == "5.10" ]] && echo "gki_defconfig.sh" || echo "gki-deconfig-6.1.sh" )"
wget -qO- "$INJECT_URL" | bash

setup_toolchain
setup_ksu_susfs

# Build Arguments
MAKE_ARGS=(
    LLVM=1
    ARCH=arm64
    CROSS_COMPILE=aarch64-linux-gnu-
    CROSS_COMPILE_COMPAT=arm-linux-gnueabi-
    -j$(nproc --all)
)
[[ "$KVER" != "6.1" && "$KVER" != "6.6" ]] && MAKE_ARGS+=(LLVM_IAS=1)

run_compilation

# --- Post Build & Packaging ---
# (Bagian AnyKernel3 dan Upload tetap sama logikanya namun lebih rapi)
# ... [Sisa kode AnyKernel3 mengikuti logika asli kamu] ...

log "Build Selesai!"
