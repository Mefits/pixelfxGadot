"""Independent numerical reference: landing, support, and world rebase.
Does not execute GDScript or the Godot renderer."""
from copy import deepcopy
from check_attack_adaptation_math import clip, fk, swap, S
from check_planted_punch_math import plant

for lead in (0,1):
    kick=1-lead; support=lead
    def source(tick):
        p=clip['keys'][38+tick]['pose']; return swap(p) if lead else deepcopy(p)
    def toes(p):
        q=fk(p); return [q['toe_'+s] for s in S]
    start=14; fixed=complex(toes(source(start))[support].real,0)
    assert abs(toes(source(start))[support].imag)<.06
    end=next(t for t in range(start,39) if abs(toes(source(t))[kick].imag)<=.06)
    assert end==26
    for t in range(start,39):
        assert abs(toes(source(t))[support]-fixed)<.08
        if t>=end: assert abs(toes(source(t))[kick]-toes(source(end))[kick])<.08
    for span in (8,12,16,20):
        back=1-span/2; advance=fixed.real-back; target=fixed+span; guard_root=complex(advance,.35)
        maxerr=0; maxcorrection=0; prev=toes(source(start)); maxspeed=0
        for t in range(start+1,end+1):
            p=source(t); old=toes(p); u=(t-start)/(end-start); w=u*u*(3-2*u)
            goals=old[:]; goals[support]=fixed
            goals[kick]=complex(old[kick].real+(target.real-old[kick].real)*w,min(0,old[kick].imag)) if t<end else target
            root=complex(*p['root'])*(1-w)+guard_root*w; p['root']=[root.real,root.imag]
            out=plant(p,goals); actual=toes(out)
            maxerr=max(maxerr,*(abs(a-b) for a,b in zip(actual,goals)))
            maxcorrection=max(maxcorrection,abs(complex(*out['root'])-root))
            maxspeed=max(maxspeed,abs(actual[kick]-prev[kick])); prev=actual
            assert actual[kick].imag<.001 and abs(actual[support]-fixed)<.01
        assert maxerr<.01 and abs(actual[kick]-target)<.01
        assert actual[kick].real-actual[support].real>span-.01
        before=fk(out); out['root'][0]-=advance; after=fk(out)
        assert max(abs(after[k]+advance-before[k]) for k in before)<1e-10
        assert abs(toes(out)[support]-back)<.01 and abs(toes(out)[kick]-(back+span))<.01
        print(f'lead={lead} width={span}: release {end}/38, max toe residual {maxerr:.6g}, root correction {maxcorrection:.3f}, max swing/tick {maxspeed:.3f}, world rebase exact')
print('landing reference OK: 12 ticks / 200 ms earlier, both guards')
