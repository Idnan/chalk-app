#!/usr/bin/env python3
"""Regenerates the app icon set and the menu bar template images from the SVGs in Design/.
Requires rsvg-convert (brew install librsvg). Run: python3 scripts/generate-icons.py
Source glyphs: koboyo.com "cartoon-blackboard-chalk" and "cartoon-chalk-stick" (free for commercial use, no attribution)."""
import re, subprocess, json, os, pathlib
P = pathlib.Path(__file__).resolve().parent.parent
D = P/'Design'
ICONSET = P/'Chalk/Resources/Assets.xcassets/AppIcon.appiconset'
XC = P/'Chalk/Resources/Assets.xcassets'

def glyph(path, x, y, w, h, color):
    s = open(path).read()
    s = re.sub(r'\s*aria-label="[^"]*"', '', s)
    s = s.replace('fill="currentColor"', f'fill="{color}"', 1)
    s = s.replace('<svg ', f'<svg x="{x}" y="{y}" width="{w}" height="{h}" preserveAspectRatio="xMidYMid meet" ', 1)
    return s

bb = glyph(D/'cartoon-blackboard-chalk.svg', 210, 210, 604, 604, '#F4EFE4')
shadow = glyph(D/'cartoon-blackboard-chalk.svg', 210, 222, 604, 604, '#000000')
app_svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#3B7A5C"/><stop offset="1" stop-color="#1E4A36"/>
  </linearGradient>
  <linearGradient id="gloss" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#ffffff" stop-opacity="0.16"/><stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
  </linearGradient>
  <clipPath id="clip"><rect x="100" y="100" width="824" height="824" rx="185" ry="185"/></clipPath>
</defs>
<rect x="100" y="100" width="824" height="824" rx="185" ry="185" fill="url(#bg)"/>
<g clip-path="url(#clip)">
  <rect x="100" y="100" width="824" height="412" fill="url(#gloss)"/>
  <rect x="100" y="100" width="824" height="824" rx="185" ry="185" fill="none" stroke="#000" stroke-opacity="0.35" stroke-width="16"/>
  <rect x="112" y="112" width="800" height="800" rx="176" ry="176" fill="none" stroke="#fff" stroke-opacity="0.12" stroke-width="6"/>
</g>
<g opacity="0.35">{shadow}</g>
{bb}
</svg>'''
open(D/'appicon.svg','w').write(app_svg)
sizes = [(16,1),(16,2),(32,1),(32,2),(128,1),(128,2),(256,1),(256,2),(512,1),(512,2)]
images = []
for pt, scale in sizes:
    px = pt*scale
    name = f'icon_{pt}x{pt}@{scale}x.png'
    subprocess.run(['rsvg-convert','-w',str(px),'-h',str(px),str(D/'appicon.svg'),'-o',str(ICONSET/name)], check=True)
    images.append({"filename": name, "idiom": "mac", "scale": f"{scale}x", "size": f"{pt}x{pt}"})
json.dump({"images": images, "info": {"author": "xcode", "version": 1}}, open(ICONSET/'Contents.json','w'), indent=2)

def menubar(name, badge):
    # Menu bar wants a solid silhouette, so keep only the outer subpath of the chalk stick (the rest are outline cutouts).
    body = glyph(D/'cartoon-chalk-stick.svg', 1, 1, 16, 16, '#000000')
    d = re.search(r'd="([^"]*)"', body.replace('\n', ' ')).group(1)
    outer = re.split(r'(?<=[zZ])\s*(?=[mM])', d.strip())[0]
    body = re.sub(r'd="[^"]*"', 'd="' + outer + '"', body.replace('\n', ' '), count=1)
    mask = ''
    extra = ''
    if badge:
        mask = '<mask id="m"><rect width="18" height="18" fill="#fff"/><circle cx="14.5" cy="14.5" r="6" fill="#000"/></mask>'
        body = f'<g mask="url(#m)">{body}</g>'
    if badge == 'draw':
        extra = '<circle cx="14.5" cy="14.5" r="4" fill="#000"/>'
    elif badge == 'freeze':
        extra = '<circle cx="14.5" cy="14.5" r="3.6" fill="none" stroke="#000" stroke-width="1.6"/>'
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 18 18"><defs>{mask}</defs>{body}{extra}</svg>'
    d = XC/f'{name}.imageset'; d.mkdir(exist_ok=True)
    for scale in (1,2):
        subprocess.run(['rsvg-convert','-w',str(18*scale),'-h',str(18*scale),'-o',str(d/f'{name}@{scale}x.png')], input=svg.encode(), check=True)
    json.dump({"images":[{"filename":f"{name}@1x.png","idiom":"universal","scale":"1x"},{"filename":f"{name}@2x.png","idiom":"universal","scale":"2x"}],
               "info":{"author":"xcode","version":1},"properties":{"template-rendering-intent":"template"}}, open(d/'Contents.json','w'), indent=2)
menubar('MenuBarOff', None)
menubar('MenuBarDraw', 'draw')
menubar('MenuBarFreeze', 'freeze')
print('icons written to', XC)
