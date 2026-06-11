# Frameworks

This directory contains vendored dynamic libraries bundled with Baud.app.

## libPCBUSB.dylib

PEAK System PCAN-USB macOS library (PCBUSB-Library).

- **Source**: https://github.com/mac-can/PCBUSB-Library
- **License**: Freeware, may be used and distributed freely
- **Version**: v0.13+ (Universal Binary: Intel + Apple Silicon)

### Updating

1. Download the latest release from the GitHub releases page
2. Extract `libPCBUSB.dylib` from the DMG
3. Replace this file
4. Run `./build-app.sh --run` to verify

The library is weak-linked via `dlopen()` — Baud works perfectly without it,
PCAN-USB support is automatically enabled when the library is present.
