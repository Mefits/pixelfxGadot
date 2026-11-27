extends RefCounted
## Optional execution policy for single planted-leg kicks. The source clip and
## its strike window remain unchanged; only the post-contact landing is retargeted.
const Adapt=preload("res://lab/attack_adaptation.gd")
const Walk=preload("res://lab/walk_control.gd")
const Motion=preload("res://lab/walk_motion.gd")
const GROUND_EPS:float=.06
const STABLE_EPS:float=.08

static func policy(doc:Dictionary)->String:
    return str(doc.get("landing_policy","forward_land" if doc.get("id","")=="combo_original_3" else "authored"))

static func mapped_at(doc:Dictionary,rig,binding:Dictionary,tick:int)->Dictionary:
    return Adapt.mapped_channels(Motion.sample(doc,clampf(float(tick)/(60.*float(doc.duration)),0.,1.)),rig,binding.swapped,binding.legs_swapped)

static func plan(doc:Dictionary,walker,binding:Dictionary)->Dictionary:
    if policy(doc)!="forward_land" or binding.role=="authored" or not str(binding.anchor).begins_with("foot_"):return {}
    var rig=walker.rig
    var kick:int=Adapt.side_of(binding.anchor)
    var support:int=1-kick
    var last:int=roundi(float(doc.duration)*60.)
    var start:int=ceili(float(binding.events[0].t)*60.)+2
    if start>=last-3 or float(start)/60.<float(binding.blend_time):return {}
    var points:Array=[]
    for tick in range(start,last+1):points.append(Motion.toes(rig,mapped_at(doc,rig,binding,tick)))
    var fixed:Vector2=points[0][support]
    if absf(fixed.y)>GROUND_EPS or Vector2(points[0][kick]).y>=-1.:return {}
    var touchdown:int=-1
    for i in points.size():
        if Vector2(points[i][support]).distance_to(fixed)>STABLE_EPS:return {}
        if touchdown<0 and absf(Vector2(points[i][kick]).y)<=GROUND_EPS:touchdown=i
    if touchdown<4:return {}
    var landed:Vector2=points[touchdown][kick]
    # Refuse a clip whose tail contains another step or aerial phase.
    for i in range(touchdown,points.size()):
        if Vector2(points[i][kick]).distance_to(landed)>STABLE_EPS:return {}
    var guard:Dictionary=walker.guard_intent(walker.programs.walk_idle,0.)
    var front:float=maxf(Vector2(guard.paths[0].toe).x,Vector2(guard.paths[1].toe).x)
    var back:float=minf(Vector2(guard.paths[0].toe).x,Vector2(guard.paths[1].toe).x)
    if front-back<1. or front-back>20.:return {}
    var advance:float=fixed.x-back
    # Don't change the world origin beyond the locomotion stage bounds.
    if absf(walker.x+advance)>Walk.LIMIT:return {}
    var target:=Vector2(fixed.x+front-back,0.)
    var guard_root:Vector2=Vector2(float(guard.pose.root[0])+advance,float(guard.pose.root[1]))
    rig.evaluate(walker.pose)
    return {"start":start,"end":start+touchdown,"kick":kick,"support":support,"support_toe":Vector2(fixed.x,0.),"landing_toe":target,"advance":advance,"guard_root":guard_root}

static func pose_at(p:Dictionary,rig,plan_data:Dictionary,tick:int)->Dictionary:
    if plan_data.is_empty() or tick<=int(plan_data.start):return p
    var w:float=smoothstep(float(plan_data.start),float(plan_data.end),float(tick))
    var kick:int=plan_data.kick
    var support:int=plan_data.support
    var toes:Array=Motion.toes(rig,p)
    var old:Vector2=toes[kick]
    # Retain the authored vertical descent; redirect horizontal retraction
    # toward the forward landing point with a zero-velocity boundary blend.
    toes[kick]=Vector2(lerpf(old.x,Vector2(plan_data.landing_toe).x,w),minf(0.,old.y))
    if tick>=int(plan_data.end):toes[kick]=plan_data.landing_toe
    toes[support]=plan_data.support_toe
    var root:Vector2=Vector2(p.root[0],p.root[1]).lerp(plan_data.guard_root,w)
    p.root=[root.x,root.y]
    return Adapt.plant_pose(rig,p,toes,Vector2.ZERO)
