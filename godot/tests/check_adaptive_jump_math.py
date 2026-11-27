"""Numerical reference for v9 (not actual GDScript execution)."""
import math
from check_adaptive_guard_math import solve, Q

def smooth(a,b,t):
    v=max(0,min(1,(t-a)/(b-a)))
    return v*v*(3-2*v)

max_error=0
min_clearance=0
cases=0
for scale in (.85,1.,1.15):
    for lead in (0,1):
        goals=[complex(Q(1+6*scale)),complex(Q(1-6*scale))]
        if lead: goals.reverse()
        for initial in (-1,0,1):
            for mode in ('held','released','reverse'):
                vx=64*initial
                x=0
                peak=0
                height=1.5*52.7
                for tick in range(1,49):
                    u=tick/48
                    altitude=height*4*u*(1-u)
                    peak=max(peak,altitude)
                    command=initial if mode=='held' or tick<=12 else (0 if mode=='released' else -initial)
                    if command:
                        vx+=max(-110/60,min(110/60,64*command-vx))
                    nxt=max(-48,min(48,x+vx/60))
                    if abs(nxt-x-vx/60)>.0001: vx=0
                    x=nxt
                    lean=vx/64
                    tuck=max(0,math.sin(math.pi*u))**1.4
                    points=[g+complex((2.2*lean+(1.4 if i==lead else -1.4))*tuck,-(7 if i==lead else 10)*tuck) for i,g in enumerate(goals)]
                    root_y=.35 if tick<48 else 1.70
                    _,solved=solve(1.5*lean*tuck,root_y,2+12*lean*tuck,45,points,[8*tuck]*2)
                    err=max(abs(v[0]-p) for v,p in zip(solved,points))
                    max_error=max(max_error,err)
                    min_clearance=min(min_clearance,*(altitude-v[0].imag for v in solved))
                    assert err<.03, (scale,lead,initial,mode,tick,err)
                    assert -48<=x<=48 and altitude>=0
                    assert solved[lead][0].real>solved[1-lead][0].real
                    cases+=1
                assert abs(peak/52.7-1.5)<1e-9
                assert abs(altitude)<1e-9
                if mode!='reverse': assert x*initial>35 if initial else x==0
print(f'jump reference: {cases} flight/landing samples; max toe residual={max_error:.6f}; min clearance={min_clearance:.6f}; peak=1.5 body heights')
