#!/bin/sh

# ==============================================================================
# Universal Android VNC Session Starter
# ------------------------------------------------------------------------------
# Starts a NEW graphical session matching your Android device's resolution
# and forwards it over USB via ADB for a low-latency remote desktop.
# ==============================================================================

set -e

# --- Configuration ---
DISPLAY_NUM=1
VNC_PORT_LOCAL=$((5900 + DISPLAY_NUM))
VNC_PORT_REMOTE=5900 # Standard VNC port for Android clients
LOG_FILE="$HOME/android-vnc.log"
ROTATE=90            # Rotate 90 deg clockwise (swaps width/height)
ATTACH_SIDE="east"   # Side to attach host mouse (north, south, east, west)
AUTO_INSTALL=1       # Set to 1 to allow non-interactive auto-install of packages (DEFAULT ON)

# --- Logger Functions ---
log() {
    printf "[vnc-android] \033[1;32mINFO:\033[0m %s\n" "$*"
}

warn() {
    printf "[vnc-android] \033[1;33mWARN:\033[0m %s\n" "$*"
}

error() {
    printf "[vnc-android] \033[1;31mERROR:\033[0m %s\n" "$*" >&2
}

# --- OS & Distro Detection ---
DETECT_OS() {
    OS="$(uname -s)"
    DISTRO="unknown"
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    fi
}

# --- dependency Check & Guidance ---
CHECK_DEPS() {
    MISSING=""
    if ! command -v adb >/dev/null 2>&1; then MISSING="$MISSING adb"; fi
    
    # Check for x11vnc and Xdummy/Xvfb for high-compatibility virtual sessions
    HAS_X11VNC=0
    if command -v x11vnc >/dev/null 2>&1; then HAS_X11VNC=1; fi
    
    # Check for x2x for mouse/keyboard sharing
    HAS_X2X=0
    if command -v x2x >/dev/null 2>&1; then HAS_X2X=1; fi

    VNC_CMD=""
    if [ $HAS_X11VNC -eq 1 ] && command -v Xdummy >/dev/null 2>&1; then
        VNC_CMD="x11vnc-xdummy"
    elif [ $HAS_X11VNC -eq 1 ] && command -v Xvfb >/dev/null 2>&1; then
        VNC_CMD="x11vnc-xvfb"
    else
        # Fallback to standard vncservers
        for cmd in tigervncserver vncserver tightvncserver vncserver-virtual; do
            if command -v "$cmd" >/dev/null 2>&1; then
                VNC_CMD="$cmd"
                break
            fi
        done
    fi

    if [ -z "$VNC_CMD" ]; then
        MISSING="$MISSING vncserver/x11vnc"; 
    fi

    if [ -n "$MISSING" ]; then
        error "Missing dependencies:$MISSING"
        echo "----------------------------------------------------------"
        case "$DISTRO" in
            debian|devuan|ubuntu|raspbian)
                echo "Please run: sudo apt update && sudo apt install adb x11vnc xserver-xorg-video-dummy xvfb x2x"
                ;;
            arch|artix)
                echo "Please run: sudo pacman -S android-tools x11vnc xf86-video-dummy xorg-server-xvfb x2x"
                ;;
            freebsd)
                echo "Please run: sudo pkg install android-tools x11vnc xorg-server xvfb x2x"
                ;;
            *)
                echo "Please install ADB, x11vnc, x2x and either Xdummy or Xvfb for $DISTRO."
                ;;
        esac
        echo "----------------------------------------------------------"
        exit 1
    fi
    
    if [ $HAS_X2X -eq 0 ]; then
        log "x2x (host mouse/keyboard bridging) not found."
        if [ "$AUTO_INSTALL" = "1" ]; then
            log "Attempting non-interactive install of x2x..."
            if INSTALL_PACKAGE x2x; then
                log "x2x installed successfully."
                HAS_X2X=1
            else
                warn "Automatic install of x2x failed; host input bridging will remain disabled."
            fi
        else
            printf "x2x not found. Install now? [Y/n] "
            read ans || ans="y"
            case "$ans" in
                [Yy]|"")
                    if INSTALL_PACKAGE x2x; then
                        log "x2x installed successfully."
                        HAS_X2X=1
                    else
                        warn "Failed to install x2x; continue without host input bridge."
                    fi
                    ;;
                *)
                    warn "x2x will not be installed; host input bridge disabled."
                    ;;
            esac
        fi
        
    fi
}

# Install packages helper
INSTALL_PACKAGE() {
    pkg="$1"
    case "$DISTRO" in
        debian|devuan|ubuntu|raspbian)
            sudo apt update && sudo apt install -y "$pkg"
            ;;
        arch|artix)
            sudo pacman -S --noconfirm "$pkg"
            ;;
        freebsd)
            sudo pkg install -y "$pkg"
            ;;
        *)
            warn "Don't know how to auto-install on $DISTRO. Please install $pkg manually."
            return 1
            ;;
    esac
}

