# Diq identity and floating restore

The mark combines a geometric D outline with a short Q-like diagonal signature.
Ivory (#F0EBE0) and muted champagne (#C1AD8B) sit on the existing charcoal surface.
`ui/blocks/BrandMark.lua` draws overlapping filled silhouettes in the title bar
and minimized button. It avoids joining clipped UIStroke arcs to thin bars, which
showed visible seams in the live client. The inner cutout follows the actual
surface color, including hover changes. No upload, downloaded icon or
executor-specific image loader is needed.

The header shows only the logo and window controls. Its transparent drag area
covers the logo and blank center. `SetTitle` still updates `Window.Title` metadata,
but neither it nor tab switching adds the old `Diq / Tab` text back to the header.

Exports in `assets/`: `diq-mark.svg`, transparent `diq-mark.png`, and
`diq-badge-preview.png`. The last file is a design preview, not a live Roblox
screenshot. `tools/render_brand.ps1` regenerates the PNGs from the same geometry.

The sidebar footer shows the local player's circular headshot, DisplayName and
@username. Narrow navigation shows only the portrait. Thumbnail retrieval uses
Players:GetUserThumbnailAsync with up to three readiness attempts. Initials remain
visible until the image loads, or as fallback after failure. The UI owns and cancels
the thumbnail task and display-name/image listeners on teardown.

Minimize creates a 56 x 56 logo button. Click/tap to restore, or drag to reposition
using mouse/touch. Six pixels distinguish a drag from a click. Dragging cannot
restore the window on release. Position is retained within the current session,
clamped to the GUI safe area, and becomes the next minimize/restore animation's
origin/destination. It is not persisted to a profile or disk.

K, SelectTab, Stop/close cleanup and maximize state keep their existing behavior.
Hiding, focus loss, viewport changes and closing cancel active logo drags. Only
the initiating touch may move the logo. Gamepad Activated can also restore it.

`Brand.spec.luau` covers thumbnail readiness/failure/cancellation, compact account
layout, rename, mouse/touch dragging, click suppression in both event orders,
viewport clamping, remembered position, hide/focus cancellation and resource
cleanup. These are mock checks. Live acceptance still needs avatar loading,
small-size logo readability, pointer/touch event ordering and narrow layouts.
