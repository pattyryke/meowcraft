#!/bin/bash
# Meowcraft one-line setup for Mac. Friends paste this into Terminal:
#   curl -fsSL https://raw.githubusercontent.com/pattyryke/meowcraft/main/meowcraft-tools/get-mac.sh | bash
# Files downloaded this way aren't blocked by the Mac's "can't be opened" check.
set -e
mkdir -p "$HOME/.meowcraft"
echo "  =^.^=  Downloading Meowcraft..."
# The command comes from the "stable" branch (falls back to main until that branch exists)
curl -fsSL https://raw.githubusercontent.com/pattyryke/meowcraft/stable/meowcraft-tools/meowcraft-mac -o "$HOME/.meowcraft/meowcraft" ||
  curl -fsSL https://raw.githubusercontent.com/pattyryke/meowcraft/main/meowcraft-tools/meowcraft-mac -o "$HOME/.meowcraft/meowcraft"
chmod +x "$HOME/.meowcraft/meowcraft"
"$HOME/.meowcraft/meowcraft" install
