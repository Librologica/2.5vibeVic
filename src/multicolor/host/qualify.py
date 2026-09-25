"""RAM/framebuffer qualification and repeatable native emulated timing."""
from pathlib import Path
import json,re,statistics,math
from concurrent.futures import ThreadPoolExecutor
from model import framebuffer,INITIAL,simulation,ROUTE,MC_COLOR,MC_AUX,MC_BACKGROUND
from vice import ROOT,run

def labels(mode):
    return {l.split()[2].lstrip('.'):int(l.split()[1],16) for l in (ROOT/f'artifacts/build/{mode}/labels.txt').read_text().splitlines() if l.startswith('al ')}
def check(out,min_frames=120):
    sc=json.loads((ROOT/'artifacts/build/auto/scene.json').read_text());g=sc['grid'];n=0;poses=set();records=[]
    trajectory=[INITIAL]
    route_keys=[key for key,duration in ROUTE for _ in range(duration)]
    for f in sorted(out.glob('frame-*-ram.bin')):
        r=f.read_bytes();assert len(r)==32768
        vic=f.with_name(f.name.replace('-ram','-vic')).read_bytes();color=f.with_name(f.name.replace('-ram','-color')).read_bytes()
        pose=tuple(int.from_bytes(r[a:a+2],'little') for a in (0x26,0x28,0x2a))
        img,rays=framebuffer(g,pose);shown=1-r[0x70];base=0x1000+shown*0x800;screen=0x1600+shown*0x800
        assert r[base:base+1536]==img,(f,'pixels',pose)
        assert r[screen:screen+192]==bytes(range(192)),(f,'screen codes')
        assert r[screen+192:screen+512]==bytes([255])*320,(f,'screen tail')
        assert all(b&15==MC_COLOR for b in color),(f,'color RAM')
        assert vic[2]==0x90 and vic[3]&127==24 and vic[5]==(0xdc,0xfe)[shown] and vic[15]==MC_BACKGROUND and vic[14]==MC_AUX,(f,vic.hex())
        assert r[0x7c]==int('-pal-' in out.name),(f,'PAL/NTSC detection')
        tick=int.from_bytes(r[0x7a:0x7c],'little')
        while len(trajectory)<=tick:
            trajectory.append(simulation(g,trajectory[-1],route_keys[(len(trajectory)-1)%len(route_keys)]))
        camera=tuple(int.from_bytes(r[a:a+2],'little') for a in (0x20,0x22,0x24))
        assert camera==trajectory[tick],(f,'50Hz auto simulation',camera,trajectory[tick])
        for c,(depth,side,mat,steps,t) in enumerate(rays):
            actual=(r[0x3a00+c]+r[0x3a20+c]*256,r[0x3a40+c],r[0x3a80+c],r[0x3a60+c],r[0x3aa0+c]+r[0x3ac0+c]*256)
            assert actual==(depth,side,mat,steps,t),(f,c,actual,rays[c])
        n+=1;poses.add(pose);records.append(dict(frame=int.from_bytes(r[0x78:0x7a],'little'),pose=pose,ticks=int.from_bytes(r[0x7a:0x7c],'little'),buffer=shown))
    assert n>=min_frames,(out,n)
    result=dict(frames=n,distinctPoses=len(poses),descriptorDifferences=0,framebufferPixelDifferences=0,screenColorRegisters='PASS',records=records)
    (out/'correctness.json').write_text(json.dumps(result,indent=2));return result

def profile(out,mode,std):
    lab=labels(mode);names={v:k for k,v in lab.items()};events=[]
    for line in (out/'trace.log').read_text().splitlines():
        m=re.search(r'\.C:([0-9a-fA-F]{4}).*\s(\d+)\s*$',line)
        if m:events.append((names.get(int(m[1],16),hex(int(m[1],16))),int(m[2])))
    # Name aliases resolved explicitly, not dictionary label order.
    starts={k:[] for k in ['render_frame_begin','geometry_done','strips_done','render_frame_end','presentation_done','irq','irq_exit','simulation_tick','simulation_done']}
    addr_to_name={lab[k]:k for k in starts}
    events=[]
    for line in (out/'trace.log').read_text().splitlines():
        m=re.search(r'\.C:([0-9a-fA-F]{4}).*\s(\d+)\s*$',line)
        if m and int(m[1],16) in addr_to_name:
            k=addr_to_name[int(m[1],16)];t=int(m[2])
            # A trace AND snapshot breakpoint at one PC produce two monitor lines.
            # They are one executed instruction, not two published images.
            if events and events[-1]==(k,t):continue
            starts[k].append(t);events.append((k,t))
    hz=1108405 if std=='pal' else 1022727
    origin=starts['render_frame_begin'][0];lo=origin+2*hz;hi=lo+20*hz
    assert starts['presentation_done'][-1]>=hi,'benchmark too short'
    p=[t for t in starts['presentation_done'] if lo<=t<hi]
    frames=[];current={};irq_intervals=[];irq_start=None
    for name,t in events:
        if name=='irq':irq_start=t
        elif name=='irq_exit' and irq_start is not None:irq_intervals.append((irq_start-36,t+22));irq_start=None
        elif name=='render_frame_begin':current={name:t}
        elif name in ('geometry_done','strips_done','render_frame_end','presentation_done'):
            current[name]=t
            if name=='presentation_done' and len(current)==5 and lo<=t<hi:frames.append(current)
    def irqcost(a,b):return sum(max(0,min(b,y)-max(a,x)) for x,y in irq_intervals if x<b and y>a)
    phase_names=['geometry','stripSelection','composition','presentationWait'];keys=['render_frame_begin','geometry_done','strips_done','render_frame_end','presentation_done']
    costs={k:[] for k in phase_names};irq=[];latency=[]
    for f in frames:
        for k,a,b in zip(phase_names,keys,keys[1:]):costs[k].append(f[b]-f[a]-irqcost(f[a],f[b]))
        irq.append(irqcost(f[keys[0]],f[keys[-1]]));latency.append((f[keys[-1]]-f[keys[0]])/hz*1000)
    allp=starts['presentation_done'];dur=[b-a for a,b in zip(allp,allp[1:]) if lo<=b<hi]
    def stats(x):
        a=sorted(x);return dict(mean=statistics.mean(a),median=statistics.median(a),p95=a[math.ceil(.95*len(a))-1],worst=max(a),min=min(a))
    result=dict(mode=mode,standard=std,seconds=20,warmupSeconds=2,presented=len(p),fps=len(p)/20,
                frameCycles=stats(dur),poseToPublicationMs=stats(latency),phases={k:statistics.mean(v) for k,v in costs.items()},
                irqIncludingSimulation=statistics.mean(irq),irqAccounting='trace span plus 36 entry and 22 exit clocks (disassembled KERNAL IRQ); no guest profiler code',
                clockHz=hz,renderedRaysPerView=32)
    (out/'performance.json').write_text(json.dumps(result,indent=2));return result

def one(spec):
    std,repeat=spec
    out=run('auto',std,f'qualification-{repeat}',cycles=34000000,frames=tuple(range(1,121)) if repeat==1 else ())
    c=check(out) if repeat==1 else None;p=profile(out,'auto',std)
    print(std,repeat,p['fps'],p['frameCycles'],flush=True)
    return dict(repeat=repeat,performance=p,correctness={k:v for k,v in c.items() if k!='records'} if c else None)
def main():
    with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(one,[(s,r) for s in ('pal','ntsc') for r in (1,2)]))
    (ROOT/'artifacts/qualification.json').write_text(json.dumps(results,indent=2));print('Native qualification complete',flush=True)
if __name__=='__main__':main()
