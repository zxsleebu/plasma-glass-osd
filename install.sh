#!/usr/bin/env bash
# Installs plasma-glass-osd for the current user: builds the blur helper,
# assembles an override of the org.kde.plasma.workspace.osd QML module and
# points plasmashell at it through a systemd user drop-in.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
prefix="${XDG_DATA_HOME:-$HOME/.local/share}/plasma-glass-osd"
qml_dir="$prefix/qml"
module_dir="$qml_dir/org/kde/plasma/workspace/osd"
dropin_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/plasma-plasmashell.service.d"
dropin="$dropin_dir/plasma-glass-osd.conf"

die() { echo "error: $*" >&2; exit 1; }

for tool in cmake systemctl; do
    command -v "$tool" >/dev/null || die "$tool is required"
done

# Where the stock OSD module lives
system_qml=""
if command -v qmake6 >/dev/null; then
    system_qml="$(qmake6 -query QT_INSTALL_QML 2>/dev/null || true)"
elif command -v qtpaths6 >/dev/null; then
    system_qml="$(qtpaths6 --query QT_INSTALL_QML 2>/dev/null || true)"
fi
system_qml="${system_qml:-/usr/lib/qt6/qml}"
system_module="$system_qml/org/kde/plasma/workspace/osd"
[ -f "$system_module/qmldir" ] || die "stock OSD module not found in $system_module (is this Plasma 6?)"

echo ":: building the blur helper"
build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT
cmake -S "$here/blur" -B "$build_dir" -DCMAKE_BUILD_TYPE=Release -DOSDBLUR_OUT="$qml_dir" >/dev/null
cmake --build "$build_dir" --parallel >/dev/null

echo ":: installing the OSD module to $module_dir"
mkdir -p "$module_dir"
# The stock qmldir, minus the line that makes Qt prefer the copy compiled
# into the plugin, plus our extra component
version="$(awk '$1 == "Osd" { print $2 }' "$system_module/qmldir")"
[ -n "$version" ] || die "unexpected qmldir format in $system_module"
grep -v -e '^prefer ' -e '^$' "$system_module/qmldir" > "$module_dir/qmldir"
echo "MorphText $version MorphText.qml" >> "$module_dir/qmldir"
# The C++ part of the module stays the system one
for f in "$system_module"/*.so "$system_module"/*.qmltypes; do
    [ -e "$f" ] && ln -sf "$f" "$module_dir/"
done
install -m644 "$here"/qml/*.qml "$module_dir/"

echo ":: pointing plasmashell at it"
mkdir -p "$dropin_dir"
cat > "$dropin" <<EOF
# plasma-glass-osd: run uninstall.sh (or delete this file) to revert
[Service]
Environment=QML_IMPORT_PATH=$qml_dir
EOF
systemctl --user daemon-reload

if systemctl --user is-active --quiet plasma-plasmashell.service; then
    echo ":: restarting plasmashell"
    systemctl --user restart plasma-plasmashell.service
fi

echo ":: done. Try changing the volume or the keyboard layout."
