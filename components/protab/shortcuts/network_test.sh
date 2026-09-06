#!/bin/bash
# Tab+N - Network connectivity test

# Test China network
cn_status="X"
if curl -s --max-time 3 --connect-timeout 2 "https://www.baidu.com" > /dev/null 2>&1; then
    cn_status="OK"
fi

# Test global network
global_status="X"
if curl -s --max-time 3 --connect-timeout 2 "https://www.google.com" > /dev/null 2>&1; then
    global_status="OK"
fi

# Get IP address
ip_addr=$(curl -s --max-time 3 --connect-timeout 2 "https://ifconfig.me" 2>/dev/null | head -1)
if [ -z "$ip_addr" ]; then
    ip_addr="unknown"
fi

# Show notification
osascript -e "display notification \"CN: ${cn_status} | Global: ${global_status} | IP: ${ip_addr}\" with title \"ProTab - Network\""
