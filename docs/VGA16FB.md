# The `tinyxserver-fbdev-vga16.patch`

This patch teaches tinyxserver's `Xfbdev` driver (`hw/kdrive/fbdev/fbdev.c`,
`fbdev.h`) to work on top of Linux's `vga16fb` framebuffer driver — the
driver that backs `/dev/fb0` on plain VGA hardware in 16-colour mode (the
classic `vga=771`/`vga16fb` boot mode, and what QEMU's `-vga std` text/VGA
console exposes before a "real" high-colour mode is set).

It is applied in `scripts/build.sh` right after
`tinyxserver-fbdev-device.patch` (the patch that adds the `FBDEVICE`
environment variable) and before `tinyxserver-xvesa-vm86.patch`.

## The problem: `vga16fb` is not packed pixels

Every other framebuffer mode `Xfbdev` supports (8bpp, 15/16bpp, 24/32bpp) is
**packed-pixel**: each pixel's colour bits live contiguously in memory, so a
byte offset into the mmap'd framebuffer corresponds directly to a pixel (or a
small group of pixels). `Xfbdev`'s existing code just hands X's `fb` layer a
`byteStride`/`pixelStride`/`frameBuffer` pointer into that mmap and lets it
write there directly.

`vga16fb`, however, exposes classic **EGA/VGA planar memory**: 16 colours are
stored as 4 bitplanes, each plane holding 1 bit per pixel. All 4 planes are
mapped at the *same* linear address range (traditionally `0xa0000`); which
plane a given write actually lands in is selected out-of-band, through the
VGA Sequencer's **Map Mask register** (index 2 at I/O ports `0x3c4`/`0x3c5`).
A CPU write of one byte to the framebuffer aperture doesn't write one pixel
— it writes 8 pixels' worth of *one bit each*, in whichever plane(s) the Map
Mask currently selects.

Because of this, the existing linear/packed-pixel code path in `Xfbdev` is
fundamentally unusable for `vga16fb`: there is no `bits_per_pixel` /
`line_length` interpretation of this memory that produces correct pixels.
The frame buffer has to be treated specially, and X's own **shadow
framebuffer** layer already contains exactly the conversion code needed
(`miext/shadow/shplanar8.c`, function `shadowUpdatePlanar4x8`) — it was
written for real EGA/VGA hardware drivers. The patch's job is to detect
`vga16fb`, route through that shadow layer instead of the direct/linear
path, and drive the Map Mask register from the window callback the shadow
layer calls.

## What each change does

### 1. Detect planar memory and get I/O port access (`fbdevCardInit`, `fbdev.c` ~L52)

```c
priv->planar = (priv->fix.type == FB_TYPE_VGA_PLANES);
if (priv->planar && ioperm (0x3c4, 2, 1) < 0) {
    perror ("Error getting I/O privilege for VGA sequencer ports (need to run as root)");
    close (priv->fd);
    return FALSE;
}
```

- `fix.type` comes from the `FBIOGET_FSCREENINFO` ioctl the driver already
  performs. `vga16fb` reports `FB_TYPE_VGA_PLANES`; every packed-pixel
  driver reports `FB_TYPE_PACKED_PIXELS`. This is the one bit of
  information the kernel gives us to distinguish the two, so it's the
  correct and only place to make the decision.
