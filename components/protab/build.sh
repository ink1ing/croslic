#!/bin/bash
# ProTab Build Script
# Compile Swift source to executable

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check Swift compiler
if ! command -v swiftc &> /dev/null; then
    echo "Error: Swift compiler not found"
    echo "Please install Xcode Command Line Tools"
    exit 1
fi

echo "Compiling ProTab..."

# Single file compilation
swiftc tab_monitor.swift -o tab_monitor 2>&1

if [ $? -eq 0 ]; then
    echo "Compilation successful"
    echo "Executable created: ./tab_monitor"

    chmod +x tab_monitor

    echo
    echo "To run: ./tab_monitor"
else
    echo "Compilation failed"
    exit 1
fi