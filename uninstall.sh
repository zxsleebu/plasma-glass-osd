#!/usr/bin/env bash
# Removes plasma-glass-osd and brings back the stock Plasma OSD
set -euo pipefail

prefix="${XDG_DATA_HOME:-$HOME/.local/share}/plasma-glass-osd"
dropin="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/plasma-plasmashell.service.d/plasma-glass-osd.conf"

rm -f "$dropin"
systemctl --user daemon-reload
rm -rf "$prefix"

if systemctl --user is-active --quiet plasma-plasmashell.service; then
    echo ":: restarting plasmashell"
    systemctl --user restart plasma-plasmashell.service
fi

echo ":: removed, the stock OSD is back"
