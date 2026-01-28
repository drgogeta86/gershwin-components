# Use Android device as a "screen"

This directory contains scripts to use an Android device connected via USB as a high-performance, low-latency display for your computer.

## Scripts

### `run-vnc-to-android-universal.sh`
A polished, POSIX-compliant script that:
1.  **Auto-detects Resolution**: Queries your Android device and sets up a new VNC session with matching dimensions.
2.  **High Compatibility**: Works on FreeBSD, Debian, Devuan, Arch, and Artix.
3.  **ADB Reverse Bridge**: Tunnels the VNC port over USB for the best possible performance (no WiFi required).
4.  **Universal USB Support**: Automatically installs udev rules for hundreds of Android devices.
5.  **Gershwin Ready**: Automatically sources the GNUstep environment and launches the Gershwin desktop session.

### `run-pi-vnc-to-android.sh`
The original Raspberry Pi specific script for sharing the primary display (:0).

## Requirements
- `adb` (Android Debug Bridge)
- `vncserver` (TigerVNC, TightVNC, or RealVNC)
- `x2x` (optional) — lets you share your host mouse & keyboard with the Android session. The script will attempt to auto-install `x2x` if it is missing (the variable `AUTO_INSTALL=1` is the default). To prevent automatic installs set `AUTO_INSTALL=0` at the top of the script or export it in your environment before running the script.
- A VNC Viewer app on the Android device (e.g., RealVNC Viewer, bVNC)

## Usage
1. Enable **USB Debugging** on your Android device.
2. Connect it via USB.
3. Run the universal script:
   ```sh
   ./run-vnc-to-android-universal.sh
   ```

   Tip: The script can install `x2x` for you interactively. To allow non-interactive installs (useful for automation), set `AUTO_INSTALL=1` at the top of the script or export it in your environment.

4. On the Android device, connect to `localhost:5900` in your VNC app.

## Troubleshooting

### LoginWindow on Host Screen
The `LoginWindow` application currently hardcodes its display to `:0` in its source code. As a result, if a session is started via `LoginWindow`, it will appear on the hardware monitor of the computer rather than the Android screen.

**Workaround**: The universal script is configured to launch `Gershwin.sh` or the Workspace directly, bypassing `LoginWindow` to ensure the session stays on the remote display.

### Gershwin Window Manager Crash
If the Gershwin session crashes or closes immediately after connecting, it is likely due to the virtual X server (like `Xvnc`) lacking support for modern X11 extensions like **RANDR**.

**Solution**: The universal script now prioritizes `x11vnc` combined with `Xdummy` (via `xserver-xorg-video-dummy`). This provides a full Xorg-compatible environment with excellent extension support. Ensure these are installed:
- Debian/Devuan: `sudo apt install x11vnc xserver-xorg-video-dummy`
- Arch: `sudo pacman -S x11vnc xf86-video-dummy`

### Input Bridge & Rotation
- Host input: When `x2x` is available the script will bridge your host mouse and keyboard to the Android session. Move your mouse to the configured edge of your monitor (default: **east**, i.e., right edge) to jump into the phone's display; the keyboard focus follows the pointer.
- Rotation: The script can rotate the virtual display (use `ROTATE=0|90|180|270` at the top of the script). For 90° and 270° rotation the script swaps the width/height when creating the framebuffer and attempts to set rotation via `xrandr` inside the virtual X server.

Notes:
- Automatic installation of `x2x` is enabled by default (`AUTO_INSTALL=1`). You can turn this off by setting `AUTO_INSTALL=0` prior to running the script or by editing the variable at the top of the script.
- If rotation via `xrandr` fails on your system, try updating your Xorg dummy driver or run the script without rotation and rotate the phone physically instead.
### udev permissions
On Linux, if the script fails to see your device, ensure your user is in the `plugdev` group and you have re-logged since the script installed the rules.

