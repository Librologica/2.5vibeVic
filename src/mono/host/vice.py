"""Native VIC-20 capture. Cycles are emulated 6502 clocks, not host time."""
from pathlib import Path
import subprocess,shutil,json,os,argparse,re
ROOT=Path(os.environ['VIBEVIC_WORK'])
PHASES=['render_frame_begin','geometry_done','strips_done','render_frame_end','presentation_done','irq','irq_exit','simulation_tick','simulation_done']
def run(mode='auto',standard='pal',tag='probe',cycles=5000000,frames=(2,3),extra=(),tick_frames=()):
    b=ROOT/'artifacts/build'/mode;out=ROOT/'artifacts/vice'/f'{mode}-{standard}-{tag}';out.mkdir(parents=True)
    lines=[f'logname "{out.as_posix()}/trace.log"','log on','disable 1','sidefx off',f'load_labels "{b.as_posix()}/labels.txt"']
    lines += ['trace exec .'+n for n in PHASES]
    for idx,f in enumerate(frames,2+len(PHASES)):
        stem=f'frame-{f:04d}'
        play=[f'dump "{out.as_posix()}/{stem}.vsf"',f'bsave "{out.as_posix()}/{stem}-ram.bin" 0 $0000 $7fff',
              f'bsave "{out.as_posix()}/{stem}-vic.bin" 0 $9000 $900f',f'bsave "{out.as_posix()}/{stem}-color.bin" 0 $9600 $97ff','x']
        (out/f'{stem}.mon').write_text('\n'.join(play)+'\n')
        lines += [f'break exec .presentation_done if (@cpu:$0078 == ${f&255:02x}) && (@cpu:$0079 == ${f>>8:02x})',f'command {idx} "playback \\"{out.as_posix()}/{stem}.mon\\""']
    for idx,t in enumerate(tick_frames,2+len(PHASES)+len(frames)):
        stem=f'frame-tick-{t:04d}'
        play=[f'dump "{out.as_posix()}/{stem}.vsf"',f'bsave "{out.as_posix()}/{stem}-ram.bin" 0 $0000 $7fff',
              f'bsave "{out.as_posix()}/{stem}-vic.bin" 0 $9000 $900f',f'bsave "{out.as_posix()}/{stem}-color.bin" 0 $9600 $97ff',f'disable {idx}','x']
        (out/f'{stem}.mon').write_text('\n'.join(play)+'\n')
        cond=f'(@cpu:$007b > ${t>>8:02x}) || ((@cpu:$007b == ${t>>8:02x}) && (@cpu:$007a >= ${t&255:02x}))'
        lines += [f'break exec .presentation_done if {cond}',f'command {idx} "playback \\"{out.as_posix()}/{stem}.mon\\""']
    lines+=list(extra)+['x'];(out/'run.mon').write_text('\n'.join(lines)+'\n')
    emulator=os.environ.get('XVIC_EXE') or shutil.which('xvic')
    if not emulator:raise RuntimeError('xvic not found: use PATH or XVIC_EXE')
    cmd=[emulator,'-default','+confirmonexit','-console','-warp','-'+standard,'-memory','24k',
         '-VICfilter','0','-autostartprgmode','1','-initbreak','0x2000','-moncommands',str(out/'run.mon'),
         '-limitcycles',str(cycles),'-exitscreenshot',str(out/'screen.png'),str(b/'vibe20.prg')]
    startup=None
    if os.name=='nt':
        startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=0
    p=subprocess.run(cmd,cwd=out,capture_output=True,timeout=180,startupinfo=startup)
    (out/'console.log').write_bytes(p.stdout+p.stderr);(out/'run.json').write_text(json.dumps(dict(command=cmd,returncode=p.returncode),indent=2))
    print(out,p.returncode,flush=True)
    assert (out/'trace.log').exists(),'No trace; emulator startup failed'
    return out
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--mode',default='auto');p.add_argument('--standard',default='pal');p.add_argument('--tag',default='probe');p.add_argument('--cycles',type=int,default=5000000);a=p.parse_args();run(a.mode,a.standard,a.tag,a.cycles)
