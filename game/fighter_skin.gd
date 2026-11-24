extends RefCounted
## Provisional original articulated vector skin. Draw-only consumer of rig points.
## No changes to hit geometry, motor, animation or physics.
const INK=Color("#121b26")
const SKIN=Color("#d9aa85")
const HAIR=Color("#263342")
static func poly(c:CanvasItem,pts:Array,color:Color)->void:
    c.draw_colored_polygon(PackedVector2Array(pts),color)
static func shape(c:CanvasItem,origin:Vector2,axis:Vector2,face:float,pts:Array,color:Color)->void:
    var normal:=Vector2(axis.y,-axis.x)*face
    var vertices:=PackedVector2Array()
    for p in pts:vertices.append(origin+normal*float(p.x)+axis*float(p.y))
    c.draw_colored_polygon(vertices,color)
static func limb(c:CanvasItem,a:Vector2,b:Vector2,wa:float,wb:float,color:Color)->void:
    var axis:Vector2=(b-a).normalized()
    if axis.length_squared()<.001:return
    var n:=Vector2(-axis.y,axis.x)
    poly(c,[a-axis*2,a-n*(wa+1),b-n*(wb+1),b+axis*2,b+n*(wb+1),a+n*(wa+1)],INK)
    poly(c,[a-axis*.5,a-n*wa,b-n*wb,b+axis,b+n*wb,a+n*wa],color)
    poly(c,[a+n*wa*.35,b+n*wb*.3,b+n*wb,a+n*wa],color.darkened(.20))
static func band(c:CanvasItem,a:Vector2,b:Vector2,t:float,width:float,color:Color)->void:
    var axis:Vector2=(b-a).normalized()
    var n:=Vector2(-axis.y,axis.x)
    var p:Vector2=a.lerp(b,t)
    poly(c,[p-n*width-axis*2,p+n*width-axis*2,p+n*width+axis*2,p-n*width+axis*2],color)
static func leg(c:CanvasItem,p:Dictionary,side:String,face:float,accent:Color,shade:float)->void:
    var a:Vector2=p["thigh_"+side]
    var k:Vector2=p["knee_"+side]
    var f:Vector2=p["foot_"+side]
    var pants:=Color("#364251").darkened(shade)
    limb(c,a,k,9,6.7,pants)
    c.draw_circle(k,6.6,pants)
    limb(c,k,f,6.5,4.5,pants.darkened(.08))
    band(c,k,f,.72,5,Color("#53606a").darkened(shade))
    band(c,k,f,.84,4.8,accent.darkened(.30+shade))
    shape(c,f,Vector2.DOWN,face,[Vector2(-6,-5),Vector2(4,-5),Vector2(5,-1),Vector2(12,0),Vector2(14,2),Vector2(-6,2)],INK)
    shape(c,f,Vector2.DOWN,face,[Vector2(-5,-4),Vector2(3,-4),Vector2(4,0),Vector2(11,0),Vector2(12,1),Vector2(-5,1)],Color("#657584").darkened(shade))
static func arm(c:CanvasItem,p:Dictionary,side:String,accent:Color,shade:float)->void:
    var a:Vector2=p["shoulder_"+side]
    var e:Vector2=p["elbow_"+side]
    var h:Vector2=p["hand_"+side]
    var sleeve:Color=accent.darkened(.28+shade)
    var forearm:Color=SKIN.darkened(shade)
    c.draw_circle(a,7.5,INK)
    c.draw_circle(a,6.3,sleeve)
    limb(c,a,e,7,5,sleeve)
    c.draw_circle(e,5,sleeve)
    limb(c,e,h,4.9,3.8,forearm)
    band(c,e,h,.18,5.2,Color("#263544").darkened(shade))
    band(c,e,h,.68,4.6,Color("#465666").darkened(shade))
    var axis:Vector2=(h-e).normalized()
    var n:=Vector2(-axis.y,axis.x)
    poly(c,[h-axis*5-n*4,h+axis*2-n*6,h+axis*6-n*3,h+axis*6+n*3,h+axis*2+n*5,h-axis*5+n*4],INK)
    poly(c,[h-axis*4-n*3,h+axis*2-n*5,h+axis*5-n*2,h+axis*5+n*2,h+axis*2+n*4,h-axis*4+n*3],Color("#53616c").darkened(shade))
    c.draw_line(h+axis*2-n*3,h+axis*2+n*3,Color("#a5a9a7").darkened(shade),1,true)
