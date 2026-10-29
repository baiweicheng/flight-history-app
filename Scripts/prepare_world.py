#!/usr/bin/env python3
"""Convert the approved Natural Earth / atlas reference into native Mercator rings."""
import json, re, math
from pathlib import Path
html=Path('.project-context/design/flight-history-ui.html').read_text()
topo=json.loads(re.search(r'<script[^>]+id="fh-world-data"[^>]*>(.*?)</script>', html, re.S).group(1))
sx,sy=topo['transform']['scale']; tx,ty=topo['transform']['translate']
arcs=[]
for arc in topo['arcs']:
    x=y=0; points=[]
    for dx,dy in arc:
        x+=dx; y+=dy; points.append([x*sx+tx,y*sy+ty])
    arcs.append(points)
def ring(indices):
    points=[]
    for i in indices:
        a=arcs[i] if i>=0 else list(reversed(arcs[~i]))
        points.extend(a if not points else a[1:])
    return [[round((lon+180)/360,7), round((1-math.asinh(math.tan(math.radians(max(-85.05112878,min(85.05112878,lat)))))/math.pi)/2,7)] for lon,lat in points]
rings=[]
for g in topo['objects']['features']['geometries']:
    if g['properties']['id']=='ATA': continue
    polys=[g['arcs']] if g['type']=='Polygon' else g['arcs']
    rings.extend(ring(r) for poly in polys for r in poly)
Path('Flightbook/Resources/world.json').write_text(json.dumps(rings,separators=(',',':')))
print(f'Bundled {len(rings)} offline map rings')
