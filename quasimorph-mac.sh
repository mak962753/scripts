#!/usr/bin/env sh
set -e # exit on error
command="${1:-}"
name="${2:-}"
if [ -z "$command" ]; then
  echo "Error: command (load/save) is expected" >&2
  exit 1
elif [ "$command" != "save" ] && [ "$command" != "load" ] && [ "$command" != "list" ]; then
  echo "Error: invalid command '$command'. save/load/list is expected" >&2
  exit 1
fi

if [ -z "$name" ] && [ "$command" != "list" ]; then
  echo "sub name is expected"
  exit -1
fi

game_path_base="/Users/maxim/Library/Application Support/CrossOver/Bottles/Steam/drive_c/users/crossover/AppData/LocalLow/Magnum Scriptum LTD/Quasimorph"
game_path="$game_path_base $name"
case "$command" in
"save")
  echo "Saving ..."
  # save logic
  rm -rf "$game_path"
  cp -R "$game_path_base" "$game_path"
  ;;
"list")
  # list all saves and their modification dates
  for d in "$game_path_base"*; do
    [ -d "$d" ] || continue
    [ "$d" = "$game_path_base" ] && continue
    printf "%s  %s\n" "$(date -r "$d" +%Y-%m-%d\ %H:%M)" "$(basename "$d")"
  done
  ;;
"load")
  echo "Loading ..."
  # load logic

  if [ ! -e "$game_path" ]; then
    echo "'Quasimorph $name' does not exist!"
    exit -1
  fi
  rm -rf "$game_path_base"
  cp -R "$game_path" "$game_path_base"
  ;;
*)
  exit 1
  ;;
esac
