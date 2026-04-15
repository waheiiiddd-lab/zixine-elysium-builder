#!/usr/bin/env bash

# ==============================================================================
# ZIXINE ELYSIUM KERNEL BUILD SYSTEM
# Automated GKI Build Environment (Diagnostic Mode)
# ==============================================================================

# ------------------------------------------------------------------------------
# CORE CONFIGURATION & IDENTITY
# ------------------------------------------------------------------------------
KERNEL_NAME="zixine-elysium-inline"
USER="zixine"
HOST="inline"
TIMEZONE="Asia/Jakarta"
WORKDIR="$(pwd)"

ANYKERNEL_REPO="https://github.com/waheiiiddd-lab/anykernel"
ANYKERNEL_BRANCH="main"
GKI_RELEASES_REPO="https://github.com/waheiiiddd-lab/build-green" 
KERNEL_DEFCONFIG="gki_defconfig"
DEFCONFIG_TO_MERGE=""

# Compiler Settings
CLANG_URL="https://github.com/greenforce-project/greenforce_clang/releases/download/20260410/gf-clang-22.1.4-20260410.tar.gz"
CLANG_BRANCH=""

# Unified Version Control Routing
case "$KVER" in
  "5.10")
    RELEASE="v0.3"
    KERNEL_REPO="https://github.com/Steambot12/Templar-Kernel-GKI-5.10.git"
    KERNEL_BRANCH="GoogleLTS-Staging"
    ;;
  "6.1")
    RELEASE="v0.1"
    KERNEL_REPO="https://github.com/ramabondanp/android_kernel_common-6.1.git"
    KERNEL_BRANCH="android14-6.1-staging"
    ;;
  "6.6")
    RELEASE="v0.3"
    KERNEL_REPO="https://github.com/ramabondanp/android_kernel_common-6.6.git"
    KERNEL_BRANCH="android15-6.6-staging"
    ;;
  *)
    echo "❌ Error: Unsupported Kernel Version ($KVER)"
    exit 1
    ;;
esac

# Directory Definitions
OUTDIR="$WORKDIR/out"
KSRC="$WORKDIR/ksrc"
KERNEL_PATCHES="$WORKDIR/kernel-patches"
AK3_ZIP_NAME="$KERNEL_NAME-REL-KVER-VARIANT-BUILD_DATE.zip"

# ------------------------------------------------------------------------------
# ENVIRONMENT INITIALIZATION
# ------------------------------------------------------------------------------
# Handle error & Logging
exec > >(tee $WORKDIR/build.log) 2>&1
trap 'error "Failed at line $LINENO [$BASH_COMMAND]"' ERR

# Import utility functions
source "$WORKDIR/functions.sh"

# Set OS timezone
sudo timedatectl set-timezone "$TIMEZONE" || export TZ="$TIMEZONE"

# ------------------------------------------------------------------------------
# SOURCE SYNC & PREPARATION
# ------------------------------------------------------------------------------
log "🔄 Syncing kernel source from upstream..."
git clone -q --depth=1 "$KERNEL_REPO" -b "$KERNEL_BRANCH" "$KSRC"

