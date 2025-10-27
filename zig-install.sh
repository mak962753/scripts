#!/usr/bin/env sh

# installation directory
INSTALL_DIR="$HOME/.local/share/zig"
BIN_DIR="$INSTALL_DIR/bin"

# ensure install directory exists
mkdir -p "$INSTALL_DIR"

# get system architecture
ARCH=$(uname -m)

# get os: Linux or Darwin
OS=$(uname -s)
OS=$(echo "$OS"|tr '[:upper:]' '[:lower:]')
case "$ARCH" in
    x86_64) ZIG_ARCH="x86_64" ;;
    arm64|aarch64) ZIG_ARCH="aarch64" ;;
esac

case "$OS" in
    linux) ZIG_ARCH="${ZIG_ARCH}-linux" ;;
    darwin) ZIG_ARCH="${ZIG_ARCH}-macos" ;;
esac

echo "ZIG_ARCH: $ZIG_ARCH"

# Get latest Zig master build URL from ziglang.org/download/index.json

QUERY=".master.\"$ZIG_ARCH\".tarball"
echo "Fetching latest Zig master build information($QUERY)..."
DOWNLOAD_URL=$(curl -s "https://ziglang.org/download/index.json" | jq -r ".master.\"$ZIG_ARCH\".tarball")

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Could not find download url for Zig master build for $ZIG_ARCH."
    exit 1
fi
echo "Downloading the latest Zig build from $DOWNLOAD_URL..."
TEMP_FILE=$(mktemp)
curl -L -o "$TEMP_FILE" "$DOWNLOAD_URL" || { echo "Download failed"; rm -f "$TEMP_FILE"; exit 1; }

# extract
mkdir -p "$INSTALL_DIR/_temp"
tar -xf "$TEMP_FILE" -C "$INSTALL_DIR/_temp" --strip-components=1

#remove old installation
if [ -d "$INSTALL_DIR/zig-master" ]; then
    echo "Removing old Zig master installation"
    rm -rf "$INSTALL_DIR/zig-master"
fi

mv "$INSTALL_DIR/_temp" "$INSTALL_DIR/zig-master"

rm "$TEMP_FILE"

# create sym-link for easier access and PATH management
mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/zig-master/zig" "$BIN_DIR/zig"

echo "Zig installed to $INSTALL_DIR/zig-master"
echo "Symlink created at $BIN_DIR/zig"

# check if Zig bin should be added to PATH
case ":$PATH:" in
    *":$BIN_DIR:"*) ;; # it;s already present in the PATH - do nothing
    *)
        echo "Adding $BIN_DIR to PATH..."
        export PATH="$BIN_DIR:$PATH"
        if [ -f "$HOME/.bashrc" ]; then
            echo 'export PATH="$HOME/.local/share/zig/bin:$PATH"' >> "$HOME/.bashrc" # For bash
        fi
        if [ -f "$HOME/.zshrc" ]; then
            echo 'export PATH="$HOME/.local/share/zig/bin:$PATH"' >> "$HOME/.zshrc"  # For zsh
        fi
        echo "Please restart your shell or run 'source ~/.bashrc' (or ~/.zshrc) for PATH changes to take effect."
    ;;
esac

echo "Zig installation complete. Verify with: zig version"
