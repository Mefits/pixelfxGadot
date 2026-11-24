extends RefCounted
## Continuous procedural skin, separate from the immutable pose/hit geometry.
## Each limb is a union of two tapered round-ended envelopes, not two
## outlined rigid segments. The shared joint has one continuous silhouette.
## Vertex colors and wrinkle positions are recomputed from the actual bend.
const OLD=preload("res://game/fighter_skin.gd")
const INK=Color("#121b26")
const SAMPLES=24
static func envelope(a:Vector2,b:Vector2,ra:float,rb:float)->PackedVector2Array:
    var cloud:=PackedVector2Array()
    for i in range(SAMPLES):
        var n:=Vector2.from_angle(TAU*float(i)/SAMPLES)
        cloud.append(a+n*ra)
        cloud.append(b+n*rb)
    var hull:PackedVector2Array=Geometry2D.convex_hull(cloud)
    if hull.size()>1 and hull[0].is_equal_approx(hull[-1]):hull.remove_at(hull.size()-1)
    return hull
static func contour(a:Vector2,k:Vector2,b:Vector2,ra:float,rk:float,rb:float)->PackedVector2Array:
    var first:PackedVector2Array=envelope(a,k,ra,rk)
    var second:PackedVector2Array=envelope(k,b,rk,rb)
    var merged:Array[PackedVector2Array]=Geometry2D.merge_polygons(first,second)
    # Both envelopes share the whole joint disc, so there must be one exterior.
    if merged.size()!=1:return PackedVector2Array()
    return merged[0]
static func closest_shade(v:Vector2,a:Vector2,k:Vector2,b:Vector2,face:float)->float:
    var p:Vector2=Geometry2D.get_closest_point_to_segment(v,a,k)
    var q:Vector2=Geometry2D.get_closest_point_to_segment(v,k,b)
    var d0:float=v.distance_squared_to(p)
    var d1:float=v.distance_squared_to(q)
    var n0:=Vector2(-(k-a).normalized().y,(k-a).normalized().x)*face
    var n1:=Vector2(-(b-k).normalized().y,(b-k).normalized().x)*face
    var s0:float=(v-p).normalized().dot(n0)
    var s1:float=(v-q).normalized().dot(n1)
    return (s0/(d0+1)+s1/(d1+1))/(1/(d0+1)+1/(d1+1))
static func paint(c:CanvasItem,a:Vector2,k:Vector2,b:Vector2,ra:float,rk:float,rb:float,color:Color,face:float)->void:
    var outline:PackedVector2Array=contour(a,k,b,ra,rk,rb)
    if outline.size()<3 or Geometry2D.triangulate_polygon(outline).is_empty():
        # Defensive fallback for a degenerate pose. No internal dark seam.
        for segment in [envelope(a,k,ra,rk),envelope(k,b,rk,rb)]:
            c.draw_colored_polygon(segment,color)
        return
    var colors:=PackedColorArray()
    for v in outline:
        var s:float=closest_shade(v,a,k,b,face)
        colors.append(color.lightened(.11*s) if s>=0 else color.darkened(-.23*s))
    c.draw_polygon(outline,colors)
    var closed:PackedVector2Array=outline.duplicate()
    closed.append(outline[0])
    c.draw_polyline(closed,INK,1.6,true)
    # Bend-dependent, subtle fabric fold on the compressed side.
    var d0:Vector2=(k-a).normalized()
    var d1:Vector2=(b-k).normalized()
    var bend:float=absf(d0.angle_to(d1))
    if bend>.25:
        var inner:Vector2=(d1-d0).normalized()
        var start:Vector2=k-d0*minf(rk*.75,4)+inner*rk*.32
        var end:Vector2=k+d1*minf(rk*.75,4)+inner*rk*.32
        var mid:Vector2=k+inner*rk*.58
        c.draw_polyline(PackedVector2Array([start,start.lerp(mid,.65),mid,mid.lerp(end,.4),end]),color.darkened(.20),1.0,true)
        if bend>1.2:
            c.draw_line(start-d0*2,mid-inner*.6,color.lightened(.10),.8,true)
static func leg(c:CanvasItem,p:Dictionary,side:String,face:float,accent:Color,shade:float)->void:
    var a:Vector2=p["thigh_"+side]
    var k:Vector2=p["knee_"+side]
    var f:Vector2=p["foot_"+side]
    var pants:Color=Color("#3e4b5a").darkened(shade)
    paint(c,a,k,f,8.7,6.6,4.5,pants,face)
    OLD.band(c,k,f,.78,4.8,accent.darkened(.30+shade))
    OLD.shape(c,f,Vector2.DOWN,face,[Vector2(-6,-5),Vector2(3,-5),Vector2(5,-2),Vector2(11,-1),Vector2(14,1),Vector2(12,2),Vector2(-6,2)],INK)
    OLD.shape(c,f,Vector2.DOWN,face,[Vector2(-5,-4),Vector2(3,-4),Vector2(4,-1),Vector2(10,0),Vector2(12,1),Vector2(-5,1)],Color("#657584").darkened(shade))