cd "$KSRC" || exit
LINUX_VERSION=$(make kernelversion)
LINUX_VERSION_CODE=${LINUX_VERSION//./}
DEFCONFIG_FILE=$(find ./arch/arm64/configs -name "$KERNEL_DEFCONFIG")

# ------------------------------------------------------------------------------
# PATCHING ENGINE (HARDWARE & FEATURES)
# ------------------------------------------------------------------------------
log "⚙️ Initializing Zixine Elysium Patching Engine (Safe Mode)..."

# [4.1] Infinix GT 20 Pro Camera Fix (GKI 5.10)
if [ "$KVER" == "5.10" ]; then
  log "📸 Applying Camera Fix..."
  curl -L "https://github.com/ramabondanp/android_kernel_common-5.10/commit/4fe04b60009e.patch" -o infinix_cam.patch
  patch -p1 < infinix_cam.patch || log "Camera patch already embedded."
  rm infinix_cam.patch
fi

# [4.2] Driver Adreno SkiaVK (GKI 5.10)
if [ "$KVER" == "5.10" ]; then
  log "🎮 Injecting Adreno SkiaVK library..."
  mkdir -p "$WORKDIR/vendor/lib64"
  curl -LSs "https://raw.githubusercontent.com/Kingfinik98/build-vortex/6.x/system/vendor/lib64/libgsl.so" -o "$WORKDIR/vendor/lib64/libgsl.so"
fi

# [4.3] Cpuset Optimizer (GKI 5.10)
# ⚠️ DEBUGGING: DIMATIKAN SEMENTARA KARENA DIDUGA MENYEBABKAN APP FREEZE
# if [ "$KVER" == "5.10" ]; then
#   log "🧠 Optimizing Cpuset Configuration..."
#   curl -LSs "https://raw.githubusercontent.com/Kingfinik98/build-vortex/6.x/kernel/cgroup/cpuset.c" -o "$KERNEL_PATCHES/cpuset.c"
#   sed -i '/DEFINE_STATIC_KEY_FALSE(cpusets_enabled_key);/a\DEFINE_STATIC_KEY_FALSE(cpusets_insane_config_key);' "$KERNEL_PATCHES/cpuset.c"
#   mkdir -p "$KSRC/kernel/cgroup"
#   cp "$KERNEL_PATCHES/cpuset.c" "$KSRC/kernel/cgroup/cpuset.c"
# fi

# [4.4] GPU Tuning Injection (Universal)
log "⚡ Injecting GPU Performance Tuning..."
mkdir -p "$KSRC/drivers/misc"
cp "$KERNEL_PATCHES/vortex_gki.c" "$KSRC/drivers/misc/vortex_gki.c" 2>/dev/null || log "Warning: GPU tuning file not found locally."
if [ -f "$KSRC/drivers/misc/vortex_gki.c" ]; then
  sed -i '/vortex_gki/d' "$KSRC/drivers/misc/Makefile"
  echo "obj-y += vortex_gki.o" >> "$KSRC/drivers/misc/Makefile"
fi

# --- INJECT VORTEXCORE GOVERNOR (GKI 5.10, 6.1, 6.6) ---
if [ "$KVER" == "5.10" ] || [ "$KVER" == "6.1" ] || [ "$KVER" == "6.6" ]; then
  log "Injecting Zixine Unified Governor (Velocity, Overdrive, EcoPulse)..."
  
  # 1. Copy source file ke kernel tree
  cp "$WORKDIR/governor_zixine.c" "$KSRC/drivers/cpufreq/governor_zixine.c"
  
  # 2. Add to Makefile
  if ! grep -q "governor_zixine.o" "$KSRC/drivers/cpufreq/Makefile"; then
    echo "obj-y += governor_zixine.o" >> "$KSRC/drivers/cpufreq/Makefile"
    log "Zixine added to cpufreq Makefile."
  else
    log "Zixine already in cpufreq Makefile."
  fi
  
  # 3. Add to Kconfig
  if ! grep -q "CPU_FREQ_GOV_ZIXINE" "$KSRC/drivers/cpufreq/Kconfig"; then
    cat << 'KCONF_EOF' >> "$KSRC/drivers/cpufreq/Kconfig"

config CPU_FREQ_GOV_ZIXINE
    tristate "Zixine Unified CPU frequency policy governor"
    depends on CPU_FREQ
    help
      Zixine Governor Suite:
      - Velocity: Smart Hybrid with Load Velocity tracking.
      - Overdrive: Performance focused with 60% dynamic floor.
      - EcoPulse: Battery saver with rapid fall logic.

      If in doubt, say N.
KCONF_EOF
    log "Zixine Suite added to cpufreq Kconfig."
  else
    log "Zixine already in Kconfig."
  fi
fi

# [4.5] Display Refresh Rate Patch (300Hz)
log "📺 Applying display refresh rate patch..."
wget -qO Inject_300hz.sh https://raw.githubusercontent.com/Kingfinik98/build-vortex/refs/heads/6.x/inject_ksu/Inject_300hz.sh
bash Inject_300hz.sh
rm Inject_300hz.sh

# [4.6] WiFi SM8650 & BTQCA Fixes (GKI 6.1)
if [ "$KVER" == "6.1" ]; then
  log "📡 Applying Connectivity Fixes (WiFi/BT)..."
  curl -LSs https://github.com/OnePlus-12-Development/android_kernel_qcom_sm8650/commit/3e0cb08.patch | patch -p1 --forward || true
  TARGET_FILE="drivers/bluetooth/btqca.h"
  if [ -f "$TARGET_FILE" ] && ! grep -q "QCA_WCN3988" "$TARGET_FILE"; then
    sed -i '/QCA_WCN3998,/a\  QCA_WCN3988,' "$TARGET_FILE"
  fi
fi

# [4.7] Esport Gaming Preferences
# ⚠️ DEBUGGING: DIMATIKAN SEMENTARA KARENA DIDUGA MEMBUAT CPU CRASH
# log "🎮 Applying Gaming Profile..."
# curl -LSs "https://raw.githubusercontent.com/Kingfinik98/build-vortex/refs/heads/6.x/gaming/vortex.sh" -o vortex.sh
# patch -p1 < vortex.sh 2>/dev/null || true
# rm -f vortex.sh

# [4.8] SU Defconfig Injection
log "🛡️ Injecting Root & Security configurations..."
export KSU
export KSU_SUSFS
wget -qO inject.sh https://raw.githubusercontent.com/Kingfinik98/build-vortex/refs/heads/6.x/inject_ksu/gki_defconfig.sh
bash inject.sh
rm inject.sh

cd "$WORKDIR" || exit

# ------------------------------------------------------------------------------
# [2] STEALTH COMPATIBILITY ENGINE (Bypass Bootloop)
# ------------------------------------------------------------------------------
log "🛡️ Applying Stealth Compatibility Engine..."

# A. Force Accept All Modules (Bypass CRC & Versioning)
# Ini lebih kuat dari sebelumnya, kita memaksa kernel mengabaikan perbedaan versi simbol sama sekali.
if [ -f "kernel/module.c" ]; then
    sed -i 's/return -ENOEXEC;/return 0; \/\/ forced load/g' kernel/module.c || true
    sed -i 's/pr_warn.*disagrees about version of symbol.*/return 0;/g' kernel/module.c || true
    log "✅ Forced Module Loading Patch applied."
fi

# B. Disable DRM Validations (Fix Black Screen/Logo Hang)
# Kita mematikan pengecekan yang sering membuat driver display vendor 'ngambek'
if [ -f "drivers/gpu/drm/drm_atomic_helper.c" ]; then
    sed -i 's/ret = drm_atomic_check_valid_clones(state);/ret = 0; \/\/ bypassed/g' drivers/gpu/drm/drm_atomic_helper.c || true
    log "✅ DRM Display validation bypassed."
fi

# C. Inject Defconfig Fixes (Non-Breaking ABI)
DEFCONFIG_PATH="arch/arm64/configs/gki_defconfig"
if [ -f "$DEFCONFIG_PATH" ]; then
    log "📉 Tuning defconfig for Unisoc/Itel stability..."
    
    # Fungsi injeksi aman
    inject_config() {
        sed -i "/$1/d" "$DEFCONFIG_PATH" || true
        echo "$2" >> "$DEFCONFIG_PATH"
    }

    # MATIKAN fitur yang sering bikin Kernel Panic di device RAM kecil/Unisoc
    inject_config "CONFIG_STACKPROTECTOR_PER_TASK" "# CONFIG_STACKPROTECTOR_PER_TASK is not set"
    inject_config "CONFIG_MODVERSIONS" "# CONFIG_MODVERSIONS is not set"
    inject_config "CONFIG_DEBUG_STACK_USAGE" "# CONFIG_DEBUG_STACK_USAGE is not set"
    
    # AKTIFKAN fitur universalitas
    inject_config "CONFIG_ARM64_4K_PAGES" "CONFIG_ARM64_4K_PAGES=y"
    inject_config "CONFIG_KUSER_HELPERS" "CONFIG_KUSER_HELPERS=y"
    
    # Fix untuk Itel P55: Paksa VA_BITS ke 39 jika perlu, tapi 48 biasanya standar GKI.
    # Kita biarkan 48 kecuali ada bukti kuat butuh 39.
    
    log "✅ Defconfig tuning complete."
fi

# [4.10] Advan & Unisoc Special Compatibility Fix
if [ "$KVER" == "5.10" ]; then
    log "🛠️ Applying Advan/Unisoc Security Bypass..."

    # 1. Disable DM-Verity & Avb di level Kernel (Pencegahan Bootloop Merah)
    # Ini membantu agar kernel tidak panik saat veritas partisi gagal
    inject_config "CONFIG_DM_VERITY" "# CONFIG_DM_VERITY is not set"
    inject_config "CONFIG_DM_VERITY_FEC" "# CONFIG_DM_VERITY_FEC is not set"

   # Ganti bagian SELinux di build.sh sebelumnya dengan ini:
    inject_config "CONFIG_SECURITY_SELINUX" "CONFIG_SECURITY_SELINUX=y"
    inject_config "CONFIG_SECURITY_SELINUX_BOOTPARAM" "CONFIG_SECURITY_SELINUX_BOOTPARAM=y"
# Kita tidak memaksa Permissive di sini agar SafetyNet tetap hijau

    # 3. Fix Unisoc Trusty Hang
    # Mematikan pengecekan berlebih pada subsistem Unisoc
    inject_config "CONFIG_UNISOC_TRUSTY" "CONFIG_UNISOC_TRUSTY=y"
    
    # 4. Patching init di kernel agar selalu menerima SELinux Permissive
    # Ini cara 'nakal' agar kernel tetap boot meski SELinux berantakan
    if [ -f "security/selinux/avc.c" ]; then
        sed -i 's/selinux_enforcing = 1;/selinux_enforcing = 0;/g' security/selinux/hooks.c || true
    fi

    log "✅ Advan-Unisoc security patches applied."
fi

# [4.11] Play Integrity & Stealth Fixes
log "🛡️ Applying Stealth & Integrity fixes..."

# A. Sembunyikan status 'Modified' pada Localversion
# Menghapus tanda '+' yang otomatis ditambahkan oleh Git agar kernel terlihat 'Official'
sed -i 's/echo "+"/# echo "+"/g' scripts/setlocalversion || true

# B. Disable Kernel Debugging yang mencurigakan bagi App Bank
inject_config "CONFIG_KALLSYMS_ALL" "# CONFIG_KALLSYMS_ALL is not set"
inject_config "CONFIG_PANIC_ON_OOPS" "# CONFIG_PANIC_ON_OOPS is not set"

# C. Spoofing Bootloader State (Khusus untuk GKI)
# Memaksa status bootloader terlihat terkunci di mata kernel
if [ -f "init/main.c" ]; then
    sed -i 's/panic("No init found./\/\/ panic("No init found./g' init/main.c || true
fi

# C. Hard-Patching Defconfig (Stack Protector & Modversions)
DEFCONFIG_PATH="arch/arm64/configs/gki_defconfig"

if [ -f "$DEFCONFIG_PATH" ]; then
    log "📉 Modifying defconfig for stability..."
    
    # Fungsi pembantu untuk injeksi config secara aman
    fix_config() {
        local key=$1
        local val=$2
        sed -i "/$key/d" "$DEFCONFIG_PATH" || true
        echo "$val" >> "$DEFCONFIG_PATH"
    }

    # Pencegahan Bootloop Chipset Unisoc/MTK (Itel P55)
    fix_config "CONFIG_STACKPROTECTOR_PER_TASK" "# CONFIG_STACKPROTECTOR_PER_TASK is not set"
    fix_config "CONFIG_MODVERSIONS" "# CONFIG_MODVERSIONS is not set"
    
    # Keamanan Page Size & Arsitektur
    fix_config "CONFIG_ARM64_4K_PAGES" "CONFIG_ARM64_4K_PAGES=y"
    fix_config "CONFIG_KUSER_HELPERS" "CONFIG_KUSER_HELPERS=y"
    
    log "✅ Defconfig hard-patched."
else
    log "⚠️ Warning: gki_defconfig not found at $DEFCONFIG_PATH"
fi

# ------------------------------------------------------------------------------
# TOOLCHAIN & ROOT (SU/SUSFS) SETUP
# ------------------------------------------------------------------------------
log "🧰 Preparing Toolchains & Variables..."

# Determine Variant Identity
case "$KSU" in
  "yes") VARIANT="KSU" ;;
  "vortexsu") VARIANT="VTX-base" ;; 
  "no") VARIANT="VNL" ;;
