#!/bin/bash
set -euo pipefail

# Build universal (arm64 + x86_64) aria2c and fetch rclone
# Output: Swift2Aria/Resources/Binaries/{aria2c,rclone}
#
# aria2c is built with ZERO homebrew dependencies:
#   - TLS: Apple SecureTransport (--with-appletls)
#   - DNS: built-in resolver (no c-ares)
#   - XML: none needed (JSON-RPC doesn't use it)
#   - zlib: macOS system zlib

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ARIA2_SRC="$(dirname "$PROJECT_DIR")/aria2-release-1.37.0"
OUTPUT_DIR="$PROJECT_DIR/Swift2Aria/Resources/Binaries"
BUILD_DIR="/tmp/aria2mac-build"
RCLONE_VERSION="1.69.1"

mkdir -p "$OUTPUT_DIR" "$BUILD_DIR"

# ============================================================
# aria2c — compile from source as universal binary
# ============================================================

build_aria2_arch() {
    local ARCH=$1
    local PREFIX="$BUILD_DIR/aria2-install-$ARCH"
    local SRC_COPY="$BUILD_DIR/aria2-src-$ARCH"

    echo "==> Building aria2c for $ARCH..."

    # Fresh copy of source
    rm -rf "$SRC_COPY" "$PREFIX"
    cp -R "$ARIA2_SRC" "$SRC_COPY"
    cd "$SRC_COPY"

    # Generate configure
    autoreconf -i 2>&1 | tail -1

    local SDK
    SDK=$(xcrun --sdk macosx --show-sdk-path)

    local HOST
    if [ "$ARCH" = "arm64" ]; then
        HOST="aarch64-apple-darwin"
    else
        HOST="x86_64-apple-darwin"
    fi

    # Pure Apple flags — no homebrew paths
    export CC="clang"
    export CXX="clang++"
    export CFLAGS="-arch $ARCH -isysroot $SDK -mmacosx-version-min=14.0 -O2"
    export CXXFLAGS="-arch $ARCH -isysroot $SDK -mmacosx-version-min=14.0 -O2 -std=c++14"
    export LDFLAGS="-arch $ARCH -isysroot $SDK -framework Security -framework CoreFoundation"
    export PKG_CONFIG_PATH=""
    export PKG_CONFIG_LIBDIR=""

    # Configure with ONLY macOS-native deps
    ./configure \
        --host="$HOST" \
        --prefix="$PREFIX" \
        --enable-static \
        --disable-shared \
        --without-gnutls \
        --without-openssl \
        --with-appletls \
        --without-libgmp \
        --without-libgcrypt \
        --without-libnettle \
        --without-libxml2 \
        --without-libexpat \
        --without-libcares \
        --without-libssh2 \
        --with-libz \
        --disable-nls \
        --disable-websocket \
        ARIA2_STATIC=yes \
        ZLIB_CFLAGS="-I$SDK/usr/include" \
        ZLIB_LIBS="-lz" \
        2>&1 | grep -E "(checking|config.status|Bittorrent|Static|RPC|TLS|DNS)" | tail -10

    echo "==> Compiling..."
    make -j"$(sysctl -n hw.ncpu)" 2>&1 | tail -3
    make install 2>&1 | tail -2

    # Verify
    file "$PREFIX/bin/aria2c"
}

build_aria2() {
    echo ""
    echo "============================================"
    echo "  Building aria2c universal binary"
    echo "============================================"

    if [ -f "$OUTPUT_DIR/aria2c" ]; then
        echo "aria2c already exists in output. Delete to rebuild."
        file "$OUTPUT_DIR/aria2c"
        return
    fi

    build_aria2_arch arm64
    build_aria2_arch x86_64

    echo "==> Creating universal binary with lipo..."
    lipo -create \
        "$BUILD_DIR/aria2-install-arm64/bin/aria2c" \
        "$BUILD_DIR/aria2-install-x86_64/bin/aria2c" \
        -output "$OUTPUT_DIR/aria2c"

    strip "$OUTPUT_DIR/aria2c"
    chmod +x "$OUTPUT_DIR/aria2c"

    echo "==> aria2c universal binary ready:"
    file "$OUTPUT_DIR/aria2c"
    ls -lh "$OUTPUT_DIR/aria2c"

    # Verify no homebrew dylib deps
    echo "==> Dynamic dependencies:"
    otool -L "$OUTPUT_DIR/aria2c" | grep -v "aria2c:" || true
}

# ============================================================
# rclone — download official universal binary
# ============================================================

build_rclone() {
    echo ""
    echo "============================================"
    echo "  Fetching rclone v${RCLONE_VERSION} universal"
    echo "============================================"

    if [ -f "$OUTPUT_DIR/rclone" ]; then
        echo "rclone already exists in output. Delete to rebuild."
        file "$OUTPUT_DIR/rclone"
        return
    fi

    local RCLONE_URL="https://downloads.rclone.org/v${RCLONE_VERSION}/rclone-v${RCLONE_VERSION}-osx-universal.zip"
    local RCLONE_ZIP="$BUILD_DIR/rclone.zip"

    echo "==> Downloading from rclone.org..."
    curl -fSL "$RCLONE_URL" -o "$RCLONE_ZIP"

    echo "==> Extracting..."
    cd "$BUILD_DIR"
    unzip -qo "$RCLONE_ZIP"

    cp "$BUILD_DIR/rclone-v${RCLONE_VERSION}-osx-universal/rclone" "$OUTPUT_DIR/rclone"
    strip "$OUTPUT_DIR/rclone" 2>/dev/null || true
    chmod +x "$OUTPUT_DIR/rclone"

    echo "==> rclone binary ready:"
    file "$OUTPUT_DIR/rclone"
    ls -lh "$OUTPUT_DIR/rclone"
}

# ============================================================
# Main
# ============================================================

echo "Project: $PROJECT_DIR"
echo "Source:  $ARIA2_SRC"
echo "Output:  $OUTPUT_DIR"
echo ""

build_aria2
build_rclone

echo ""
echo "============================================"
echo "  All binaries ready"
echo "============================================"
ls -lh "$OUTPUT_DIR/"
echo ""
echo "Total size:"
du -sh "$OUTPUT_DIR/"
