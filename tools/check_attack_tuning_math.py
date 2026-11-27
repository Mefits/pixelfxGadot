"""Independent arithmetic checks of v19 phase mapping, not GDScript execution."""
import itertools
import math

cases = samples = 0
for original in ((9,3,10,10),(10,3,13,10)):
    for spans in itertools.product((3,9,20),(2,3,8),(5,10,13,22),(5,10,25)):
        def source(age):
            a = float(age); t = 0.
            for span, orig in zip(spans, original):
                if a <= span:
                    return t + max(0., a) / span * orig
                a -= span; t += orig
            return t
        ticks = [source(i) for i in range(sum(spans)+1)]
        assert ticks[0] == 0 and ticks[-1] == sum(original)
        assert all(b > a for a,b in zip(ticks,ticks[1:]))
        for i in range(1,5):
            assert ticks[sum(spans[:i])] == sum(original[:i])
        hit = sum(spans[:2]); end = sum(spans)
        deadline = min(end,hit+(max(1,math.floor(3*spans[2]/13+.5)) if original[0]==10 else 1))
        assert 0 < hit-1 <= hit <= deadline < end
        cases += 1; samples += len(ticks)
        if spans == original: assert ticks == list(range(end+1))
# monotonic acceleration shaping, fixed endpoints and increasing late-vs-early ratio
for scale in (.5,1.,1.5):
    v=[(i/100)**(1+.65*scale) for i in range(101)]
    assert v[0]==0 and v[-1]==1 and all(a<b for a,b in zip(v,v[1:]))
    assert v[-1]-v[-2]>v[1]-v[0]
# reach and pelvis tuning clamp artistic goals instead of stretching the rig
shape_cases=0
for radius,x,angle,reach,pelvis in itertools.product((.34,.38,.91,.999),(-.06,.34,.36),(2,5,45,68,79,87),(.6,1.,1.1),(0.,1.,1.5)):
    r=min(.999,radius*reach); h=max(-.45,min(.45,x*reach)); a=max(0,min(90,45+(angle-45)*pelvis))
    assert 0<r<=.999 and abs(h)<=.45 and 0<=a<=90
    if reach==pelvis==1.: assert math.isclose(r,radius) and math.isclose(h,x) and math.isclose(a,angle)
    shape_cases+=1
print(f'ATTACK_TUNING_MATH_OK timing_cases={cases} samples={samples} shape_cases={shape_cases}')
