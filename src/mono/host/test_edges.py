"""Exhaustive integer interpolation, discontinuity guards, memory bounds."""
import json,os
from pathlib import Path
from test_numeric import load,call
ROOT=Path(os.environ['VIBEVIC_WORK'])

def prepare(cpu,l,t0,t1,key0=0,key1=0,along0=4,along1=4,mat0=1,mat1=1):
    m=cpu.memory
    m[l['ray_top']:l['ray_top']+32]=[17]*32
    m[l['ray_face']:l['ray_face']+32]=list(range(32))
    m[l['ray_along']:l['ray_along']+32]=[4]*32
    m[l['ray_mat']:l['ray_mat']+32]=[0]*32
    for field,vals in [('ray_top',[t0,t1]),('ray_face',[key0,key1]),('ray_along',[along0,along1]),('ray_mat',[mat0,mat1])]:
        m[l[field]+12:l[field]+14]=vals
    call(cpu,l,'prepare_edges')
    return m[l['pixel_top']:l['pixel_top']+128]

def main():
    cpu,l,s=load();tests=0
    for a in range(49):
        for b in range(49):
            actual=prepare(cpu,l,a,b)
            expected=[17]*128;expected[48:52]=[a]*4;expected[52:56]=[b]*4
            # Independent rational nearest rounding, no LUT/table implementation.
            for j,w in enumerate((1,3,5,7)):
                expected[50+j]=((8-w)*a+w*b+4)//8
            assert actual==expected,(a,b)
            changed=[x for x,t in enumerate(expected) if t!=([17]*12+[a,b]+[17]*18)[x//4]]
            count=cpu.memory[l['edge_count']]
            queue=cpu.memory[l['edge_queue']:l['edge_queue']+count]
            assert queue==changed,(a,b,queue,changed)
            assert all(0<=v<=48 for v in actual)
            tests+=1
    guardtests=0
    for key0,key1,along0,along1,mat0,mat1,allow in [
        (16,16,5,5,1,1,True),(16,16,5,6,1,1,True),(16,16,5,4,1,1,True),
        (16,16,5,7,1,1,False),(16,16,5,3,1,1,False),
        (16,20,5,5,1,1,False),(16,17,5,5,1,1,False),
        (16,18,5,5,1,1,False),(16,16,5,5,0,1,False),(16,16,5,5,1,0,False)]:
        actual=prepare(cpu,l,8,24,key0,key1,along0,along1,mat0,mat1)
        assert (actual[50:54]!=[8,8,24,24])==allow
        guardtests+=1
    result=dict(heightPairs=tests,guardCases=guardtests,fixedDifferences=0,
                range='0..48',rounding='nearest, half ties toward +infinity',queueExact=True)
    (ROOT/'artifacts/edge-tests.json').write_text(json.dumps(result,indent=2));print(result)
if __name__=='__main__':main()
