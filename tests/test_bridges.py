import os, sys
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "bridges"))
import prop_bridge, ril_bridge
import audio_bridge, input_bridge, netd_bridge, permission_bridge

fails = 0
def check(name, got, want):
    global fails
    ok = got == want
    print(("PASS " if ok else "FAIL ") + name)
    if not ok:
        print("  got:  %r\n  want: %r" % (got, want)); fails += 1

check("prop set allowlisted", prop_bridge.handle("SET persist.sys.locale en-US\n"), "OK\n")
check("prop get", prop_bridge.handle("GET persist.sys.locale\n"), "OK en-US\n")
check("prop denied", prop_bridge.handle("GET ro.secret\n"), "ERR denied\n")
check("prop too-long", prop_bridge.handle("SET sys.boot_completed " + "x"*300 + "\n"), "ERR too-long\n")
check("ril dial ready", ril_bridge.handle("DIAL +123\n"), "OK queued:DIAL\n")
ril_bridge.set_radio(ril_bridge.RadioState.DRAINING)
check("ril frozen in drain", ril_bridge.handle("DIAL +123\n"), "ERR DENIED-radio-not-ready\n")
ril_bridge.set_radio(ril_bridge.RadioState.READY)
check("ril unknown", ril_bridge.handle("PING\n"), "ERR unknown-action\n")
check("audio route media", audio_bridge.handle("ROUTE media\n"), "OK routed:media\n")
check("audio volume ok", audio_bridge.handle("VOLUME media 80\n"), "OK volume:media:80\n")
check("audio volume bad", audio_bridge.handle("VOLUME media 150\n"), "ERR bad-volume\n")
check("audio route call", audio_bridge.handle("ROUTE call\n"), "OK routed:call\n")
check("audio media ducked", audio_bridge.handle("ROUTE media\n"), "OK ducked\n")
check("input tap", input_bridge.handle("TAP 100 200\n"), "OK injected:TAP\n")
check("input tap bad", input_bridge.handle("TAP 5000 10\n"), "ERR bad-coords\n")
check("input swipe", input_bridge.handle("SWIPE 0 0 100 100\n"), "OK injected:SWIPE\n")
check("input key bad", input_bridge.handle("KEY 999\n"), "ERR bad-key\n")
check("netd up", netd_bridge.handle("UP wlan0\n"), "OK up:wlan0\n")
check("netd bad iface", netd_bridge.handle("DOWN eth0\n"), "ERR bad-iface\n")
check("netd dns ok", netd_bridge.handle("DNS 8.8.8.8\n"), "OK dns:8.8.8.8\n")
check("netd dns bad", netd_bridge.handle("DNS 999.1.1.1\n"), "ERR bad-ip\n")
check("perm grant", permission_bridge.handle("GRANT com.example.app LOCATION\n"), "OK granted SYNCED both-stacks\n")
check("perm revoke", permission_bridge.handle("REVOKE com.example.app LOCATION\n"), "OK revoked SYNCED both-stacks\n")
check("perm bad perm", permission_bridge.handle("GRANT com.example.app SMS\n"), "ERR bad-perm\n")
check("perm bad pkg", permission_bridge.handle("GRANT badpkg LOCATION\n"), "ERR bad-pkg\n")
print("bridges test: %s" % ("PASS" if fails == 0 else "FAIL"))
sys.exit(1 if fails else 0)
