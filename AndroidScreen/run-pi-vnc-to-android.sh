#!/bin/bash
# Fully automated Pi -> Android USB VNC with permission fixes
set -e
set -x

killall adbserver || true
sudo usermod -aG plugdev $USER

# --- Install dependencies ---
if ! command -v adb &> /dev/null; then
    sudo apt update
    sudo apt install -y adb x11vnc
fi

# --- Start VNC server if not already running ---
if ! pgrep -x "x11vnc" > /dev/null; then
    nohup x11vnc -display :0 -nopw -forever -shared > /home/pi/x11vnc.log 2>&1 &
    echo "VNC server started"
fi

# --- Ensure proper udev permissions ---
sudo bash -c 'cat <<EOF >/etc/udev/rules.d/51-android.rules
SUBSYSTEM=="usb", ATTR{idVendor}=="22b8", MODE="0666", GROUP="plugdev"
EOF'
sudo udevadm control --reload-rules
sudo udevadm trigger

# --- Wait for device ---
echo "Waiting for Android device over USB..."
adb wait-for-device

# --- Set up reverse port ---
echo "Setting up adb reverse port 5900 -> 5900..."
sudo adb reverse tcp:5900 tcp:5900

echo "All done! Connect VNC client on Android to localhost:5900"
