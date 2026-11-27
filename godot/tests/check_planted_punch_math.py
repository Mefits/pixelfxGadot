"""Independent double-precision check of the v6 geometric support rule.
Does not execute Godot or native rendering."""
import math, cmath
from copy import deepcopy
from check_attack_adaptation_math import clip, fk, swap, S, R, D, rest, rot

def channels(p, arms, legs):
    q=deepcopy(p); other=swap(p)
    for k in q['angles']:
        if (arms and k.startswith(('shoulder_', 'elbow_'))) or (legs and k.startswith(('thigh_', 'knee_', 'foot_pitch_', 'pelvis_'))):
            q['angles'][k]=other['angles'][k]
    return q

def plant(p, targets):
    p=deepcopy(p); a=p['angles']; q=fk(p)
    offsets=[targets[i]-rot(4,a['foot_pitch_'+s])-q['thigh_'+s] for i,s in enumerate(S)]
    radius=abs(rest['near']['knee'])+abs(rest['near']['foot'])-.003
    correction=0j
    for _ in range(20):
        for c in offsets:
            delta=correction-c
            if abs(delta)>radius: correction=c+delta/abs(delta)*radius
    p['root'][0]+=correction.real; p['root'][1]+=correction.imag
    q=fk(p)
    for i,s in enumerate(S):
        upper,lower=rest[s]['knee'],rest[s]['foot']; l1,l2=abs(upper),abs(lower)
        delta=targets[i]-rot(4,a['foot_pitch_'+s])-q['thigh_'+s]
        d=max(abs(l1-l2)+.002,min(l1+l2-.002,abs(delta)))
        bend=math.acos(max(-1,min(1,(d*d-l1*l1-l2*l2)/(2*l1*l2))))
        angle=cmath.phase(delta)-math.atan2(l2*math.sin(bend),l1+l2*math.cos(bend))
        a['thigh_'+s]=D(angle-cmath.phase(upper))-a['hips']
        a['knee_'+s]=D(bend+cmath.phase(upper)-cmath.phase(lower))
    return p

def blend(a,b,w):
    q=deepcopy(b)
    for k in q['angles']:
        delta=(b['angles'][k]-a['angles'][k]+180)%360-180
        q['angles'][k]=a['angles'][k]+w*delta
    q['root']=[a['root'][i]+w*(b['root'][i]-a['root'][i]) for i in range(2)]
    return q

err=0.; total=0; max_correction=0.
for lead in (0,1):
    for span in (8,12,18,22):
        for midpoint in (-1,1,3):
            targets=[complex(midpoint+span/2),complex(midpoint-span/2)]
            if lead: targets.reverse()
            for role in ('leading','trailing','near','far','auto'):
                entry=plant(channels(clip['keys'][0]['pose'],False,bool(lead)),targets)
                for start,end,auth in ((0,28,0),(28,38,1)):
                    origin=fk(clip['keys'][start]['pose'])
                    assert all(abs(fk(clip['keys'][i]['pose'])['toe_'+s]-origin['toe_'+s])<.05 for i in range(start,end+1) for s in S)
                    chosen={'leading':lead,'trailing':1-lead,'near':0,'far':1,'auto':auth^lead}[role]
                    arms=chosen!=auth; legs=bool(lead)
                    first=channels(clip['keys'][start]['pose'],arms,legs); q=fk(first)
                    shift=(sum(targets)-sum(q['toe_'+s] for s in S)).real/2
                    duration=6 if start==0 else 2
                    for i in range(start+1,end+1):
                        p=channels(clip['keys'][i]['pose'],arms,legs);p['root'][0]+=shift
                        u=min(1,(i-start)/duration); p=blend(entry,p,u*u*(3-2*u))
                        result=plant(p,targets); q=fk(result)
                        err=max(err,*(abs(q['toe_'+s]-targets[j]) for j,s in enumerate(S)))
                        max_correction=max(max_correction,abs(complex(*result['root'])-complex(*p['root'])))
                        assert (q['toe_near'].real>q['toe_far'].real)==(lead==0)
                        total+=1
                    entry=result
assert err<.02,err
print(f'v6: {total} sampled punch poses, both guards and all 5 adaptive roles; maximum toe error {err:.6g}, maximum reach correction {max_correction:.3f}')
