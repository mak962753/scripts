#!/bin/bash

while read -r I ; do
    ITEM_PATH=$(echo $I | cut -f1 -d" ")
    ITEM_COUNT=$(echo $I | cut -f2 -d" ")
    if [[ $ITEM_COUNT -gt 5000 && "$ITEM_PATH" == *gpe6F ]]; then
        echo "disabling gpe6F..." 
        echo disable | sudo tee "$ITEM_PATH"
    else 
        echo "... $I"
    fi
done <<< "$(awk '$1>1000&&$4~/unmasked|enabled/&&FILENAME~/gpe[0-9A-F]{2}$/{print(FILENAME, $1, $4)}' /sys/firmware/acpi/interrupts/*)"

