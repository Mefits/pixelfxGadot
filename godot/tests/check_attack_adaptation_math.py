"""Independent FK reference, not execution of GDScript or a visual test."""
import cmath, json, math
from pathlib import Path
from copy import deepcopy
P=Path(__file__).parent/'fixtures/body_raster/full_058/combo052a2_B.json'
clip=json.loads(P.read_text())['payload']['clip']
S=('near','far'); R=math.radians; D=math.degrees
rot=lambda v,a:v*cmath.exp(1j*R(a))
rest={s:{'elbow':complex(4*sgn,10)*.9,'hand':complex(1,10)*.9,'knee':complex(2*sgn,11),'foot':complex(-2*sgn,11)} for s,sgn in zip(S,(1,-1))}
def fk(p):
 a=p['angles']; h=a['hips']; hip=complex(*p['root'])-22j; chest=hip+rot(-16j,h); c=h+a['chest']; q={}
 for s,sgn in zip(S,(1,-1)):
  for parent,upper,lower,base,angle,turn,span,y in [('shoulder','elbow','hand',chest,c,'shoulder_turn',math.sqrt(50),1),('thigh','knee','foot',hip,h,'pelvis_turn',math.sqrt(32),0)]:
   pos=base+rot(complex(sgn*span*math.sin(R(45-max(0,min(90,a[turn])))),y),angle)
   q[parent+'_'+s]=pos; ang=angle+a[parent+'_'+s]; pos+=rot(rest[s][upper],ang); q[upper+'_'+s]=pos; ang+=a[upper+'_'+s]; pos+=rot(rest[s][lower],ang); q[lower+'_'+s]=pos
  q['toe_'+s]=q['foot_'+s]+rot(4,a['foot_pitch_'+s])
 return q

def swap(p):
 q=deepcopy(p); a=p['angles']; b=q['angles']
 for dst,src in zip(S,S[::-1]):
  for parent,upper,lower in [('shoulder','elbow','hand'),('thigh','knee','foot')]:
   u=D(cmath.phase(rest[src][upper])-cmath.phase(rest[dst][upper])); l=D(cmath.phase(rest[src][lower])-cmath.phase(rest[dst][lower])); b[parent+'_'+dst]=a[parent+'_'+src]+u; b[upper+'_'+dst]=a[upper+'_'+src]+l-u
  b['foot_pitch_'+dst]=a['foot_pitch_'+src]
 for k in ('shoulder_turn','pelvis_turn'): b[k]=90-max(0,min(90,a[k]))
 return q
err=0
for k in clip['keys']:
 p=k['pose']; before=fk(p); after=fk(swap(p))
 for joint in before:
  j,s=joint.rsplit('_',1); opposite=S[1-S.index(s)]; err=max(err,abs(before[joint]-after[j+'_'+opposite]))
 assert swap(swap(p))['root']==p['root']
assert err<1e-10
print(f'77 source frames: maximum remapped projected joint error = {err:.3g} rig units')
for tick in (0,28,38,76):
 p=clip['keys'][tick]['pose']; a=fk(p); b=fk(swap(p)); assert a['toe_near'].real>a['toe_far'].real and b['toe_near'].real<b['toe_far'].real
 print(f'Boundary {tick}: near/far {a["toe_near"].real:.3f}/{a["toe_far"].real:.3f}; swapped {b["toe_near"].real:.3f}/{b["toe_far"].real:.3f}')
for lead in (0,1):
 for anchor,role in zip((e['anchor'] for e in clip['events']),('leading','trailing','trailing')):
  side=S.index(anchor.rsplit('_',1)[1]); chosen=lead if role=='leading' else 1-lead; swapped=chosen!=side; mapped=anchor.rsplit('_',1)[0]+'_'+S[chosen]; print(lead,role,mapped,'swapped',swapped)
  assert swapped==bool(lead)
print('FK and role reference checks OK')
# For both permutations, the contact point used by the training bag is also
# identical in the original and mapped trajectory (wrist extension or toe).
def tip(q,anchor):
 part,s=anchor.rsplit('_',1)
 if part=='foot':return q['toe_'+s]
 w=q[anchor]; e=q['elbow_'+s]; v=w-e
 return w+2.55*v/abs(v)
for i,e in enumerate(clip['events']):
 tick=round(e['t']*60); anchor=e['anchor']; part,s=anchor.rsplit('_',1); other=part+'_'+S[1-S.index(s)]
 for j in range(tick-4,tick+3):
  p=clip['keys'][j]['pose']; assert abs(tip(fk(p),anchor)-tip(fk(swap(p)),other))<1e-10
print('21 contact-window frames: swapped collision tips match exactly')
for lead in (0,1):
 entry=[7+0j,-5+0j] if lead==0 else [-5+0j,7+0j]
 previous=entry
 max_step=0
 for tick in range(1,7):
  p=clip['keys'][tick]['pose']; q=fk(swap(p) if lead else p); u=tick/6; w=u*u*(3-2*u)
  goal=[entry[i]+(q['toe_'+s]-entry[i])*w for i,s in enumerate(S)]
  assert goal[lead].real>goal[1-lead].real
  max_step=max(max_step,max(abs(a-b) for a,b in zip(previous,goal))); previous=goal
 print(f'entry lead={lead}: no goal crossing; max target movement/tick={max_step:.3f}')