# --- UDEV SETUP (Linux only) ---
SETUP_PERMISSIONS() {
    if [ "$OS" != "Linux" ]; then
        warn "Non-Linux OS detected. Ensure your user has access to USB serial/HID devices."
        return
    fi

    RULES_FILE="/etc/udev/rules.d/51-android.rules"
    # Overwrite if it doesn't contain a hint of our universal list
    if [ ! -f "$RULES_FILE" ] || ! grep -q "18d1" "$RULES_FILE"; then
        log "Updating Android udev rules with comprehensive Vendor ID list..."
        # Extensive list of Android Vendor IDs
        VENDORS="0502 0b05 0489 1d91 0414 091e 18d1 109b 201e 0bb4 12d1 17ef 1004 22b8 04e8 22d9 19eb 2a70 05c6 04cc 054c 0fce 1bbb 2d95 2717 19d2"
        
        TEMP_RULES=$(mktemp)
        printf '# Universal Android udev rules
' > "$TEMP_RULES"
        for vid in $VENDORS; do
            printf 'SUBSYSTEM=="usb", ATTR{idVendor}=="%s", MODE="0666", GROUP="plugdev"\n' "$vid" >> "$TEMP_RULES"
        done
        
        log "Installing udev rules to $RULES_FILE (requires sudo)..."
        if sudo cp "$TEMP_RULES" "$RULES_FILE"; then
            sudo udevadm control --reload-rules
            sudo udevadm trigger
            log "udev rules successfully installed."
        else
            error "Failed to write udev rules. USB connectivity might fail."
        fi
        rm -f "$TEMP_RULES"
    fi

    # Check group membership
    if getent group plugdev >/dev/null 2>&1; then
        if ! id -nG "$USER" | grep -qw "plugdev"; then
            log "Adding user $USER to the 'plugdev' group..."
            sudo usermod -aG plugdev "$USER"
            warn "NOTE: You must log out and back in for group changes to take effect!"
        fi
    fi
}

# --- ADB Connection ---
INIT_ADB() {
    log "Restarting ADB server to ensure fresh state..."
    sudo adb kill-server >/dev/null 2>&1 || true
    sudo adb start-server >/dev/null 2>&1

    log "Waiting for Android device... (Plug it in and enable USB Debugging now)"
    # Some older adb versions don't have wait-for-usb, so we use wait-for-device
    sudo adb wait-for-device
    
    # Check if authorized
    if sudo adb devices | grep -q "unauthorized"; then
        error "Device unauthorized! Please check your phone screen and allow USB debugging."
        exit 1
    fi
    log "Device connected and authorized."
}

# --- Get Resolution ---
GET_RESOLUTION() {
    log "Querying device screen resolution..."
    # Format typically: "Physical size: 1080x2340"
    RAW_SIZE=$(sudo adb shell wm size 2>/dev/null | head -n1)
    SIZE=$(echo "$RAW_SIZE" | awk '{print $3}' | grep -E '^[0-9]+x[0-9]+$')

    if [ -z "$SIZE" ]; then
        warn "Could not auto-detect resolution from '$RAW_SIZE'. Defaulting to 1280x720."
        SIZE="1280x720"
    else
        log "Detected resolution: $SIZE"
    fi
}

