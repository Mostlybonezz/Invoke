"""Original geometric Invoke mark; requires Pillow. No reference image pixels used."""
from pathlib import Path
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[1]
size, scale = 1024, 2
image = Image.new('RGB', (size*scale, size*scale), '#F6F1E6')
draw = ImageDraw.Draw(image)
def box(values): return tuple(int(x*scale) for x in values)
draw.ellipse(box((142,142,882,882)), fill='#6D202B')
draw.ellipse(box((163,163,861,861)), outline='#C49C8E', width=2*scale)
draw.ellipse(box((176,176,848,848)), outline='#A96065', width=scale)
points=[(512,245),(548,466),(717,512),(548,558),(512,779),(476,558),(307,512),(476,466)]
draw.polygon([(x*scale,y*scale) for x,y in points],fill='#F7ECDD')
draw.ellipse(box((410,410,614,614)),outline='#F7ECDD',width=2*scale)
for x,y in [(300,330),(716,345),(700,693),(310,697)]:
 draw.line(box((x-9,y,x+9,y)), fill='#F7ECDD',width=2*scale)
 draw.line(box((x,y-13,x,y+13)),fill='#F7ECDD',width=2*scale)
image.resize((size,size),Image.Resampling.LANCZOS).save(ROOT/'Invoke/Assets.xcassets/AppIcon.appiconset/Invoke.png')
print('Rendered original opaque 1024px Invoke app icon.')
