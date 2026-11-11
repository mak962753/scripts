#!/usr/bin/env sh

GAME_PATH="/home/maxim/.local/share/Steam/steamapps/compatdata/2059170/pfx/drive_c/users/steamuser/AppData/LocalLow/Magnum Scriptum Ltd/Quasimorph"
if [ "$#" -eq 1 ] && [ "$1" = "list" ]; then 
    ls -lah "$GAME_PATH/.."
    exit 0
fi 

if [ $# -ne 2 ]; then
    echo "Usage: $0 {save|load} <foldername>"
    exit 1
fi
COMMAND="$1"
NAME="$2"

TARGET="${GAME_PATH} ${NAME}"
TARGET_NAME=$(basename "$TARGET")

case "$COMMAND" in
    save)
        # Remove target folder if exists, then copy source to target
        rm -rf "$TARGET"
        cp -R "$GAME_PATH" "$TARGET"
        echo "Saved game '$NAME' to '$TARGET_NAME'"
        ;;
    load)
        # Backup the current (existing) GAME_PATH first
        if [ ! -d "$GAME_PATH" ]; then
            echo "ERROR: No existing GAME_PATH at $GAME_PATH. Nothing to load."
            exit 1
        fi
        BACKUP="${GAME_PATH}.bak"
        rm -rf "$BACKUP"
        cp -R "$GAME_PATH" "$BACKUP"
        # Remove current GAME_PATH and copy the named folder in
        rm -rf "$GAME_PATH"
        cp -R "$TARGET" "$GAME_PATH"
        echo "Loaded '$TARGET_NAME'"
        ;;
    *)
        echo "Unknown command: $COMMAND. Use save or load."
        exit 1
        ;;
esac