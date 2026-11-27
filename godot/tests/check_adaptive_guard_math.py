"""Independent numerical check of guard geometry; not a Godot runtime test."""
import cmath
import json
import math
from pathlib import Path

TAU=math.tau
PI=math.pi
Q=lambda v: round(v*1024)/1024
rot=lambda v,r:v*cmath.exp(1j*r)
rad=math.radians
wrap=lambda a:(a+PI)%TAU-PI
L=abs(2+11j)
SIDES=(1,-1)

def solve(x,y,h,pelvis,targets,pitches):
    x,y,h,pelvis=map(Q,(x,y,h,pelvis))
    hip=complex(x,y-22)
    hip_x=math.sqrt(32)*math.sin(rad(45-pelvis))
    hips=[hip+rot(s*hip_x,rad(h)) for s in SIDES]
    goals=[t-rot(4,rad(Q(p))) for t,p in zip(targets,pitches)]
    delta=[g-a for g,a in zip(goals,hips)]
    radius=2*L-.15
    drop=min(2,max(0,*(d.imag-math.sqrt(max(0,radius**2-d.real**2)) for d in delta)))
    out=[]
    for s,d,a,pitch in zip(SIDES,delta,hips,pitches):
        d-=drop*1j
        distance=min(2*L-.002,max(.002,abs(d)))
        bend=math.acos(max(-1,min(1,(distance**2-2*L**2)/(2*L**2))))
        up=cmath.phase(d)-math.atan2(L*math.sin(bend),L+L*math.cos(bend))
        rest=cmath.phase(complex(2*s,11)); lower=cmath.phase(complex(-2*s,11))
        th=Q(math.degrees(wrap(up-rest-rad(h))))
        knee=Q(math.degrees(wrap(bend+rest-lower)))
        angle=rad(h+th); angle2=rad(h+th+knee)
        ankle=a+1j*(Q(y+drop)-y)+rot(complex(2*s,11),angle)+rot(complex(-2*s,11),angle2)
        toe=ankle+rot(4,rad(Q(pitch)))
        out.append((toe,ankle))
    return Q(y+drop),out

base_y,_=solve(0,.35,2,45,[7+0j,-5+0j],[0,0])
for lead in (0,1):
    targets=[7+0j,-5+0j] if lead==0 else [-5+0j,7+0j]
    xs=[]; ys=[]; errors=[]; heels=[]
    for tick in range(121):
        u=tick/120; t=math.sin(TAU*u); c=math.sin(PI*u)**2
        x=.7*t; y=base_y+.30*c+.12*t*t; h=2+.45*t-.25*c
        pitch=[2*max(0,-t)**2,2*max(0,t)**2]
        if lead: pitch.reverse()
        actual_y,solved=solve(x,y,h,45,targets,pitch)
        xs.append(Q(x)); ys.append(actual_y)
        errors.extend(abs(v[0]-goal) for v,goal in zip(solved,targets))
        heels.extend(-v[1].imag for v in solved)
        assert solved[lead][0].real-solved[1-lead][0].real>11.9
    xr=max(xs)-min(xs); yr=max(ys)-min(ys)
    print(f'lead={lead} x_range={xr:.5f} y_range={yr:.5f} heel={max(heels):.5f} toe_error={max(errors):.6f}')
    assert 1.0<xr<1.6 and .15<yr<.8 and max(heels)<.25 and max(errors)<.01

# Check every combination of sampled old toe pairs for recovery order safety.
for lead in (0,1):
    goal=[7,-5] if lead==0 else [-5,7]
    for left in range(-20,21):
        for right in range(left+1,22):
            old=[right,left] if lead==0 else [left,right]
            for first in (0,1):
                other=1-first
                if (first==lead and goal[first]<old[other]) or (first!=lead and goal[first]>old[other]): first=other
                for tick in range(17):
                    pos=[]
                    for i in range(2):
                        k=max(0,min(1,tick/8-(0 if i==first else 1))); k=k*k*(3-2*k)
                        pos.append(old[i]+(goal[i]-old[i])*k)
                    assert pos[lead]>=pos[1-lead]-1e-9
print('recovery goal ordering: OK')
clip=json.loads((Path(__file__).parent/'fixtures/body_raster/full_058/combo052a2_B.json').read_text())['payload']['clip']
for tick in (28,38,76):
    pose=clip['keys'][tick]['pose']; a=pose['angles']; hip=complex(*pose['root'])-22j; h=rad(a['hips']); hx=math.sqrt(32)*math.sin(rad(45-a['pelvis_turn'])); toes=[]
    for side,sign in zip(('near','far'),SIDES):
        thigh=hip+rot(sign*hx,h); u=h+rad(a['thigh_'+side]); v=u+rad(a['knee_'+side]); toes.append(thigh+rot(complex(2*sign,11),u)+rot(complex(-2*sign,11),v)+rot(4,rad(a['foot_pitch_'+side])))
    print(f'original tick {tick}: near_x={toes[0].real:.3f}, far_x={toes[1].real:.3f}')
assert len(clip['keys'])==77
