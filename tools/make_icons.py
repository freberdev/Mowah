#!/usr/bin/env python3
"""Draws Mowah's icons: .ico files for Windows into windows/res/, and the app
icon and menu bar icons for the Mac into the asset catalog under macos/.

Run from the repository root:  python3 tools/make_icons.py [preview.png]
Needs Pillow. The optional argument writes a contact sheet for eyeballing.
"""
import io
import json
import struct
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "windows" / "res"
MAC_ASSETS = ROOT / "macos" / "Mowah" / "Resources" / "Assets.xcassets"

ACTIVE = ((108, 76, 255), (20, 200, 176))    # indigo -> teal
PAUSED = ((150, 155, 165), (92, 97, 108))    # light grey -> dark grey

# Pointer outline on a 24-unit grid: tip at top-left, tail to the lower right.
POINTER = [(5.2, 4.6), (10.9, 19.6), (13.3, 13.5), (19.4, 11.1)]


def gradient(size, colors):
    """Diagonal gradient, top-left to bottom-right."""
    small = 64
    ramp = Image.new("L", (small, small))
    ramp.putdata([int(255 * (x + y) / (2 * small - 2)) for y in range(small) for x in range(small)])
    ramp = ramp.resize((size, size), Image.BICUBIC)
    start = Image.new("RGBA", (size, size), colors[0] + (255,))
    end = Image.new("RGBA", (size, size), colors[1] + (255,))
    return Image.composite(end, start, ramp)


def pointer_mask(size, scale, offset=(0.0, 0.0)):
    """White-on-black mask of the pointer with softly rounded corners."""
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    unit = size / 24 * scale
    shift = (24 - 24 * scale) / 2 * size / 24
    pts = [(shift + x * unit + offset[0], shift + y * unit + offset[1]) for x, y in POINTER]
    draw.polygon(pts, fill=255)
    stroke = max(1, round(unit * 1.5))
    draw.line(pts + [pts[0]], fill=255, width=stroke, joint="curve")
    for x, y in pts:
        draw.ellipse((x - stroke / 2, y - stroke / 2, x + stroke / 2, y + stroke / 2), fill=255)
    return mask


def motion_arcs(size):
    """Two short arcs behind the pointer's tail, suggesting a wiggle."""
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    centre = size * 0.56
    for radius, width, level in ((0.275, 0.042, 235), (0.375, 0.040, 150)):
        r = size * radius
        draw.arc((centre - r, centre - r, centre + r, centre + r), start=20, end=70,
                 fill=level, width=max(1, round(size * width)))
    return mask


def render(size, colors):
    """One square RGBA image of the icon at the given pixel size."""
    factor = 8 if size <= 64 else 4
    big = size * factor
    tiny = size < 32

    badge = Image.new("L", (big, big), 0)
    inset = 0 if tiny else big * 0.035
    ImageDraw.Draw(badge).rounded_rectangle(
        (inset, inset, big - 1 - inset, big - 1 - inset), radius=big * (0.24 if tiny else 0.225), fill=255)

    icon = gradient(big, colors)

    # Tiny sizes get a bigger pointer and no decoration so they stay legible in the tray.
    scale = 1.08 if tiny else 0.86
    nudge = (0, 0) if tiny else (-big * 0.035, -big * 0.035)
    pointer = pointer_mask(big, scale, nudge)

    if not tiny:
        arcs = motion_arcs(big)
        icon = Image.composite(Image.new("RGBA", (big, big), (255, 255, 255, 255)), icon, arcs)

    shadow = pointer_mask(big, scale, (nudge[0] + big * 0.02, nudge[1] + big * 0.035))
    shadow = shadow.filter(ImageFilter.GaussianBlur(big * 0.025)).point(lambda v: v * 0.38)
    icon = Image.composite(Image.new("RGBA", (big, big), (20, 16, 60, 255)), icon, shadow)
    icon = Image.composite(Image.new("RGBA", (big, big), (255, 255, 255, 255)), icon, pointer)

    icon.putalpha(badge)
    return icon.resize((size, size), Image.LANCZOS)


def bmp_entry(image):
    """32-bit DIB payload for an .ico entry: header, BGRA rows bottom-up, 1-bit mask."""
    width, height = image.size
    header = struct.pack("<IiiHHIIiiII", 40, width, height * 2, 1, 32, 0, 0, 0, 0, 0, 0)
    pixels = image.tobytes("raw", "BGRA")
    rows = [pixels[y * width * 4:(y + 1) * width * 4] for y in range(height)]
    alpha = image.getchannel("A").point(lambda a: 255 if a == 0 else 0).convert("1")
    row_bytes = ((width + 31) // 32) * 4
    mask_rows = []
    raw_mask = alpha.tobytes()
    packed = (width + 7) // 8
    for y in range(height):
        row = raw_mask[y * packed:(y + 1) * packed]
        mask_rows.append(row + b"\x00" * (row_bytes - len(row)))
    return header + b"".join(reversed(rows)) + b"".join(reversed(mask_rows))


def png_entry(image):
    buffer = io.BytesIO()
    image.save(buffer, format="PNG", optimize=True)
    return buffer.getvalue()


def write_ico(path, images):
    entries = [(im, png_entry(im) if im.width >= 256 else bmp_entry(im)) for im in images]
    out = struct.pack("<HHH", 0, 1, len(entries))
    offset = 6 + 16 * len(entries)
    for im, data in entries:
        dim = 0 if im.width >= 256 else im.width
        out += struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(data), offset)
        offset += len(data)
    for _, data in entries:
        out += data
    path.write_bytes(out)
    print(f"{path.name}: {len(out)} bytes, sizes {[im.width for im in images]}")


