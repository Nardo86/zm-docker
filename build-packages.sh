#!/bin/bash

# Script per compilare i pacchetti ZoneMinder per entrambe le architetture
# Basato sul processo di build utilizzato dall'autore originale

set -e

ZONEMINDER_REPO_PATH=${ZONEMINDER_REPO_PATH:-"/tmp/ZoneMinder"}
ZM_VERSION=${ZM_VERSION:-"1.36.35"}
OUTPUT_DIR=${OUTPUT_DIR:-"$(pwd)"}

echo "=== ZoneMinder Package Builder ==="
echo "Version: $ZM_VERSION"
echo "Output directory: $OUTPUT_DIR"
echo "ZoneMinder repo: $ZONEMINDER_REPO_PATH"

# Clone o aggiorna il repository ZoneMinder
if [ ! -d "$ZONEMINDER_REPO_PATH" ]; then
    echo "Cloning ZoneMinder repository..."
    git clone https://github.com/ZoneMinder/ZoneMinder.git "$ZONEMINDER_REPO_PATH"
else
    echo "Updating ZoneMinder repository..."
    cd "$ZONEMINDER_REPO_PATH"
    git fetch --all
    git checkout master
    git pull
fi

cd "$ZONEMINDER_REPO_PATH"

# Mostra le versioni disponibili
echo "Available tags:"
git tag -l | grep -E '^[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -10

# Checkout della versione specificata
echo "Checking out version $ZM_VERSION..."
git checkout "$ZM_VERSION"

# Pulizia build precedenti
echo "Cleaning previous builds..."
rm -rf build/*

# Build AMD64
echo "=== Building AMD64 package ==="
OS=debian DIST=bullseye utils/packpack/startpackpack.sh

if [ -f build/zoneminder_*_amd64.deb ]; then
    echo "AMD64 build successful"
    cp build/zoneminder_*_amd64.deb "$OUTPUT_DIR/"
else
    echo "AMD64 build failed!"
    exit 1
fi

# Pulizia per ARM64 build
echo "Cleaning for ARM64 build..."
rm -rf build/*

# Build ARM64 (solo se richiesto tramite variabile d'ambiente)
if [ "$BUILD_ARM64" = "true" ]; then
    echo "=== Building ARM64 package ==="
    
    # Verifica se siamo su un sistema che può fare cross-compilation
    if command -v qemu-user-static >/dev/null 2>&1; then
        echo "QEMU detected, proceeding with ARM64 build..."
        OS=debian DIST=bullseye ARCH=aarch64 utils/packpack/startpackpack.sh
        
        if [ -f build/zoneminder_*_arm64.deb ]; then
            echo "ARM64 build successful"
            cp build/zoneminder_*_arm64.deb "$OUTPUT_DIR/"
        else
            echo "ARM64 build failed!"
            exit 1
        fi
    else
        echo "ARM64 build requested but cross-compilation not available"
        echo "Install qemu-user-static or run on ARM64 system"
        exit 1
    fi
else
    echo "ARM64 build skipped (set BUILD_ARM64=true to enable)"
fi

echo "=== Build completed ==="
ls -la "$OUTPUT_DIR"/zoneminder_*.deb