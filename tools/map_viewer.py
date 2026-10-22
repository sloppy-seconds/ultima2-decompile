#!/usr/bin/env python3
"""Generate a self-contained HTML map viewer for Ultima II sector maps.

Why: the tile table is not 64 terrains (see docs/passability-findings.md F13). It
mixes ground, structures, creatures, borders and the A-Z shop/sign fixtures, and
the only way to see that is to look at real maps. This renders the shipped
mapxNN files with the real tile art, in a browser, with no server.

Output is one HTML file with everything embedded: the 64 tile PNGs as data URIs,
every sector's 4096 tile bytes, and the tile-art.tsv descriptions. Open it
directly; it makes no network requests.

Read-only by construction. It reads original/ and tmp/tiles/ and writes only to
the --out path, refusing to write into original/ or references/.

Usage:
    python3 tools/tile_atlas.py --out tmp/tiles        # first, if tiles missing
    python3 tools/map_viewer.py -o tmp/map-viewer.html
"""
import argparse
import base64
import glob
import json
import os
import sys

TILE_PX = 16          # art is 16x16; PNGs are upscaled, drawn with smoothing off
GRID = 64
TAIL = 128            # 4224 - 4096; byte 4096 is the 0x1A marker, not terrain


def load_tiles(tiledir, optional=False):
    """Extracted original art: 16x16 PNGs, one per art index."""
    tiles = {}
    for n in range(64):
        p = os.path.join(tiledir, 'tile_%02X.png' % n)
        if not os.path.exists(p):
            p = os.path.join(tiledir, 'tile_%02x.png' % n)
        if not os.path.exists(p):
            if optional:
                return {}
            sys.exit('missing tile %s; run tools/tile_atlas.py --out %s' % (p, tiledir))
        tiles[n] = 'data:image/png;base64,' + base64.b64encode(open(p, 'rb').read()).decode()
    return tiles


def load_cleanroom(dirpath, optional=True):
    """Cleanroom substitute art: SVGs.

    The committed SVGs carry a viewBox but no width/height, which is correct for
    an image asset but leaves them with no intrinsic size, and drawImage will not
    scale an SVG that has none. The attributes are injected here at embed time so
    the art files themselves stay untouched.
    """
    tiles = {}
    for n in range(64):
        p = os.path.join(dirpath, 'tile_%02X.svg' % n)
        if not os.path.exists(p):
            if optional:
                return {}
            sys.exit('missing cleanroom tile %s' % p)
        svg = open(p).read()
        if 'width=' not in svg.split('>', 1)[0]:
            svg = svg.replace('<svg ', '<svg width="16" height="16" ', 1)
        tiles[n] = 'data:image/svg+xml;base64,' + base64.b64encode(svg.encode()).decode()
    return tiles


def load_art(tsv):
    art = {}
    with open(tsv) as f:
        for line in f:
            line = line.rstrip('\n')
            if not line or line.startswith('#'):
                continue
            p = line.split('\t')
            if len(p) < 5 or p[1].strip() == 'id':
                continue
            a = int(p[1].strip(), 16)
            art[a] = {'kind': p[3].strip(), 'desc': p[4].strip(),
                      'note': p[6].strip() if len(p) > 6 else ''}
    return art


def load_maps(srcdir):
    maps = []
    for path in sorted(glob.glob(os.path.join(srcdir, 'mapx*'))):
        name = os.path.basename(path)
        data = open(path, 'rb').read()
        if len(data) != GRID * GRID + TAIL:
            print('  note: %s is %d bytes, expected %d' % (name, len(data), GRID * GRID + TAIL))
        maps.append({'name': name, 'sector': name[4:], 'bytes': list(data[:GRID * GRID])})
    if not maps:
        sys.exit('no mapx* found in %s' % srcdir)
    return maps


