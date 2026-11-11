#!/usr/bin/env sh

# Goose (aardappel/goose) installer - macOS & Linux only
# https://github.com/aardappel/goose/releases

INSTALL_DIR="$HOME/.goose"
REPO="aardappel/goose"

# ------------------------------------------------------------------ platform

OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$OS" in
    linux)  GOOSE_OS="linux" ;;
    darwin) GOOSE_OS="macos" ;;
    *) echo "Unsupported OS: $(uname -s) (this installer supports macOS and Linux only)"; exit 1 ;;
esac

case "$ARCH" in
    x86_64|amd64)          GOOSE_ARCH="x64" ;;
    arm64|aarch64)         GOOSE_ARCH="arm64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

TARGET="${GOOSE_OS}-${GOOSE_ARCH}"
echo "Platform: $TARGET"

command -v curl >/dev/null 2>&1 || { echo "curl is required but not found."; exit 1; }
command -v jq   >/dev/null 2>&1 || { echo "jq is required but not found (install jq)."; exit 1; }

# ------------------------------------------------------------------ latest release

TMP_DIR=$(mktemp -d) || { echo "Could not create a temporary directory."; exit 1; }
trap 'rm -rf "$TMP_DIR"' EXIT INT TERM

echo "Querying latest release of $REPO ..."
RELEASE_JSON="$TMP_DIR/release.json"
if ! curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" -o "$RELEASE_JSON"; then
    echo "Could not fetch the latest release information from GitHub."
    exit 1
fi

LATEST_TAG=$(jq -r '.tag_name // empty' "$RELEASE_JSON")
DOWNLOAD_URL=$(jq -r --arg suffix "-$TARGET.tar.gz" \
    '.assets[] | select(.name | endswith($suffix)) | .browser_download_url' "$RELEASE_JSON" | head -n 1)

if [ -z "$LATEST_TAG" ] || [ -z "$DOWNLOAD_URL" ]; then
    echo "No $TARGET asset found in the latest release ($LATEST_TAG)."
    exit 1
fi

LATEST_VER=$(echo "$LATEST_TAG" | sed 's/^v//')
echo "Latest Goose release: $LATEST_TAG"

# ------------------------------------------------------------------ installed version

VERSION_FILE="$INSTALL_DIR/.version"

installed_ver=""
if [ -f "$VERSION_FILE" ]; then
    installed_ver=$(cat "$VERSION_FILE" | tr -d '[:space:]' | sed 's/^v//')
fi
if [ -z "$installed_ver" ] && [ -x "$INSTALL_DIR/goose" ]; then
    installed_ver=$("$INSTALL_DIR/goose" --version 2>/dev/null | sed -n 's/.*v\([0-9][0-9A-Za-z.]*\).*/\1/p' | head -n 1)
fi

if [ -n "$installed_ver" ]; then
    echo "Installed Goose version: $installed_ver"
else
    echo "Goose is not installed in $INSTALL_DIR"
fi

if [ "${FORCE:-0}" != "1" ] && [ "$installed_ver" = "$LATEST_VER" ]; then
    cat <<EOF

✔ Goose is already up to date (v$LATEST_VER) — nothing to do.
  Installed at: $INSTALL_DIR/goose
  Run it with:  goose --version

EOF
    exit 0
fi

# ------------------------------------------------------------------ download first

echo "Downloading $DOWNLOAD_URL ..."
TMP_TARBALL="$TMP_DIR/goose-$TARGET.tar.gz"

curl -fL --retry 3 -o "$TMP_TARBALL" "$DOWNLOAD_URL" || {
    echo "Download failed!"; exit 1;
}

echo "Extracting ..."
mkdir -p "$TMP_DIR/unpacked"
tar -xzf "$TMP_TARBALL" -C "$TMP_DIR/unpacked" --strip-components=1 || {
    echo "Package extraction failed!"; exit 1;
}
[ -f "$TMP_DIR/unpacked/goose" ] || {
    echo "Extracted archive does not contain a 'goose' binary."; exit 1;
}

# ------------------------------------------------------------------ only now replace the old install

if [ -d "$INSTALL_DIR" ]; then
    echo "Removing previous Goose installation from $INSTALL_DIR"
    rm -rf "$INSTALL_DIR"
fi

mkdir -p "$INSTALL_DIR"
mv "$TMP_DIR/unpacked"/* "$INSTALL_DIR"/ || {
    echo "Could not move the new files into $INSTALL_DIR"; exit 1;
}
chmod +x "$INSTALL_DIR/goose"
printf '%s\n' "$LATEST_VER" > "$VERSION_FILE"

echo "Goose $LATEST_TAG installed to $INSTALL_DIR"

# ------------------------------------------------------------------ PATH wiring

PATH_LINE='export PATH="$HOME/.goose:$PATH"'

for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [ -f "$RC" ]; then
        if grep -q '\.goose' "$RC"; then
            echo "$RC already references .goose - leaving it alone."
        else
            printf '\n# Goose\n%s\n' "$PATH_LINE" >> "$RC"
            echo "Added Goose to PATH in $RC"
        fi
    fi
done

case ":$PATH:" in
    *":$INSTALL_DIR:"*) ;;
    *) export PATH="$INSTALL_DIR:$PATH";;
esac

cat <<EOF

✔ Goose $LATEST_TAG installed into $INSTALL_DIR

Open a new shell, or run:  source ~/.bashrc   (or source ~/.zshrc)
Verify with:  goose --version

EOF
