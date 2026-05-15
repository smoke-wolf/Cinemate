#!/usr/bin/env python3
"""Generate Cinemate app icon as .icns"""
from PIL import Image, ImageDraw, ImageFont
import subprocess, os, shutil

SIZE = 1024

img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Rounded rectangle background - dark gradient
for y in range(SIZE):
    r = int(15 + (y / SIZE) * 10)
    g = int(2 + (y / SIZE) * 3)
    b = int(2 + (y / SIZE) * 3)
    draw.line([(80, y), (SIZE - 80, y)], fill=(r, g, b, 255))

# Draw rounded rect mask
mask = Image.new('L', (SIZE, SIZE), 0)
mask_draw = ImageDraw.Draw(mask)
mask_draw.rounded_rectangle([60, 60, SIZE - 60, SIZE - 60], radius=180, fill=255)
bg = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
bg_draw = ImageDraw.Draw(bg)

# Gradient background
for y in range(SIZE):
    t = y / SIZE
    r = int(18 * (1 - t) + 8 * t)
    g = int(2 * (1 - t) + 2 * t)
    b = int(4 * (1 - t) + 8 * t)
    bg_draw.line([(0, y), (SIZE, y)], fill=(r, g, b, 255))

bg.putalpha(mask)
img = bg

draw = ImageDraw.Draw(img)

# Red/orange gradient bar at top (like Netflix branding)
for y in range(160, 200):
    t = (y - 160) / 40
    r_val = int(229 * (1 - t) + 255 * t)
    g_val = int(9 * (1 - t) + 100 * t)
    b_val = int(20 * (1 - t) + 0 * t)
    draw.line([(180, y), (SIZE - 180, y)], fill=(r_val, g_val, b_val, 255))

# Play triangle
play_points = [(380, 350), (380, 700), (720, 525)]
draw.polygon(play_points, fill=(229, 9, 20, 255))

# Inner play triangle (lighter)
inner_points = [(410, 390), (410, 660), (680, 525)]
draw.polygon(inner_points, fill=(255, 50, 50, 255))

# "M" letter at top
try:
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 160)
except:
    font = ImageFont.load_default()

bbox = draw.textbbox((0, 0), "M", font=font)
tw = bbox[2] - bbox[0]
draw.text(((SIZE - tw) // 2, 100), "M", fill=(229, 9, 20, 255), font=font)

# Film strip lines on sides
for i in range(6):
    y = 300 + i * 80
    draw.rectangle([100, y, 140, y + 40], fill=(40, 40, 40, 200))
    draw.rectangle([SIZE - 140, y, SIZE - 100, y + 40], fill=(40, 40, 40, 200))

# Save as PNG first
png_path = "/Users/maliqbarnard/pipeline/cinemate/icon/icon_1024.png"
img.save(png_path)

# Create iconset
iconset = "/Users/maliqbarnard/pipeline/cinemate/icon/Cinemate.iconset"
if os.path.exists(iconset):
    shutil.rmtree(iconset)
os.makedirs(iconset)

sizes = [16, 32, 64, 128, 256, 512, 1024]
for s in sizes:
    resized = img.resize((s, s), Image.LANCZOS)
    resized.save(os.path.join(iconset, f"icon_{s}x{s}.png"))
    if s <= 512:
        double = img.resize((s * 2, s * 2), Image.LANCZOS)
        double.save(os.path.join(iconset, f"icon_{s}x{s}@2x.png"))

# Convert to icns
icns_path = "/Users/maliqbarnard/pipeline/cinemate/icon/Cinemate.icns"
subprocess.run(["iconutil", "-c", "icns", iconset, "-o", icns_path], check=True)
print(f"Icon created: {icns_path}")