HTML = r"""<!doctype html>
<html><head><meta charset="utf-8"><title>Ultima II sector maps</title><style>
:root{color-scheme:dark}
body{font:13px/1.45 ui-monospace,SFMono-Regular,Menlo,monospace;background:#111;color:#ddd;
     margin:0;padding:14px;display:flex;gap:16px;align-items:flex-start;flex-wrap:wrap}
#panel{width:330px}
h1{font-size:15px;margin:0 0 8px}
label{display:block;margin:9px 0 3px;color:#8fa}
select,input{width:100%;box-sizing:border-box;background:#1b1b1b;color:#ddd;border:1px solid #444;
             padding:5px;font:inherit}
.row{display:flex;gap:8px;align-items:center;margin:7px 0}
.row input{width:auto}
canvas{image-rendering:pixelated;border:1px solid #555;background:#000;cursor:crosshair}
#view{display:flex;gap:10px;align-items:flex-start}
.pane{text-align:center}
.pane b{display:block;color:#8fa;font-weight:normal;margin-bottom:4px;font-size:12px}
#info{background:#1b1b1b;border:1px solid #444;padding:8px;margin-top:10px;min-height:74px}
#info b{color:#ffd479}
#legend{background:#1b1b1b;border:1px solid #444;padding:8px;margin-top:10px;
        max-height:300px;overflow:auto}
.k{display:flex;gap:6px;align-items:center;margin:2px 0}
.sw{width:14px;height:14px;border:1px solid #000;flex:none}
small{color:#888}
.hint{color:#777;margin-top:8px}
</style></head><body>
<div id="panel">
<h1>Ultima II sector maps</h1>
<div style="margin:0 0 6px"><a href="tile-review.html" style="color:#8cf">tile review sheet — original vs cleanroom, all 64</a></div>
<label>World / time (tens digit)</label><select id="grp"></select>
<label>Sector</label><select id="sec"></select>
<label>Tile art</label><select id="art"></select>
<label>Zoom (px per tile)</label><input id="zoom" type="number" min="4" max="32" value="12">
<div class="row"><input id="grid" type="checkbox"><label for="grid" style="margin:0">1px red tile borders</label></div>
<div class="row"><input id="cls" type="checkbox"><label for="cls" style="margin:0">Colour by class</label></div>
<div class="row"><input id="mask" type="checkbox"><label for="mask" style="margin:0">Show only byte</label>
<input id="maskv" value="80" style="width:60px"></div>
<div id="info">hover a tile</div>
<div id="legend"></div>
<div class="hint">Layout assumption: bytes 0..4095 = 64x64 row-major, then a 128-byte
tail whose first byte is always 0x1A. Unproven; if these maps look shifted or wrong,
that assumption is the first suspect.</div>
</div>
<div id="view">
<div class="pane"><b id="lab1">cleanroom</b><canvas id="c" width="768" height="768"></canvas></div>
<div class="pane" id="pane2" style="display:none"><b id="lab2">extracted original</b>
<canvas id="c2" width="768" height="768"></canvas></div>
</div>
<script>
const ORIG=%TILES_ORIG%, CLEAN=%TILES_CLEAN%, ART=%ART%, MAPS=%MAPS%;
const HAS_ORIG = ORIG.length===64;
// drawImage needs decoded Image objects, not data-URI strings. Build them once
// and repaint when the whole set has decoded, otherwise the first frame is blank.
function mk(set){return set.map(src=>{const im=new Image();im.src=src;return im})}
const IMGS_CLEAN=mk(CLEAN), IMGS_ORIG=mk(HAS_ORIG?ORIG:CLEAN);
const CLS={terrain:'#2e7d32',ground:'#2e7d32',object:'#1565c0',structure:'#1565c0',
           creature:'#c62828',font:'#ef6c00',block:'#546e7a'};
const $=id=>document.getElementById(id);
const maps=MAPS, byName={}; maps.forEach(m=>byName[m.name]=m);
const groups=[...new Set(maps.map(m=>m.sector[0]))].sort();
function opts(el,arr,sel){el.innerHTML='';arr.forEach(v=>{const o=document.createElement('option');
  o.value=v[0];o.textContent=v[1];if(v[0]===sel)o.selected=true;el.appendChild(o)})}
opts($('grp'),groups.map(g=>[g,'group '+g+'  ('+maps.filter(m=>m.sector[0]===g).length+' sectors)']),groups[0]);
function secs(){return maps.filter(m=>m.sector[0]===$('grp').value).map(m=>[m.name,m.name+'  (sector '+m.sector+')'])}
function paint(c, IMGS){
  const m=byName[$('sec').value], z=Math.max(4,Math.min(32,+$('zoom').value||12));
  c.width=c.height=64*z; const x=c.getContext('2d');
  x.imageSmoothingEnabled=false; x.fillStyle='#000'; x.fillRect(0,0,c.width,c.height);
  const want=$('mask').checked?(parseInt($('maskv').value,16)&0xFF):-1;
  for(let r=0;r<64;r++)for(let col=0;col<64;col++){
    const b=m.bytes[r*64+col], a=b>>2;
    if($('cls').checked){x.fillStyle=CLS[(ART[a]||{}).kind]||'#333';
      x.fillRect(col*z,r*z,z,z);
      x.fillStyle='#fff';x.font=(z*0.6|0)+'px monospace';x.textAlign='center';
      x.fillText(a.toString(16).toUpperCase(),col+z/2,r+z*0.75);}
    else if(want>=0){ if(b===want){x.fillStyle='#ff0';x.fillRect(col*z,r*z,z,z);}
      else{x.globalAlpha=0.18;if(IMGS[a].complete)x.drawImage(IMGS[a],col*z,r*z,z,z);x.globalAlpha=1;} }
    else{ if(IMGS[a].complete) x.drawImage(IMGS[a],col*z,r*z,z,z); }
  }
  if($('grid').checked){x.strokeStyle='#f00';x.lineWidth=1;x.beginPath();
    for(let i=0;i<=64;i++){x.moveTo(i*z+.5,0);x.lineTo(i*z+.5,64*z);
      x.moveTo(0,i*z+.5);x.lineTo(64*z,i*z+.5);}x.stroke();}
}
function redraw(){
  const mode=$('art').value;
  // Left pane always shows the chosen set; side-by-side puts the other set on the
  // right so a sector can be compared without switching back and forth.
  $('lab1').textContent = mode==='original' ? 'extracted original' : 'cleanroom (substitute)';
  paint($('c'), mode==='original'?IMGS_ORIG:IMGS_CLEAN);
  const p2=$('pane2');
  if(mode==='side' && HAS_ORIG){p2.style.display='';paint($('c2'),IMGS_ORIG);}
  else p2.style.display='none';
}
$('c').addEventListener('mousemove',e=>{
  const m=byName[$('sec').value], z=Math.max(4,Math.min(32,+$('zoom').value||12));
  const r=e.offsetY/z|0, col=e.offsetX/z|0;
  if(r>63||col>63){$('info').textContent='outside';return}
  const b=m.bytes[r*64+col], a=b>>2, art=ART[a]||{};
  const n=m.bytes.filter(v=>v===b).length;
  $('info').innerHTML='<b>'+m.name+'</b> at x='+col+' y='+r+
    '<br>byte 0x'+b.toString(16).padStart(2,'0')+' &rarr; art 0x'+a.toString(16).padStart(2,'0')+
    ' <span style="color:#8fa">'+(art.kind||'?')+'</span>'+
    '<br>'+(art.desc||'')+((art.note)?' <small>| '+art.note+'</small>':'')+
    '<br><small>'+n+' of 4096 tiles in this sector use this byte</small>'+
    '<br><small>warp target: sector '+m.sector+' &nbsp; x='+col+' y='+r+'</small>';
});
$('grp').onchange=()=>{opts($('sec'),secs(),secs()[0][0]);redraw()};
['sec','zoom','grid','cls','mask','maskv','art'].forEach(i=>{$(i).oninput=redraw});
opts($('art'),[['clean','cleanroom (original substitute art)'],
  ['original', HAS_ORIG?'extracted original art':'extracted original art (not extracted)'],
  ['side', HAS_ORIG?'side by side: cleanroom | original':'side by side (needs extracted art)']],
  HAS_ORIG?'side':'clean');
if(!HAS_ORIG){$('art').options[1].disabled=true;$('art').options[2].disabled=true;}
$('legend').innerHTML='<b>classes</b>'+Object.entries(CLS).filter(([k])=>k!=='ground').map(
  ([k,v])=>'<div class="k"><span class="sw" style="background:'+v+'"></span>'+k+'</div>').join('');
opts($('sec'),secs(),secs()[0][0]);redraw();
let ready=0, need=IMGS_CLEAN.length+(HAS_ORIG?IMGS_ORIG.length:0);
IMGS_CLEAN.concat(HAS_ORIG?IMGS_ORIG:[]).forEach(im=>{ if(im.complete)return;
  im.onload=im.onerror=()=>{ if(++ready===need) redraw(); }; });
</script></body></html>
"""


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--maps', default='original')
    ap.add_argument('--tiles', default='tmp/tiles',
                    help='extracted original art (PNG); optional, viewer degrades')
    ap.add_argument('--cleanroom', default='engine/assets/tiles/cleanroom/tiles',
                    help='cleanroom substitute art (SVG)')
    ap.add_argument('--art', default='disasm/tile-art.tsv')
    ap.add_argument('-o', '--out', required=True)
    a = ap.parse_args()

    low = os.path.abspath(a.out).lower()
    if '/original/' in low or '/references/' in low:
        sys.exit('refusing to write into original/ or references/')

    tiles = load_tiles(a.tiles, optional=True)
    clean = load_cleanroom(a.cleanroom, optional=False)
    art = load_art(a.art)
    maps = load_maps(a.maps)
    missing = [hex(i) for i in range(64) if i not in art]
    if missing:
        print('warning: tile-art.tsv has no description for %d entries: %s'
              % (len(missing), ' '.join(missing)))

    html = (HTML.replace('%TILES_ORIG%', json.dumps([tiles.get(i, '') for i in range(64)]))
                .replace('%TILES_CLEAN%', json.dumps([clean[i] for i in range(64)]))
                .replace('%ART%', json.dumps(art))
                .replace('%MAPS%', json.dumps(maps)))
    with open(a.out, 'w') as f:
        f.write(html)
    print('wrote %s (%.1f MB)' % (a.out, len(html) / 1e6))
    print('  %d sectors: %s' % (len(maps), ' '.join(m['name'] for m in maps)))
    print('  cleanroom art: %d/64 SVG' % len(clean))
    print('  original art:  %d/64 PNG%s' % (len(tiles), '' if len(tiles) == 64
                                            else '  (not extracted - run tools/tile_atlas.py)'))
    print('  %d tile-art descriptions' % len(art))
    print('  open in a browser, or: playwright -> file://%s' % os.path.abspath(a.out))


main()
