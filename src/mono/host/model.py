"""VIC-20 numeric contract; DDA derived from 3Dvibe64 raycast-stock.
Copyright 2026 librologica.digital. PolyForm Noncommercial 1.0.0.
Independent continuous oracle enumerates grid intersections, not DDA steps.
"""
import math
N=32
OFF=[round(math.atan(((2*c+1)/N-1)*math.tan(math.pi/6))*512/math.tau) for c in range(N)]
COS=[round(256*math.cos(a*math.tau/512)) for a in OFF]
DIR=[]
for a in range(512):
    x=math.sin(a*math.tau/512);y=math.cos(a*math.tau/512)
    if abs(x)<1e-12:x=0
    if abs(y)<1e-12:y=0
    DIR.append(dict(x=x,y=y,dx=min(65535,round(256/abs(x))) if x else 65535,
                    dy=min(65535,round(256/abs(y))) if y else 65535,
                    sign=(1 if x<0 else 0)|(2 if y<0 else 0)))
INITIAL=(1408,1664,0)
# Two closed loops: outer galleries, then the central hall and north passage.
# Keys9 = forward + right; each64-tick quarter-turn is a continuous ~1cell arc.
# Opposite motions cancel exactly in the qualified integer movement tables.
ROUTE=[(1,800),(9,64),(1,768),(9,64),(1,800),(9,64),(1,768),(9,64),
       (1,342),(9,64),(1,342),(9,64),(1,342),(9,64),(1,342),(9,64)]
FOCAL=64/math.tan(math.pi/6)
HEIGHT=[max(0,48-round(FOCAL/max(1/16,(i+.5)/16))) for i in range(1024)]
# Static 8x8 tile, 75% white. Two black samples in each row AND column.
# No directly adjacent black samples at tile seams. Fixed screen phase.
# Expanded host-side into existing strips and edge_shade; no runtime modulo.
WALL_DITHER=(0x77,0xdd,0x7b,0xee,0xbb,0xed,0xb7,0xde)

def scene():
    grid=[1]*1024
    # Five distinct rooms and a connected ring/cross of three-cell galleries.
    areas=[(2,2,10,9),(18,2,29,9),(11,4,17,6),
           (4,10,6,21),(23,10,25,21),(2,22,11,29),(18,22,29,29),
           (12,25,17,27),(10,12,20,19),(7,14,9,16),(21,14,22,16),
           (14,7,16,11),(14,20,16,24),(7,18,9,21)]
    for x0,y0,x1,y1 in areas:
        for y in range(y0,y1+1):
            for x in range(x0,x1+1):grid[y*32+x]=0
    # Recesses and piers break long flat walls without adding rendering features.
    for x,y in [(8,3),(8,4),(26,4),(27,4),(26,5),(27,5),
                (8,27),(8,28),(21,27),(12,14),(18,14),(12,17),(18,17)]:
        grid[y*32+x]=1
    return dict(schema='vibe20-galleries-v1',size=[32,32],grid=grid,
                initial=list(INITIAL),wallHeight=2,eyeHeight=1,fov=60,rays=32)

def validate(s):
    if s.get('size')!=[32,32]:raise ValueError('size must be [32,32]')
    g=s['grid']
    if len(g)!=1024 or any(type(v)!=int or v not in (0,1) for v in g):raise ValueError('grid requires 1024 integer 0/1 cells')
    if any(g[y*32+x]!=1 for y in range(32) for x in range(32) if x in (0,31) or y in (0,31)):raise ValueError('map borders must be solid')
    x,y,a=s['initial']
    if not (0<=a<512 and 0<=x<8192 and 0<=y<8192 and clear(g,x,y)):raise ValueError('initial camera must be free with radius 48/256')
    for k,v in [('wallHeight',2),('eyeHeight',1),('fov',60),('rays',32)]:
        if s.get(k)!=v:raise ValueError(f'{k} must be {v} in this prototype')
    return g

def fixed(g,px,py,a,c):
    d=DIR[(a+OFF[c])&511];x=px>>8;y=py>>8
    sx=d['dx']*(px&255)//256;sy=d['dy']*(py&255)//256
    if not d['sign']&1:sx=d['dx']-sx
    if not d['sign']&2:sy=d['dy']-sy
    if not d['x']:sx=65535
    if not d['y']:sy=65535
    for step in range(1,65):
        side=0 if sx<=sy else 1
        if side==0:
            t=sx;x+=-1 if d['sign']&1 else 1;sx=min(65535,sx+d['dx'])
        else:
            t=sy;y+=-1 if d['sign']&2 else 1;sy=min(65535,sy+d['dy'])
        if not(0<=x<32 and 0<=y<32):return 65535,side,0,step,65535
        if g[y*32+x]:return (t*COS[c])>>8,side,g[y*32+x],step,t
    return 65535,side,0,65,65535