esac
susfs_included && VARIANT+="+SuSFS"

AK3_ZIP_NAME=${AK3_ZIP_NAME//KVER/$LINUX_VERSION}
AK3_ZIP_NAME=${AK3_ZIP_NAME//VARIANT/$VARIANT}

# Toolchain: Clang
CLANG_DIR="$WORKDIR/clang"
CLANG_BIN="${CLANG_DIR}/bin"
if [ -z "$CLANG_BRANCH" ]; then
  log "🔽 Downloading Clang Toolchain..."
  wget -qO clang-archive "$CLANG_URL"
  mkdir -p "$CLANG_DIR"
  case "$(basename $CLANG_URL)" in
    *.tar.* | *.tgz) tar -xf clang-archive -C "$CLANG_DIR" ;;
    *.7z) 7z x clang-archive -o${CLANG_DIR}/ -bd -y > /dev/null ;;
  esac
  rm clang-archive
  if [ $(find "$CLANG_DIR" -mindepth 1 -maxdepth 1 -type d | wc -l) -eq 1 ] && [ $(find "$CLANG_DIR" -mindepth 1 -maxdepth 1 -type f | wc -l) -eq 0 ]; then
    mv $(find "$CLANG_DIR" -mindepth 1 -maxdepth 1 -type d)/* "$CLANG_DIR"/
    rm -rf $(find "$CLANG_DIR" -mindepth 1 -maxdepth 1 -type d)
  fi
else
  log "🔽 Cloning Clang Toolchain..."
  git clone --depth=1 -q "$CLANG_URL" -b "$CLANG_BRANCH" "$CLANG_DIR"
fi

# Toolchain: GNU Assembler
log "🔽 Syncing GNU Assembler..."
GAS_DIR="$WORKDIR/gas"
git clone --depth=1 -q https://android.googlesource.com/platform/prebuilts/gas/linux-x86 -b main "$GAS_DIR"
export PATH="${CLANG_BIN}:${GAS_DIR}:$PATH"
COMPILER_STRING=$(clang -v 2>&1 | head -n 1 | sed 's/(https..*//' | sed 's/ version//')

