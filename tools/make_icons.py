"""Generates the PWA icons. Run: python tools/make_icons.py  (needs Pillow).
Opaque RGB, not pre-rounded — iOS/Android apply their own mask."""
from PIL import Image, ImageDraw
ACC=(217,119,87)
def icon(size, scale=1.0):
    S=size*4; im=Image.new('RGB',(S,S),(0,0,0)); d=ImageDraw.Draw(im)
    c=S/2; r=S*0.30*scale; w=S*0.055*scale
    d.ellipse([c-r,c-r,c+r,c+r], outline=ACC, width=int(w))          # clock face
    d.line([c,c,c,c-r*0.62], fill=ACC, width=int(w))                   # minute hand
    d.line([c,c,c+r*0.48,c+r*0.20], fill=ACC, width=int(w))            # hour hand
    d.ellipse([c-w*0.75,c-w*0.75,c+w*0.75,c+w*0.75], fill=ACC)
    p=S*0.075*scale; px,py=c+r*0.92,c-r*0.92                           # the "+" of overtime
    d.line([px-p,py,px+p,py], fill=(239,239,237), width=int(w*0.9))
    d.line([px,py-p,px,py+p], fill=(239,239,237), width=int(w*0.9))
    return im.resize((size,size), Image.LANCZOS)
icon(180).save('icon-180.png'); icon(192).save('icon-192.png'); icon(512).save('icon-512.png')
icon(512, 0.78).save('icon-512-maskable.png')