def geometric(g,px,py,a,c):
    # All grid plane crossings independently sorted in continuous coordinates.
    d=DIR[(a+OFF[c])&511];x=px/256;y=py/256;events=[]
    for side,(p,v) in enumerate(((x,d['x']),(y,d['y']))):
        if not v:continue
        for line in range(33):
            t=(line-p)/v
            if t<0:continue
            xx=x+t*d['x'];yy=y+t*d['y']
            ix=math.floor(xx+(1e-9 if d['x']>=0 else -1e-9))
            iy=math.floor(yy+(1e-9 if d['y']>=0 else -1e-9))
            # Corner's entered diagonal is ambiguous: expose it to tests.
            corner=abs(xx-round(xx))<1e-8 and abs(yy-round(yy))<1e-8
            events.append((t,side,ix,iy,corner))
    for t,side,ix,iy,corner in sorted(events):
        if 0<=ix<32 and 0<=iy<32 and g[iy*32+ix]:
            return t*math.cos(OFF[c]*math.tau/512),side,corner
    raise ValueError('no wall')

def strip(top,side):
    # Same fixed 1-bit palette in both buffers. Side dimming is static, no textures.
    return bytes(0 if y<top else (WALL_DITHER[y&7] if side else 255)
                 if y<96-top else (0xaa if y%2==0 else 0x55) for y in range(96))

def hit_face(g,px,py,a,c):
    # Separate fixed traversal for the surface guard; no inference from depth.
    d=DIR[(a+OFF[c])&511];x=px>>8;y=py>>8
    sx=d['dx']*(px&255)//256;sy=d['dy']*(py&255)//256
    if not d['sign']&1:sx=d['dx']-sx
    if not d['sign']&2:sy=d['dy']-sy
    if not d['x']:sx=65535
    if not d['y']:sy=65535
    for _ in range(64):
        side=int(sx>sy)
        if not side:x+=-1 if d['sign']&1 else 1;sx=min(65535,sx+d['dx'])
        else:y+=-1 if d['sign']&2 else 1;sy=min(65535,sy+d['dy'])
        if not (0<=x<32 and 0<=y<32):return 255,255
        if g[y*32+x]:return ((x if not side else y)*4+side*2+((d['sign']>>side)&1),y if not side else x)
    return 255,255

def edge_tops(g,pose,rays):
    top=[HEIGHT[min(1023,r[0]>>4)] for r in rays]
    face=[hit_face(g,*pose,c) for c in range(N)]
    out=[t for t in top for _ in range(4)]
    for i in range(N-1):
        if (rays[i][2] and rays[i+1][2] and face[i][0]==face[i+1][0]
                and abs(face[i][1]-face[i+1][1])<=1):
            # Ray centres 1.5 and 5.5; actual pixel centres at x=2,3,4,5.
            # Nearest integer row, exact half ties toward positive infinity.
            for j,k in enumerate((1,3,5,7)):
                out[i*4+2+j]=top[i]+((top[i+1]-top[i])*k+4)//8
    return out

def framebuffer(g,pose):
    rays=[fixed(g,*pose,c) for c in range(N)]
    out=bytearray(1536)
    tops=edge_tops(g,pose,rays)
    for x,top in enumerate(tops):
        pattern=strip(top,rays[x//4][1]);mask=128>>(x&7)
        for y in range(96):out[(y//8)*128+(x//8)*8+(y&7)] |= pattern[y]&mask
    return out,rays

def clear(g,x,y):
    return all(0<=xx<32 and 0<=yy<32 and not g[yy*32+xx]
               for xx in ((x-48)>>8,(x+48)>>8) for yy in ((y-48)>>8,(y+48)>>8))

def simulation(g,pose,key):
    x,y,a=pose
    a=(a+(2 if key&8 else 0)-(2 if key&4 else 0))&511
    if key&3 in (1,2):
        k=-1 if key&2 else 1;d=DIR[a]
        dx=k*round(6*d['x']);dy=k*round(6*d['y'])
        if clear(g,x+dx,y):x+=dx
        if clear(g,x,y+dy):y+=dy
    return x,y,a
