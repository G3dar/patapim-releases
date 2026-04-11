#!/usr/bin/env bash
# PATAPIM Installer for macOS
# Usage: curl -fsSL https://raw.githubusercontent.com/G3dar/patapim-releases/main/install-mac.sh | bash
set -euo pipefail

echo ""
echo "  ____   _  _____  _   ____ ___ __  __ "
echo " |  _ \\ / \\|_   _|/ \\ |  _ \\_ _|  \\/  |"
echo " | |_) / _ \\ | | / _ \\| |_) | || |\\/| |"
echo " |  __/ ___ \\| |/ ___ \\  __/| || |  | |"
echo " |_| /_/   \\_\\_/_/   \\_\\_| |___|_|  |_|"
echo ""
echo "  Project Management IDE for Claude Code"
echo ""

INFO_URL="https://patapim.ai/api/download/info"
INSTALL_DIR="/Applications"

# ---- Detect architecture ----
ARCH=$(uname -m)
if [ "$ARCH" = "arm64" ]; then
  DOWNLOAD_URL="https://patapim.ai/api/download/latest-mac-arm64"
  ARCH_LABEL="Apple Silicon (arm64)"
elif [ "$ARCH" = "x86_64" ]; then
  DOWNLOAD_URL="https://patapim.ai/api/download/latest-mac-x64"
  ARCH_LABEL="Intel (x86_64)"
else
  echo "  Error: Unsupported architecture: $ARCH" >&2
  exit 1
fi

# ---- Step 1: Fetch release info ----
echo "  Fetching latest release..."
INFO=$(curl -fsSL "$INFO_URL" 2>/dev/null) || {
  echo "  Error: Could not fetch release info." >&2
  echo "  Check your internet connection and try again." >&2
  exit 1
}

# Prefer macVersion (set by mac release), fall back to version
VERSION=$(echo "$INFO" | grep -o '"macVersion":"[^"]*"' | cut -d'"' -f4)
if [ -z "$VERSION" ]; then
  VERSION=$(echo "$INFO" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
fi
echo "  Found version: v${VERSION}"
echo "  Architecture:  ${ARCH_LABEL}"
echo ""

# ---- Step 2: Download DMG ----
TEMP_DMG=$(mktemp /tmp/PATAPIM-XXXXX.dmg)
echo "  Downloading PATAPIM v${VERSION} for ${ARCH_LABEL}..."
curl -fSL --progress-bar "$DOWNLOAD_URL" -o "$TEMP_DMG" || {
  echo "  Error: Download failed." >&2
  rm -f "$TEMP_DMG"
  exit 1
}
echo "  Download complete."

# ---- Step 3: Close running PATAPIM ----
if pgrep -x "PATAPIM" >/dev/null 2>&1; then
  echo "  Closing running PATAPIM..."
  osascript -e 'quit app "PATAPIM"' 2>/dev/null || true
  sleep 2
  # Force kill if still running
  pkill -x "PATAPIM" 2>/dev/null || true
  sleep 1
fi

# ---- Step 4: Mount DMG and copy app ----
echo "  Installing to /Applications..."
MOUNT_DIR=$(hdiutil attach "$TEMP_DMG" -nobrowse -quiet -mountrandom /tmp 2>/dev/null | tail -1 | awk '{print $NF}')

if [ -z "$MOUNT_DIR" ] || [ ! -d "$MOUNT_DIR" ]; then
  # Fallback: try to find the mount point
  MOUNT_DIR=$(hdiutil attach "$TEMP_DMG" -nobrowse -quiet 2>/dev/null | grep "/Volumes" | awk -F'\t' '{print $NF}' | xargs)
fi

if [ -z "$MOUNT_DIR" ] || [ ! -d "$MOUNT_DIR" ]; then
  echo "  Error: Failed to mount DMG." >&2
  rm -f "$TEMP_DMG"
  exit 1
fi

APP_PATH=$(find "$MOUNT_DIR" -maxdepth 1 -name "*.app" -print -quit)

if [ -z "$APP_PATH" ]; then
  echo "  Error: No .app found in DMG." >&2
  hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
  rm -f "$TEMP_DMG"
  exit 1
fi

APP_NAME=$(basename "$APP_PATH")

# Remove old version if exists
if [ -d "${INSTALL_DIR}/${APP_NAME}" ]; then
  rm -rf "${INSTALL_DIR}/${APP_NAME}"
fi

cp -R "$APP_PATH" "$INSTALL_DIR/"

# ---- Step 5: Cleanup ----
hdiutil detach "$MOUNT_DIR" -quiet 2>/dev/null || true
rm -f "$TEMP_DMG"

# ---- Step 6: Remove quarantine attribute ----
xattr -rd com.apple.quarantine "${INSTALL_DIR}/${APP_NAME}" 2>/dev/null || true

# ---- Step 7: Register MCP servers ----
MCP_SERVER="${INSTALL_DIR}/${APP_NAME}/Contents/Resources/app/src/mcp/patapim-browser-server.js"

if [ -f "$MCP_SERVER" ]; then
  echo "  Registering MCP server in AI coding tools..."

  # Claude Code: ~/.claude.json
  CLAUDE_CONFIG="$HOME/.claude.json"
  if command -v claude >/dev/null 2>&1 || [ -f "$CLAUDE_CONFIG" ]; then
    if [ ! -f "$CLAUDE_CONFIG" ]; then
      echo '{"mcpServers":{}}' > "$CLAUDE_CONFIG"
    fi
    # Use node if available, otherwise python3, otherwise skip
    if command -v node >/dev/null 2>&1; then
      node -e "
        const fs = require('fs');
        const cfg = JSON.parse(fs.readFileSync('$CLAUDE_CONFIG', 'utf8'));
        if (!cfg.mcpServers) cfg.mcpServers = {};
        cfg.mcpServers['patapim-browser'] = { type: 'stdio', command: 'node', args: ['$MCP_SERVER'] };
        delete cfg.mcpServers['frame-browser'];
        fs.writeFileSync('$CLAUDE_CONFIG', JSON.stringify(cfg, null, 2));
      " 2>/dev/null && echo "    Claude Code: registered" || echo "    Claude Code: registration failed"
    else
      echo "    Claude Code: skipped (node not found)"
    fi
  else
    echo "    Claude Code: not installed, skipped"
  fi

  # Gemini CLI: ~/.gemini/settings.json
  GEMINI_DIR="$HOME/.gemini"
  if [ -d "$GEMINI_DIR" ]; then
    GEMINI_CONFIG="$GEMINI_DIR/settings.json"
    if command -v node >/dev/null 2>&1; then
      [ ! -f "$GEMINI_CONFIG" ] && echo '{}' > "$GEMINI_CONFIG"
      node -e "
        const fs = require('fs');
        const cfg = JSON.parse(fs.readFileSync('$GEMINI_CONFIG', 'utf8'));
        if (!cfg.mcpServers) cfg.mcpServers = {};
        cfg.mcpServers['patapim-browser'] = { command: 'node', args: ['$MCP_SERVER'] };
        fs.writeFileSync('$GEMINI_CONFIG', JSON.stringify(cfg, null, 2));
      " 2>/dev/null && echo "    Gemini CLI: registered" || echo "    Gemini CLI: registration failed"
    fi
  else
    echo "    Gemini CLI: not installed, skipped"
  fi

  echo ""
fi

echo "  PATAPIM v${VERSION} installed successfully!"
echo ""
echo "  To launch: open /Applications/${APP_NAME}"
echo ""
