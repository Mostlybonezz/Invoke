"""Original geometric Invoke mark; requires Pillow. No reference image pixels used."""
from pathlib import Path
from PIL import Image, ImageDraw
import math
ROOT = Path(__file__).resolve().parents[1]
size, scale = 1024, 2
image = Image.new('RGB', (size, size))
pixels = image.load()
for y in range(size):
 for x in range(size):
  glow = max(0, 1 - math.hypot((x-512)/750, (y-430)/850))
  pixels[x,y] = (int(10+19*glow), int(17+24*glow), int(35+45*glow))
image = image.resize((size*scale, size*scale), Image.Resampling.BICUBIC)
draw = ImageDraw.Draw(image)
def box(values): return tuple(int(x*scale) for x in values)
draw.ellipse(box((142,142,882,882)), fill='#18233F')
draw.ellipse(box((163,163,861,861)), outline='#EC8F57', width=3*scale)
draw.ellipse(box((177,177,847,847)), outline='#825144', width=scale)
points=[(512,245),(548,466),(717,512),(548,558),(512,779),(476,558),(307,512),(476,466)]
draw.polygon([(x*scale,y*scale) for x,y in points],fill='#FFA76C')
draw.ellipse(box((410,410,614,614)),outline='#FFD2AC',width=2*scale)
for x,y in [(300,330),(716,345),(700,693),(310,697)]:
 draw.line(box((x-9,y,x+9,y)), fill='#FFD2AC',width=2*scale)
 draw.line(box((x,y-13,x,y+13)),fill='#FFD2AC',width=2*scale)
image.resize((size,size),Image.Resampling.LANCZOS).save(ROOT/'Invoke/Assets.xcassets/AppIcon.appiconset/Invoke.png')
print('Rendered original opaque 1024px Invoke app icon.')
