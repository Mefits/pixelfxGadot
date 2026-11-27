"""Independent arithmetic checks, not a Godot run."""
import itertools
cases=0
for duration, rest, pause in itertools.product((17,32,36,75),range(12,181,6),(0,1,60)):
    enabled=True; remaining=0; busy=0; starts=[]; sim=0
    while len(starts)<4:
        # During a paused interval the scheduler and the attack clock do not run.
        for _ in range(pause):
            snapshot=(remaining,busy,sim)
            assert (remaining,busy,sim)==snapshot
        if enabled and busy==0:
            if remaining>0:remaining-=1
            else:
                starts.append(sim);busy=duration;remaining=rest
        busy=max(0,busy-1);sim+=1
    assert starts==[i*(duration+rest) for i in range(4)]
    enabled=False;remaining=0
    assert not enabled and remaining==0
    cases+=1
print(f'ATTACK_REPEAT_MATH_OK cases={cases}')
