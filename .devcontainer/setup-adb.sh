#!/bin/bash
# Auto-connect to host ADB server if available

# Determine host IP from docker bridge
HOST_IP="$(ip route | grep default | cut -d" " -f3)"
echo "Host IP detected: $HOST_IP"

# First, kill any local ADB server to ensure clean state
echo "Ensuring clean ADB state..."
adb kill-server 2>/dev/null || true
sleep 1

# Check if host ADB server is accessible
echo "Checking for ADB server on host at $HOST_IP:5037..."
if timeout 2 bash -c "cat < /dev/null > /dev/tcp/${HOST_IP}/5037" 2>/dev/null; then
    echo "✓ ADB server detected on host"

    # Set environment variables for THIS session
    export ANDROID_ADB_SERVER_ADDRESS=${HOST_IP}
    export ANDROID_ADB_SERVER_PORT=5037

    # Persist for future shells (if not already there)
    grep -q "ANDROID_ADB_SERVER_ADDRESS" ~/.bashrc || {
        echo "export ANDROID_ADB_SERVER_ADDRESS=${HOST_IP}" >> ~/.bashrc
        echo "export ANDROID_ADB_SERVER_PORT=5037" >> ~/.bashrc
    }
    grep -q "ANDROID_ADB_SERVER_ADDRESS" ~/.zshrc || {
        echo "export ANDROID_ADB_SERVER_ADDRESS=${HOST_IP}" >> ~/.zshrc
        echo "export ANDROID_ADB_SERVER_PORT=5037" >> ~/.zshrc
    }

    # Now check devices (this should connect to host ADB)
    echo "Connecting to host ADB server..."
    adb devices

    # Try to connect to emulators explicitly
    connected=0
    for port in 5554 5556 5558 5560; do
        if timeout 1 bash -c "cat < /dev/null > /dev/tcp/${HOST_IP}/${port}" 2>/dev/null; then
            echo "Found emulator on port ${port}, connecting..."
            if adb connect ${HOST_IP}:${port} 2>&1 | grep -q "connected"; then
                connected=$((connected + 1))
            fi
        fi
    done

    if [ $connected -gt 0 ]; then
        echo ""
        echo "✓ Successfully connected to $connected emulator(s)"
        echo "Run 'adb devices' or 'flutter devices' to verify."
    else
        echo ""
        echo "⚠ ADB server found but no emulators detected."
        echo "Start an emulator on your host machine first."
    fi
else
    echo "❌ No ADB server detected on host at $HOST_IP:5037"
    echo ""
    echo "To enable Android emulator access:"
    echo "  1. On your HOST machine, run:"
    echo "     adb kill-server && adb -a nodaemon server start"
    echo "  2. Start your Android emulator(s)"
    echo "  3. Inside this container, run:"
    echo "     /usr/local/bin/setup-adb.sh"
fi