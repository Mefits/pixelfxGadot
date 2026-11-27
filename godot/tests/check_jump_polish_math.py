"""Independent reference checks for tuning/timing; not a Godot runtime test."""
from itertools import product
import math

def phase(a,b,u):
    t=min(1,max(0,(u-a)/(b-a)))
    return t*t*(3-2*t)

def shape(u,power,tuck):
    return (phase(0,.16,u)*(1-phase(.18,.38,u))*power,
            phase(.16,.42,u)*(1-phase(.56,.82,u))*tuck,
            phase(.62,1,u))

cases=samples=0
for ratio, seconds,power,tuck,direction,steer in product((.5,1.,1.5,1.7),(.4,.45,.8,1.4),(.5,1.,1.5),(0.,1.,1.5),(-1,0,1),('hold','reverse','release')):
    n=round(seconds*60); height=52.7*ratio; x=0.; vx=64*direction; peak=0
    for age in range(1,n+1):
        u=age/n; alt=height*4*u*(1-u); peak=max(peak,alt)
        command=direction if steer=='hold' or age<=n//2 else (-direction if steer=='reverse' else 0)
        if command: vx+=max(-110/60,min(110/60,64*command-vx))
        nx=max(-120,min(120,x+vx/60))
        if abs(nx-x-vx/60)>.0001:vx=0
        x=nx
        a,b,c=shape(u,power,tuck)
        assert 0<=a<=power and 0<=b<=tuck and 0<=c<=1
        assert math.isfinite(x) and -120<=x<=120 and 0<=alt<=height+1e-9
        assert all(math.isfinite(v) for v in (a,b,c))
        samples+=1
    assert alt==0 and abs(peak/52.7-ratio)<=ratio/n**2+1e-9
    if steer!='reverse':assert x*direction>0 if direction else x==0
    cases+=1
for speed in (1.,.5,.25,.1):
    credit=0; steps=0
    for frame in range(600):
        credit+=speed
        if credit>=1-1e-6:
            credit=max(0,credit-1);steps+=1
    assert steps==round(600*speed),(speed,steps)
assert shape(.5,1.,0.)[1]==0
assert shape(.5,1.,1.5)[1]==1.5
assert shape(.16,1.5,1.)[0]==1.5
print(f'V12 reference: {cases} parameter/direction cases, {samples} flight samples, 4 playback speeds OK')