static func body(c:CanvasItem,p:Dictionary,face:float,accent:Color)->void:
    var hip:Vector2=p.hips
    var chest:Vector2=p.chest
    var axis:Vector2=(hip-chest).normalized()
    shape(c,chest,axis,face,[Vector2(-12,-5),Vector2(10,-5),Vector2(14,4),Vector2(10,20),Vector2(10,34),Vector2(6,41),Vector2(-11,39),Vector2(-12,27),Vector2(-10,12)],INK)
    shape(c,chest,axis,face,[Vector2(-10,-4),Vector2(9,-4),Vector2(12,4),Vector2(8,20),Vector2(8,33),Vector2(5,38),Vector2(-9,37),Vector2(-10,27),Vector2(-8,12)],Color("#334355"))
    shape(c,chest,axis,face,[Vector2(-10,-4),Vector2(-2,-3),Vector2(4,12),Vector2(1,28),Vector2(-8,28),Vector2(-8,12)],accent.darkened(.30))
    shape(c,chest,axis,face,[Vector2(9,-4),Vector2(12,4),Vector2(8,20),Vector2(8,28),Vector2(3,28),Vector2(5,10),Vector2(0,0)],accent.darkened(.12))
    shape(c,chest,axis,face,[Vector2(-8,28),Vector2(8,28),Vector2(9,33),Vector2(-9,33)],Color("#182431"))
    shape(c,chest,axis,face,[Vector2(2,29),Vector2(8,29),Vector2(8,32),Vector2(2,32)],Color("#ad9470"))
    shape(c,chest,axis,face,[Vector2(-9,1),Vector2(-4,-3),Vector2(2,8),Vector2(-1,10)],Color("#71818a"))
    shape(c,chest,axis,face,[Vector2(1,-4),Vector2(6,-5),Vector2(10,0),Vector2(4,8),Vector2(1,8)],Color("#88969a"))
static func head(c:CanvasItem,p:Dictionary,face:float,accent:Color)->void:
    var h:Vector2=p.head
    var axis:Vector2=(p.chest-h).normalized()
    limb(c,p.chest,h,5,4,SKIN.darkened(.22))
    shape(c,h,axis,face,[Vector2(-12,-11),Vector2(-6,-15),Vector2(5,-15),Vector2(12,-9),Vector2(12,-2),Vector2(15,2),Vector2(11,4),Vector2(10,10),Vector2(4,14),Vector2(-6,12),Vector2(-11,6)],INK)
    shape(c,h,axis,face,[Vector2(-10,-10),Vector2(-5,-13),Vector2(4,-13),Vector2(10,-8),Vector2(10,-2),Vector2(13,2),Vector2(9,4),Vector2(8,9),Vector2(3,12),Vector2(-5,10),Vector2(-9,5)],SKIN)
    shape(c,h,axis,face,[Vector2(-10,-10),Vector2(-5,-13),Vector2(4,-13),Vector2(1,-4),Vector2(-3,5),Vector2(-5,10),Vector2(-9,5)],SKIN.darkened(.18))
    shape(c,h,axis,face,[Vector2(-13,-5),Vector2(-15,-10),Vector2(-8,-10),Vector2(-9,-18),Vector2(-1,-15),Vector2(5,-19),Vector2(6,-14),Vector2(13,-11),Vector2(9,-6),Vector2(4,-7),Vector2(0,-3),Vector2(-3,-7),Vector2(-7,3),Vector2(-11,6)],HAIR)
    shape(c,h,axis,face,[Vector2(-9,-12),Vector2(-1,-14),Vector2(4,-16),Vector2(0,-9),Vector2(-4,-9)],Color("#445365"))
    shape(c,h,axis,face,[Vector2(3,-5),Vector2(10,-5),Vector2(9,-2),Vector2(4,-2)],INK)
    shape(c,h,axis,face,[Vector2(5,-4),Vector2(9,-4),Vector2(8,-3),Vector2(5,-3)],Color("#e7ded0"))
    shape(c,h,axis,face,[Vector2(6,6),Vector2(9,6),Vector2(8,7),Vector2(5,7)],SKIN.darkened(.48))
    shape(c,h,axis,face,[Vector2(-5,10),Vector2(4,12),Vector2(4,15),Vector2(-5,13)],accent.darkened(.18))
static func draw(c:CanvasItem,p:Dictionary,face:int,accent:Color)->void:
    leg(c,p,"far",face,accent,.29)
    arm(c,p,"far",accent,.25)
    leg(c,p,"near",face,accent,0)
    body(c,p,face,accent)
    head(c,p,face,accent)
    arm(c,p,"near",accent,0)