# --- X Session Setup ---
SETUP_XSTARTUP() {
    VNC_DIR="$HOME/.vnc"
    XSTARTUP="$VNC_DIR/xstartup"
    if [ ! -d "$VNC_DIR" ]; then mkdir -p "$VNC_DIR"; fi
    
    # Always regenerate xstartup to ensure correct Gershwin-aware paths
    log "Configuring Gershwin-aware xstartup..."
    # Capture the DISPLAY number into the script
    CURRENT_VNC_DISPLAY=":$DISPLAY_NUM"
    
    cat <<EOF > "$XSTARTUP"
#!/bin/sh
# This session was automatically generated for Android VNC

# Define local logging
log() { echo "[session] INFO: \$*"; }

# Force the VNC display for this session's children
export DISPLAY=$CURRENT_VNC_DISPLAY

# Source GNUstep environment
if [ -f "/System/Library/Makefiles/GNUstep.sh" ]; then
    . /System/Library/Makefiles/GNUstep.sh
fi

# Ensure Gershwin paths are in PATH
export PATH=\$HOME/Library/Tools:/Local/Library/Tools:/System/Library/Tools:/System/Library/CoreServices/Applications/LoginWindow.app:/System/Library/CoreServices/Applications/WindowManager.app:/System/Library/CoreServices/Applications/Workspace.app:/System/Library/CoreServices/Applications/Menu.app:\$PATH

[ -r \$HOME/.Xresources ] && xrdb \$HOME/.Xresources
xsetroot -solid grey

# Debug info
echo "Gershwin VNC Session starting on DISPLAY=\$DISPLAY" > "\$HOME/gershwin-vnc-session.log"

# Function to launch Gershwin components safely on THIS display
launch_gershwin() {
    # WindowManager
    if [ -x "/System/Library/CoreServices/Applications/WindowManager.app/WindowManager" ]; then
        /System/Library/CoreServices/Applications/WindowManager.app/WindowManager --display \$DISPLAY &
    elif command -v WindowManager >/dev/null 2>&1; then
        WindowManager --display \$DISPLAY &
    fi
    
    sleep 2
    
    # Menu
    if [ -x "/System/Library/CoreServices/Applications/Menu.app/Menu" ]; then
        /System/Library/CoreServices/Applications/Menu.app/Menu --display \$DISPLAY &
    elif command -v Menu >/dev/null 2>&1; then
        Menu --display \$DISPLAY &
    fi
    
    sleep 1
    
    # Workspace (the main loop)
    if [ -x "/System/Library/CoreServices/Applications/Workspace.app/Workspace" ]; then
        /System/Library/CoreServices/Applications/Workspace.app/Workspace --display \$DISPLAY
    elif command -v Workspace >/dev/null 2>&1; then
        Workspace --display \$DISPLAY
    else
        xterm -title "Gershwin Fallback"
    fi
}

# 1. Prefer the official Gershwin session script
if [ -f "/System/Library/Scripts/Gershwin.sh" ]; then
    log "Starting Gershwin session..."
    /System/Library/Scripts/Gershwin.sh
# 2. Manual launch
else
    launch_gershwin
fi

# Session keep-alive and debug
log "Session script finished or crashed. Starting fallback terminal..."
if command -v xterm >/dev/null 2>&1; then
    exec xterm -title "Gershwin Session Fallback"
else
    # Keep the X session alive even if everything crashed
    while true; do sleep 3600; done
fi
EOF
    chmod +x "$XSTARTUP"
}

# --- Start VNC Session ---
START_VNC() {
    log "Preparing new VNC session on :$DISPLAY_NUM..."
    
    # Handle Rotation (Swap width and height for 90/270 degrees)
    if [ "$ROTATE" = "90" ] || [ "$ROTATE" = "270" ]; then
        W=$(echo "$SIZE" | cut -d'x' -f1)
        H=$(echo "$SIZE" | cut -d'x' -f2)
        log "Rotating display $ROTATE deg: Swapping resolution to ${H}x${W}"
        SIZE="${H}x${W}"
    fi

    SETUP_XSTARTUP
    
    # Clean up stale locks
    vncserver -kill ":$DISPLAY_NUM" >/dev/null 2>&1 || true
    rm -f "/tmp/.X11-unix/X$DISPLAY_NUM" "/tmp/.X$DISPLAY_NUM-lock" >/dev/null 2>&1 || true

    log "Starting VNC server ($SIZE) using $VNC_CMD..."
    
    case "$VNC_CMD" in
        x11vnc-xdummy)
            # High-compatibility mode using Xorg + dummy driver (BEST FOR GERSHWIN)
            Xdummy ":$DISPLAY_NUM" -geometry "$SIZE" > "$LOG_FILE" 2>&1 &
            # Wait for X
            sleep 3
            # Rotate via xrandr inside the dummy server if needed
            if [ "$ROTATE" = "90" ]; then
                 xrandr -display ":$DISPLAY_NUM" --output dummy0 --rotate right >/dev/null 2>&1 || true
            fi
            # Start session
            "$HOME/.vnc/xstartup" >> "$LOG_FILE" 2>&1 &
            # Start x11vnc to share it
            x11vnc -display ":$DISPLAY_NUM" -nopw -forever -shared -bg >> "$LOG_FILE" 2>&1
            ;;
        x11vnc-xvfb)
            Xvfb ":$DISPLAY_NUM" -screen 0 "${SIZE}x24" > "$LOG_FILE" 2>&1 &
            sleep 3
            "$HOME/.vnc/xstartup" >> "$LOG_FILE" 2>&1 &
            x11vnc -display ":$DISPLAY_NUM" -nopw -forever -shared -bg >> "$LOG_FILE" 2>&1
            ;;
        vncserver-virtual)
            vncserver-virtual ":$DISPLAY_NUM" -geometry "$SIZE" Authentication=None Encryption=AlwaysOff > "$LOG_FILE" 2>&1 &
            ;;
        tigervncserver|vncserver)
            vncserver ":$DISPLAY_NUM" -geometry "$SIZE" -SecurityTypes None -localhost no > "$LOG_FILE" 2>&1 &
            ;;
        *)
            vncserver ":$DISPLAY_NUM" -geometry "$SIZE" > "$LOG_FILE" 2>&1 &
            ;;
    esac

    # Wait for the VNC server to start and open the port
    log "Waiting for VNC server to listen on port $VNC_PORT_LOCAL..."
    RETRIES=0
    while ! ss -tulpn | grep -q ":$VNC_PORT_LOCAL"; do
        sleep 1
        RETRIES=$((RETRIES + 1))
        if [ $RETRIES -gt 15 ]; then
            error "VNC server failed to start or listen on $VNC_PORT_LOCAL within 15s."
            echo "--- LOGS ($LOG_FILE) ---"
            cat "$LOG_FILE"
            exit 1
        fi
    done
    
    log "VNC session started on display :$DISPLAY_NUM"
    
    if [ "$VNC_CMD" = "vncserver-virtual" ]; then
        log "RealVNC started with Authentication=None (Password disabled)."
    fi
}

