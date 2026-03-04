from PIL import Image, ImageDraw, ImageFont, ImageFilter
import math

SIZE = 1024
CORNER_RADIUS = 220

img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# 1. Draw background gradient (dark teal with center glow)
# Create rounded corner mask
mask = Image.new('L', (SIZE, SIZE), 0)
mask_draw = ImageDraw.Draw(mask)
mask_draw.rounded_rectangle([0, 0, SIZE, SIZE], radius=CORNER_RADIUS, fill=255)

# Fill base background
bg = Image.new('RGBA', (SIZE, SIZE), (4, 47, 46, 255))
bg_draw = ImageDraw.Draw(bg)

# Radial glow in center (simulate with concentric circles)
center_x, center_y = 512, 460
max_radius = 450
for r in range(max_radius, 0, -1):
    ratio = r / max_radius
    # From #0F766E at center to #042F2E at edge
    red = int(4 + (15 - 4) * (1 - ratio))
    green = int(47 + (118 - 47) * (1 - ratio))
    blue = int(46 + (110 - 46) * (1 - ratio))
    alpha = int(255 * (1 - ratio * 0.7))
    bg_draw.ellipse(
        [center_x - r, center_y - r, center_x + r, center_y + r],
        fill=(red, green, blue, alpha)
    )

# 2. Draw subtle concentric circles
bg_draw.ellipse([512-390, 512-390, 512+390, 512+390], outline=(19, 78, 74, 40), width=2)
bg_draw.ellipse([512-310, 512-310, 512+310, 512+310], outline=(19, 78, 74, 40), width=2)

# 3. Draw the glow behind the pin
glow_layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
glow_draw = ImageDraw.Draw(glow_layer)
# Draw a large soft ellipse for glow
for r in range(200, 0, -1):
    alpha = int(35 * (1 - r/200))
    glow_draw.ellipse(
        [512-r-60, 340-r-40, 512+r+60, 340+r+120],
        fill=(94, 234, 212, alpha)
    )
bg = Image.alpha_composite(bg, glow_layer)
bg_draw = ImageDraw.Draw(bg)

# 4. Draw the pin shape (teardrop)
pin_layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
pin_draw = ImageDraw.Draw(pin_layer)

pin_cx, pin_cy = 512, 330  # center of pin circle
pin_radius = 130
pin_tip_y = pin_cy + 300  # bottom tip of pin

# Draw pin body - circle part
pin_draw.ellipse(
    [pin_cx - pin_radius, pin_cy - pin_radius, pin_cx + pin_radius, pin_cy + pin_radius],
    fill=(20, 184, 166, 255)  # #14B8A6
)

# Draw pin pointer (triangle below circle)
pin_draw.polygon(
    [(pin_cx - 70, pin_cy + 100), (pin_cx, pin_tip_y), (pin_cx + 70, pin_cy + 100)],
    fill=(20, 184, 166, 255)
)

# Gradient overlay on pin (lighter at top)
for y_offset in range(-pin_radius, pin_radius):
    ratio = (y_offset + pin_radius) / (2 * pin_radius)
    r = int(94 * (1 - ratio) + 20 * ratio)
    g = int(234 * (1 - ratio) + 184 * ratio)
    b = int(212 * (1 - ratio) + 166 * ratio)
    y = pin_cy + y_offset
    # Calculate x range for this y within the circle
    dx = math.sqrt(max(0, pin_radius**2 - y_offset**2))
    pin_draw.line([(pin_cx - dx, y), (pin_cx + dx, y)], fill=(r, g, b, 255))

# Dark circle inside pin
pin_draw.ellipse(
    [pin_cx - 85, pin_cy - 85, pin_cx + 85, pin_cy + 85],
    fill=(4, 47, 46, 255)  # #042F2E
)

# W letter
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 110)
except:
    try:
        font = ImageFont.truetype("C:\\Windows\\Fonts\\arialbd.ttf", 110)
    except:
        font = ImageFont.load_default()

bbox = pin_draw.textbbox((0, 0), "W", font=font)
tw = bbox[2] - bbox[0]
th = bbox[3] - bbox[1]
pin_draw.text(
    (pin_cx - tw // 2, pin_cy - th // 2 - 8),
    "W",
    fill=(94, 234, 212, 255),  # #5EEAD4
    font=font
)

bg = Image.alpha_composite(bg, pin_layer)
bg_draw = ImageDraw.Draw(bg)

# 5. Draw wave lines below pin
wave_layer = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
wave_draw = ImageDraw.Draw(wave_layer)

def draw_wave(draw_obj, y_center, amplitude, color, width, points=100):
    coords = []
    for i in range(points + 1):
        x = 256 + (512 * i / points)
        y = y_center + amplitude * math.sin(2 * math.pi * i / points)
        coords.append((x, y))
    for i in range(len(coords) - 1):
        draw_obj.line([coords[i], coords[i+1]], fill=color, width=width)

draw_wave(wave_draw, 700, 15, (94, 234, 212, 76), 10)   # First wave - brightest
draw_wave(wave_draw, 740, 12, (20, 184, 166, 50), 8)     # Second wave
draw_wave(wave_draw, 775, 10, (13, 148, 136, 38), 6)     # Third wave

# Small dot on first wave
wave_draw.ellipse([500, 688, 524, 712], fill=(94, 234, 212, 127))

bg = Image.alpha_composite(bg, wave_layer)

# Apply rounded corner mask
output = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
output.paste(bg, (0, 0), mask)

# Save
output.save('assets/icon/wayture_icon_1024.png', 'PNG')
print("Icon saved: assets/icon/wayture_icon_1024.png")
print("Done!")
