#!/system/bin/sh

ui_print "- Open-iSCSI for Android"
ui_print "- ARM64, Android 8.0+ (API 26)"
ui_print "- Config/runtime directory: /data/iscsi"

set_perm_recursive 0 0 0755 0755 "$MODPATH/system/bin"
set_perm_recursive 0 0 0755 0644 "$MODPATH/system/lib64"
