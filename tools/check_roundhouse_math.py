"""Analytic check of the authored v18 targets, not Godot execution.
Reuses the independent v17a FK/IK reference and verifies the new polar path.
"""
import ast
import math as m
import re
import runpy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
base = runpy.run_path(str(ROOT / 'tools/check_sparse_kick_math.py'))
geometry, solve, reach, smooth = (base[x] for x in ('geometry','solve','reach','smooth'))
keys = [ast.literal_eval(row) for row in re.findall(r'^    (\{[^\n]+\})', (ROOT/'godot/lab/roundhouse_kick_poses.gd').read_text(), re.M)]
assert [k['tick'] for k in keys] == [10,13,26]
drive_channels = {'pelvis_turn','shoulder_turn','support_hip_x','support_length','support_pitch','lean','chest','head','pitch'}
def lerp(a,b,u): return a+(b-a)*u

def sample(tick):
    a,b=keys[:2];limb=drive=0.;radius,angle=a['radius'],a['angle']
    if 10<tick<=13:
        t=(tick-10)/3
        limb=t**1.65;drive=smooth(t*1.35)
        radius=lerp(a['radius'],b['radius'],limb)
        angle=lerp(a['angle'],b['angle'],smooth(t))
    elif tick>13:
        a,b=keys[1:];t=min(1,(tick-13)/13)
        limb=drive=smooth(t)
        if tick<=18:
            arc=smooth((tick-13)/5)
            radius=lerp(a['radius'],.91,arc);angle=lerp(a['angle'],-42.,arc)
        else:
            fold=min(1,(tick-18)/8)
            radius=lerp(.91,b['radius'],smooth(fold*1.35));angle=lerp(-42.,b['angle'],smooth(fold**2))
    result={k:lerp(a[k],b[k],drive if k in drive_channels else limb) for k in a if k not in ('tick','radius','angle')}
    result['ankle']=(radius*m.cos(m.radians(angle)),radius*m.sin(m.radians(angle)))
    return result

def shin_tip(hip,ankle,bend):
    # Equal length links of accepted rig. Positive knee bend for both sides.
    theta=m.atan2(ankle[1]-hip[1],ankle[0]-hip[0])-m.radians(bend)/2
    knee=(hip[0]+reach/2*m.cos(theta),hip[1]+reach/2*m.sin(theta))
    return tuple(lerp(k,a,.9) for k,a in zip(knee,ankle))

max_slip=0.;max_floor=-m.inf;samples=0
for support in (0,1):
    for anchor in (-150,-35,-5,0,8,25,150):
        for n in range(65):
            t=10+n/4
            k=sample(t)
            st,toe,ankle,hip,sb,sa,b,a=geometry(k,support,anchor)
            max_slip=max(max_slip,m.dist(st,(anchor,0)))
            max_floor=max(max_floor,toe[1])
            assert toe[1]<=0
            assert 0<=sb<=155 and -95-1e-8<=sa<=85+1e-8
            assert 0<=b<=155 and -95-1e-8<=a<=85+1e-8
            assert m.hypot(*k['ankle'])<=.999001
            if t in (10,26):assert b>120
            if t==13:assert b<8 and (ankle[1]-hip[1])<-.44*reach
            samples+=1
    tips=[]
    for t in range(10,19):
        st,toe,ankle,hip,sb,sa,b,a=geometry(sample(t),support)
        tips.append(shin_tip(hip,ankle,b))
    hit=tips[3];peak=max(m.dist(a,b)*60 for a,b in zip(tips[:3],tips[1:4]))
    assert hit[0]>1.25*reach and hit[1]<-reach
    assert peak>20*reach
    assert tips[-1][1]<hit[1] # follows through upwards, not an immediate recoil
    print(f'ROUND_SIDE={1-support} SHIN_REACH={hit[0]:.3f} SHIN_HEIGHT={-hit[1]:.3f} PEAK_SPEED={peak:.3f} FOLLOW_THROUGH_DY={tips[-1][1]-hit[1]:.3f}')
assert max_slip<1e-8
for t in (10,13,18,26):
    x=sample(t)['ankle']
    assert m.dist(x,sample(t-1e-5)['ankle'])<1e-4
    assert m.dist(x,sample(t+1e-5)['ankle'])<1e-4
assert sample(13)['pelvis_turn']<sample(11)['pelvis_turn']<sample(10)['pelvis_turn']
assert sample(26)['pelvis_turn']<sample(13)['pelvis_turn']
print(f'ROUND_TARGETS_OK samples={samples} anchor_error={max_slip:.9f} max_free_toe_y={max_floor:.3f}')