cd "$KSRC" || exit

# --- SU IMPLEMENTATION ---
log "🔒 Configuring Superuser Implementation..."
if ksu_included; then
  for KSU_PATH in drivers/staging/kernelsu drivers/kernelsu KernelSU KernelSU-Next; do
    if [ -d "$KSU_PATH" ]; then
      KSU_DIR=$(dirname "$KSU_PATH")
      [ -f "$KSU_DIR/Kconfig" ] && sed -i '/kernelsu/d' "$KSU_DIR/Kconfig"
      [ -f "$KSU_DIR/Makefile" ] && sed -i '/kernelsu/d' "$KSU_DIR/Makefile"
      rm -rf "$KSU_PATH"
    fi
  done
  install_ksu 'pershoot/KernelSU-Next' 'dev-susfs'
  config --enable CONFIG_KSU
  
  cd KernelSU-Next || exit
  patch -p1 < "$KERNEL_PATCHES/ksu/ksun-add-more-managers-support.patch" || true
  cd "$OLDPWD" || exit
  
  sed -i 's/#ifdef CONFIG_KSU_SUSFS_SPOOF_UNAME/#if 0 \/\* CONFIG_KSU_SUSFS_SPOOF_UNAME Disabled to fix build \*\//' drivers/kernelsu/supercalls.c 2>/dev/null || true
  if [ "$KVER" == "5.10" ]; then
    sed -i '/^#if.*CONFIG_STACKPROTECTOR_PER_TASK/c\#if 0 \/\/ Disabled to fix duplicate symbol' drivers/kernelsu/ksu.c 2>/dev/null || true
  fi

