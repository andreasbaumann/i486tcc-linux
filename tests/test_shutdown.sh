#!/bin/oksh
# test_shutdown.sh [LABEL]
#
# Boots root.img with the same qemu flags as run_qemu.sh (headless,
# +serial capture, +monitor for the floppy-swap/vga=ask prompt), waits
# for SSH to come up, logs in and issues `poweroff`, then watches the
# serial log for up to 90s to confirm the kernel reaches "System halted"
# with no "I/O error, dev nbd0" spam in between (regression check for the
# nbd-client-killed-too-early-by-killall5 shutdown bug). Exits 0 on a
# clean shutdown, non-zero otherwise. Requires: qemu-system-i386, qemu-nbd,
# socat, expect.
set -u

LABEL="${1:-shutdown}"

SELFDIR=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$SELFDIR/.." && pwd)
EXP="$REPO/tests/ssh_cmd.exp"

WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/i486tcc-shutdown-test.XXXXXX")
WORKIMG="$WORKDIR/work-${LABEL}.img"
LOG="$WORKDIR/serial-${LABEL}.log"
RESULT="$WORKDIR/result-${LABEL}.txt"
MONSOCK="$WORKDIR/mon-${LABEL}.sock"

cp "$REPO/root.img" "$WORKIMG"
: > "$LOG"
: > "$RESULT"

cleanup() {
	[ -n "${KEYER_PID:-}" ] && kill "$KEYER_PID" 2>/dev/null
	[ -n "${QEMU_PID:-}" ] && kill "$QEMU_PID" 2>/dev/null
	[ -n "${NBD_PID:-}" ] && kill "$NBD_PID" 2>/dev/null
	sleep 1
	[ -n "${QEMU_PID:-}" ] && kill -9 "$QEMU_PID" 2>/dev/null
	rm -f "$WORKIMG" "$MONSOCK"
}
trap cleanup EXIT

# -t/--persistent: without it qemu-nbd exits after serving exactly one
# connection, so any guest reconnect (dhcp renewal, transient hiccup) finds
# no server on the other end and the block layer hangs forever ("Possible
# stuck request" in the guest's dmesg) -- seen in practice during repeated
# back-to-back test runs.
qemu-nbd -f raw -t "$WORKIMG" -x ROOT &
NBD_PID=$!
sleep 2

qemu-system-i386 -cpu 486 -m 24M -machine isapc \
	-drive "file=${REPO}/floppy00.img,if=floppy,format=raw" \
	-netdev user,id=net0,net=10.0.0.0/24,host=10.0.0.2,dhcpstart=10.0.0.16,hostfwd=tcp::2222-:22,hostfwd=tcp::6001-:6000 \
	-vga std \
	-device ne2k_isa,iobase=0x300,irq=10,netdev=net0 \
	-display none \
	-monitor unix:"$MONSOCK",server,nowait \
	-serial file:"$LOG" &
QEMU_PID=$!

(
	sleep 8
	[ -S "$MONSOCK" ] && printf 'change floppy0 %s/floppy01.img\n' "$REPO" | timeout 2 socat - UNIX-CONNECT:"$MONSOCK" >/dev/null 2>&1
	for n in $(seq 1 20); do
		sleep 2
		[ -S "$MONSOCK" ] && printf 'sendkey ret\n' | timeout 2 socat - UNIX-CONNECT:"$MONSOCK" >/dev/null 2>&1
	done
) &
KEYER_PID=$!

i=0
STATE="TIMEOUT"
while [ $i -lt 240 ]; do
	if grep -qE "Kernel panic|Out of memory: Killed process|invoked oom-killer|VFS: Unable to mount root fs|Unable to handle kernel|BUG: " "$LOG" 2>/dev/null; then
		STATE="FATAL_LOG"
		break
	fi
	# a stuck nbd request that's still stuck 60s later never recovers in
	# practice -- fail fast instead of burning the full 240s timeout.
	if [ "$(grep -c "Possible stuck request" "$LOG" 2>/dev/null)" -ge 3 ]; then
		STATE="STUCK_NBD"
		break
	fi
	if ! kill -0 "$QEMU_PID" 2>/dev/null; then
		STATE="QEMU_DIED"
		break
	fi
	if grep -qiE "login:" "$LOG" 2>/dev/null; then
		STATE="LOGIN_PROMPT"
		break
	fi
	sleep 2
	i=$((i+2))
done

echo "BOOT_STATE=$STATE (after ${i}s)" >> "$RESULT"

RC=1

if [ "$STATE" = "LOGIN_PROMPT" ]; then
	j=0
	while [ $j -lt 90 ]; do
		grep -qE "Starting SSH daemon" "$LOG" 2>/dev/null && break
		sleep 2
		j=$((j+2))
	done
	sleep 5

	echo "--- issuing poweroff over SSH ---" >> "$RESULT"
	OUT=""
	for attempt in 1 2 3 4 5; do
		OUT=$("$EXP" "poweroff; sleep 1; echo POWEROFF_ISSUED" 20 2>&1)
		echo "--- attempt $attempt ---" >> "$RESULT"
		echo "$OUT" >> "$RESULT"
		# expect's "spawn ..." banner always echoes the argv text, including
		# "echo POWEROFF_ISSUED", so grepping for that string is a false
		# positive even when the connection died pre-auth. Detect real
		# success by the ABSENCE of the known pre-password failure markers.
		if ! echo "$OUT" | grep -qE "SSH_EOF_PRE_PASSWORD|SSH_TIMEOUT_PRE_PASSWORD|Connection reset|kex_exchange_identification"; then
			break
		fi
		sleep 3
	done

	# The isapc machine type has no ACPI, so a clean poweroff never makes
	# qemu itself exit -- the kernel just halts ("Power off not available:
	# System halted instead"). Watch for that halt message rather than for
	# qemu to exit. The regression this guards against is nbd-client being
	# killed too early by killall5, which shows up as "I/O error, dev nbd0"
	# spam once /etc/rc.shutdown starts running.
	k=0
	HALTED="NO"
	while [ $k -lt 90 ]; do
		if grep -qE "System halted|Power down" "$LOG" 2>/dev/null; then
			HALTED="YES"
			break
		fi
		if ! kill -0 "$QEMU_PID" 2>/dev/null; then
			HALTED="QEMU_DIED"
			break
		fi
		sleep 2
		k=$((k+2))
	done
	echo "HALT_STATE=$HALTED (after ${k}s)" >> "$RESULT"

	NBD_IO_ERRORS=$(awk '/Shutting down all processes/{f=1} f && /I\/O error, dev nbd0/{c++} END{print c+0}' "$LOG")
	echo "NBD_IO_ERRORS_DURING_SHUTDOWN=$NBD_IO_ERRORS" >> "$RESULT"

	[ "$HALTED" = "YES" ] && [ "$NBD_IO_ERRORS" -eq 0 ] && RC=0
fi

echo "--- full serial log ---" >> "$RESULT"
cat "$LOG" >> "$RESULT"
cat "$RESULT"
echo "results kept in: $WORKDIR" >&2
exit $RC
