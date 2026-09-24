# telephony/refa/ussd-path.md -- USSD transport path for SKU refa (ch.07 S25)
# USSD rides different QMI services per baseband; the path per SKU is recorded here
# because guessing wastes weeks. ASCII only.

sku: refa
mm_path: TODO (mmcli -m N --3gpp-ussd-initiate/respond/cancel OR QMI UIM/voice-USSD delegation)
qmi_service: TODO (record which service carries USSD on this baseband after first lab run)
gsm7_ucs2_decode: host-side (reuses S13 PDU discipline)
session_timeout_s: 90 (NETWORK-TIMEOUT, then cancel + string per telephony/ussd-policy.conf)
idle_cancel_s: 60 (cancel-on-idle correctness rule)
status: UNTESTED (flip only after tests/ussd-flow.sh gates green on this SKU)
