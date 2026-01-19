# Menu Status Items

This directory contains status item bundles for the Menu application.

## Available Status Items

### SystemMonitor.bundle
Displays real-time CPU and RAM usage in the menu bar.
- Format: "CPU XX% RAM YY%"
- Updates every second
- Click to see detailed per-core CPU breakdown
- Cross-platform: Linux (proc filesystem) and BSD (sysctl)

### TimeDisplay.bundle
Shows current time with interactive date display.
- Format: "HH:MM" (24-hour)
- Updates every second
- Click to see full date (e.g., "Sunday, January 19, 2026")
- Date display automatically reverts to time after 5 seconds

## Building

From the Menu directory:
```bash
./build-all.sh
```

Or build individual bundles:
```bash
cd StatusItems/SystemMonitor && make
cd StatusItems/TimeDisplay && make
```

## Installing

Bundles are automatically installed to `/System/Library/Menu/StatusItems/` when running:
```bash
make install
```

## Creating New Status Items

1. Create a new directory in `StatusItems/`
2. Implement the `StatusItemProvider` protocol (see `../StatusItemProvider.h`)
3. Create `GNUmakefile` and `Info.plist`
4. Build and install

See `../STATUS_ITEM_ARCHITECTURE.md` for detailed documentation.

## Architecture

Status items are loadable bundles that:
- Conform to the `StatusItemProvider` protocol
- Are discovered and loaded at Menu startup
- Run in the Menu process (not separate processes)
- Update on configurable timers
- Can provide menus or handle clicks

## Files Structure

```
StatusItems/
├── SystemMonitor/
│   ├── GNUmakefile
│   ├── Info.plist
│   ├── SystemMonitorProvider.h
│   ├── SystemMonitorProvider.m
│   └── SystemMonitor.bundle/ (built)
└── TimeDisplay/
    ├── GNUmakefile
    ├── Info.plist
    ├── TimeDisplayProvider.h
    ├── TimeDisplayProvider.m
    └── TimeDisplay.bundle/ (built)
```
