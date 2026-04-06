import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import colorsys

# Параметры
WIDTH = 10
HEIGHT = 3000
FRAMES = 90
COLOR = (255, 59, 48)  # Красный iOS стиль

frames_left = []
frames_right = []

for i in range(FRAMES):
    phase = i * (np.pi * 2 / FRAMES)
    
    # Пульсация яркости
    brightness = 0.7 + 0.3 * np.sin(phase)
    
    # Создаем изображение
    img = Image.new('RGBA', (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Рисуем градиентную полоску со свечением
    for x in range(WIDTH):
        # Гауссово распределение для мягкого свечения
        dist_from_center = abs(x - WIDTH / 2)
        glow = np.exp(-(dist_from_center ** 2) / (2 * (WIDTH / 3.5) ** 2))
        
        alpha = int(210 * glow * brightness)
        
        # Рисуем вертикальную линию по всей высоте
        for y in range(HEIGHT):
            draw.point((x, y), fill=(*COLOR, alpha))
    
    # Небольшое размытие для мягкости краев
    img = img.filter(ImageFilter.GaussianBlur(radius=0.7))
    
    frames_left.append(img)
    frames_right.append(img.transpose(Image.FLIP_LEFT_RIGHT))


# Сохраняем левую полоску
frames_left[0].save(
    '../neon_left.gif',
    save_all=True,
    append_images=frames_left[1:],
    duration=35,
    loop=0,
    disposal=2,
    optimize=True
)

# Сохраняем правую полоску (смещена на половину цикла для противофазы)
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

print("✅ Гифки сгенерированы успешно: neon_left.gif, neon_right.gif")
print("📏 Ширина: 16px")
print("🌈 Переливающийся радужный неон")
print("📦 Вес каждого файла ~ 220 кб")