- `ioperm(0x3c4, 2, 1)` requests permission for the *2* ports starting at
  `0x3c4` (i.e. `0x3c4` and `0x3c5`, the Sequencer's index/data pair) so the
  process may later issue raw `outb()` to them. This requires either root or
  `CAP_SYS_RAWIO`, hence the explicit error message — a silent SIGSEGV from
  a failed `outb` would be far more confusing to debug.
- This is exactly why kernel commit `8265e23`/`46b2f4e` in this repo's
  history enabled `CONFIG_X86_IOPL_IOPERM`: without that kernel config,
  `ioperm()` itself is unavailable and this whole approach can't work.
- Failure here closes the fd and bails out cleanly, matching the existing
  error-handling style in the function rather than continuing in a
  half-initialized state.

### 2. Describe the screen to X as depth-4/8bpp with no direct framebuffer (`fbdevScreenInit`, ~L218)

```c
if (priv->planar)
{
    screen->fb[0].depth = 4;
    screen->fb[0].bitsPerPixel = 8;
    screen->width = priv->var.xres;
    screen->height = priv->var.yres;
    screen->softCursor = TRUE;
}
else { /* existing packed-pixel path, byteStride/pixelStride/frameBuffer */ }
```

- Depth 4 (16 colours) is what the hardware can actually display; `bitsPerPixel = 8`
  is deliberate, *not* a mismatch — X's shadow-planar code (`shadowUpdatePlanar4x8`)
  works from an 8-bit-per-pixel software scratch buffer (1 byte holds one
  pixel's 4-bit colour index, padded to 8 bits) and converts *that* down
  into the 4 real 1bpp hardware planes. Depth/bpp here describe the shadow
  buffer X renders into, not the hardware layout.
- `byteStride`, `pixelStride`, and `frameBuffer` are deliberately left unset
  in this branch — comment in the patch explains they're irrelevant because
  ownership of the pixel buffer moves to the shadow layer, which allocates
  its own linear scratch pixmap and never touches `screen->fb[0]` directly.
- `softCursor = TRUE` forces a software-rendered cursor. There is no
  hardware cursor overlay support being wired up for planar mode, so a
  hardware cursor path would simply not draw.

### 3. Map Mask helper — `fbdevSetPlane()` (~L281)

```c
static void
fbdevSetPlane (int plane)
{
    outb (0x02, 0x3c4);
    outb (1 << plane, 0x3c5);
}
```

Standard VGA sequencer programming sequence: write the register index (2 =
Map Mask) to `0x3c4`, then the value to `0x3c5`. The value is a 4-bit mask,
one bit per plane; `1 << plane` selects exactly one plane at a time, which
is what the shadow layer's window callback needs (it updates one plane's
worth of data per call).

### 4. The window callback — `fbdevWindowPlanar()` (~L281, the trickiest part)

```c
void *
fbdevWindowPlanar (ScreenPtr pScreen, CARD32 row, CARD32 offset,
                    int mode, CARD32 *size, void *closure)
{
    KdScreenPriv(pScreen);
    FbdevPriv *priv = pScreenPriv->card->driver;
    int plane = offset & 0xf;
    CARD32 byteOffset = (offset >> 4) << 2;

    if (!pScreenPriv->enabled)
        return 0;
    fbdevSetPlane (plane);
    *size = priv->fix.line_length - byteOffset;
    return (CARD8 *) priv->fb + row * priv->fix.line_length + byteOffset;
}
```

X's shadow-planar update routines (`shadowUpdatePlanar4`/
`shadowUpdatePlanar4x8`) call a driver-supplied "window" function to get a
pointer to hardware memory for each chunk of damage they flush. They encode
which plane a given chunk targets in the **low 4 bits of `offset`**, and the
remaining high bits are *not* a byte offset — both routines do their pointer
arithmetic in units of the `CARD32` words they write (each 32-bit word holds
32 pixels' worth of 1-bit-per-pixel data for one plane). So converting back
to a real byte address requires `(offset >> 4) * 4`, i.e. `(offset >> 4) << 2`,
not just `offset >> 4` or `offset & ~0xf`.

**This was the actual bug this patch fixes over a naive first attempt**: an
earlier version of this window function (still visible as the shape of the
mistake in the comment) treated `offset >> 4` directly as a byte offset.
That is wrong by a factor of 4, but the error is invisible for the *first*
32-pixel-wide word of every scanline, because `offset >> 4 == 0` regardless
of which formula you use when `offset < 16`. It only manifests once damage
starts at `x >= 32` — i.e. as soon as anything wider than the very left edge
of the screen is drawn, such as real text. That's exactly the kind of bug
that "looks fine" in a quick smoke test and then corrupts everything once
you actually use the display, which is why the comment calls it out
explicitly and why live testing with real text/window content (not just
"it compiled and booted") matters for this kind of change.

The function:
1. Extracts `plane` from the low 4 bits and the real byte offset from the rest.
2. Bails out early (returns `0`, i.e. `NULL`) if the screen isn't currently
   enabled/active — avoids touching hardware registers for a VT-switched-away
   or otherwise inactive screen.
3. Programs the Map Mask to the target plane via `fbdevSetPlane()`.
4. Reports the remaining bytes in that scanline via `*size`, and returns a
   pointer into the mmap'd aperture at `row * line_length + byteOffset` —
   the same aperture all 4 planes share, now steered to the right plane by
   the Map Mask.

### 5. Wiring shadow mode on for planar screens (`fbdevSetScreenSizes`/layer setup, ~L460)

```c
if (priv->planar)
    scrpriv->shadow = TRUE;
...
if (scrpriv->shadow)
{
    if (priv->planar)
    {
        window = fbdevWindowPlanar;
        update = shadowUpdatePlanar4x8;
    }
    else
    {
        /* existing linear/rotate/FAKE24 logic, unchanged */
    }
}
```

- Forces `shadow = TRUE` unconditionally for planar framebuffers, regardless
  of rotation settings — there is no non-shadow path that could ever work
  for planar memory, unlike the packed-pixel case where shadow is only
  needed for rotation or the `FAKE24_ON_16` emulation.
- Selects `fbdevWindowPlanar`/`shadowUpdatePlanar4x8` as the window/update
  callback pair instead of the existing `fbdevWindowLinear`/
  `shadowUpdatePacked`(`Rotate`)/`fbdevUpdateFake24` choices. This is a pure
  `if/else` split alongside the pre-existing logic — the packed-pixel
  branch is otherwise untouched (just re-indented one level deeper).

### 6. Teardown — release I/O port permissions (`fbdevCardFini`, ~L875)

```c
if (priv->planar)
    ioperm (0x3c4, 2, 0);
```

Symmetric with step 1: drops the I/O privilege for ports `0x3c4`/`0x3c5`
before unmapping and closing the framebuffer, so the process doesn't hold
raw port access it no longer needs after the card is shut down.

### 7. Header changes (`fbdev.h`)

- `#include <sys/io.h>` — declares `ioperm()`/`outb()`, used by the new code
  in `fbdev.c`.
- `#include <sys/ioctl.h>` — already needed independently (present from the
  earlier `tinyxserver-fbdev-device.patch`); kept here since this patch is
  layered on top and regenerated against the post-device-patch tree.
- New `Bool planar;` field on `FbdevPriv`, with a comment explaining its
  purpose, so `fbdevScreenInit`, `fbdevWindowPlanar`, and `fbdevCardFini`
  (which run at different times, some via `KdScreenPriv`/`pScreenPriv->card->driver`
  rather than holding onto `priv` directly) can all agree on whether this
  card is planar without re-deriving it from `fix.type` repeatedly.

## How this fits into the rest of the boot chain

- `local/root/.xserverrc` switches the default X server invocation from
  `Xvesa -screen 640x480x8` to `exec Xfbdev :0 -cc 4 -fp /share/X11/fonts`.
  `-cc 4` requests a depth-4 (16-colour) visual class, matching the
  `screen->fb[0].depth = 4` this patch sets up for the planar path — Xfbdev
  auto-detects `vga16fb` via `fix.type` as described above, so `-cc 4` is
  about the requested visual, not about *triggering* planar mode.
- `scripts/build.sh` applies this patch (`tinyxserver-fbdev-vga16.patch`)
  after `tinyxserver-fbdev-device.patch` (the `FBDEVICE` env var patch,
  formerly `tinyxserver-fbdev.patch`) and before
  `tinyxserver-xvesa-vm86.patch`, so it always builds on top of a tree that
  already knows how to pick an arbitrary `/dev/fbN` via `$FBDEVICE` — useful
  since selecting `vga16fb` in practice is a matter of which fbdev node the
  kernel enumerates it as.
- The kernel-side prerequisite is `CONFIG_X86_IOPL_IOPERM` (enabled in this
  repo's kernel config per commit `46b2f4e`), without which the `ioperm()`
  call in step 1 above fails outright and `Xfbdev` refuses to start on a
  planar framebuffer.

## Summary of the design rationale

| Design choice | Why |
|---|---|
| Detect via `fix.type == FB_TYPE_VGA_PLANES` | Only kernel-provided signal that distinguishes planar from packed-pixel fbdev devices |
| Route through X's existing shadow-planar code instead of writing a custom blitter | `shadowUpdatePlanar4x8` already implements correct 4bpp→4-plane conversion; reimplementing it would duplicate well-tested X server code |
| Program Map Mask per-window-call rather than once | Each shadow flush chunk targets one specific plane (encoded in `offset`); the hardware has no way to accept a byte destined for a specific plane other than via the Map Mask, so it must be set right before each write region is handed back |
| `(offset >> 4) << 2`, not `offset >> 4` | `shadowUpdatePlanar4x8` operates in units of `CARD32` (4-byte) words per plane, not bytes; the shift-then-multiply is the correct unit conversion, and its absence is the bug this patch specifically fixes (invisible until `x >= 32`) |
| `ioperm`/`outb` instead of `/dev/port` or a kernel driver ioctl | Direct, standard, minimal-dependency way to reach VGA I/O ports from userspace on x86, matching how real VGA drivers (e.g. X.Org's `vga` driver) do it; requires the `CONFIG_X86_IOPL_IOPERM` kernel option already enabled in this repo |
| `softCursor = TRUE` | No hardware cursor path was implemented for planar mode; software cursor is the only option that actually renders |
| Force `shadow = TRUE` unconditionally for planar | There is no direct-write path that can work on planar memory, unlike rotation/FAKE24 which are opt-in reasons for shadow mode in the packed-pixel case |
