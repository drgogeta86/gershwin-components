# Network Preferences Pane

Network pane that allows you to configure your wired and wireless networks if Network Manager is installed.
We may add other backends in the future. For now Network Manager because it comes with most Linux distributions by default. For FreeBSD we may need a different backend.

## Architecture

The Network preference pane uses a cross-platform architecture with a backend abstraction layer:

```
┌─────────────────────────────────────────────────────────────────┐
│                        NetworkPane                               │
│                    (NSPreferencePane)                            │
└──────────────────────────┬──────────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                     NetworkController                            │
│              (UI logic, table views, dialogs)                    │
│                                                                  │
│  • Service list (left panel)                                     │
│  • Status display                                                │
│  • TCP/IP configuration                                          │
│  • DNS configuration                                             │
│  • WLAN network list and management                             │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           │ NetworkBackend protocol
                           │
┌──────────────────────────▼──────────────────────────────────────┐
│                   Backend Abstraction                            │
│                 (NetworkBackend.h protocol)                      │
└─────────┬───────────────────────────────────────┬───────────────┘
          │                                       │
┌─────────▼─────────┐                   ┌─────────▼─────────┐
│    NMBackend      │                   │  Future Backends  │
│  (NetworkManager) │                   │  (ifconfig, etc)  │
│                   │                   │                   │
│ Uses nmcli for    │                   │ BSD ifconfig      │
│ all operations    │                   │ BSD nm-cli        │
└───────────────────┘                   └───────────────────┘
```

### Files

| File | Description |
|------|-------------|
| `NetworkPane.h/m` | Preference pane entry point, lifecycle management |
| `NetworkController.h/m` | Main UI controller, handles all user interaction |
| `NetworkBackend.h` | Protocol defining the backend interface |
| `NetworkModels.m` | Data model implementations (NetworkInterface, WLAN, etc.) |
| `NMBackend.h/m` | NetworkManager backend using nmcli |
| `NetworkInfo.plist` | Bundle metadata |
| `GNUmakefile` | Build configuration |
| `Network.png` | Preference pane icon (48x48) |

### Data Models

- **NetworkInterface**: Represents a network interface (Ethernet, WLAN, etc.)
- **NetworkConnection**: Represents a saved connection profile
- **WLAN**: Represents a detected WLAN network
- **IPConfiguration**: IPv4/IPv6 configuration settings

### Backend Protocol

The `NetworkBackend` protocol defines the interface for network management backends:

```objc
@protocol NetworkBackend <NSObject>
// Identification
- (NSString *)backendName;
- (BOOL)isAvailable;

// Interface management
- (NSArray *)availableInterfaces;
- (BOOL)enableInterface:(NetworkInterface *)interface;
- (BOOL)disableInterface:(NetworkInterface *)interface;

// Connection management
- (NSArray *)savedConnections;
- (BOOL)activateConnection:(NetworkConnection *)connection onInterface:(NetworkInterface *)interface;
- (BOOL)deactivateConnection:(NetworkConnection *)connection;

// WLAN
- (BOOL)isWLANEnabled;
- (BOOL)setWLANEnabled:(BOOL)enabled;
- (NSArray *)scanForWLANs;
- (BOOL)connectToWLAN:(WLAN *)network withPassword:(NSString *)password;
@end
```

### Adding a New Backend

To add support for a new network management system:

1. Create a new class that conforms to `NetworkBackend` protocol
2. Implement all required methods
3. In `NetworkController.m`, add logic to select the appropriate backend

Example for a FreeBSD ifconfig backend:

```objc
@interface IfconfigBackend : NSObject <NetworkBackend>
// Implementation specific to BSD ifconfig
@end
```

## Usage

The preference pane provides:

1. **Service List**: Shows all network interfaces (Ethernet, WLAN, etc.)
2. **Status Display**: Shows current connection status and IP information
3. **TCP/IP Tab**: Configure IP address, subnet mask, router (DHCP or manual)
4. **DNS Tab**: Configure DNS servers and search domains
5. **WLAN Tab**: Scan for networks, connect with password, enable/disable WLAN

### Keyboard Shortcuts

- **Return**: Connect to selected network / apply changes
- **Escape**: Cancel dialogs

## Building

```bash
cd Network
. /Developer/Makefiles/GNUstep.sh
make
sudo -A make install
```

## Dependencies

- GNUstep (Foundation, AppKit)
- PreferencePanes framework
- NetworkManager (network-manager package) and nmcli
- For direct WiFi management fallback: wpa_supplicant, dhcpcd

## DHCP Configuration

When DHCP is selected for an interface in the Network preferences pane:

1. **Via NetworkManager** (preferred): The pane uses `nmcli` to configure connections with automatic IP configuration
2. **Direct fallback**: If NetworkManager isn't managing the interface, the pane can use `network-helper` to:
   - Configure WiFi authentication via `wpa_cli` 
   - Request DHCP lease via `dhcpcd`

### DHCP Troubleshooting

If you're not getting an IP address via DHCP:

1. Check WiFi authentication status:
   ```bash
   sudo wpa_cli -i wlan0 status
   ```
   You should see `wpa_state=COMPLETED` when properly connected.

2. Manually renew DHCP lease:
   ```bash
   sudo /System/Library/Tools/network-helper dhcp-renew wlan0
   ```

3. For WiFi networks not managed by NetworkManager, use direct connection:
   ```bash
   sudo /System/Library/Tools/network-helper wlan-direct-connect wlan0 "YourSSID" "YourPassword"
   ```

4. Check if NetworkManager is managing your interface:
   ```bash
   nmcli device status
   ```
   If the device shows as "unmanaged", NetworkManager won't handle it.

### Network Helper Commands

The `network-helper` tool provides these commands for privileged network operations:

- `dhcp-renew <interface>` - Renew DHCP lease using dhcpcd
- `dhcp-release <interface>` - Release DHCP lease
- `wlan-direct-connect <interface> <ssid> [password]` - Direct WiFi connection with DHCP
- `wlan-enable` / `wlan-disable` - Control WiFi radio via NetworkManager
- `wlan-connect <ssid> [password]` - Connect via NetworkManager
- `connection-up/down <name>` - Activate/deactivate NetworkManager connections
- `interface-enable/disable <device>` - Enable/disable interfaces via NetworkManager

## License

BSD-2-Clause
