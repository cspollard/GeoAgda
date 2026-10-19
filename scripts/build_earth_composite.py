#!/usr/bin/env python3
"""
Assemble a comprehensive, layered physical + bathymetric + elevation-tinted GeoJSON dataset
from Natural Earth sources.

Layers in visual order (bottom to top):
1. Bathymetric depth contours (depths: 0m, 200m, 1000m, 2000m, 4000m, 6000m, 10000m)
2. Land base with sea-level elevation (50m: lush coastal lowland green #a8cca0)
3. Physical topography regions with accurate hypsometric elevation values in meters:
   - Lowland basins (Amazon 80m, Congo 350m)
   - Plains & Steppes (Northern European 120m, Kazakh 350m, Great Plains 700m)
   - Deserts & Plateaus (Sahara 450m, Kalahari 950m, Brazilian Highlands 1000m, Gobi 1200m, Colorado 1900m)
   - Mountain Ranges (Urals 1200m, Appalachians 1300m, Great Dividing Range 1600m, Atlas 2500m,
     Alps 3400m, Rockies 3400m, Tian Shan 4200m, Andes 4500m, Himalayas 6500m)
4. Spot elevation summits (Mt. Everest 8848m, K2 8611m, Aconcagua 6959m, Denali 6194m, Kilimanjaro 5895m, Elbrus 5642m)
5. Glaciated areas (Antarctica & Greenland ice sheets: ice white #f4f9fa)
6. Hydrography (Major lakes and river centerlines: water blue)
7. Country boundary lines (International land borders: subtle stroke)
8. Top-level country label points (Major countries)
"""

import json
import os
import unicodedata

def clean_str(s):
    if not isinstance(s, str):
        return s
    return unicodedata.normalize('NFKD', s).encode('ascii', 'ignore').decode('ascii')

def round_coords(c):
    if isinstance(c, (float, int)):
        return round(float(c), 2)
    return [round_coords(x) for x in c]

def compute_centroid(coords, geom_type):
    flat = []
    def extract(c):
        if len(c) > 0 and isinstance(c[0], (float, int)):
            flat.append((c[0], c[1]))
        else:
            for sub in c:
                extract(sub)
    extract(coords)
    if not flat:
        return 0.0, 0.0
    cx = sum(p[0] for p in flat) / len(flat)
    cy = sum(p[1] for p in flat) / len(flat)
    return round(cx, 2), round(cy, 2)

TOPO_ELEVATIONS = {
    'AMAZON BASIN': 80,
    'CONGO BASIN': 350,
    'NORTH CHINA PLAIN': 50,
    'NORTHERN EUROPEAN PLAIN': 120,
    'KAZAKH STEPPE': 350,
    'GREAT PLAINS': 700,
    'CANADIAN SHIELD': 400,
    'GREAT VICTORIA DESERT': 250,
    'SAHARA': 450,
    'ARABIAN DESERT': 600,
    'KALAHARI DESERT': 950,
    'GOBI DESERT': 1200,
    'WESTERN PLATEAU': 500,
    'DECCAN PLATEAU': 600,
    'PENINSULA IBERICA': 650,
    'PENÍNSULA IBÉRICA': 650,
    'IBERIAN PENINSULA': 650,
    'GUIANA SHIELD': 900,
    'BRAZILIAN HIGHLANDS': 1000,
    'CENTRAL SIBERIAN PLATEAU': 700,
    'COLORADO PLATEAU': 1900,
    'POLAR PLATEAU': 2800,
    'ALTIPLANO': 3800,
    'PLATEAU OF TIBET': 4800,
    'URAL MOUNTAINS': 1200,
    'APPALACHIAN MTS.': 1300,
    'APPALACHIAN MOUNTAINS': 1300,
    'GREAT DIVIDING RANGE': 1600,
    'KJØLEN MOUNTAINS': 1600,
    'CARPATHIAN MOUNTAINS': 1800,
    'ATLAS MOUNTAINS': 2500,
    'PYRENEES': 2600,
    'ETHIOPIAN HIGHLANDS': 2600,
    'ZAGROS MOUNTAINS': 2600,
    'ALTAY MOUNTAINS': 2800,
    'TRANSANTARCTIC MOUNTAINS': 2800,
    'CASCADE RANGE': 2800,
    'SIERRA NEVADA': 3000,
    'ALPS': 3400,
    'ROCKY MOUNTAINS': 3400,
    'CAUCASUS MTS.': 3800,
    'ALASKA RANGE': 4000,
    'TIAN SHAN': 4200,
    'ANDES': 4500,
    'HINDU KUSH': 4800,
    'KUNLUN MOUNTAINS': 5000,
    'KARAKORAM RA.': 6000,
    'HIMALAYAS': 6500
}

