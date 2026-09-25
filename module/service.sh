#!/system/bin/sh

MODDIR=${0%/*}
ISCSI_DIR=/data/iscsi
LOG_FILE="$ISCSI_DIR/iscsid.log"

mkdir -p "$ISCSI_DIR" 2>/dev/null
chmod 0770 "$ISCSI_DIR"
chown 0 0 "$ISCSI_DIR"

if [ ! -x /system/bin/iscsid ]; then
  return 0
fi

nohup /system/bin/iscsid >>"$LOG_FILE" 2>&1 &
