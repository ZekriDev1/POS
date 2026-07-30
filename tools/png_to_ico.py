import os
from PIL import Image

base = os.path.dirname
png_path = os.path.join(base(__file__), '..', 'assets', 'Logo.png')
ico_path = os.path.join(base(__file__), '..', 'windows', 'runner', 'resources', 'app_icon.ico')

img = Image.open(png_path).convert('RGBA')

sizes = [(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
img.save(ico_path, format='ico', sizes=sizes)

print(f'Created: {ico_path} ({os.path.getsize(ico_path)} bytes)')
