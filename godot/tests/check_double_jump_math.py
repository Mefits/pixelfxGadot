"""Independent arithmetic model. Does not execute Godot/GDScript."""
from itertools import product
from math import sqrt, ceil, isfinite
cases = samples = 0
for ratio, seconds, extra_ratio, speed_scale, first, second, fraction in product(
    (.5,1.25,1.35,1.7),(.4,.8,1.,1.4),(.25,.55,.8),(1.,1.25,1.5),(-1,0,1),(-1,0,1),(.02,.25,.5,.75,.98)):
    h = 52.7; H = h*ratio; n=round(seconds*60); g=8*H/(n/60)**2
    trigger=max(1,min(n-1,round(fraction*n))); u=trigger/n
    origin=4*H*u*(1-u); vy=sqrt(2*g*h*extra_ratio)
    duration=(vy+sqrt(vy*vy+2*g*origin))/g; ticks=ceil(duration*60)
    assert abs(origin+vy*duration-.5*g*duration**2)<1e-8
    x=64*first*trigger/60; vx=64*first if not second else 64*speed_scale*second
    assert vx==64*first if not second else vx*second>0
    peak=origin
    for age in range(1,ticks+1):
        t=min(age/60,duration); y=max(0,origin+vy*t-.5*g*t*t)
        peak=max(peak,y); x=max(-165,min(165,x+vx/60))
        assert isfinite(x) and 0<=y<=origin+h*extra_ratio+1e-8
        if age<ticks:assert y>0
        samples+=1
    assert y<1e-8 and -1e-8<=origin+h*extra_ratio-peak<=g/(8*60**2)+1e-8
    assert (origin+h*extra_ratio+h)*4.5<1025-114
    cases+=1
print(f'V13 independent trajectory: {cases} cases, {samples} flight samples OK')
