#!/usr/local/bin/bash

# Path to Apps
MENU_APP="/home/user/Developer/repos/gershwin-components/Menu/Menu.app/Menu"
TEXTEDIT_APP="/home/user/Developer/repos/gershwin-textedit/TextEdit.app/TextEdit"
SYSPREF_APP="/home/user/Developer/repos/gershwin-systempreferences/SystemPreferences/SystemPreferences.app/SystemPreferences"
GIMP_APP="/usr/local/bin/gimp"
CHROME_APP="/usr/local/bin/chrome"

# Kill any existing instances
pkill -f "$MENU_APP" || true
pkill -f "TextEdit" || true
pkill -f "SystemPreferences" || true
pkill -i gimp || true
pkill -i chrome || true

LOG_FILE="/home/user/Developer/repos/gershwin-components/Menu/menu_test.log"
rm -f "$LOG_FILE"

echo "Starting Menu.app in the background..."
$MENU_APP > "$LOG_FILE" 2>&1 &
MENU_PID=$!

sleep 2

# --- Test Switching between Chromium and Gimp ---
echo "Launching Chromium..."
$CHROME_APP --no-first-run --no-default-browser-check &
CHROME_PID=$!
sleep 15

echo "Launching GIMP..."
$GIMP_APP &
GIMP_PID=$!
sleep 20

# Interaction: Chrome -> Gimp -> Chrome
echo "Activating Chromium (switch)..."
xdotool search --all --class "chrome" | head -n 1 | xargs -I {} xdotool windowactivate {}
sleep 5

echo "Activating GIMP (switch)..."
xdotool search --all --class "gimp" | head -n 1 | xargs -I {} xdotool windowactivate {}
sleep 5

echo "Verifying switches in logs..."
grep "belongs to application:" "$LOG_FILE"

# Quitting them one by one
echo "Quitting GIMP..."
kill $GIMP_PID
sleep 5
echo "Quitting Chromium..."
kill $CHROME_PID
sleep 5

# --- Test TextEdit ---

echo "Launching TextEdit..."
$TEXTEDIT_APP &
TEXTEDIT_PID=$!

echo "Waiting for TextEdit menus..."
sleep 10

if grep -q "belongs to application: TextEdit" "$LOG_FILE"; then
    echo "SUCCESS: TextEdit menu detected."
else
    echo "FAILURE: TextEdit menu NOT detected."
fi

echo "Quitting TextEdit..."
kill $TEXTEDIT_PID
sleep 5

if grep -A 20 "belongs to application: TextEdit" "$LOG_FILE" | grep -q "clearing menu"; then
    echo "SUCCESS: TextEdit menu was cleared after closing."
else
    echo "FAILURE: TextEdit menu might still be active."
fi

# --- Test SystemPreferences ---
echo "Launching SystemPreferences..."
$SYSPREF_APP &
SYSPREF_PID=$!

echo "Waiting for SystemPreferences menus..."
sleep 10

if grep -q "belongs to application:.*System.*Preferences" "$LOG_FILE"; then
    echo "SUCCESS: SystemPreferences menu detected."
else
    echo "FAILURE: SystemPreferences menu NOT detected."
fi

echo "Quitting SystemPreferences..."
kill $SYSPREF_PID
sleep 5

# Check if it was cleared after the LAST detection of SystemPreferences
if grep -A 50 "belongs to application:.*System.*Preferences" "$LOG_FILE" | grep -q "clearing menu"; then
    echo "SUCCESS: SystemPreferences menu was cleared after closing."
else
    echo "FAILURE: SystemPreferences menu might still be active."
fi

# Final check: No stale menus in the very end of the log
echo "Verifying no stale menus at end of log..."
tail -n 20 "$LOG_FILE" | grep -q "clearing menu" && echo "FINAL SUCCESS: Menu is cleared." || echo "FINAL WARNING: Last operation was not a clear."

# Cleanup
kill $MENU_PID 2>/dev/null
echo "Test finished."

