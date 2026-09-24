#!/bin/sh
# factory-reset.sh — phone-safe STUB, never erases from here.
set -eu
echo "factory-reset plan (text only):"
echo "1. backup user data (if consented)"
echo "2. crypto-erase userdata + metadata"
echo "3. verify attestation / vbmeta chain"
echo "refusing to execute on phone: destructive + needs builder/fastboot" >&2
exit 2
