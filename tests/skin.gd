extends SceneTree
const W=preload("res://game/world.gd")
const S=preload("res://game/smooth_skin.gd")
var errors:int=0
var checked:int=0
func _initialize()->void:call_deferred("_run")
func verify(a:Vector2,k:Vector2,b:Vector2,r:Vector3)->void:
    checked+=1
    var p:PackedVector2Array=S.contour(a,k,b,r.x,r.y,r.z)
    if p.size()<3 or Geometry2D.triangulate_polygon(p).is_empty():
        errors+=1
        if errors<5:push_error("Invalid contour "+str([a,k,b,r]))
        return
    for v in p:
        if not v.is_finite():errors+=1
    if not Geometry2D.is_point_in_polygon(k,p):errors+=1
func check_rig(r)->void:
    var p:Dictionary=r.points
    for side in ["near","far"]:
        verify(p["thigh_"+side],p["knee_"+side],p["foot_"+side],Vector3(8.7,6.6,4.5))
        verify(p["shoulder_"+side],p["elbow_"+side],p["hand_"+side],Vector3(6.7,5,3.8))
func _run()->void:
    for angle in range(-179,180,3):
        var a:=Vector2(0,0)
        var k:=Vector2(22,0)
        var b:=k+Vector2.from_angle(deg_to_rad(angle))*23
        verify(a,k,b,Vector3(6.7,5,3.8))
        verify(-a,-k,-b,Vector3(6.7,5,3.8))
    for mode in ["walk","run","jump","jab","heavy","kick","back"]:
        var w=W.new()
        if mode in ["jab","heavy","kick"]:
            w.a.separate(150)
            w.b.separate(w.a.pos.x+66-w.b.pos.x)
            w.rig_a.sample(w.a)
            w.rig_b.sample(w.b)
        for i in range(160):
            var input:Dictionary={"move":1 if mode in ["walk","run"] and i<100 else (-1 if mode=="back" and i<100 else 0),"run":mode=="run","jump":mode=="jump" and i==5,"jab":mode=="jab" and i==5,"heavy":mode=="heavy" and i==5,"kick":mode=="kick" and i==5}
            w.tick(input,{})
            check_rig(w.rig_a)
            check_rig(w.rig_b)
    print("N skin contours checked: ",checked,"; failures: ",errors)
    quit(0 if errors==0 else 1)
