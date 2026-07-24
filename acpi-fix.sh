#!/bin/bash
# Disable ACPI GPEs that are storming (count > 5000, still enabled)

awk '
  $1 > 5000 && /[[:space:]]enabled[[:space:]]/ && !/disabled/ && FILENAME ~ /gpe[0-9A-F]{2}$/ {
    print FILENAME, $1
  }
' /sys/firmware/acpi/interrupts/* | while read -r ITEM_PATH ITEM_COUNT; do
  echo "disabling $(basename "$ITEM_PATH") (count=$ITEM_COUNT)..."
  echo disable | sudo tee "$ITEM_PATH" >/dev/null
done
