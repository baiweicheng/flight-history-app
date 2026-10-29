#!/usr/bin/env python3
"""Convert a Natural Earth / atlas TopoJSON file (or reference HTML) into native Mercator rings."""
import json, re, math, sys
from pathlib import Path
if len(sys.argv) != 2:
    raise SystemExit('Usage: python3 Scripts/prepare_world.py /path/to/countries-110m.json (or reference.html)')
source=Path(sys.argv[1]).read_text()
embedded=re.search(r'<script[^>]+id="fh-world-data"[^>]*>(.*?)</script>', source, re.S)
topo=json.loads(embedded.group(1) if embedded else source)
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
