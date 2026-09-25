"""VIC-I scanout and VIA keyboard verification. No program-code patches."""
from pathlib import Path
import json,subprocess,shutil,os
from concurrent.futures import ThreadPoolExecutor
from PIL import Image
from vice import ROOT,run
from model import framebuffer,MC_COLOR,MC_AUX,MC_BACKGROUND

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

def calibrate(std):
    """Known 00/01/10/11 bands, observed through VIC-I, no production PRG changes."""
    out=ROOT/f'artifacts/palette/{std}';out.mkdir(parents=True)
    # Frame2 displays charset B. Fill its 16x12 glyphs with four known bit-pair codes.
    fills=[]
    for row in range(12):
        for code in range(4):
            a=0x1800+row*128+code*32
            fills.append(f'fill ${a:04x} ${a+31:04x} ${code*85:02x}')
    (out/'bands.mon').write_text('\n'.join(fills+[
        f'bsave "{out.as_posix()}/vic.bin" 0 $9000 $900f',
        f'bsave "{out.as_posix()}/color.bin" 0 $9600 $97ff',
        'disable 2','enable 3','x'])+'\n')
    (out/'shot.mon').write_text('quit\n')
    cond='if (@cpu:$0078 == $02) && (@cpu:$0079 == $00)'
    launch(out,'auto',std,[f'break exec .presentation_done {cond}',
        f'command 2 "playback \\"{out.as_posix()}/bands.mon\\""',
        f'break exec .render_frame_end {cond}',f'command 3 "playback \\"{out.as_posix()}/shot.mon\\""','disable 3','x'])
    im=Image.open(out/'screen.png').convert('RGB');ox,oy=(120,70) if std=='pal' else (112,74)
    colors=[im.getpixel((ox+c*64+32,oy+48)) for c in range(4)]
    assert len(set(colors))==4,colors
    assert colors[1]==(0,0,0),'01 must be black border'
    assert colors[0][2]>max(colors[0][:2]),'00 must be blue background'
    assert colors[2][1]>colors[2][0] and colors[2][2]>colors[2][0],'10 must be cyan'
    assert sum(colors[3])>sum(colors[2]),'11 must be lighter cyan'
    expected=Image.new('RGB',im.size,colors[1])
    for code in range(4):expected.paste(Image.new('RGB',(64,96),colors[code]),(ox+code*64,oy))
    assert im.tobytes()==expected.tobytes(),'Multicolor mapping or origin mismatch'
    regs=(out/'vic.bin').read_bytes();cr=(out/'color.bin').read_bytes()
    assert regs[5]==0xfe and regs[14]==MC_AUX and regs[15]==MC_BACKGROUND
    assert all(v&15==MC_COLOR for v in cr)
    (out/'result.json').write_text(json.dumps(dict(codeRGB=colors,origin=[ox,oy],physicalPixelDifferences=0),indent=2))
    print(std,'VIC-I code00/01/10/11 calibration PASS',colors,flush=True)

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
    palette=json.loads((ROOT/f'artifacts/palette/{std}/result.json').read_text())
    colors=[tuple(v) for v in palette['codeRGB']];ox,oy=palette['origin']
    ref=Image.new('RGB',(64,96))
    for y in range(96):
        for x in range(64):ref.putpixel((x,y),colors[(fb[(y//8)*128+(x//4)*8+(y&7)]>>(6-2*(x&3)))&3])
    ref=ref.resize((256,96),Image.Resampling.NEAREST);im=Image.open(out/'screen.png').convert('RGB')
    assert im.crop((ox,oy,ox+256,oy+96)).tobytes()==ref.tobytes(),(std,frame,'RGB scanout differences')
    expected=Image.new('RGB',im.size,colors[1]);expected.paste(ref,(ox,oy))
    assert im.tobytes()==expected.tobytes(),'unexpected pixels outside viewport'
    result=dict(standard=std,frame=frame,pose=pose,origin=[ox,oy],physicalPixelDifferences=0,outsideViewportDifferences=0,codeRGB=colors)
    (out/'results.json').write_text(json.dumps(result,indent=2));print(std,frame,'multicolor RGB scanout PASS',(ox,oy),flush=True)
def main():
    with ThreadPoolExecutor(max_workers=2) as pool:list(pool.map(calibrate,['pal','ntsc']))
    with ThreadPoolExecutor(max_workers=2) as pool:list(pool.map(keyboard,['pal','ntsc']))
    with ThreadPoolExecutor(max_workers=2) as pool:list(pool.map(lambda x:visual(*x),[(s,f) for s in ('pal','ntsc') for f in (2,3)]))
if __name__=='__main__':main()
