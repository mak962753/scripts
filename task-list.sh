#!/usr/bin/env bash

path1="$HOME/projects/nms/systems/emlo/backend"
path2="$HOME/projects/nms/systems/voice-screen/systems-admin-src/backend"

user="maksim dz"

today=$(date '+%Y-%m-%d 00:00:00')
echo "$today"

get_logs() {
    path=$1
    cd "$path"
    git log --all --author="$user" --since="$today" --oneline | grep -oPi 'nd-\d{4,}'
}

(get_logs "$path1"; get_logs "$path2") | sort -u | paste -sd ',' | sed 's/,/, /g'
