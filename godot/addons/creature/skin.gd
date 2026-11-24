extends RefCounted
## Simple prototype skin; can be replaced by modular sprites/meshes.
static func _limb(c: CanvasItem,a: Vector2,b: Vector2,width: float,color: Color) -> void:
    c.draw_line(a,b,Color("#151b29"),width+2,false)
    c.draw_line(a,b,color,width,false)
    c.draw_circle(b,width*.42,color,true)

static func draw_body(c: CanvasItem,rig,origin: Vector2,facing: int,tint: Color,debug: bool=false) -> void:
    var p: Dictionary={}
    for j in rig.joints:
        var q: Vector2=rig.point(j.id)
        p[j.id]=origin+Vector2(q.x*facing,q.y)
    if p.has("hips") and p.has("head"):
        _side(c,p,"far",tint.darkened(.4))
        _limb(c,p.hips,p.chest,10,tint.darkened(.1))
        var torso: Vector2=Vector2(p.chest)-Vector2(p.hips)
        var side: Vector2=torso.normalized().orthogonal()*4.5
        var torso_top: Vector2=p.chest
        var torso_bottom: Vector2=p.hips
        c.draw_colored_polygon(PackedVector2Array([torso_top-side,torso_top+side,torso_bottom+side*.65,torso_bottom-side*.65]),tint.darkened(.03))
        c.draw_line(torso_top+side*.5,torso_bottom+side*.4,tint.lightened(.25),1)
        _side(c,p,"near",tint)
        c.draw_circle(p.head,6,Color("#151b29"),true)
        c.draw_circle(p.head,5,tint.lightened(.2),true)
        c.draw_rect(Rect2(p.head+Vector2(1 if facing==1 else -4,-2),Vector2(3,1)),Color("#ecf7ff"))
        for suffix in ["far","near"]:
            if p.has("hand_"+suffix):
                c.draw_circle(p["hand_"+suffix],2.4,tint.lightened(.25),true)
            if p.has("foot_"+suffix):
                c.draw_rect(Rect2(p["foot_"+suffix]+Vector2(-2,-2),Vector2(6,2)),Color("#263143"))
    else:
        for j in rig.joints:
            if not j.parent.is_empty(): _limb(c,p[j.parent],p[j.id],4,tint)
    if debug:
        for j in rig.joints:
            if not j.parent.is_empty():
                c.draw_line(p[j.parent],p[j.id],Color("#82d8c7"),.65)
            c.draw_circle(p[j.id],1.5,Color("#f4c77b"),true)

static func _side(c: CanvasItem,p: Dictionary,suffix: String,shade: Color) -> void:
    for pair in [["thigh_"+suffix,"knee_"+suffix],["knee_"+suffix,"foot_"+suffix],["shoulder_"+suffix,"elbow_"+suffix],["elbow_"+suffix,"hand_"+suffix]]:
        if p.has(pair[0]) and p.has(pair[1]):
            _limb(c,p[pair[0]],p[pair[1]],4 if pair[0].begins_with("shoulder") or pair[0].begins_with("elbow") else 5,shade)
    if p.has("shoulder_"+suffix):
        c.draw_circle(p["shoulder_"+suffix],3.1,shade.lightened(.12),true)
