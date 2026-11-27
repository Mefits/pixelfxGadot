"""Independent arithmetic checks, not an execution of the GDScript solver."""
from itertools import product
from math import isfinite, ceil

RUN, WALK, ACCEL, BRAKE, AIR, BASE = 111., 30., 300., 420., 110., 64.
def approach(x, target, step):
    return max(x-step,min(x+step,target))

def ground(speed, direction, command, shift, x, right=1000):
    target=(RUN if shift else WALK) if direction==command else 0.
    old=abs(speed)
    v=approach(old,target,(ACCEL if target>old else BRAKE)/60)
    nx=max(-1000,min(right,x+direction*v/60))
    delta=abs(nx-x)
    blocked=delta+1e-5<v/60
    return (0. if blocked or v<1e-5 else direction*delta*60),nx,blocked

def launch(speed, command):
    direction=(1 if speed>0 else -1) if abs(speed)>.01 else command
    v=BASE*direction
    if abs(speed)>.01:
        v=speed if command==0 or command!=direction else direction*max(BASE,abs(speed))
    return v,max(BASE,abs(v))

cases=samples=0
for direction, initial, release in product((-1,1),(0.,WALK),range(1,31)):
    x=0.; speed=initial*direction
    for _ in range(release):
        prev=speed; speed,x,_=ground(speed,direction,direction,True,x)
        assert 0<=direction*speed<=RUN+1e-7
        assert abs(speed-prev)<=ACCEL/60+1e-7
        samples+=1
    for command in (0,-direction,direction):
        v=speed; pos=x
        for _ in range(30):
            prev=v; v,pos,_=ground(v,direction,command,False,pos)
            assert v*direction>=-1e-8 and abs(v-prev)<=BRAKE/60+1e-7
            samples+=1
        assert abs(abs(v)-(WALK if command==direction else 0))<1e-7
        cases+=1
for direction, speed, command, seconds, ratio, steering in product((-1,1),(0,30,60,80,111),(-1,0,1),(.4,.8,1.4),(.5,1.35,1.7),('hold','release','reverse')):
    v,limit=launch(speed*direction,command); initial=v
    n=round(seconds*60); h=52.7*ratio; x=peak=0.
    for age in range(1,n+1):
        c=command if steering=='hold' or age<=n//2 else (0 if steering=='release' else -command)
        before=v
        if c:v=approach(v,limit*c,AIR/60)
        assert abs(v-before)<=AIR/60+1e-7
        x+=v/60; y=4*h*(age/n)*(1-age/n); peak=max(peak,y)
        assert isfinite(x) and 0<=y<=h+1e-7
        samples+=1
    assert y==0 and abs(peak-h)<.01
    if speed==111 and command==direction and steering=='hold':assert abs(x-direction*111*seconds)<1e-7
    if speed==111 and not command:assert abs(x-direction*111*seconds)<1e-7
    if speed:assert initial*direction>0
    for second in (-1,0,1):
        cap=max(BASE,limit)*1.25
        after=cap*second if second else v
        assert after==v if second==0 else after*second>0
    cases+=1
# Boundary: full sprint must not tunnel into the training target.
x=0.; v=0.
for _ in range(100):
    v,x,_=ground(v,1,1,True,x,19.)
    assert x<=19.
assert v==0. and launch(v,0)[0]==0.
# Standard reference: first jump horizontal displacement, no walls.
assert abs(RUN*.8-88.8)<1e-9 and abs(BASE*.8-51.2)<1e-9
print(f'V14 independent model: {cases} scenarios, {samples} motor/flight ticks; 51.2 -> 88.8 units; all checks OK')
