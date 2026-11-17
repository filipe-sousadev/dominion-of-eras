#!/bin/sh
# Builds the Linux version into export/linux and an Arch Linux package into export/arch.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$(dirname "$HERE")"
GODOT="${GODOT:-$HOME/.config/craft-anything/engines/godot/Godot_v4.4.1-stable_linux.x86_64}"
mkdir -p "$HERE/linux"
"$GODOT" --headless --path "$APP" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$APP" --export-pack "Linux" "$HERE/linux/dominion-of-eras.pck" >/dev/null 2>&1
# The Godot runtime loads the .pck that has the same name as the program.
cp "$GODOT" "$HERE/linux/dominion-of-eras.x86_64"
chmod +x "$HERE/linux/dominion-of-eras.x86_64"
cp "$APP/icon.png" "$HERE/linux/dominion-of-eras.png"
cat > "$HERE/linux/run.sh" <<'RUN'
#!/bin/sh
cd "$(dirname "$0")" && exec ./dominion-of-eras.x86_64 "$@"
RUN
chmod +x "$HERE/linux/run.sh"
if command -v makepkg >/dev/null 2>&1; then
  cd "$HERE/arch" && makepkg -f --nodeps
fi
echo "Linux build ready in $HERE/linux"
