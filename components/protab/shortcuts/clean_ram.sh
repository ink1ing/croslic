#!/bin/bash
# Tab+R - Clean RAM using Rust memory cleaner

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

RUST_BINARY="$PROJECT_DIR/rust/target/release/freeup_ram_rust"

if [[ "$1" == "--force" ]]; then
    echo "Force cleanup mode..."

    if [ -f "$RUST_BINARY" ]; then
        echo "Round 1..."
        result1=$("$RUST_BINARY" 2>&1 | tail -1)
        sleep 1

        echo "Round 2..."
        result2=$("$RUST_BINARY" 2>&1 | tail -1)
        sleep 1

        echo "Round 3..."
        result3=$("$RUST_BINARY" 2>&1 | tail -1)

        result="$result3"
    else
        echo "System purge"
        sudo purge
        sleep 1
        sudo purge
        result="Force cleanup done"
    fi
else
    if [ -f "$RUST_BINARY" ]; then
        result=$("$RUST_BINARY" 2>&1 | tail -1)
    else
        if sudo purge 2>/dev/null; then
            result="System cleanup done"
        else
            result="Cleanup failed"
        fi
    fi
fi

if [[ "$result" == *"->"* ]]; then
    osascript -e "display notification \"$result\" with title \"ProTab - RAM\""
else
    osascript -e "display notification \"$result\" with title \"ProTab\""
fi

echo "$result"