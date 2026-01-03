# NSICNSImageRep - ICNS Support for GNUstep

This component provides native support for the ICNS icon format throughout the GNUstep system.

## Features

- Automatic registration with NSImageRep
- Supports multiple icon resolutions (16x16 to 512x512)
- Works in app bundles (`.app/Resources/*.icns`)
- Integrates with NSWorkspace for file icons
- Compatible with standard NSImage APIs

## Dependencies

- libicns (available in FreeBSD ports as `graphics/libicns`, Debian/Ubuntu as `libicns-dev`)
- libicns-dev or development headers with pkg-config support
- GNUstep AppKit

The build system uses `pkg-config` to automatically detect libicns installation paths, making it portable across Linux and BSD systems.

## Installation

The bundle is automatically installed to `/System/Library/Bundles/NSICNSImageRep.bundle` where it will be loaded by AppKit at runtime.

## Usage

Once installed, ICNS files work automatically:

```objective-c
// Load an ICNS file directly
NSImage *icon = [[NSImage alloc] initWithContentsOfFile:@"/path/to/icon.icns"];

// App bundle icons work automatically
NSImage *appIcon = [NSApp applicationIconImage];

// File type icons via NSWorkspace
NSImage *fileIcon = [[NSWorkspace sharedWorkspace] iconForFile:@"document.txt"];
```

## Building

```bash
gmake
sudo -A -E gmake install
```

## Technical Details

The implementation uses libicns to decode ICNS files and creates NSBitmapImageRep instances for each resolution available in the file. AppKit automatically selects the best resolution for the current display context.