# --- Bridge to ADB ---
BRIDGE_ADB() {
    log "Setting up ADB reverse bridge: $VNC_PORT_REMOTE -> $VNC_PORT_LOCAL"
    # Port 5900 on Android will be tunneled to our local VNC port
    if ! sudo adb reverse "tcp:$VNC_PORT_REMOTE" "tcp:$VNC_PORT_LOCAL"; then
        error "Failed to setup ADB reverse port."
        exit 1
    fi
}

# --- Bridge Host Input ---
BRIDGE_INPUT() {
    if command -v x2x >/dev/null 2>&1 && [ -n "$DISPLAY" ]; then
        log "Bridging host mouse/keyboard to Android... (Move mouse to $ATTACH_SIDE edge of screen)"
        # x2x allows moving mouse between two displays
        x2x -to ":$DISPLAY_NUM" "-$ATTACH_SIDE" >/dev/null 2>&1 &
        X2X_PID=$!
    fi
}

# --- MAIN ---
DETECT_OS
CHECK_DEPS
SETUP_XSTARTUP   # Move up so it updates even if ADB is waiting
SETUP_PERMISSIONS
INIT_ADB
GET_RESOLUTION
START_VNC
BRIDGE_ADB
BRIDGE_INPUT

echo "                                                          "
echo " \033[1;32m**********************************************************\033[0m"
echo " \033[1;32m* SUCCESS! Android VNC Bridge is ACTIVE                  *\033[0m"
echo " \033[1;32m**********************************************************\033[0m"
echo "                                                          "
echo " \033[1mWHAT TO DO NOW:\033[0m"
echo " 1. Open a VNC Client app on your Android (e.g. RealVNC Viewer)"
echo " 2. Connect to address: \033[1;36mlocalhost:5900\033[0m"
echo " 3. Enjoy your low-latency desktop over USB!"
if [ -n "$X2X_PID" ]; then
echo " 4. Move your mouse to the \033[1;33m$ATTACH_SIDE\033[0m edge of your PC screen to use it on Android."
fi
echo "                                                          "
echo " \033[1mTO STOP:\033[0m"
echo " - Press \033[1mCtrl+C\033[0m to exit this script"
echo " - Or run: \033[1;33mvncserver -kill :$DISPLAY_NUM\033[0m"
echo "                                                          "

# Keep the script running to keep the reverse forward alive? 
# actually 'adb reverse' stays alive until server dies, but let's wait.
# Catch Ctrl+C to clean up
trap "log 'Cleaning up...'; \
      [ -n '$X2X_PID' ] && kill '$X2X_PID' >/dev/null 2>&1 || true; \
      case '$VNC_CMD' in \
          x11vnc*) pkill -f 'Xdummy :$DISPLAY_NUM' || true; pkill -f 'Xvfb :$DISPLAY_NUM' || true; pkill -f 'x11vnc -display :$DISPLAY_NUM' || true ;; \
          vncserver-virtual) vncserver-virtual -kill :$DISPLAY_NUM || true ;; \
          *) vncserver -kill :$DISPLAY_NUM || true ;; \
      esac; \
      rm -f /tmp/.X11-unix/X$DISPLAY_NUM /tmp/.X$DISPLAY_NUM-lock >/dev/null 2>&1; \
      sudo adb reverse --remove tcp:$VNC_PORT_REMOTE >/dev/null 2>&1; \
      exit" INT TERM

log "Bridge is running. Logs: $LOG_FILE"
# Wait indefinitely
while true; do sleep 60; done
