#!/usr/bin/env sh
set -e  #
PKG_JSON="package.json"

get_keys() {
    # $1 -section name (dependencies or devDependencies)
    jq -r ".$1 | keys[]? // empty" "$PKG_JSON"
}

install() {
    echo "Installing ${1}..."
    npm i -$2 "$1@latest"
}

deps=$(get_keys "dependencies")
if [ -n "$deps" ]; then
    echo "...dependencies..."
    printf "%s\n" "$deps" | while IFS= read -r pkg; do
        install "$pkg" "S"
    done
else
    echo "No dependencies found."
fi

deps=$(get_keys "devDependencies")
if [ -n "$deps" ]; then
    echo "...dev dependencies..."
    printf "%s\n" "$deps" | while IFS= read -r pkg; do
        install "$pkg" "D"
    done
else
    echo "No dev dependencies found."
fi
