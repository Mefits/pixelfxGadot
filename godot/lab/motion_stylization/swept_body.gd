extends RefCounted
## 003: body-colored swept surfaces, generated from actual limb history.
## This is NOT a rig or collision deformation. All generated geometry is temporary.
var history:Array[Dictionary]=[]
var tick:int=-1
var key:String=""
var anchor:String=""
var age:int=-1
var envelope:float=0.
var hold_until:int=-1
var power:float=1.
var speed_threshold:float=35.
var current:Array=[]
var last_mesh:Array=[]

func reset()->void:
    history.clear()
    tick=-1
    key=""
    anchor=""
    age=-1
    envelope=0.
    hold_until=-1
    current=[]
    last_mesh=[]

static func xy(a:Array)->Vector2:
    return Vector2(float(a[0]),float(a[1]))

static func xyz(p:Vector2,z:float)->Array:
    return [p.x,p.y,z]

static func indices(id:String)->Array:
    var near:bool=id.ends_with("_near")
    if id.begins_with("hand_"):return [9,10,16] if near else [3,4,14]
    if id.begins_with("foot_"):return [12,13,17] if near else [6,7,15]
    return []

func sample(t:int,attack:String,id:String,phase_age:int,gate:bool,accent:bool,parts:Array,root_x:float,tip:Vector2)->void:
    if tick==t:return
    if t!=tick+1 or attack!=key or id!=anchor or phase_age<age:
        history.clear()
        envelope=0.
        hold_until=-1
    tick=t
    key=attack
    anchor=id
    age=phase_age
    var ids:Array=indices(id)
    if attack.is_empty() or ids.is_empty() or parts.size()<=int(ids[-1]):
        current=[]
        history.clear()
        envelope=0.
        return
    current=[]
    for i in ids:current.append(parts[i].duplicate(true))
    var p:Vector2=tip-Vector2(root_x,0)
    var speed:float=0.
    if not history.is_empty():
        speed=p.distance_to(Vector2(history[-1].local))*60.
    history.append({"tick":t,"parts":current.duplicate(true),"local":p,"world":tip,"root":root_x})
    while history.size()>5:history.pop_front()
    # Do not drop a fast frame just because the terminal movement slows.
    # 3-tick maximum display window, strictly before the authored accent.
    if gate and speed>=speed_threshold:
        envelope=maxf(envelope,smoothstep(speed_threshold,speed_threshold+140.,speed))
        envelope=maxf(envelope,.6)
        hold_until=t+2
    if accent or not gate or t>hold_until:
        envelope=0.
    elif t<hold_until:
        envelope=maxf(envelope,.6)

static func row_width(p:Dictionary)->float:
    var w:float=0.
    for row in p.sections:w=maxf(w,maxf(float(row[1]),float(row[2])))
    return w

static func loft(a:Array,b:Array,rad:float,depth:float,mat:int,id:int)->Dictionary:
    return {"type":"loft","a":a,"b":b,"sections":[[0.,rad*.16,rad*.16,depth*.35,0.],[.24,rad*.66,rad*.66,depth*.7,0.],[.68,rad,rad,depth,0.],[1.,rad*.78,rad*.78,depth*.8,0.]],"profile":2.,"part_id":id,"material_id":mat}

func swept(parts:Array,style:int)->Array:
    last_mesh=[]
    if envelope<=0. or power<=0. or history.size()<2 or current.size()!=3:return parts
    var out:Array=parts.duplicate(true)
    var arm:bool=anchor.begins_with("hand_")
    var n:int=mini(history.size()-1,3 if arm else 4)
    # Current body stays intact. Additional solid tapered volumes merge
    # visually into the striking limb. No ghost limbs in this mode.
    var used:int=0
    for k in [1,2]:
        var now:Dictionary=current[k]
        var rad:float=row_width(now)
        var mat:int=now.material_id
        var z:float=float(now.b[2])-.08
        var tip_now:Vector2=xy(now.b)
        var end:Vector2=tip_now
        for j in range(1,n+1):
            var old:Dictionary=history[history.size()-1-j].parts[k]
            var target:Vector2=xy(old.b)
            # Local motion only: do not create a smear from root translation.
            var amount:float=minf(1.,envelope*power)
            var next:Vector2=tip_now+(target-tip_now).limit_length(18. if arm else 24.)*amount
            if next.distance_to(end)<.24:continue
            var taper:float=1.-float(j-1)/float(n+1)
            var w:float=rad*(1.28 if style==0 else .85)*taper*minf(power,1.5)
            var a:Array=xyz(next,z-.12*j)
            var b:Array=xyz(end,z-.12*(j-1))
            var p:Dictionary=loft(a,b,maxf(.18,w),maxf(.25,rad*.78*taper),mat,100+used)
            out.append(p)
            last_mesh.append(p)
            used+=1
            end=next
    return out

func multiples(parts:Array)->Array:
    last_mesh=[]
    if envelope<=0. or power<=0. or history.size()<3 or current.size()!=3:return parts
    var out:Array=parts.duplicate(true)
    # One older distal limb at reduced thickness. Retain its actual sampled
    # orientation and material; the body/upper limb is never duplicated.
    var old:Array=history[maxi(0,history.size()-3)].parts
    if xy(old[2].b).distance_to(xy(current[2].b))<1.:return parts
    for i in [1,2]:
        var p:Dictionary=old[i].duplicate(true)
        p.part_id=120+i
        for k in ["a","b"]:p[k][2]-=.35
        for row in p.sections:
            row[1]*=.72*minf(power,1.25)
            row[2]*=.72*minf(power,1.25)
            row[3]*=.80
        out.append(p)
        last_mesh.append(p)
    return out

func ribbon()->Array[Dictionary]:
    var out:Array[Dictionary]=[]
    if envelope<=0. or power<=0. or history.size()<2:return out
    # A broad blade-like ribbon based on the actual wrist/ankle + tip
    # trajectories, not circles stamped along a point. Root shift restored.
    for i in history.size():
        var h:Dictionary=history[i]
        var p:Dictionary=h.parts[2]
        var root:Vector2=Vector2(float(h.root),0.)
        var a:Vector2=xy(p.a)+root
        var b:Vector2=xy(p.b)+root
        var u:float=float(i)/float(history.size()-1)
        var width:float=lerpf(.08,1.,u)*envelope*minf(power,1.)
        var center:Vector2=a.lerp(b,.68)
        var axis:Vector2=(b-a).normalized()
        if axis.length_squared()<.01:axis=Vector2.RIGHT
        # One edge follows distal surface, one sweeps towards the joint.
        out.append({"a":center-axis*(b-a).length()*.65*width,"b":center+axis*(b-a).length()*.48*width,"alpha":.48+.45*u})
    return out
