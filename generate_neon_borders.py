import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import colorsys

# Параметры
WIDTH = 10
HEIGHT = 3000
FRAMES = 90

frames_left = []
frames_right = []

for i in range(FRAMES):
    phase = i * (np.pi * 2 / FRAMES)
    
    # Пульсация яркости
    brightness = 0.7 + 0.3 * np.sin(phase)
    
    # ✅ RGB-перелив через hue
    hue = (i / FRAMES) % 1.0
    r, g, b = colorsys.hsv_to_rgb(hue, 1.0, 1.0)
    COLOR = (int(r * 255), int(g * 255), int(b * 255))
    
    img = Image.new('RGBA', (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    for x in range(WIDTH):
        dist_from_center = abs(x - WIDTH / 2)
        glow = np.exp(-(dist_from_center ** 2) / (2 * (WIDTH / 3.5) ** 2))
        alpha = int(210 * glow * brightness)
        
        for y in range(HEIGHT):
            draw.point((x, y), fill=(*COLOR, alpha))
    
    img = img.filter(ImageFilter.GaussianBlur(radius=0.7))
    
    frames_left.append(img)
    frames_right.append(img.transpose(Image.FLIP_LEFT_RIGHT))


frames_left[0].save(
    '../neon_left.gif',
    save_all=True,
    append_images=frames_left[1:],
    duration=35,
    loop=0,
    disposal=2,
    optimize=True
)

frames_right = frames_right[FRAMES//2:] + frames_right[:FRAMES//2]
frames_right[0].save(
    '../neon_right.gif',
    save_all=True,
    append_images=frames_right[1:],
    duration=35,
    loop=0,
    disposal=2,
    optimize=True
)

print("✅ Гифки сгенерированы: neon_left.gif, neon_right.gif")
print(f"📏 Ширина: {WIDTH}px")
print("🌈 Переливающийся радужный неон")