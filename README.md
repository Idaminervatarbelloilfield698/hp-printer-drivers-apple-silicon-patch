# HP Printer Drivers — macOS Compatibility Patch

## The Problem

Apple's official **HewlettPackardPrinterDrivers** package (v10.6, dated Oct 2021) refuses to install on modern Macs due to two artificial restrictions in the installer's `Distribution` file:

1. **Architecture lock** — The installer only declares `x86_64` support, so macOS blocks it on Apple Silicon (M1/M2/M3/M4) Macs entirely.
2. **macOS version cap** — A JavaScript `InstallationCheck()` function rejects any macOS version above 15.0 (Sequoia), throwing a fatal error.

The actual driver binaries inside the package work fine under Rosetta 2. Only the **installer metadata** blocks installation — the drivers themselves are not broken.

## What Was Changed

**Only the `Distribution` file was modified.** No driver binaries, scripts, or payloads were touched.

### Change 1: Allow Apple Silicon

```xml
<!-- ORIGINAL -->
<options hostArchitectures="x86_64"/>

<!-- PATCHED -->
<options hostArchitectures="x86_64,arm64"/>
```

Added `arm64` to the `hostArchitectures` attribute so the installer runs on Apple Silicon Macs.

### Change 2: Remove macOS version cap

```xml
<!-- ORIGINAL -->
function InstallationCheck(prefix) {
    if (system.compareVersions(system.version.ProductVersion, '15.0') > 0) {
        my.result.message = system.localizedStringWithFormat('ERROR_25CBFE41C7', '15.0');
        my.result.type = 'Fatal';
        return false;
    }
    return true;
}

<!-- PATCHED -->
function InstallationCheck(prefix) {
    return true;
}
```

Removed the version check that blocked installation on macOS versions newer than 15.0.

### Verification: Nothing else changed

| Component | Modified? |
|-----------|-----------|
| `Distribution` | Yes (2 changes above) |
| `HewlettPackardPrinterDrivers.pkg/Payload` | No (identical MD5: `e0576d1db286a4878d4e89b7d0f0dbd9`) |
| `HewlettPackardPrinterDrivers.pkg/Bom` | No (identical MD5: `9acc9cd5d19e6c29bfff6dbd4e8f9270`) |
| `HewlettPackardPrinterDrivers.pkg/PackageInfo` | No |
| `HewlettPackardPrinterDrivers.pkg/Scripts` | No (identical contents) |
| `Resources/` (localizations, license) | No |

## How to Reproduce the Patch

```bash
# 1. Mount the original DMG
hdiutil attach HewlettPackardPrinterDrivers.dmg -nobrowse

# 2. Extract the pkg
mkdir hp_pkg && cd hp_pkg
xar -xf /Volumes/HP_PrinterSupportManual/HewlettPackardPrinterDrivers.pkg

# 3. Edit Distribution — make the two changes described above
#    a) Add arm64:  hostArchitectures="x86_64,arm64"
#    b) Remove the version check in InstallationCheck()

# 4. Re-pack into a new pkg
xar -cf ../HewlettPackardPrinterDrivers-patched.pkg *

# 5. Unmount
hdiutil detach /Volumes/HP_PrinterSupportManual

# 6. Install the patched pkg
sudo installer -pkg HewlettPackardPrinterDrivers-patched.pkg -target /
```

## Notes

- The drivers run under **Rosetta 2** on Apple Silicon. Make sure Rosetta is installed (`softwareupdate --install-rosetta`).
- This package includes drivers for many HP printers (LaserJet, OfficeJet, DeskJet, etc.), not just a single model.
- The original DMG is Apple's own distribution from `swscan.apple.com`, package identifier `com.apple.pkg.HewlettPackardPrinterDrivers`.
- **No proprietary binaries are modified or redistributed** — only the installer metadata (Distribution XML) is patched.
