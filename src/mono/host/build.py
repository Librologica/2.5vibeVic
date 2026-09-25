"""Isolated VIC-20 generator, native RAM expansion 24K (blocks 1,2,3)."""
from pathlib import Path
import argparse,json,hashlib,subprocess,shutil,os
from model import *
ROOT=Path(__file__).resolve().parents[1]
def emit(name,data):
    return name+':\n'+'\n'.join(' .byte '+','.join(f'${b:02x}' for b in data[i:i+16]) for i in range(0,len(data),16))+'\n'

def edge_tables():
    source=''
    for k in (1,3,5,7):source+=emit(f'edge_lerp_{k}',bytes(((d*k+4)//8)&255 for d in range(-48,49)))
    for plane in ('lo','hi'):
        source+=emit(f'edge_row_{plane}',bytes((((y//8)*128+(y&7))>>(8 if plane=='hi' else 0))&255 for y in range(96)))
    source+=emit('edge_masks',bytes(128>>(x&7) for x in range(128)))
    source+=emit('edge_columns',bytes((x//8)*8 for x in range(128)))
    source+=emit('edge_floor',bytes(0xaa if y%2==0 else 0x55 for y in range(96)))
    source+=emit('edge_shade',bytes(WALL_DITHER[y&7] for y in range(96)))
    return source

def composer():
    code=['compose:',' lda drawbuf',' bne compose_b']
    for name,base in [('a',0x1000),('b',0x1800)]:
        code += [f'compose_{name}:',' ldx #0',f'compose_{name}_col:',' txa',' lsr',' lsr',' tay',
                 ' lda strip_lo,y',' sta ptr_l',' lda strip_hi,y',' sta ptr_l+1',' iny',
                 ' lda strip_lo,y',' sta ptr_r',' lda strip_hi,y',' sta ptr_r+1',' ldy #0']
        for y in range(96):
            code+=[' lda (ptr_l),y',' and #$f0',' sta compose_tmp',' lda (ptr_r),y',' and #$0f',
                   ' ora compose_tmp',f' sta ${base+(y//8)*128+(y&7):04x},x']
            if y!=95:code+=[' iny']
        code+=[' txa',' clc',' adc #8',' tax',f' bpl compose_{name}_col',' jmp refine_edges']
    return '\n'.join(code)+'\n'

def raycode():
    s=(ROOT/'reference/raycast.asm').read_text()
    # Keep geometric setup/traversal. Remove UV/texture state and all UV products.
    start=s.index('ray_t_lo=$3a00');end=s.index('init_camera:',start)
    s=s[:start]+s[end:]
    s=s.replace('cmp #80','cmp #32')
    start=s.index('ray_hit:');end=s.index('uv_ready:',start)
    s=s[:start]+'ray_hit:\n sta hit_mat\n'+s[end+len('uv_ready:\n'):]
    s=s.replace(' sta hit_u\n','').replace(' lda hit_u\n sta ray_u,x\n','')
    s=s.replace('ray_store:\n ldx ray_index', '''ray_store:
 ldx ray_index
 lda hit_side
 bne store_face_y
 lda cell_y
 sta ray_along,x
 lda dir_sign
 and #1
 sta temp
 lda cell_x
 jmp store_face_key
store_face_y:
 lda cell_x
 sta ray_along,x
 lda dir_sign
 lsr
 and #1
 ora #2
 sta temp
 lda cell_y
store_face_key:
 asl
 asl
 ora temp
 sta ray_face,x''')
    start=s.index('mul16x8_shift8:');s=s[:start]+(ROOT/'reference/multiply.asm').read_text()+'\n'
    fields=[('dx','delta_x',0),('dx','delta_x+1',8),('dy','delta_y',0),('dy','delta_y+1',8),('sign','dir_sign',0)]
    code=['load_direction:',' ldy angle',' lda angle+1',' bne direction_high']
    for half in (0,1):
        if half:code+=['direction_high:']
        for i,(_,dst,_) in enumerate(fields):code+=[f' lda direction_{i}+{half*256},y',f' sta {dst}']
        # A reciprocal 65535 occurs only for exact axis in this 512-entry domain.
        code+=[' lda delta_x+1',' eor #$ff',' sta dir_x',' lda delta_y+1',' eor #$ff',' sta dir_y',
               ' lda #0',' sta dir_x+1',' sta dir_y+1',' rts']
    return s+'\n'.join(code)+'\n',fields

def simulation():
    s=(ROOT/'reference/simulation.asm').read_text()
    start=s.index(' ; Joystick port2');end=s.index('.endif',start)
    # VIA drives the matrix column via PB and reads the row through PA;
    # it is transposed relative to the C64 CIA scan. Verified with VICE matrices.
    keyboard=''' lda #$ff
 sta $9122
 lda #$fd
 sta $9120
 lda $9121
 and #2
 bne input_not_w
 lda keys
 ora #1
 sta keys
input_not_w:
 lda #$df
 sta $9120
 lda $9121
 and #2
 bne input_not_s
 lda keys
 ora #2
 sta keys
input_not_s:
 lda #$fb
 sta $9120
 lda $9121
 sta key_row
 and #2
 bne input_not_a
 lda keys
 ora #4
 sta keys
input_not_a:
 lda key_row
 and #4
 bne input_not_d
 lda keys
 ora #8
 sta keys
input_not_d:
 lda #$ff
 sta $9120
 rts
'''
    joystick=''' lda #0
 sta $9123
 lda $9113
 and #$e3
 sta $9113
 lda $9111
 eor #$ff
 lsr
 lsr
 and #7
 sta keys
 lda #$7f
 sta $9122
 lda #$ff
 sta $9120
 lda $9120
 bmi input_no_joy_right
 lda keys
 ora #8
 sta keys
input_no_joy_right:
'''
    return s[:start]+joystick+keyboard+s[end:]

def build(mode='interactive',scene_file=None,out=None):
    if out is None:raise ValueError('Use the public build.py with an external --out directory')
    out=Path(out);out.mkdir(parents=True,exist_ok=False)
    sc=json.loads(Path(scene_file).read_text()) if scene_file else scene();g=validate(sc)
    (out/'scene.json').write_text(json.dumps(sc,indent=2))
    (out/'map.bin').write_bytes(bytes(g))
    constants='\n'.join(f'{k}={v}' for k,v in zip(('INITIAL_X','INITIAL_Y','INITIAL_ANGLE'),sc['initial']))
    route=sc.get('autoRoute',ROUTE)
    constants+=f'\nAUTO_RUN={int(mode=="auto")}\nROUTE_LENGTH={len(route)}\n'
    ray,fields=raycode()
    source=constants+(ROOT/'asm/runtime.asm').read_text()+'\n'+ray+simulation()+composer()+(ROOT/'asm/edges.asm').read_text()+'\ncode_end:\n'+edge_tables()+'low_end:\n'
    source+=' .cerror * > $3a00, "Code collides with descriptors"\n*=$3c00\n .binary "map.bin"\n*=$4000\n'
    strips=b''.join(strip(t,side) for side in (0,1) for t in range(49))
    source+=emit('scaled_strips',strips)
    source+=emit('strip_address_lo',bytes((0x4000+i*96)&255 for i in range(98)))
    source+=emit('strip_address_hi',bytes((0x4000+i*96)>>8 for i in range(98)))
    source+=emit('ray_offset_lo',bytes(o&255 for o in OFF))+emit('ray_offset_hi',bytes((o>>8)&255 for o in OFF))
    source+=emit('ray_cos',bytes(c&255 for c in COS))+emit('ray_cos_axis',bytes(c>>8 for c in COS))
    source+=emit('movement_x',bytes(round(6*d['x'])&255 for d in DIR))+emit('movement_y',bytes(round(6*d['y'])&255 for d in DIR))
    for name,data in [('auto_keys',[k for k,n in route]),('auto_duration_lo',[n&255 for k,n in route]),('auto_duration_hi',[n>>8 for k,n in route])]:source+=emit(name,bytes(data))
    source+=' .align 256\n'+emit('quarter_lo',bytes(((n*n)//4)&255 for n in range(512)))+emit('quarter_hi',bytes(((n*n)//4)>>8 for n in range(512)))
    source+='tables_end:\n .cerror * > $7000, "Tables collide with directions"\n*=$7000\n'
    for i,(key,_,shift) in enumerate(fields):source+=emit(f'direction_{i}',bytes((d[key]>>shift)&255 for d in DIR))
    source+='directions_end:\n .cerror * > $7c00, "Directions collide with projection"\n*=$7c00\n'+emit('height_table',bytes(HEIGHT))+'data_end:\n'
    (out/'vibe20.asm').write_text(source)
    assembler=os.environ.get('TASS64_EXE') or shutil.which('64tass')
    if not assembler:raise RuntimeError('64tass not found: use PATH or TASS64_EXE')
    cmd=[assembler,'-a','-B','--m6502','--vice-labels-numeric',f'--labels={out}/labels.txt',f'--list={out}/listing.txt',f'--map={out}/memory.map','-o',str(out/'vibe20.prg'),str(out/'vibe20.asm')]
    run=subprocess.run(cmd,cwd=out,capture_output=True,text=True)
    (out/'assembler.log').write_text(run.stdout+run.stderr)
    if run.returncode:raise RuntimeError(run.stdout+run.stderr)
    labels={l.split()[2].lstrip('.'):int(l.split()[1],16) for l in (out/'labels.txt').read_text().splitlines() if l.startswith('al ')}
    # Entire PRG stays below $8000; no load crosses character ROM or VIC/VIA I/O.
    report=dict(mode=mode,prgBytes=(out/'vibe20.prg').stat().st_size,codeBytes=labels['code_end']-0x2000,
                stripsBytes=len(strips),directionsBytes=2560,projectionBytes=1024,
                edgeTablesBytes=labels['low_end']-labels['code_end'],
                tableBytes=labels['tables_end']-0x4000,freeCode=0x3a00-labels['low_end'],
                prgSHA256=hashlib.sha256((out/'vibe20.prg').read_bytes()).hexdigest().upper())
    (out/'build.json').write_text(json.dumps(report,indent=2));print(json.dumps(report));return out
if __name__=='__main__':
    raise SystemExit('Use the SDK root build.py entry point')
