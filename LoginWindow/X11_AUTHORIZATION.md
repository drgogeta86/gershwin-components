# X11 Authorization Fix for Gershwin LoginWindow

## Problem
When running a custom login manager, Xorg may be running and the greeter visible, but users cannot start X clients because X11 authorization (Xauthority) is never created.

## Solution
LoginWindow handles X11 authorization through PAM:

### Changes Made

1. **PAM Configuration File**: `LoginWindow-pam.pam`
   - Creates `/etc/pam.d/LoginWindow-pam` during installation
   - Includes `pam_xauth.so` module (required for X11 authorization)
   - Includes `pam_env.so` for environment variable management
   - Optional systemd support with `pam_systemd.so`

2. **Code Updates**: `LoginWindowPAM.m`
   - Changed PAM service from "system" to "LoginWindow-pam"
   - Added `PAM_XDISPLAY` setting before opening sessions
   - This tells pam_xauth which display to create authorization for
   - Applied to both normal login and auto-login code paths

3. **Build System**: `GNUmakefile`
   - Installs PAM configuration to `/etc/pam.d/LoginWindow-pam`
   - Sets proper permissions (644) for the PAM file

## How It Works

When a user logs in:

1. LoginWindow calls `pam_start("LoginWindow-pam", ...)`
2. PAM reads `/etc/pam.d/LoginWindow-pam`
3. LoginWindow sets `PAM_XDISPLAY` to current DISPLAY value
4. LoginWindow calls `pam_open_session()`
5. `pam_xauth.so` automatically:
   - Generates MIT-MAGIC-COOKIE
   - Creates `~/.Xauthority` with proper ownership
   - Adds authorization for the specified display
   - Sets `XAUTHORITY` environment variable

## Verification

After installing and running the updated LoginWindow:

```bash
# Check that PAM config exists
ls -l /etc/pam.d/LoginWindow-pam

# After login, verify Xauthority was created
ls -l ~/.Xauthority
xauth list
```

You should see entries like:
```
hostname/unix:0  MIT-MAGIC-COOKIE-1  <hex-string>
```

## Requirements

- `pam_xauth.so` must be available on the system
  - Usually in package: `libpam-modules` (Debian/Ubuntu) or `pam` (FreeBSD)
- DISPLAY environment variable must be set when LoginWindow runs
- Xorg must be running with `-auth` support (default)

## Troubleshooting

If X clients still cannot connect:

1. Check PAM logs: `journalctl -t LoginWindow-pam` or `/var/log/auth.log`
2. Verify DISPLAY is set: Check LoginWindow logs for "PAM_XDISPLAY"
3. Test manually:
   ```bash
   xauth generate :0 . trusted
   xterm  # Should work
   ```
4. Ensure `pam_xauth.so` is installed and in PAM module path

## References

- PAM xauth module: `man pam_xauth`
- X11 authorization: `man xauth`
- PAM configuration: `man pam.conf`
