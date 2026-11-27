"""Independent analytic check of v17a targets; NOT a GDScript/engine test.
Uses the actual authored key table and the 069 rig leg dimensions/conventions.
"""
import ast
import math as m
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
text=(ROOT/'godot/lab/sparse_kick_poses.gd').read_text()
keys=[]
for row in re.findall(r'^    (\{[^\n]+\})',text,re.M):
    keys.append(ast.literal_eval(row.replace('Vector2(', '(')))
assert [k['tick'] for k in keys]==[9,12,22]

def smooth(t):
    t=max(0,min(1,t));return t*t*(3-2*t)
DRIVE={'pelvis_turn','shoulder_turn','support_hip_x','support_length','support_pitch','lean','chest','head'}
def sample(t,table=keys,version=17):
    if t<=table[0]["tick"]:return table[0]
    for i,(a,b) in enumerate(zip(table,table[1:])):
        if t<=b['tick']:
            u=(t-a['tick'])/(b['tick']-a['tick'])
            limb=(u**1.65 if i==0 else smooth(u*u)) if version==17 else smooth(u)
            drive=(smooth(min(1,u*1.35)) if i==0 else smooth(u*u)) if version==17 else limb
            return {k:tuple(x+(y-x)*limb for x,y in zip(a[k],b[k])) if k=='ankle' else a[k]+(b[k]-a[k])*(drive if k in DRIVE or (version==17 and k=="pitch") else limb) for k in a}
    return table[-1]
def rot(x,y,angle):
    c,s=m.cos(m.radians(angle)),m.sin(m.radians(angle));return (x*c-y*s,x*s+y*c)
def wrap(a):return (a+180)%360-180
def q(x):return round(x*1024)/1024
L=m.hypot(2,11);reach=2*L
rest=m.degrees(m.atan2(2,11))
def solve(hip,goal,pitch,hip_angle,side):
    """Direct analytic two-link IK, including rest-angle conventions."""
    dx,dy=goal[0]-hip[0],goal[1]-hip[1]
    length=min(reach-.002,max(.002,m.hypot(dx,dy)))
    bend=m.degrees(m.acos(max(-1,min(1,(length*length-2*L*L)/(2*L*L)))))
    phi=m.degrees(m.atan2(dy,dx))-bend/2
    bend=max(0,min(155,bend))
    sign=1 if side==0 else -1
    thigh=wrap(phi-(90-sign*rest)-hip_angle)
    knee=bend-2*sign*rest
    shin=hip_angle+thigh+knee+sign*rest
    ankle=wrap(pitch-shin)
    pitch=wrap(shin+min(85,max(-95,ankle)))
    a=hip_angle+thigh
    upper=rot(sign*2,11,a)
    lower=rot(-sign*2,11,a+knee)
    ankle_pos=(hip[0]+upper[0]+lower[0],hip[1]+upper[1]+lower[1])
    toe_vec=rot(4,0,pitch)
    toe=(ankle_pos[0]+toe_vec[0],ankle_pos[1]+toe_vec[1])
    return toe,ankle_pos,bend,wrap(pitch-shin),pitch

def geometry(k,support,anchor_x=0,version=17):
    strike=1-support
    hip_angle=k['lean']
    support_dx=reach*k['support_hip_x']
    support_d=reach*k['support_length']
    pitch=k.get('support_pitch',0.)
    offset=rot(4,0,pitch)
    support_ankle=(anchor_x-offset[0],-offset[1])
    support_hip=(support_ankle[0]+support_dx,support_ankle[1]-m.sqrt(support_d**2-support_dx**2))
    support_toe,_,sb,sa,_=solve(support_hip,support_ankle,pitch,hip_angle,support)
    turn=k['pelvis_turn'] if strike==0 or version==16 else 90-k['pelvis_turn']
    hip_x=m.sqrt(32)*m.sin(m.radians(45-turn))
    separation=rot(2*hip_x*(1 if strike==0 else -1),0,hip_angle)
    striking_hip=tuple(x+y for x,y in zip(support_hip,separation))
    target=tuple(x+y*reach for x,y in zip(striking_hip,k['ankle']))
    toe,ankle,b,a,_=solve(striking_hip,target,k['pitch'],hip_angle,strike)
    return support_toe,toe,ankle,striking_hip,sb,sa,b,a

