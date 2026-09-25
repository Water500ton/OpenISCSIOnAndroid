#!/system/bin/sh

MODDIR=${0%/*}
ISCSI_DIR=/data/iscsi

mkdir -p "$ISCSI_DIR" 2>/dev/null
chmod 0770 "$ISCSI_DIR"
chown 0 0 "$ISCSI_DIR"

for subdir in ifaces nodes send_targets static isns fw; do
  mkdir -p "$ISCSI_DIR/$subdir" 2>/dev/null
  chmod 0770 "$ISCSI_DIR/$subdir"
  chown 0 0 "$ISCSI_DIR/$subdir"
done

if [ ! -f "$ISCSI_DIR/iscsid.conf" ]; then
  cp "$MODDIR/config/iscsid.conf" "$ISCSI_DIR/iscsid.conf"
  chmod 0640 "$ISCSI_DIR/iscsid.conf"
  chown 0 0 "$ISCSI_DIR/iscsid.conf"
fi

if [ ! -f "$ISCSI_DIR/initiatorname.iscsi" ]; then
  SERIAL="$(getprop ro.boot.serialno 2>/dev/null)"
  [ -z "$SERIAL" ] && SERIAL="$(getprop ro.serialno 2>/dev/null)"
  if [ -z "$SERIAL" ]; then
    SERIAL="$(date +%s)"
  fi
  SERIAL="$(echo "$SERIAL" | tr -c 'A-Za-z0-9._-:' '_')"
  echo "InitiatorName=iqn.2026-09.com.android:${SERIAL}" > "$ISCSI_DIR/initiatorname.iscsi"
  chmod 0640 "$ISCSI_DIR/initiatorname.iscsi"
  chown 0 0 "$ISCSI_DIR/initiatorname.iscsi"
fi
