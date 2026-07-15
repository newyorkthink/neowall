# Ubuntu 22.04 AppImage

NeoWall's x86-64 AppImage is built on Ubuntu 22.04 with the repository script:

```bash
sudo apt-get update
sudo apt-get install -y \
  build-essential git pkg-config meson ninja-build curl file binutils \
  desktop-file-utils fuse3 libfuse2 \
  libwayland-dev wayland-protocols libwayland-egl1 \
  libx11-dev libxrandr-dev libegl1-mesa-dev libgl-dev \
  libpng-dev libjpeg-dev

VERSION=0.5.5 packaging/build-appimage-ubuntu22.04.sh
```

The script uses `linuxdeploy` to create the AppDir, explicitly bundles
`libjpeg.so.8`, creates the final file with `appimagetool`, and performs an
extracted-runtime check proving that the bundled JPEG library is selected.

## FUSE3 systems

Current type-2 AppImages use the FUSE2 compatibility library for mounting.
Ubuntu 22.04 can keep FUSE3 installed and add the compatibility library beside
it:

```bash
sudo apt install fuse3 libfuse2
chmod +x neowall-*-ubuntu22.04-x86_64.AppImage
./neowall-*-ubuntu22.04-x86_64.AppImage
```

If FUSE mounting is unavailable (for example inside a restricted container),
use the built-in extract-and-run mode:

```bash
APPIMAGE_EXTRACT_AND_RUN=1 ./neowall-*-ubuntu22.04-x86_64.AppImage
```
