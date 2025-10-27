#!/bin/bash 

is_uuid() {
    local s="$1"
    [[ $s =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]
}

s="$1" 

if is_uuid "$s"; then 
    echo "VALID"
else 
    echo "INVALID";
fi