def contact_sheet(path):
    sheet = Image.new("RGBA", (1180, 640), (243, 243, 243, 255))
    dark = Image.new("RGBA", (1180, 320), (32, 32, 32, 255))
    sheet.paste(dark, (0, 320))
    for row, colors in enumerate((ACTIVE, PAUSED)):
        y = 20 + row * 320
        x = 20
        sheet.alpha_composite(render(256, colors), (x, y))
        x += 290
        for size in (64, 48, 32, 24, 16):
            sheet.alpha_composite(render(size, colors), (x, y))
            # Enlarged copy so the pixel grid of the small sizes can be judged.
            zoom = render(size, colors).resize((size * 4, size * 4), Image.NEAREST)
            if size <= 32:
                sheet.alpha_composite(zoom, (x, y + 90))
            x += max(size, size * 4 if size <= 32 else size) + 30
    sheet.save(path)
    print(f"preview: {path}")


def render_mac_app_icon(pixels):
    """The app icon for the Mac. macOS icons leave a margin around the shape, so
    the badge fills 82 % of the canvas, the proportion of Apple's own icon grid."""
    inner = round(pixels * 0.82)
    canvas = Image.new("RGBA", (pixels, pixels), (0, 0, 0, 0))
    offset = (pixels - inner) // 2
    canvas.alpha_composite(render(inner, ACTIVE), (offset, offset))
    return canvas


def render_menu_bar_icon(pixels, opacity=1.0, dot=False):
    """The pointer alone, black on transparent. The menu bar tints it, so only the
    transparency matters: a fainter icon means Mowah is resting, and a dot in the
    corner means it needs the user's attention."""
    big = pixels * 8
    mask = pointer_mask(big, 1.1)
    if dot:
        draw = ImageDraw.Draw(mask)
        cx, cy, r = big * 0.85, big * 0.15, big * 0.13
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    mask = mask.resize((pixels, pixels), Image.LANCZOS).point(lambda v: round(v * opacity))
    icon = Image.new("RGBA", (pixels, pixels), (0, 0, 0, 0))
    icon.putalpha(mask)
    return icon


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def write_mac_assets():
    info = {"author": "xcode", "version": 1}
    MAC_ASSETS.mkdir(parents=True, exist_ok=True)
    write_json(MAC_ASSETS / "Contents.json", {"info": info})

    app_icon = MAC_ASSETS / "AppIcon.appiconset"
    app_icon.mkdir(exist_ok=True)
    images = []
    for points in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            pixels = points * scale
            name = f"icon_{pixels}.png"
            render_mac_app_icon(pixels).save(app_icon / name)
            images.append({"filename": name, "idiom": "mac", "scale": f"{scale}x", "size": f"{points}x{points}"})
    write_json(app_icon / "Contents.json", {"images": images, "info": info})

    # 18 points is the height macOS draws menu bar icons at.
    variants = {"MenuBarIcon": {}, "MenuBarIconResting": {"opacity": 0.4}, "MenuBarIconAttention": {"dot": True}}
    for name, options in variants.items():
        folder = MAC_ASSETS / f"{name}.imageset"
        folder.mkdir(exist_ok=True)
        images = []
        for scale in (1, 2):
            filename = f"{name}@{scale}x.png"
            render_menu_bar_icon(18 * scale, **options).save(folder / filename)
            images.append({"filename": filename, "idiom": "mac", "scale": f"{scale}x"})
        write_json(folder / "Contents.json", {
            "images": images,
            "info": info,
            "properties": {"template-rendering-intent": "template"},
        })
    print(f"{MAC_ASSETS.relative_to(ROOT)}: app icon in 10 sizes, {len(variants)} menu bar icons")


def main():
    RES.mkdir(exist_ok=True)
    write_ico(RES / "mowah.ico", [render(s, ACTIVE) for s in (16, 20, 24, 32, 40, 48, 64, 256)])
    write_ico(RES / "mowah-paused.ico", [render(s, PAUSED) for s in (16, 20, 24, 32, 40, 48)])
    write_mac_assets()
    if len(sys.argv) > 1:
        contact_sheet(Path(sys.argv[1]))


if __name__ == "__main__":
    main()
