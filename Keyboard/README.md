# Keyboard Preference Pane

This preference pane lets you select an XKB layout and optional variant using two side-by-side list views. Changes apply instantly with `setxkbmap`, saves your choice to user defaults, and writes a small autostart helper so the layout is restored when you log in again. If `sudo -E -A` is available it also attempts to update `/etc/default/keyboard` for system-wide persistence.

## Notes

- Layout and variant data are parsed from `/usr/share/X11/xkb/rules/base.lst` or `/usr/local/share/X11/xkb/rules/base.lst` (e.g., for FreeBSD); a small fallback list is used if neither file is found.
- User-level persistence lives in `~/.local/bin/gershwin-apply-keyboard.sh`.F
- System-wide persistence uses `/etc/default/keyboard` and requires `sudo -E -A`.
