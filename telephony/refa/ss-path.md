# telephony/refa/ss-path.md -- supplementary-services transport path for SKU refa (ch.07 S26)
# Same discipline as ussd-path.md. ASCII only.

sku: refa
mm_dbus: TODO (Modem3gppUssd/ModemVoice QueryCallForwarding/SetCallForwarding/
  QueryCallWaiting/SetCallWaiting exposure after first lab probe)
qmi_fallback: TODO (qmicli --voice-query-call-forwarding usable Y/N on this baseband)
ss_domain_default: TODO (CS forced where VoLTE unblessed; record per carrier)
shared_lock: ss_ussd_mutex + 30s deadlock-watchdog (files SS-DEADLOCK metric)
set_flows: disabled v1 (read-only; enabling needs carrier-acceptance evidence)
status: UNTESTED (flip only after tests/ss-flows.sh round-trips green on this SKU)
