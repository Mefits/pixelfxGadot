extends RefCounted
const SPACE = preload("res://lab/motion_rd/pose_space.gd")
const FOCAL = 82.0
const INK = Color("#182339")
const JADE = Color("#58b8bd")
const LIGHT = Color("#9de0d6")
const CLOTH = Color("#357a8f")

static func band(c: CanvasItem, a: Vector2, b: Vector2, ra: float, rb: float, col: Color) -> void:
    var n := (b-a).normalized().orthogonal()
    if n.is_zero_approx():
        c.draw_circle(a,ra,col)
        return
    c.draw_colored_polygon(PackedVector2Array([a+n*ra,b+n*rb,b-n*rb,a-n*ra]),col)
    c.draw_circle(a,ra,col)
    c.draw_circle(b,rb,col)

static func draw(c: CanvasItem, xyz: Dictionary) -> void:
    var p := SPACE.project(xyz,FOCAL)
    var parts := []
    for side in ["far","near"]:
        var near_side: bool = side == "near"
        var layer := 0.25 if near_side else -0.25
        var cloth := JADE if near_side else CLOTH
        var cuff := LIGHT if near_side else Color("#76aebb")
        for desc in [["thigh","knee",3.55,2.8,cloth],["knee","foot",2.7,1.85,Color("#52748b")],
                ["shoulder","elbow",3.35,2.15,cloth],["elbow","hand",2.4,1.8,cuff]]:
            var a: String = desc[0]+"_"+side
            var b: String = desc[1]+"_"+side
            parts.append({"a":a,"b":b,"ra":desc[2],"rb":desc[3],"col":desc[4],
                "depth":(xyz[a].z+xyz[b].z)*0.5+layer,"order":parts.size()})
        for tip in ["foot","hand"]:
            var id: String = tip+"_"+side
            parts.append({"tip":tip,"id":id,"depth":xyz[id].z+layer+0.02,"order":parts.size()})
    parts.append({"torso":true,"depth":(xyz.hips.z+xyz.chest.z)*0.5,"order":parts.size()})
    parts.append({"head":true,"depth":xyz.head.z+0.04,"order":parts.size()})
    parts.sort_custom(func(a,b): return a.order < b.order if a.depth == b.depth else a.depth < b.depth)
    for part in parts:
        if part.has("torso"):
            band(c,p.hips,p.chest,4.2,5.5,INK)
            band(c,p.hips,p.chest,3.5,4.8,JADE)
            c.draw_line(p.shoulder_far,p.shoulder_near,LIGHT,1.4)
        elif part.has("head"):
            var h: Vector2 = p.head
            var s: float = FOCAL/(FOCAL-xyz.head.z)
            c.draw_circle(h,6*s,INK)
            c.draw_circle(h,4.9*s,JADE)
            c.draw_line(h+Vector2(-3,-1)*s,h+Vector2(4,-2)*s,INK,2.2*s)
            c.draw_circle(h+Vector2(2.7,-1.9)*s,0.75*s,Color.WHITE)
        elif part.has("tip"):
            var q: Vector2 = p[part.id]
            var s: float = FOCAL/(FOCAL-xyz[part.id].z)
            if part.tip == "hand":
                c.draw_circle(q,3.05*s,INK)
                c.draw_circle(q,2.4*s,LIGHT)
            else:
                band(c,q+Vector2(-1,-2)*s,q+Vector2(3,-1.2)*s,1.9*s,1.2*s,INK)
        else:
            var ra: float = part.ra*FOCAL/(FOCAL-xyz[part.a].z)
            var rb: float = part.rb*FOCAL/(FOCAL-xyz[part.b].z)
            band(c,p[part.a],p[part.b],ra+0.55,rb+0.55,INK)
            band(c,p[part.a],p[part.b],ra,rb,part.col)
