"""Execute assembled instructions, compare to host fixed and continuous geometry."""
import sys,json,random,time,os
from pathlib import Path
ROOT=Path(os.environ['VIBEVIC_WORK'])
from py65.devices.mpu6502 import MPU
from model import *

def load(mode='auto'):
    b=ROOT/'artifacts/build'/mode
    labels={l.split()[2].lstrip('.'):int(l.split()[1],16) for l in (b/'labels.txt').read_text().splitlines() if l.startswith('al ')}
    cpu=MPU();p=(b/'vibe20.prg').read_bytes();addr=int.from_bytes(p[:2],'little');cpu.memory[addr:addr+len(p)-2]=p[2:]
    return cpu,labels,json.loads((b/'scene.json').read_text())

def call(cpu,labels,name,limit=1000000):
    cpu.sp=255;cpu.stPushWord(0x0ffe-1);cpu.pc=labels[name];start=cpu.processorCycles
    for _ in range(limit):
        cpu.step()
        if cpu.pc==0x0ffe:return cpu.processorCycles-start
    raise AssertionError(f'{name} did not return, pc={cpu.pc:04x}')
def putpose(mem,addr,pose):
    for i,v in enumerate(pose):mem[addr+i*2:addr+i*2+2]=[v&255,v>>8]

def run():
    cpu,l,s=load();g=s['grid'];rng=random.Random(2048)
    poses=[(1408,1408,a) for a in list(range(0,512,8))+[1,127,129,255,257,383,385,511]]
    poses += [(x,y,a) for x,y in [(560,560),(800,560),(1281,2500),(1535,3900),(1600,5000),(2800,6000)] for a in (0,64,128,256,384,511) if clear(g,x,y)]
    tour=json.loads((ROOT/'artifacts/trajectory.json').read_text())
    poses += [tuple(p) for p in tour[::80]]
    result=[];errors=[];ambiguous=[]
    for pose in poses:
        putpose(cpu.memory,0x26,pose);cy=call(cpu,l,'raycast_all')
        image,rays=framebuffer(g,pose)
        for c,(depth,side,mat,steps,t) in enumerate(rays):
            actual=(cpu.memory[0x3a00+c]+cpu.memory[0x3a20+c]*256,cpu.memory[0x3a40+c],cpu.memory[0x3a80+c],cpu.memory[0x3a60+c],cpu.memory[0x3aa0+c]+256*cpu.memory[0x3ac0+c])
            assert actual==(depth,side,mat,steps,t),(pose,c,actual,rays[c])
            z,gs,corner=geometric(g,*pose,c)
            error=abs(z-depth/256)
            if corner or gs!=side:ambiguous.append(dict(pose=pose,column=c,error=error,corner=corner,sideDifferent=gs!=side))
            else:errors.append(error)
        cs=call(cpu,l,'select_strips')
        draw=[]
        for b,base in [(0,0x1000),(1,0x1800)]:
            cpu.memory[0x70]=b;draw.append(call(cpu,l,'compose'))
            assert bytes(cpu.memory[base:base+1536])==image,(pose,b)
        result.append(dict(pose=pose,geometry=cy,strips=cs,compose=draw[0],meanSteps=sum(r[3] for r in rays)/32))
    # Same simulation code, no IRQ or graphics; verify collisions and wrap on actual CPU.
    pose=INITIAL;putpose(cpu.memory,0x20,pose);call(cpu,l,'init_simulation')
    for tick in range(4000):
        key=rng.choice([0,1,2,4,8,5,9]);cpu.memory[0x6a]=key
        call(cpu,l,'simulation_tick');pose=simulation(g,pose,key)
        actual=tuple(cpu.memory[0x20+i*2]+256*cpu.memory[0x21+i*2] for i in range(3))
        assert pose==actual,(tick,key,pose,actual)
    out=ROOT/'artifacts/numeric';out.mkdir(parents=True,exist_ok=True)
    report=dict(poses=len(poses),rays=len(poses)*32,framebuffers=len(poses)*2,simulationTicks=4000,
                fixedMismatches=0,maxContinuousDepthErrorCells=max(errors),cornerOrSideCases=ambiguous,
                cycles=result)
    (out/'results.json').write_text(json.dumps(report,indent=2))
    assert max(errors)<0.2,'depth error exceeds 0.2-cell numeric qualification bound'
    print({k:v for k,v in report.items() if k not in ('cycles','cornerOrSideCases')},'corner/side cases',len(ambiguous),flush=True)
if __name__=='__main__':run()
