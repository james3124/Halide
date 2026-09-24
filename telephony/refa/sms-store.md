# telephony/refa/sms-store.md -- SMS storage path for SKU refa (ch.07 S31)
# Some basebands lie about SM capacity (report 30 slots with 10 usable); usable counts are
# measured per SKU with a fill-fixture and committed here, never datasheet-copied. ASCII only.

sku: refa
preferred: ME with SM overflow where AT+CPMS exposes both
cpms_path: TODO (record AT+CPMS=<mem1>,<mem2>,<mem3> actually honored on this baseband)
me_usable_slots_measured: TODO (fill-fixture count + date)
sm_usable_slots_measured: TODO (fill-fixture count + date)
watermarks: USED>=80% trim safe-delete set; >=95% banner + memory-full RP-ACK where exposed;
  100% inbound held at SMSC + SMS-STORAGE-FULL mirrored (RESULT_NO_MEMORY)
status: UNTESTED (flip only after local-full fixture green: fill to 100% -> held -> free 5 ->
  auto-resume, per telephony/sms-policy.conf)
