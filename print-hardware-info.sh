#!/bin/bash

# === Hardware Information ===
echo "===== Hardware Information ====="
echo "Hostname: $(hostname)"
echo "CPU:"
lscpu | grep -E 'Model name|Socket|Thread|Core|CPU\(s\)' || echo "lscpu not available"

echo -e "\nMemory:"
free -h || echo "free not available"

echo -e "\nGPU:"
lspci | grep -i 'vga\|3d\|2d' || echo "lspci not available"

echo -e "\nDisk:"
df -h / || echo "df not available"
