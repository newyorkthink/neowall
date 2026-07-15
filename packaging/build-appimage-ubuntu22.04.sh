#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:?Set VERSION to the NeoWall version, for example 0.5.5}"
ARCH="${ARCH:-x86_64}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build-appimage}"
APPDIR="${APPDIR:-$ROOT_DIR/AppDir}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
TOOLS_DIR="${TOOLS_DIR:-$ROOT_DIR/.appimage-tools}"

LINUXDEPLOY_URL="https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
LINUXDEPLOY_SHA256="e87ee0815d109282fdda73e34c2361d64d02b0ffaea3674b18f1fd1f6a687dcf"
APPIMAGETOOL_URL="https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage"
APPIMAGETOOL_SHA256="a6d71e2b6cd66f8e8d16c37ad164658985e0cf5fcaa950c90a482890cb9d13e0"

[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "Invalid VERSION: $VERSION" >&2
    exit 2
}

download_tool() {
    local url="$1"
    local expected_sha256="$2"
    local output="$3"

    if [[ ! -f "$output" ]] || ! echo "$expected_sha256  $output" | sha256sum --check --status; then
        rm -f -- "$output"
        curl --fail --location --retry 3 --output "$output" "$url"
    fi

    echo "$expected_sha256  $output" | sha256sum --check
    chmod +x "$output"
}

for command in awk curl ldd meson ninja readelf sha256sum; do
    command -v "$command" >/dev/null || {
        echo "Missing required command: $command" >&2
        exit 2
    }
done

mkdir -p "$TOOLS_DIR" "$DIST_DIR"
if [[ -n "${LINUXDEPLOY:-}" ]]; then
    LINUXDEPLOY="$(readlink -f -- "$LINUXDEPLOY")"
    test -x "$LINUXDEPLOY"
else
    LINUXDEPLOY="$TOOLS_DIR/linuxdeploy-x86_64.AppImage"
    download_tool "$LINUXDEPLOY_URL" "$LINUXDEPLOY_SHA256" "$LINUXDEPLOY"
fi

if [[ -n "${APPIMAGETOOL:-}" ]]; then
    APPIMAGETOOL="$(readlink -f -- "$APPIMAGETOOL")"
    test -x "$APPIMAGETOOL"
else
    APPIMAGETOOL="$TOOLS_DIR/appimagetool-x86_64.AppImage"
    download_tool "$APPIMAGETOOL_URL" "$APPIMAGETOOL_SHA256" "$APPIMAGETOOL"
fi

rm -rf -- "$BUILD_DIR" "$APPDIR"

meson setup "$BUILD_DIR" "$ROOT_DIR" \
    --prefix=/usr \
    --buildtype=release \
    -Doptimization=2 \
    -Db_lto=true
ninja -C "$BUILD_DIR"
DESTDIR="$APPDIR" ninja -C "$BUILD_DIR" install
"$BUILD_DIR/neowall" --version

jpeg_library="$(ldd "$BUILD_DIR/neowall" | awk '$1 == "libjpeg.so.8" { print $3; exit }')"
if [[ -z "$jpeg_library" || ! -f "$jpeg_library" ]]; then
    echo "The Ubuntu 22.04 build did not resolve libjpeg.so.8" >&2
    ldd "$BUILD_DIR/neowall" >&2
    exit 1
fi

# linuxdeploy normally copies this dependency itself. Install the SONAME
# explicitly as well, because this library is the compatibility guarantee of
# the Ubuntu 22.04 AppImage and must never be omitted by an exclusion update.
install -Dm755 "$(readlink -f -- "$jpeg_library")" "$APPDIR/usr/lib/libjpeg.so.8"
if [[ -r /usr/share/doc/libjpeg-turbo8/copyright ]]; then
    install -Dm644 /usr/share/doc/libjpeg-turbo8/copyright \
        "$APPDIR/usr/share/doc/neowall/third-party/libjpeg-turbo8.copyright"
fi

APPIMAGE_EXTRACT_AND_RUN=1 "$LINUXDEPLOY" \
    --appdir "$APPDIR" \
    --executable "$APPDIR/usr/bin/neowall" \
    --library "$jpeg_library" \
    --desktop-file "$ROOT_DIR/packaging/neowall.desktop" \
    --icon-file "$ROOT_DIR/packaging/neowall.svg" \
    --custom-apprun "$ROOT_DIR/packaging/AppRun"

test -x "$APPDIR/AppRun"
test -x "$APPDIR/usr/bin/neowall"
test -e "$APPDIR/usr/lib/libjpeg.so.8"
readelf -d "$APPDIR/usr/bin/neowall" | grep -q 'Shared library: \[libjpeg.so.8\]'

output="$DIST_DIR/neowall-${VERSION}-ubuntu22.04-${ARCH}.AppImage"
rm -f -- "$output"
ARCH="$ARCH" VERSION="$VERSION" APPIMAGE_EXTRACT_AND_RUN=1 \
    "$APPIMAGETOOL" "$APPDIR" "$output"
chmod +x "$output"

# Exercise the no-FUSE path and then inspect the extracted payload. The
# LD_DEBUG assertion proves that AppRun selects the bundled libjpeg.so.8.
APPIMAGE_EXTRACT_AND_RUN=1 "$output" --version | grep -F "NeoWall v$VERSION"
verify_dir="$(mktemp -d)"
trap 'rm -rf -- "$verify_dir"' EXIT
(
    cd "$verify_dir"
    "$output" --appimage-extract >/dev/null
    test -e squashfs-root/usr/lib/libjpeg.so.8
    LD_LIBRARY_PATH= LD_DEBUG=libs squashfs-root/AppRun --version \
        >version.txt 2>loader.txt
    grep -F "NeoWall v$VERSION" version.txt
    grep -F "squashfs-root/usr/lib/libjpeg.so.8" loader.txt
)

sha256sum "$output"
echo "Created $output"
