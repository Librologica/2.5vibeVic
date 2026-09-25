"""VIC-I scanout and VIA keyboard verification. No program-code patches."""
from pathlib import Path
import json,subprocess,shutil,os
from concurrent.futures import ThreadPoolExecutor
from PIL import Image
from vice import ROOT,run
from model import framebuffer

def launch(out,mode,std,lines):
    out.mkdir(parents=True,exist_ok=True);b=ROOT/f'artifacts/build/{mode}'
    (out/'run.mon').write_text('\n'.join([f'logname "{out.as_posix()}/trace.log"','log on','disable 1','sidefx off',f'load_labels "{b.as_posix()}/labels.txt"',*lines])+'\n')
    cmd=[os.environ.get('XVIC_EXE') or shutil.which('xvic'),'-default','+confirmonexit','-console','-warp','-'+std,'-memory','24k','-VICfilter','0','-autostartprgmode','1','-initbreak','0x2000','-moncommands',str(out/'run.mon'),'-limitcycles','10000000','-exitscreenshot',str(out/'screen.png'),str(b/'vibe20.prg')]
    st=None
    if os.name=='nt':
        st=subprocess.STARTUPINFO();st.dwFlags|=subprocess.STARTF_USESHOWWINDOW;st.wShowWindow=0
    proc=subprocess.run(cmd,cwd=out,capture_output=True,timeout=60,startupinfo=st)
    (out/'command.json').write_text(json.dumps(cmd,indent=2));(out/'console.log').write_bytes(proc.stdout+proc.stderr)
    return proc.returncode

def keyboard(std):
    cap=run('interactive',std,'input-source-v2',7000000,frames=(3,))
    b=(cap/'frame-0003.vsf').read_bytes();idx=b.index(b'KEYBOARD');data=idx+22
    assert b[idx+16:idx+18]==bytes([1,1]) and int.from_bytes(b[idx+18:idx+22],'little')==118
    results=[]
    for name,row,col,key in [('none',0,0,0),('W',1,1,1),('S',1,5,2),('A',1,2,4),('D',2,2,8)]:
        out=ROOT/f'artifacts/input-v2/{std}/{name}';out.mkdir(parents=True)
        snap=bytearray(b);snap[data:data+96]=bytes(96)
        if key:
            snap[data+4*row:data+4*row+4]=(1<<col).to_bytes(4,'little')
            snap[data+64+4*col:data+64+4*col+4]=(1<<row).to_bytes(4,'little')
        (out/'pressed.vsf').write_bytes(snap)
        (out/'capture.mon').write_text(f'bsave "{out.as_posix()}/sample.bin" 0 $0000 $00ff\nquit\n')
        lines=[f'undump "{out.as_posix()}/pressed.vsf"','break exec .input_sampled',f'command 2 "playback \\"{out.as_posix()}/capture.mon\\""','x']
        launch(out,'interactive',std,lines)
        r=(out/'sample.bin').read_bytes();assert r[0x60]==key,(std,name,r[0x60],key)
        results.append(dict(key=name,expected=key,actual=r[0x60]))
    (ROOT/f'artifacts/input-v2/{std}/results.json').write_text(json.dumps(results,indent=2));print(std,'keyboard PASS',flush=True)

def visual(std,frame):
    out=ROOT/f'artifacts/visual/{std}-{frame}';out.mkdir(parents=True)
    # Save the published pose; stop before next publication, after its complete scanout.
    # Renderer > one refresh, so no extra guest wait or screen writes are necessary.
    (out/'pose.mon').write_text(f'bsave "{out.as_posix()}/published.bin" 0 $0000 $7fff\ndisable 2\nenable 3\nx\n')
    (out/'shot.mon').write_text('quit\n')
    cond=f'if (@cpu:$0078 == ${frame:02x}) && (@cpu:$0079 == $00)'
    launch(out,'auto',std,[f'break exec .presentation_done {cond}',f'command 2 "playback \\"{out.as_posix()}/pose.mon\\""',
                           f'break exec .render_frame_end {cond}',f'command 3 "playback \\"{out.as_posix()}/shot.mon\\""','disable 3','x'])
    r=(out/'published.bin').read_bytes();pose=tuple(int.from_bytes(r[a:a+2],'little') for a in (0x26,0x28,0x2a))
    sc=json.loads((ROOT/'artifacts/build/auto/scene.json').read_text());fb,_=framebuffer(sc['grid'],pose)
    ref=Image.new('1',(128,96))
    for y in range(96):
        for x in range(128):ref.putpixel((x,y),bool(fb[(y//8)*128+(x//8)*8+(y&7)]&(128>>(x&7))))
    ref=ref.resize((256,96),Image.Resampling.NEAREST);im=Image.open(out/'screen.png').convert('RGB')
    # Match expected raster origin measured in initial PAL/NTSC screenshots.
    # Verify complete image, not merely RAM. Black/white must remain distinct.
    actual=im.convert('L').point(lambda v:255 if v>127 else 0).convert('1')
    matches=[]
    for oy in range(30,100):
        for ox in range(60,161,2):
            if actual.crop((ox,oy,ox+256,oy+96)).tobytes()==ref.tobytes():matches.append((ox,oy))
    assert len(matches)==1,(std,frame,'scanout differences',matches)
    ox,oy=matches[0]
    expected=Image.new('1',im.size);expected.paste(ref,(ox,oy))
    assert actual.tobytes()==expected.tobytes(),'unexpected pixels outside viewport'
    colors=im.getcolors(im.width*im.height);assert len(colors)==2,colors
    result=dict(standard=std,frame=frame,pose=pose,origin=matches[0],physicalPixelDifferences=0,outsideViewportDifferences=0,colors=colors)
    (out/'results.json').write_text(json.dumps(result,indent=2));print(std,frame,'scanout PASS',matches[0],flush=True)
def main():
    with ThreadPoolExecutor(max_workers=2) as pool:list(pool.map(keyboard,['pal','ntsc']))
    with ThreadPoolExecutor(max_workers=2) as pool:list(pool.map(lambda x:visual(*x),[(s,f) for s in ('pal','ntsc') for f in (2,3)]))
if __name__=='__main__':main()