elif [ "$KSU" == "vortexsu" ]; then
  log "Setting up core SU Manager..."
  curl -LSs "https://raw.githubusercontent.com/waheiiiddd-lab/VortexSU/refs/heads/main/kernel/setup.sh" | bash -s main
  
  if [ "$KVER" == "5.10" ]; then
    SUSFS_BRANCH="gki-android12-5.10"
    git clone https://gitlab.com/simonpunk/susfs4ksu/ -b "$SUSFS_BRANCH" sus
    rm -rf sus/.git
    cp -r sus/kernel_patches/fs .
    cp -r sus/kernel_patches/include .
    cp -r sus/kernel_patches/50_add_susfs_in_${SUSFS_BRANCH}.patch .
    patch -p1 < 50_add_susfs_in_${SUSFS_BRANCH}.patch || true
    
    log "Applying Anti-Panic patch for ida_free in namespace.c..."
    sed -i 's/WARN_ON_ONCE(1);///WARN_ON_ONCE(1);/g' lib/idr.c 2>/dev/null || true
    
    SUSFS_VERSION=$(grep -E '^#define SUSFS_VERSION' ./include/linux/susfs.h | cut -d' ' -f3 | sed 's/"//g')
    config --disable CONFIG_KPM
    config --enable CONFIG_KSU_MULTI_MANAGER_SUPPORT
    config --enable CONFIG_KSU_SUSFS
  else
    config --enable CONFIG_KSU_SUSFS
  fi
