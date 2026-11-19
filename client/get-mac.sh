#!/bin/bash
# Meowcraft one-line setup for Mac. Friends paste this into Terminal:
#   curl -fsSL https://raw.githubusercontent.com/pattyryke/meowcraft/main/client/get-mac.sh | bash
# Files downloaded this way aren't blocked by the Mac's "can't be opened" check.
set -e
mkdir -p "$HOME/.meowcraft"
echo "  =^.^=  Downloading Meowcraft..."
curl -fsSL https://raw.githubusercontent.com/pattyryke/meowcraft/main/client/meowcraft-mac -o "$HOME/.meowcraft/meowcraft"
chmod +x "$HOME/.meowcraft/meowcraft"
"$HOME/.meowcraft/meowcraft" install
