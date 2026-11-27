"""Independent geometry check of profile width at guard and kick landing.
Not a Godot execution test."""
import math
import json
from pathlib import Path
from check_adaptive_guard_math import solve, Q, base_y
from check_attack_adaptation_math import clip, fk, swap, S
from check_planted_punch_math import plant
from copy import deepcopy

profile=json.loads((Path(__file__).parent.parent/'lab/profiles/default_fighter.json').read_text())
assert profile['guard']['width_scale']==1.0
max_idle_error=max_landing_error=0
idle_samples=landing_samples=0
for scale in (.85,1.,1.15):
    targets=[complex(Q(1+6*scale)),complex(Q(1-6*scale))]
    for lead in (0,1):
        goals=targets if not lead else targets[::-1]
        for tick in range(121):
            u=tick/120; t=math.sin(math.tau*u); c=math.sin(math.pi*u)**2
            pitch=[2*max(0,-t)**2,2*max(0,t)**2]
            if lead: pitch.reverse()
            _,solved=solve(.7*t,base_y+.30*c+.12*t*t,2+.45*t-.25*c,45,goals,pitch)
            err=max(abs(v[0]-g) for v,g in zip(solved,goals)); max_idle_error=max(max_idle_error,err)
            assert err<.01, (scale,lead,tick,err)
            assert solved[lead][0].real>solved[1-lead][0].real
            idle_samples+=1
        def source(tick):
            p=clip['keys'][38+tick]['pose']; return swap(p) if lead else deepcopy(p)
        def toes(p):
            q=fk(p); return [q['toe_'+s] for s in S]
        fixed=complex(toes(source(14))[lead].real,0)
        front,back=max(g.real for g in goals),min(g.real for g in goals)
        advance=fixed.real-back; target=fixed+front-back
        for tick in range(15,27):
            p=source(tick); old=toes(p); u=(tick-14)/12; w=u*u*(3-2*u)
            points=old[:]; kick=1-lead
            points[lead]=fixed; points[kick]=complex(old[kick].real+(target.real-old[kick].real)*w,min(0,old[kick].imag)) if tick<26 else target
            root=complex(*p['root'])*(1-w)+complex(advance,.35)*w; p['root']=[root.real,root.imag]
            result=plant(p,points); actual=toes(result)
            err=max(abs(a-b) for a,b in zip(actual,points)); max_landing_error=max(max_landing_error,err)
            assert err<.01
            landing_samples+=1
        result['root'][0]-=advance
        assert max(abs(a-b) for a,b in zip(toes(result),goals[::-1]))<.01
print(f'profile geometry: {idle_samples} idle and {landing_samples} landing samples; residuals {max_idle_error:.6g}, {max_landing_error:.6g}')