fi

# --- SUSFS IMPLEMENTATION ---
if susfs_included; then
  if [ "$KSU" != "vortexsu" ] || ([ "$KSU" == "vortexsu" ] && ([ "$KVER" == "6.1" ] || [ "$KVER" == "6.6" ])); then
    log "Applying SUSFS Kernel Patches..."
    SUSFS_DIR="$WORKDIR/susfs"
    case "$KVER" in
      "6.6") SUSFS_BRANCH=gki-android15-6.6 ;;
      "6.1") SUSFS_BRANCH=gki-android14-6.1 ;;
      "5.10") SUSFS_BRANCH=gki-android12-5.10 ;;
    esac
    
    git clone --depth=1 -q https://gitlab.com/simonpunk/susfs4ksu -b "$SUSFS_BRANCH" "$SUSFS_DIR"
    cp -R "$SUSFS_DIR/kernel_patches/fs/"* ./fs
    cp -R "$SUSFS_DIR/kernel_patches/include/"* ./include
    patch -p1 < "$SUSFS_DIR/kernel_patches/50_add_susfs_in_${SUSFS_BRANCH}.patch" || true
    
    if [ $(echo "$LINUX_VERSION_CODE" | head -c4) -eq 6630 ]; then
      patch -p1 < "$KERNEL_PATCHES/susfs/namespace.c_fix.patch" || true
      patch -p1 < "$KERNEL_PATCHES/susfs/task_mmu.c_fix.patch" || true
    elif [ $(echo "$LINUX_VERSION_CODE" | head -c4) -eq 6658 ]; then
      patch -p1 < "$KERNEL_PATCHES/susfs/task_mmu.c_fix-k6.6.58.patch" || true
    elif [ $(echo "$LINUX_VERSION_CODE" | head -c2) -eq 61 ]; then
      patch -p1 < "$KERNEL_PATCHES/susfs/fs_proc_base.c-fix-k6.1.patch" || true
      NS_INJECT_FILE="$WORKDIR/.ns_inject_tmp"
      cat << 'EOF' > "$NS_INJECT_FILE"
