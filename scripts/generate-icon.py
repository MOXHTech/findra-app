#!/usr/bin/env python3
import math
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ICONSET = ROOT / "build" / "Findra.iconset"
ICNS = ROOT / "Resources" / "Findra.icns"
PREVIEW = ROOT / "Resources" / "FindraIcon.png"


def rounded_rectangle_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    return mask


def lerp(a, b, t):
    return int(a + (b - a) * t)


def gradient(size, top, bottom):
    image = Image.new("RGBA", (size, size))
    px = image.load()
    for y in range(size):
        t = y / max(size - 1, 1)
        color = tuple(lerp(top[i], bottom[i], t) for i in range(4))
        for x in range(size):
            px[x, y] = color
    return image


def draw_icon(size):
    scale = size / 1024
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    pad = int(72 * scale)
    radius = int(220 * scale)
    shadow_draw.rounded_rectangle(
        (pad, int(86 * scale), size - pad, size - int(54 * scale)),
        radius=radius,
        fill=(0, 0, 0, 135),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(int(26 * scale)))
    canvas.alpha_composite(shadow)

    body_box = (pad, pad, size - pad, size - pad)
    body = gradient(size, (13, 30, 35, 255), (7, 15, 19, 255))
    mask = rounded_rectangle_mask(size, radius)
    cropped_mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(cropped_mask).rounded_rectangle(body_box, radius=radius, fill=255)
    body.putalpha(cropped_mask)
    canvas.alpha_composite(body)

    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(
        body_box,
        radius=radius,
        outline=(92, 247, 255, 68),
        width=max(2, int(6 * scale)),
    )

    # Subtle index grid: the app searches a local file graph, not the web.
    grid = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    grid_draw = ImageDraw.Draw(grid)
    grid_color = (102, 220, 224, 42)
    for i in range(-2, 8):
        x = int((120 + i * 120) * scale)
        grid_draw.line(
            (x, int(190 * scale), x + int(420 * scale), int(835 * scale)),
            fill=grid_color,
            width=max(1, int(2 * scale)),
        )
    for i in range(6):
        y = int((220 + i * 105) * scale)
        grid_draw.line(
            (int(170 * scale), y, int(840 * scale), y),
            fill=grid_color,
            width=max(1, int(2 * scale)),
        )
    grid.putalpha(Image.composite(grid.getchannel("A"), Image.new("L", (size, size), 0), cropped_mask))
    canvas.alpha_composite(grid)
    draw = ImageDraw.Draw(canvas)

    cx, cy = int(498 * scale), int(500 * scale)
    outer = int(270 * scale)
    inner = int(145 * scale)
    cyan = (43, 218, 234, 255)
    gold = (255, 205, 68, 255)
    teal_shadow = (6, 84, 91, 150)

    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse((cx - outer, cy - outer, cx + outer, cy + outer), outline=(38, 231, 245, 150), width=int(32 * scale))
    glow_draw.ellipse((cx - inner, cy - inner, cx + inner, cy + inner), outline=(255, 209, 72, 120), width=int(24 * scale))
    glow = glow.filter(ImageFilter.GaussianBlur(int(16 * scale)))
    canvas.alpha_composite(glow)
    draw = ImageDraw.Draw(canvas)

    draw.arc(
        (cx - outer, cy - outer, cx + outer, cy + outer),
        start=148,
        end=382,
        fill=cyan,
        width=max(8, int(54 * scale)),
    )
    draw.arc(
        (cx - outer, cy - outer, cx + outer, cy + outer),
        start=-38,
        end=92,
        fill=gold,
        width=max(8, int(54 * scale)),
    )
    draw.arc(
        (cx - inner, cy - inner, cx + inner, cy + inner),
        start=202,
        end=496,
        fill=gold,
        width=max(6, int(42 * scale)),
    )
    draw.arc(
        (cx - inner, cy - inner, cx + inner, cy + inner),
        start=20,
        end=165,
        fill=cyan,
        width=max(6, int(42 * scale)),
    )

    # Finder-like target dots make the mark distinct at Dock size.
    dot_r = int(48 * scale)
    for x, y, color in [
        (int(390 * scale), int(580 * scale), cyan),
        (int(590 * scale), int(410 * scale), gold),
    ]:
        draw.ellipse((x - dot_r, y - dot_r, x + dot_r, y + dot_r), fill=teal_shadow)
        draw.ellipse((x - int(34 * scale), y - int(34 * scale), x + int(34 * scale), y + int(34 * scale)), fill=color)

    # Search handle, tucked under the index ring.
    angle = math.radians(42)
    handle_start = (cx + int(math.cos(angle) * 206 * scale), cy + int(math.sin(angle) * 206 * scale))
    handle_end = (cx + int(math.cos(angle) * 356 * scale), cy + int(math.sin(angle) * 356 * scale))
    draw.line((handle_start[0], handle_start[1], handle_end[0], handle_end[1]), fill=(238, 250, 250, 235), width=max(8, int(42 * scale)))
    draw.line((handle_start[0], handle_start[1], handle_end[0], handle_end[1]), fill=(43, 218, 234, 255), width=max(6, int(24 * scale)))

    highlight = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    highlight_mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(highlight_mask).rounded_rectangle(body_box, radius=radius, fill=255)
    highlight_draw = ImageDraw.Draw(highlight)
    highlight_draw.arc(
        (int(150 * scale), int(126 * scale), int(874 * scale), int(760 * scale)),
        start=205,
        end=292,
        fill=(255, 255, 255, 80),
        width=max(2, int(7 * scale)),
    )
    highlight.putalpha(Image.composite(highlight.getchannel("A"), Image.new("L", (size, size), 0), highlight_mask))
    canvas.alpha_composite(highlight)

    return canvas


def main():
    if shutil.which("iconutil") is None:
        print("iconutil is required on macOS", file=sys.stderr)
        return 1

    if ICONSET.exists():
        shutil.rmtree(ICONSET)
    ICONSET.mkdir(parents=True)
    ICNS.parent.mkdir(parents=True, exist_ok=True)

    base = draw_icon(1024)
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    base.save(PREVIEW)

    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png"),
    ]
    for pixels, name in sizes:
        base.resize((pixels, pixels), Image.Resampling.LANCZOS).save(ICONSET / name)

    subprocess.run(["iconutil", "-c", "icns", str(ICONSET), "-o", str(ICNS)], check=True)
    print(ICNS)
    print(PREVIEW)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
