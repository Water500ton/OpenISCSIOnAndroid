#!/system/bin/sh

ISCSI_DIR=/data/iscsi
pkill -f '/system/bin/iscsid' 2>/dev/null || true
sleep 1
echo "Open-iSCSI daemon stopped. Runtime files in $ISCSI_DIR were left in place."
