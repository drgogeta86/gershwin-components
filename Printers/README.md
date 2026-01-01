# Printers

GNUstep preference pane for managing printers using CUPS (Common UNIX Printing System).

## Features

### Printer Management
- List all configured printers with status information
- Add new printers with device discovery
- Remove existing printers
- Set default printer
- Enable/disable printers
- View printer options and configuration

### Print Queue Management  
- View active print jobs
- Cancel print jobs
- Hold/release print jobs
- Job status monitoring

### Device Discovery
- Automatic discovery of USB printers
- Network printer discovery (IPP, LPD, AppSocket)
- Support for IPP Everywhere (driverless printing)

## Requirements

- CUPS (Common UNIX Printing System) installed and running
- libcups development headers for building
- GNUstep with PreferencePanes framework
- User must be in the `lpadmin` group for printer administration

### Installing Dependencies

On Debian/Ubuntu:
```bash
sudo apt install cups libcups2-dev
```

On Fedora/RHEL:
```bash
sudo dnf install cups-devel
```

### Granting Printer Administration Privileges

To allow your user to manage printers without root privileges, add yourself to the `lpadmin` group:

```bash
sudo usermod -a -G lpadmin $USER
```

Then log out and log back in for the group membership to take effect. You can verify with:

```bash
groups | grep lpadmin
```

## Building

```bash
. /Developer/Makefiles/GNUstep.sh
make
```

## Installation

```bash
sudo -A make install
```

This installs the preference pane to `/System/Library/Bundles/Printers.prefPane`.

## Uninstallation

```bash
sudo -A make uninstall
```

## Technical Details

This preference pane uses libcups directly for all printer operations:

### CUPS API Functions Used

- `cupsGetDests` - List printers and classes
- `cupsRemoveDest` - Remove printers
- `cupsSetDefaultDest` - Set default printer
- `cupsGetJobs` - List print jobs
- `cupsCancelJob2` - Cancel jobs
- `cupsGetDevices` - Discover printers

### IPP Operations

- `IPP_RESUME_PRINTER` / `IPP_PAUSE_PRINTER` - Enable/disable printers
- `IPP_HOLD_JOB` / `IPP_RELEASE_JOB` - Hold/release jobs
- `IPP_OP_CUPS_ADD_MODIFY_PRINTER` - Add new printers

## Troubleshooting

### CUPS Not Available
If the preference pane shows "Printer configuration is not available", ensure:
1. CUPS is installed: `apt install cups`
2. CUPS service is running: `systemctl start cups`
3. Your user has access to CUPS

### Cannot Add/Remove Printers
Adding and removing printers requires administrative privileges. To enable these
operations:

1. **Recommended:** Add your user to the `lpadmin` group:
   ```bash
   sudo usermod -a -G lpadmin $USER
   ```
   Then log out and log back in.

2. CUPS is configured by default (in `/etc/cups/cups-files.conf`) to allow
   members of the `lpadmin` group to perform all administrative operations
   without requiring root privileges.

**Note:** Unlike executables, preference pane bundles cannot be made suid root
because they are dynamically loaded libraries. The `lpadmin` group is the
standard CUPS mechanism for delegating printer administration privileges.

### Printers Not Discovered
- Ensure printers are powered on and connected
- For network printers, verify network connectivity
- USB printers may require appropriate udev rules

## License

BSD-2-Clause

Copyright (c) 2025 Simon Peter
