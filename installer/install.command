#!/bin/bash
# Meowcraft client installer for Mac - double-click me
cd "$(dirname "$0")"
xattr -dr com.apple.quarantine . 2>/dev/null
osascript -l JavaScript ./install-mac.js "$(pwd)"
echo
read -n 1 -s -r -p "Press any key to close this window..."