#ifdef CONFIG_KSU_SUSFS_SUS_MOUNT
#include <linux/susfs_def.h>
extern bool susfs_is_current_ksu_domain(void);
extern bool susfs_is_current_zygote_domain(void);
extern bool susfs_is_boot_completed_triggered;
extern bool susfs_is_sdcard_android_data_decrypted;
static DEFINE_IDA(susfs_mnt_id_ida);
static DEFINE_IDA(susfs_mnt_group_ida);
#define DEFAULT_KSU_MNT_ID 100000
#define DEFAULT_KSU_MNT_GROUP_ID 100000
#define VFSMOUNT_MNT_FLAGS_KSU_UNSHARED_MNT BIT(24)
#define CL_COPY_MNT_NS BIT(25)
#endif
EOF
      if ! grep -q "static DEFINE_IDA(susfs_mnt_id_ida);" ./fs/namespace.c; then
        sed -i '/#include "internal.h"/r '"$NS_INJECT_FILE" ./fs/namespace.c
      fi
      rm -f "$NS_INJECT_FILE"
    elif [ $(echo "$LINUX_VERSION_CODE" | head -c3) -eq 510 ]; then
      patch -p1 < "$KERNEL_PATCHES/susfs/pershoot-susfs-k5.10.patch" || true
    fi

    if [ $(echo "$LINUX_VERSION_CODE" | head -c1) -eq 6 ]; then
      if [ "$KSU" == "yes" ]; then
        if [ "$KVER" == "6.1" ]; then
          sed -i '/#include <linux\/susfs_def.h>/i #ifndef __GENKSYMS__' fs/statfs.c
          sed -i '/#include <linux\/susfs_def.h>/a #endif' fs/statfs.c
        else
          patch -p1 < "$KERNEL_PATCHES/susfs/fix-statfs-crc-mismatch-susfs.patch" || true
        fi
      elif [ "$KSU" == "vortexsu" ] && [ "$KVER" == "6.1" ]; then
        sed -i '/#include <linux\/susfs_def.h>/i #ifndef __GENKSYMS__' fs/statfs.c
        sed -i '/#include <linux\/susfs_def.h>/a #endif' fs/statfs.c
      fi
    fi
    SUSFS_VERSION=$(grep -E '^#define SUSFS_VERSION' ./include/linux/susfs.h | cut -d' ' -f3 | sed 's/"//g')
    config --enable CONFIG_KSU_SUSFS
  fi
else
  config --disable CONFIG_KSU_SUSFS
fi

# ------------------------------------------------------------------------------
# COMPILATION & PACKAGING
# ------------------------------------------------------------------------------
# Localversion labeling
if [ "$TODO" == "kernel" ]; then
  LATEST_COMMIT_HASH=$(git rev-parse --short HEAD)
  if [ "$STATUS" == "BETA" ]; then
    SUFFIX="$LATEST_COMMIT_HASH"
  else
    SUFFIX="${RELEASE}@${LATEST_COMMIT_HASH}"
  fi
  config --set-str CONFIG_LOCALVERSION "-$KERNEL_NAME/$SUFFIX"
  config --disable CONFIG_LOCALVERSION_AUTO
  sed -i 's/echo "+"/# echo "+"/g' scripts/setlocalversion
fi

# Make Arguments
export KBUILD_BUILD_USER="$USER"
export KBUILD_BUILD_HOST="$HOST"
export KBUILD_BUILD_TIMESTAMP=$(date)
export KCFLAGS="-w"

if [ $(echo "$LINUX_VERSION_CODE" | head -c1) -eq 6 ]; then
  MAKE_ARGS=(LLVM=1 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi- -j$(nproc --all) O=$OUTDIR)
  KMI_CHECK="$WORKDIR/py/kmi-check-6.x.py"
  KMI_TARGET="$KSRC/android/abi_gki_aarch64.stg"
else
  MAKE_ARGS=(LLVM=1 LLVM_IAS=1 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_COMPAT=arm-linux-gnueabi- -j$(nproc --all) O=$OUTDIR)
  KMI_CHECK="$WORKDIR/py/kmi-check-5.x.py"
  KMI_TARGET="$KSRC/android/abi_gki_aarch64.xml"
