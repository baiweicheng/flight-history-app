#!/usr/bin/env python3
"""Build the offline catalog from an OurAirports airports.csv download. No runtime network use."""
import csv, json, sys, hashlib
from pathlib import Path
source = Path(sys.argv[1])
version = 'OurAirports-2026-10-28'
rows = []
for a in csv.DictReader(source.open()):
    try:
        lat, lon = float(a['latitude_deg']), float(a['longitude_deg'])
        if not (-90 <= lat <= 90 and -180 <= lon <= 180): continue
    except ValueError: continue
    rows.append(dict(id=a['id'], ident=a['ident'], iata=a['iata_code'] or None,
                     name=a['name'], city=a['municipality'], country=a['iso_country'],
                     latitude=lat, longitude=lon, kind=a['type'], sourceVersion=version))
rows.sort(key=lambda a: (a['kind'] != 'large_airport', a['name']))
assert len({a['id'] for a in rows}) == len(rows)
Path('Flightbook/Resources/airports.json').write_text(json.dumps(rows, ensure_ascii=False, separators=(',', ':')))
Path('Flightbook/Resources/catalog-provenance.json').write_text(json.dumps(dict(
    source='https://ourairports.com/data/', download='https://davidmegginson.github.io/ourairports-data/airports.csv',
    retrieved='2026-10-28', version=version, records=len(rows), license='Public domain',
    sourceSHA256=hashlib.sha256(source.read_bytes()).hexdigest()), indent=2))
print(f'Bundled {len(rows)} airports, including closed and historical entries')
