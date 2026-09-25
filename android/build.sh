#!/usr/bin/env bash
#
# Build Open-iSCSI for ARM64 Android and package it as a KernelSU module.
#
# Prerequisites:
#   - Android NDK r27 (or newer). Set ANDROID_NDK_HOME/ANDROID_NDK_ROOT
#     or edit NDK below.
#   - curl, tar, make, python3.
#
# Output:
#   OpenISCSIOnAndroid-KernelSU-arm64-v2.1.13.zip
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULE_DIR="$ROOT/module"
BUILD_DIR="$ROOT/build"
API="${ANDROID_API:-26}"
ABI="${ANDROID_ABI:-aarch64-linux-android}"
VERSION="2.1.13"
OPENSSL_VERSION="3.0.15"

NDK="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-/usr/lib/android-ndk}}"
TOOLCHAIN="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
if [ ! -x "$TOOLCHAIN/bin/${ABI}${API}-clang" ]; then
  echo "error: NDK clang not found: $TOOLCHAIN/bin/${ABI}${API}-clang" >&2
  echo "       set ANDROID_NDK_HOME or install the NDK." >&2
  exit 1
fi

export ANDROID_NDK_ROOT="$NDK"
export ANDROID_NDK_HOME="$NDK"
export PATH="$TOOLCHAIN/bin:$PATH"

CC="$TOOLCHAIN/bin/${ABI}${API}-clang"
AR="$TOOLCHAIN/bin/llvm-ar"
RANLIB="$TOOLCHAIN/bin/llvm-ranlib"
STRIP="$TOOLCHAIN/bin/llvm-strip"
SYSROOT="$TOOLCHAIN/sysroot"

OPENSSL_PREFIX="${OPENSSL_PREFIX:-$BUILD_DIR/openssl-install}"
OPENSSL_SRC="$BUILD_DIR/openssl-$OPENSSL_VERSION"

mkdir -p "$BUILD_DIR"

if [ ! -f "$OPENSSL_PREFIX/lib/libcrypto.a" ]; then
  if [ ! -d "$OPENSSL_SRC" ]; then
    echo "==> downloading OpenSSL $OPENSSL_VERSION"
    curl -L --fail --retry 3 \
      -o "$BUILD_DIR/openssl.tar.gz" \
      "https://github.com/openssl/openssl/releases/download/openssl-$OPENSSL_VERSION/openssl-$OPENSSL_VERSION.tar.gz"
    tar -xzf "$BUILD_DIR/openssl.tar.gz" -C "$BUILD_DIR"
  fi
  echo "==> building static libcrypto"
  (cd "$OPENSSL_SRC" && \
    ./Configure android-arm64 "-D__ANDROID_API__=$API" \
      no-shared no-tests no-ui-console \
      --prefix="$OPENSSL_PREFIX" >/dev/null && \
    make -j"$(nproc)" build_sw >/dev/null && \
    make install_sw >/dev/null)
fi

COMMON_MAKE_ARGS=(
  "ANDROID=1"
  "CC=$CC"
  "AR=$AR"
  "RANLIB=$RANLIB"
  "STRIP=$STRIP"
  "ANDROID_CFLAGS=--sysroot=$SYSROOT -isystem $OPENSSL_PREFIX/include -O2 -fPIC -Wno-error"
  "WARNFLAGS=-Wall -Wextra -Wno-error -Wstrict-prototypes -fno-common"
  "LDFLAGS=-Wl,-rpath,/system/lib64"
  "DBROOT=/data/iscsi"
  "HOMEDIR=/data/iscsi"
  "SBINDIR=/system/bin"
  "ISCSI_VERSION_STR=$VERSION"
)

cd "$ROOT"

echo "==> building libopeniscsiusr"
make -C libopeniscsiusr clean >/dev/null 2>&1 || true
make -C libopeniscsiusr -j"$(nproc)" "${COMMON_MAKE_ARGS[@]}"

echo "==> building iscsid/iscsiadm/iscsistart"
make -C usr clean >/dev/null 2>&1 || true
make -C usr -j"$(nproc)" "${COMMON_MAKE_ARGS[@]}" \
  "CRYPTO_LIBS=$OPENSSL_PREFIX/lib/libcrypto.a -ldl -pthread" \
  "ISNS_LIBS=" "MOUNT_LIBS=" "RT_LIBS="

echo "==> building iscsi-iname"
make -C utils clean >/dev/null 2>&1 || true
make -C utils iscsi-iname "CC=$CC" \
  "ANDROID_CFLAGS=--sysroot=$SYSROOT -O2 -fPIC -Wno-error" \
  "IQN_PREFIX=iqn.2016-04.com.open-iscsi"

echo "==> staging module"
rm -rf "$MODULE_DIR/system/bin" "$MODULE_DIR/system/lib64"
mkdir -p "$MODULE_DIR/system/bin" "$MODULE_DIR/system/lib64"

cp usr/iscsid usr/iscsiadm usr/iscsistart utils/iscsi-iname "$MODULE_DIR/system/bin/"
cp libopeniscsiusr/libopeniscsiusr.so.0.2.0 "$MODULE_DIR/system/lib64/"

"$STRIP" --strip-all \
  "$MODULE_DIR/system/bin/iscsid" \
  "$MODULE_DIR/system/bin/iscsiadm" \
  "$MODULE_DIR/system/bin/iscsistart" \
  "$MODULE_DIR/system/bin/iscsi-iname" \
  "$MODULE_DIR/system/lib64/libopeniscsiusr.so.0.2.0"

chmod 0755 "$MODULE_DIR/system/bin/"*
chmod 0644 "$MODULE_DIR/system/lib64/"*
chmod 0755 "$MODULE_DIR/customize.sh" "$MODULE_DIR/post-fs-data.sh" \
  "$MODULE_DIR/service.sh" "$MODULE_DIR/uninstall.sh"

echo "==> packaging"
ZIP_OUT="$ROOT/OpenISCSIOnAndroid-KernelSU-arm64-v$VERSION.zip"
python3 - "$ZIP_OUT" "$MODULE_DIR" <<'PY'
import os, sys, zipfile

out, root = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
    for dirpath, dirnames, filenames in os.walk(root):
        for name in filenames:
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, root)
            zf.write(full, rel)
print("created", out)
PY

echo "==> done: $ZIP_OUT"
