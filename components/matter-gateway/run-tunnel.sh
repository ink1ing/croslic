#!/bin/bash
export PATH=$PATH:/opt/homebrew/bin:/usr/local/bin
export GODEBUG=netdns=go
cloudflared tunnel --config /Users/silas/.cloudflared/config.yml --protocol quic run