def default_elevation_by_class(cla):
    if cla in ('Basin', 'Delta', 'Lowland'):
        return 100
    if cla in ('Plain', 'Valley'):
        return 350
    if cla == 'Tundra':
        return 400
    if cla in ('Desert', 'Playa'):
        return 600
    if cla in ('Plateau', 'Highland'):
        return 1200
    if cla == 'Foothills':
        return 1500
    if cla in ('Range/mtn', 'mountain'):
        return 2800
    return 100

def main():
    features = []

    # 1. Bathymetric depth contours from shallowest to deepest
    # Re-use existing simplified bathymetry from fixture if present
    fixture_fn = 'data/fixtures/earth_physical_topography.geojson'
    bathy_loaded = False
    if os.path.exists(fixture_fn):
        with open(fixture_fn) as f:
            prev = json.load(f)
        bathy_feats = [feat for feat in prev['features'] if feat['properties'].get('featurecla') == 'Bathymetry']
        if bathy_feats:
            features.extend(bathy_feats)
            bathy_loaded = True
            print(f"Loaded {len(bathy_feats)} bathymetry contours from existing fixture")

    if not bathy_loaded:
        # Fallback to reading 10m bathymetry files
        bathymetry_levels = [
            ('L', 0), ('K', 200), ('J', 1000), ('I', 2000),
            ('G', 4000), ('E', 6000), ('A', 10000)
        ]
        for code, depth in bathymetry_levels:
            fn = f'natural-earth-geojson/10m/physical/ne_10m_bathymetry_{code}_{depth}.json'
            if os.path.exists(fn):
                with open(fn) as f:
                    d = json.load(f)
                for feat in d['features']:
                    g = feat['geometry']
                    features.append({
                        'type': 'Feature',
                        'properties': {'featurecla': 'Bathymetry', 'depth': depth, 'scalerank': 10},
                        'geometry': {'type': g['type'], 'coordinates': round_coords(g['coordinates'])}
                    })

    print(f"Bathymetry added: {len(features)} features")

    # 2. Base Landmass (lowland / coastal elevation 50m)
    land_fn = 'natural-earth-geojson/110m/physical/ne_110m_land.json'
    if os.path.exists(land_fn):
        with open(land_fn) as f:
            d = json.load(f)
        for feat in d['features']:
            g = feat['geometry']
            features.append({
                'type': 'Feature',
                'properties': {
                    'featurecla': 'Land',
                    'elevation': 50,
                    'scalerank': 10
                },
                'geometry': {'type': g['type'], 'coordinates': round_coords(g['coordinates'])}
            })

    print(f"After Land: {len(features)} features")

    # 3. Topography Regions with Elevation values
    seen_topo = set()

    # 3a. 110m regions
    topo_fn = 'natural-earth-geojson/110m/physical/ne_110m_geography_regions_polys.json'
    if os.path.exists(topo_fn):
        with open(topo_fn) as f:
            d = json.load(f)
        for feat in d['features']:
            cla = feat['properties'].get('featurecla')
            if cla in {'Range/mtn', 'Plateau', 'Desert', 'Basin', 'Plain', 'Tundra'}:
                raw_name = feat['properties'].get('name', '')
                uname = clean_str(raw_name).upper()
                if uname == 'PENINSULA IBERICA' or uname == 'PENÍNSULA IBÉRICA':
                    name = 'Iberian Peninsula'
                else:
                    name = clean_str(raw_name).title()
                elev = TOPO_ELEVATIONS.get(uname, default_elevation_by_class(cla))
                g = feat['geometry']
                cx, cy = compute_centroid(g['coordinates'], g['type'])
                seen_topo.add(uname)
                features.append({
                    'type': 'Feature',
                    'properties': {
                        'featurecla': cla,
                        'name': name,
                        'elevation': elev,
                        'LABELRANK': 1,
                        'scalerank': 1,
                        'LABELX': cx,
                        'LABELY': cy
                    },
                    'geometry': {'type': g['type'], 'coordinates': round_coords(g['coordinates'])}
                })

    # 3b. 50m prominent mountain ranges and plateaus with elevation
    topo50_fn = 'natural-earth-geojson/50m/physical/ne_50m_geography_regions_polys.json'
    if os.path.exists(topo50_fn):
        with open(topo50_fn) as f:
            d50 = json.load(f)
        for feat in d50['features']:
            uname = clean_str(feat['properties'].get('name', '')).upper()
            cla = feat['properties'].get('featurecla')
            if uname in TOPO_ELEVATIONS and uname not in seen_topo:
                elev = TOPO_ELEVATIONS[uname]
                g = feat['geometry']
                cx, cy = compute_centroid(g['coordinates'], g['type'])
                seen_topo.add(uname)
                features.append({
                    'type': 'Feature',
                    'properties': {
                        'featurecla': cla or 'Range/mtn',
                        'name': clean_str(feat['properties'].get('name', '')).title(),
                        'elevation': elev,
                        'LABELRANK': 1,
                        'scalerank': 1,
                        'LABELX': cx,
                        'LABELY': cy
                    },
                    'geometry': {'type': g['type'], 'coordinates': round_coords(g['coordinates'])}
                })

    print(f"After Topography: {len(features)} features")

    # 4. Spot Elevation Summits (Top iconic peaks)
    elev_pts_fn = 'natural-earth-geojson/10m/physical/ne_10m_geography_regions_elevation_points.json'
    prominent_peaks = {
        'MT. EVEREST', 'K2', 'CERRO ACONCAGUA', 'DENALI', 'MT. KILIMANJARO',
        'GORA ELBRUS', 'CHIMBORAZO', 'MONT BLANC', 'MT. FUJI', 'MT. COOK'
    }
    if os.path.exists(elev_pts_fn):
        with open(elev_pts_fn) as f:
            d_pts = json.load(f)
        for feat in d_pts['features']:
            p = feat['properties']
            raw_name = p.get('name') or ''
            name_u = clean_str(raw_name).upper()
            if name_u in prominent_peaks or (p.get('elevation', 0) >= 6000 and p.get('scalerank', 10) <= 2):
                elev = int(p['elevation'])
                features.append({
                    'type': 'Feature',
                    'properties': {
                        'featurecla': 'spot elevation',
                        'name': clean_str(p['name']),
                        'elevation': elev,
                        'scalerank': 1
                    },
                    'geometry': feat['geometry']
                })

    print(f"After Spot Elevations: {len(features)} features")

    # 5. Glaciated Areas
    glacier_fn = 'natural-earth-geojson/110m/physical/ne_110m_glaciated_areas.json'
    if os.path.exists(glacier_fn):
        with open(glacier_fn) as f:
            d = json.load(f)
        for feat in d['features']:
            g = feat['geometry']
            features.append({
                'type': 'Feature',
                'properties': {'featurecla': 'Glaciated areas', 'scalerank': 10},
                'geometry': {'type': g['type'], 'coordinates': round_coords(g['coordinates'])}
            })

    # 6. Lakes
    lakes_fn = 'natural-earth-geojson/110m/physical/ne_110m_lakes.json'
    if os.path.exists(lakes_fn):
        with open(lakes_fn) as f:
            d = json.load(f)
        for feat in d['features']:
            g = feat['geometry']
            features.append({
                'type': 'Feature',
                'properties': {'featurecla': 'Lake', 'name': clean_str(feat['properties'].get('name', '')), 'scalerank': 10},
                'geometry': {'type': g['type'], 'coordinates': round_coords(g['coordinates'])}
            })

    # 7. Rivers
    rivers_fn = 'natural-earth-geojson/110m/physical/ne_110m_rivers_lake_centerlines.json'
    if os.path.exists(rivers_fn):
        with open(rivers_fn) as f:
            d = json.load(f)
        for feat in d['features']:
            g = feat['geometry']
            features.append({
                'type': 'Feature',
                'properties': {'featurecla': 'River', 'scalerank': 10},
                'geometry': {'type': g['type'], 'coordinates': round_coords(g['coordinates'])}
            })

    # 8. Country Boundary lines
    borders_fn = 'natural-earth-geojson/110m/cultural/ne_110m_admin_0_boundary_lines_land.json'
    if os.path.exists(borders_fn):
        with open(borders_fn) as f:
            d = json.load(f)
        for feat in d['features']:
            g = feat['geometry']
            features.append({
                'type': 'Feature',
                'properties': {'featurecla': 'Admin-0 boundary lines', 'scalerank': 10},
                'geometry': {'type': g['type'], 'coordinates': round_coords(g['coordinates'])}
            })

    # 9. Major Country Labels
    countries_fn = 'natural-earth-geojson/110m/cultural/ne_110m_admin_0_countries.json'
    if os.path.exists(countries_fn):
        with open(countries_fn) as f:
            d = json.load(f)
        for feat in d['features']:
            props = feat['properties']
            lrank = props.get('LABELRANK', 10)
            name = clean_str(props.get('NAME') or props.get('NAME_EN') or props.get('ADMIN'))
            if lrank <= 2 and name:
                g = feat['geometry']
                cx, cy = compute_centroid(g['coordinates'], g['type'])
                features.append({
                    'type': 'Feature',
                    'properties': {
                        'featurecla': 'CountryLabel',
                        'NAME': name,
                        'LABELRANK': lrank,
                        'scalerank': 1,
                        'LABELX': cx,
                        'LABELY': cy
                    },
                    'geometry': {
                        'type': 'Point',
                        'coordinates': [cx, cy]
                    }
                })

    out_fc = {
        'type': 'FeatureCollection',
        'features': features
    }

    out_file = 'data/fixtures/earth_physical_topography.geojson'
    with open(out_file, 'w') as f:
        json.dump(out_fc, f, separators=(',', ':'))

    size_kb = os.path.getsize(out_file) / 1024
    print(f"Generated {out_file}: {len(features)} features, {size_kb:.1f} KB")

if __name__ == '__main__':
    main()