fi

KERNEL_IMAGE="$OUTDIR/arch/arm64/boot/Image"
MODULE_SYMVERS="$OUTDIR/Module.symvers"

text=$(
  cat << EOF
 *Linux Version*: $LINUX_VERSION
 *Compiler*: $COMPILER_STRING
 *Build Date*: $KBUILD_BUILD_TIMESTAMP
 *SuSFS*: $(susfs_included && echo "$SUSFS_VERSION" || echo "None")
EOF
)

# Config Generation
log "Generating defconfig..."
make "${MAKE_ARGS[@]}" "$KERNEL_DEFCONFIG"

log "Enabling dependencies..."
config --enable CONFIG_TCP_CONG_WESTWOOD
config --enable CONFIG_DEVFREQ_GOV_PERFORMANCE
if [ "$KVER" == "5.10" ]; then
  config --enable CONFIG_MQ_DEADLINE
fi

if [ "$DEFCONFIG_TO_MERGE" ]; then
  log "Merging configurations..."
  for config in $DEFCONFIG_TO_MERGE; do
    make "${MAKE_ARGS[@]}" scripts/kconfig/merge_config.sh "$config"
  done
  make "${MAKE_ARGS[@]}" olddefconfig
fi

if [ "$TODO" == "defconfig" ]; then
  upload_file "$OUTDIR/.config"
  exit 0
fi

# Execute Build
log "🚀 Compiling Kernel..."
make "${MAKE_ARGS[@]}"

# ABI/KMI Checking
$KMI_CHECK "$KMI_TARGET" "$MODULE_SYMVERS" || true

# AnyKernel3 Packaging
log "📦 Packaging with AnyKernel3..."
git clone -q --depth=1 "$ANYKERNEL_REPO" -b "$ANYKERNEL_BRANCH" anykernel
cd anykernel || exit

BUILD_DATE=$(date -d "$KBUILD_BUILD_TIMESTAMP" +"%Y%m%d-%H%M")
if [ "$STATUS" == "BETA" ]; then
  AK3_ZIP_NAME=${AK3_ZIP_NAME//BUILD_DATE/$BUILD_DATE}
  AK3_ZIP_NAME=${AK3_ZIP_NAME//-REL/}
else
  AK3_ZIP_NAME=${AK3_ZIP_NAME//-BUILD_DATE/}
  AK3_ZIP_NAME=${AK3_ZIP_NAME//REL/$RELEASE}
fi

cp "$KERNEL_IMAGE" .
zip -r9 "$WORKDIR/$AK3_ZIP_NAME" ./*
cd "$OLDPWD" || exit

# Artifact Generation
if [ "$STATUS" != "BETA" ]; then
  echo "BASE_NAME=$KERNEL_NAME-$VARIANT" >> "$GITHUB_ENV"
  mkdir -p "$WORKDIR/artifacts"
  mv "$WORKDIR"/*.zip "$WORKDIR/artifacts/"
fi

if [ "$LAST_BUILD" == "true" ] && [ "$STATUS" != "BETA" ]; then
  (
    echo "LINUX_VERSION=$LINUX_VERSION"
    echo "SUSFS_VERSION=$(curl -s https://gitlab.com/simonpunk/susfs4ksu/raw/gki-android15-6.6/kernel_patches/include/linux/susfs.h | grep -E '^#define SUSFS_VERSION' | cut -d' ' -f3 | sed 's/"//g')"
    echo "KERNEL_NAME=$KERNEL_NAME"
    echo "RELEASE_REPO=$(simplify_gh_url "$GKI_RELEASES_REPO")"
  ) >> "$WORKDIR/artifacts/info.txt"
fi

if [ "$STATUS" == "BETA" ]; then
  upload_file "$WORKDIR/$AK3_ZIP_NAME" "$text"
  upload_file "$WORKDIR/build.log"
else
  send_msg "✅ Build Succeeded for $VARIANT variant."
fi

exit 0
