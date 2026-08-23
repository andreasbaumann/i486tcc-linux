#!/bin/oksh
# test_x_rxvt.sh [LABEL]
#
# Boots root.img with the same qemu flags as run_qemu.sh (headless,
# +serial capture, +monitor for the floppy-swap/vga=ask prompt), waits
# for SSH to come up, logs in and starts `xinit` (.xinitrc: `rxvt &` then
# `exec notion`), then types "echo hello" and "touch marker123" into the
# guest console via the QEMU monitor's `sendkey` (the only keyboard path
# when running headless with -display none) and takes a `screendump`,
# saved as screen-LABEL.png in the current directory, as a visual snapshot
# of the result.
#
# Pass criterion: /root/marker123 exists afterwards, checked over a fresh
# SSH connection -- this proves the typed keystrokes actually reached and
# were executed by the rxvt shell, independent of how the framebuffer
# happens to render (qemu's -vga std has a known, unrelated color-banding
# bug, see README, which can make OCR/visual inspection of the screendump
# unreliable even when X/rxvt themselves work correctly). Tesseract OCR of
# the screendump is also attempted and logged, best-effort only.
#
# Keystrokes are typed via tests/monitor_type.exp, which uses a single
# persistent monitor connection paced by the "(qemu)" prompt -- one-shot
# socat calls per key (a fresh connection each time) drop letters under
# host load.
#
# Exits 0 if the marker file round-trips, non-zero otherwise. Requires:
# qemu-system-i386, qemu-nbd, socat, expect, ImageMagick's `convert`;
# optionally tesseract for OCR.
#
# KNOWN ISSUE (as of 2026-08-23): currently always fails at the typing step.
# Boot/SSH/xinit/Xfbdev/notion/rxvt all come up fine and the screendump
# renders a correct desktop with rxvt visibly focused, but typed keystrokes
# never appear in rxvt or execute. Confirmed via /proc/interrupts that the
# injected scancodes DO reach the guest kernel (IRQ1 count increases by
# exactly 2x the keystrokes sent), so this isn't a QEMU-injection or timing
# problem -- it points to Xfbdev/kdrive not actually consuming the keyboard
# once it owns the framebuffer (e.g. never switching the VT into raw
# keyboard mode). Not yet root-caused.
set -u

LABEL="${1:-xrxvt}"

SELFDIR=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$SELFDIR/.." && pwd)
EXP="$REPO/tests/ssh_cmd.exp"
TYPEEXP="$REPO/tests/monitor_type.exp"

WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/i486tcc-x-rxvt-test.XXXXXX")
WORKIMG="$WORKDIR/work-${LABEL}.img"
LOG="$WORKDIR/serial-${LABEL}.log"
RESULT="$WORKDIR/result-${LABEL}.txt"
SCREENSHOT_PPM="$WORKDIR/screen-${LABEL}.ppm"
SCREENSHOT_PNG="$(pwd)/screen-${LABEL}.png"
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

monitor_cmd() {
	[ -S "$MONSOCK" ] && printf '%s\n' "$1" | timeout 2 socat - UNIX-CONNECT:"$MONSOCK" >/dev/null 2>&1
}

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
	i=$((i + 2))
done

echo "BOOT_STATE=$STATE (after ${i}s)" >> "$RESULT"

RC=1

