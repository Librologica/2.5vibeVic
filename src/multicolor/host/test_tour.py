"""Full native tour and restart, including each room and moving turns."""
from concurrent.futures import ThreadPoolExecutor
import json
from vice import run,ROOT
from qualify import check
TICKS=(100,600,850,1200,1750,2300,2550,3100,3370,3450,3770,4100,4520,4820,5016,5100)
def one(std):
    out=run('auto',std,'full-tour',cycles=124000000 if std=='pal' else 115000000,frames=(),tick_frames=TICKS)
    r=check(out,len(TICKS));print(std,'complete tour:',r['frames'],'views verified',flush=True)
    return dict(standard=std,frames=r['frames'],differences=0)
if __name__=='__main__':
    with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(one,['pal','ntsc']))
    (ROOT/'artifacts/tour-native.json').write_text(json.dumps(results,indent=2))