static func arm(c:CanvasItem,p:Dictionary,side:String,face:float,accent:Color,shade:float)->void:
    var a:Vector2=p["shoulder_"+side]
    var e:Vector2=p["elbow_"+side]
    var h:Vector2=p["hand_"+side]
    # Long, fitted sleeve: one cloth surface across the elbow.
    var fabric:Color=accent.darkened(.32+shade)
    paint(c,a,e,h,6.7,5.0,3.8,fabric,face)
    OLD.band(c,e,h,.78,4.3,Color("#394956").darkened(shade))
    var axis:Vector2=(h-e).normalized()
    var n:=Vector2(-axis.y,axis.x)
    # Compact rounded glove, follows actual wrist direction, no exposed joint disc.
    c.draw_circle(h+axis*1.5,5.8,INK,true,-1,true)
    c.draw_circle(h+axis*1.5,4.7,Color("#53616c").darkened(shade),true,-1,true)
    c.draw_line(h+axis*2-n*3,h+axis*2+n*3,Color("#9ba7ae").darkened(shade),.8,true)
static func round_points(pts:Array)->Array:
    var out:Array=[]
    for i in range(pts.size()):
        var a:Vector2=pts[i]
        var b:Vector2=pts[(i+1)%pts.size()]
        out.append(a.lerp(b,.16))
        out.append(a.lerp(b,.84))
    return out
static func torso_shape(c:CanvasItem,chest:Vector2,hip:Vector2,face:float,pts:Array,color:Color,round_edges:bool=false)->void:
    var axis:Vector2=(hip-chest).normalized()
    var n:=Vector2(axis.y,-axis.x)*face
    var lean:float=clampf(axis.x*face,-.8,.8)
    var source:Array=round_points(pts) if round_edges else pts
    var vertices:=PackedVector2Array()
    for v in source:
        var u:float=clampf(float(v.y)/34,0,1)
        # A bounded curvature across the jacket; shoulders/waist anchors stay fixed.
        var curve:float=sin(PI*u)*lean*3.5
        var pinch:float=1.0-.07*sin(PI*u)*absf(lean)
        vertices.append(chest+axis*float(v.y)+n*(float(v.x)*pinch+curve))
    c.draw_colored_polygon(vertices,color)
static func body(c:CanvasItem,p:Dictionary,face:float,accent:Color)->void:
    var h:Vector2=p.hips
    var a:Vector2=p.chest
    torso_shape(c,a,h,face,[Vector2(-12,-5),Vector2(10,-5),Vector2(14,4),Vector2(10,20),Vector2(10,34),Vector2(6,41),Vector2(-11,39),Vector2(-12,27),Vector2(-10,12)],INK,true)
    torso_shape(c,a,h,face,[Vector2(-10,-4),Vector2(9,-4),Vector2(12,4),Vector2(8,20),Vector2(8,33),Vector2(5,38),Vector2(-9,37),Vector2(-10,27),Vector2(-8,12)],Color("#334355"),true)
    torso_shape(c,a,h,face,[Vector2(-10,-4),Vector2(-2,-3),Vector2(4,12),Vector2(1,28),Vector2(-8,28),Vector2(-8,12)],accent.darkened(.30),true)
    torso_shape(c,a,h,face,[Vector2(9,-4),Vector2(12,4),Vector2(8,20),Vector2(8,28),Vector2(3,28),Vector2(5,10),Vector2(0,0)],accent.darkened(.12),true)
    torso_shape(c,a,h,face,[Vector2(-8,28),Vector2(8,28),Vector2(9,33),Vector2(-9,33)],Color("#182431"),true)
    torso_shape(c,a,h,face,[Vector2(2,29),Vector2(8,29),Vector2(8,32),Vector2(2,32)],Color("#ad9470"),true)
    torso_shape(c,a,h,face,[Vector2(-9,1),Vector2(-4,-3),Vector2(2,8),Vector2(-1,10)],Color("#71818a"),true)
    torso_shape(c,a,h,face,[Vector2(1,-4),Vector2(6,-5),Vector2(10,0),Vector2(4,8),Vector2(1,8)],Color("#88969a"),true)
static func draw(c:CanvasItem,p:Dictionary,face:int,accent:Color)->void:
    leg(c,p,"far",face,accent,.29)
    arm(c,p,"far",face,accent,.25)
    leg(c,p,"near",face,accent,0)
    body(c,p,face,accent)
    OLD.head(c,p,face,accent)
    arm(c,p,"near",face,accent,0)