samples=0;max_anchor=0;max_floor=-100;peak=[]
for support in (0,1):
    for anchor_x in (-150,-35,-5,0,8,25,150):
        for n in range(53):
            t=9+n/4
            k=sample(t)
            st,toe,ankle,hip,sb,sa,b,a=geometry(k,support,anchor_x)
            max_anchor=max(max_anchor,m.dist(st,(anchor_x,0)))
            max_floor=max(max_floor,toe[1]);assert toe[1]<=0
            assert 0<=sb<=155 and -95-1e-8<=sa<=85+1e-8
            assert 0<=b<=155 and -95-1e-8<=a<=85+1e-8
            if t in (9,22):assert b>100
            if t==12:
                peak.append(b);assert ankle[0]-hip[0]>.995*reach and abs(ankle[1]-hip[1])<2
            samples+=1
assert max_anchor<1e-8
# Heel contact uses the same ankle-local proxy as the new K hit query.
# This does not change the toe reference used for locomotion contacts.
def heel(k,support):
    st,toe,ankle,hip,*_=geometry(k,support)
    actual=solve(hip,ankle,k['pitch'],k['lean'],1-support)[-1]
    h=rot(-1.65,.35,actual)
    return (ankle[0]+h[0],ankle[1]+h[1]),toe
for support in (0,1):
    positions=[heel(sample(t),support)[0] for t in range(9,13)]
    h,toe=heel(keys[1],support)
    peak_speed=max((b[0]-a[0])*60 for a,b in zip(positions,positions[1:]))
    assert h[0]>toe[0]+.5
    assert h[0]>1.45*reach and peak_speed>28*reach
    # Heel is already ahead of the toe when the active sweep opens.
    assert heel(sample(11),support)[0][0]>heel(sample(11),support)[1][0]
    print(f'STRIKE_SIDE={1-support} HEEL_REACH={h[0]:.3f} HEEL_LEAD={h[0]-toe[0]:.3f} HEEL_PEAK_SPEED={peak_speed:.3f}')
assert m.dist(heel(keys[1],0)[0],heel(keys[1],1)[0])<1e-8
# Independent check of motor carry and 32-tick release: no sign flip or
# acceleration, stops before retraction, cannot cross travel/bag boundary.
braking_cases=0
for speed in range(-111,112):
    for x0 in (-165.,-10.,0.,18.9,19.,165.):
        right=19. if x0<=34 else 165.
        x=x0;v=speed
        for tick in range(1,33):
            old=v;v=m.copysign(max(0,abs(v)-12),v)
            target=max(-165,min(right,x+v/60))
            assert -165<=target<=right
            assert abs(v)<=abs(old) and v*old>=0
            if abs((target-x)*60-v)>.001:v=0
            x=target
            if tick>=10:assert v==0
        braking_cases+=1
# MotionEntry horizon mathematically has a continuous derivative and zero
# derivative at the endpoint; target weight starts/ends with zero slope.
for h in (4,8,12):
    f=lambda t:min(t,h)*(1-min(t,h)/(2*h))
    assert f(0)==0 and f(h)==h/2 and f(h+1)==f(h)
    assert abs((f(h)-f(h-1e-4))/1e-4)<1e-4
print(f'TARGET_GEOMETRY_OK samples={samples} anchor_error={max_anchor:.9f} peak_knee={min(peak):.3f}..{max(peak):.3f} max_air_toe_y={max_floor:.3f}')
print(f'BRAKING_MODEL_OK cases={braking_cases} samples={braking_cases*32}')
print('MOTION_ENTRY_HORIZON_OK')