if [ "$STATE" = "LOGIN_PROMPT" ]; then
	j=0
	while [ $j -lt 90 ]; do
		grep -qE "Starting SSH daemon" "$LOG" 2>/dev/null && break
		sleep 2
		j=$((j + 2))
	done
	sleep 5

	# Detach xinit from the SSH session with a double-background subshell
	# so it (and X/notion/rxvt under it) survive past this SSH command
	# exiting -- otherwise the guest's shell would SIGHUP them when the
	# session closes.
	echo "--- starting X over SSH ---" >> "$RESULT"
	# Xfbdev itself can take most of this time to start on emulated 486
	# hardware; xinit only launches its clients (rxvt, then notion) once
	# the X server socket is actually ready, so a short wait or checking
	# for Xfbdev alone can pass before rxvt/notion ever run.
	XCMD='rm -f /root/marker123; ( xinit -- :0 -cc 4 -fp /share/X11/fonts >/tmp/xinit.log 2>&1 & ); sleep 25; ps ax | grep -E "Xfbdev|notion|rxvt" | grep -v grep | sed "s/^/PSLINE: /"; echo XMARKER_DONE'
	XOUT=$("$EXP" "$XCMD" 45 2>&1)
	echo "$XOUT" >> "$RESULT"
	# same false-positive trap as elsewhere -- the grep pattern text itself
	# would appear in the echoed spawn command, so require real PSLINE: hits,
	# and require all three processes, not just the X server.
	XINIT_OK="NO"
	if echo "$XOUT" | grep -q "^PSLINE:.*Xfbdev" \
		&& echo "$XOUT" | grep -q "^PSLINE:.*notion" \
		&& echo "$XOUT" | grep -q "^PSLINE:.*rxvt"; then
		XINIT_OK="YES"
	fi
	echo "XINIT_OK=$XINIT_OK" >> "$RESULT"

	XLOG=$("$EXP" "cat /tmp/xinit.log 2>&1; echo XLOG_DONE" 20 2>&1)
	echo "--- guest /tmp/xinit.log ---" >> "$RESULT"
	echo "$XLOG" >> "$RESULT"

	if [ "$XINIT_OK" = "YES" ]; then
		# ps showing the processes doesn't mean notion has finished loading
		# fonts and mapped the rxvt window onto the screen yet -- give it
		# extra time before assuming the desktop is interactive.
		sleep 15
		DIAG0=$("$EXP" "cat /proc/interrupts | grep -iE 'CPU|i8042|  1:'; echo DIAG_DONE" 20 2>&1)
		echo "--- diagnostic: /proc/interrupts BEFORE typing ---" >> "$RESULT"
		echo "$DIAG0" >> "$RESULT"

		echo "--- typing into rxvt via QEMU monitor ---" >> "$RESULT"
		TOUT1=$("$TYPEEXP" "$MONSOCK" "echo hello" 2>&1)
		echo "$TOUT1" >> "$RESULT"
		sleep 1
		TOUT2=$("$TYPEEXP" "$MONSOCK" "touch marker123" 2>&1)
		echo "$TOUT2" >> "$RESULT"
		sleep 1

		monitor_cmd "screendump $SCREENSHOT_PPM"
		sleep 1

		if command -v convert >/dev/null 2>&1 && [ -s "$SCREENSHOT_PPM" ]; then
			convert "$SCREENSHOT_PPM" "$SCREENSHOT_PNG" 2>/dev/null
			echo "SCREENSHOT_PNG=$SCREENSHOT_PNG" >> "$RESULT"
		fi

		if command -v tesseract >/dev/null 2>&1 && [ -s "$SCREENSHOT_PPM" ]; then
			OCR=$(tesseract "$SCREENSHOT_PPM" - 2>/dev/null)
			echo "--- tesseract OCR of screendump (best-effort) ---" >> "$RESULT"
			echo "$OCR" >> "$RESULT"
		fi

		echo "--- checking marker over a fresh SSH connection ---" >> "$RESULT"
		MOUT=$("$EXP" "ls -la /root/marker123 2>&1; echo MARKER_CHECK_DONE" 20 2>&1)
		echo "$MOUT" >> "$RESULT"
		echo "$MOUT" | grep -q "marker123" && ! echo "$MOUT" | grep -qi "No such file" && RC=0

		# DIAGNOSTIC (temporary): did the injected scancodes even reach the
		# guest kernel? If IRQ1 (i8042 keyboard) didn't increment by ~20
		# (2 commands x ~10 keys incl. Return), the problem is at the
		# QEMU->guest hardware level, not in X's handling of real keystrokes.
		DIAG=$("$EXP" "cat /proc/interrupts | grep -iE 'CPU|i8042|  1:'; echo DIAG_DONE" 20 2>&1)
		echo "--- diagnostic: /proc/interrupts (IRQ1=keyboard) ---" >> "$RESULT"
		echo "$DIAG" >> "$RESULT"
	fi
fi

echo "--- full serial log ---" >> "$RESULT"
cat "$LOG" >> "$RESULT"
cat "$RESULT"
[ -s "$SCREENSHOT_PNG" ] && echo "screenshot: $SCREENSHOT_PNG" >&2
echo "results kept in: $WORKDIR" >&2
exit $RC
