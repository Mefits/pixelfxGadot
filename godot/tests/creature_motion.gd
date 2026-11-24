extends SceneTree
const C=preload("res://addons/creature/physical_creature.gd")
var failures:int=0
func _initialize()->void:
    create_timer(20).timeout.connect(func():quit(1))
    call_deferred("_run")
func check(ok:bool,msg:String)->void:
    if not ok:failures+=1;push_error(msg)
func make_body(flat:Array[Rect2],modern:bool=true):
    var c=C.new(Vector2(100,170),flat)
    c.smooth_motion=modern
    c.limbs.adaptive_gait=modern
    for i in range(120):c.advance(1.0/60,0,false)
    return c
func jump_height(c,hold_frames:int)->float:
    var start:float=c.body.point("front").y
    var apex:float=start
    for i in range(90):
        c.advance(1.0/60,0,i==0,false,0,false,i<hold_frames)
        apex=minf(apex,c.body.point("front").y)
    return start-apex
func _run()->void:
    var flat:Array[Rect2]=[Rect2(-1000,200,4000,80)]
    var c=make_body(flat)
    var old=make_body(flat,false)
    var h:float=jump_height(c,90)
    var h0:float=jump_height(old,90)
    var short:float=jump_height(make_body(flat),5)
    print("Jump height new ",h," old tuning ",h0," short ",short)
    check(h>40 and h>h0*1.5,"Higher jump")
    check(short<h*.8 and short>10,"Variable jump")
    check(c.jump_count==1 and c.grounded,"Land once")
    var runner=make_body(flat)
    for i in range(18):runner.advance(1.0/60,1,false)
    var speed:float=(float(runner.body.nodes[0].v.x)+float(runner.body.nodes[1].v.x))*.5
    var x:float=runner.body.center_of_mass().x
    for i in range(18):runner.advance(1.0/60,0,false)
    var stop:float=runner.body.center_of_mass().x-x
    print("Run speed after 0.3s ",speed," braking distance ",stop)
    check(speed>90 and stop<15,"Responsive motor")
    for i in range(36):runner.advance(1.0/60,-1,false)
    var facing:float=runner.body.point("front").x-runner.body.point("rear").x
    print("Turn trunk x ",facing)
    check(facing< -10 and float(runner.body.nodes[0].v.x)< -60,"Physical reverse")
    check(runner.body.penetration()<.05 and runner.body.finite(),"Turn stable")
    var landing=make_body(flat)
    landing.body.nodes[0].p.y-=40
    landing.body.nodes[1].p.y-=40
    for i in range(2,landing.body.nodes.size()):landing.body.nodes[i].p.y-=40
    landing.limbs.release_all()
    landing.coyote=0
    for i in range(100):
        var p:Vector2=landing.body.point("front")
        var vy:float=landing.body.nodes[0].v.y
        var request:bool=landing.jump_count==0 and p.y>165 and vy>20 and not landing.grounded
        landing.advance(1.0/60,0,request)
    check(landing.jump_count==1,"Buffered landing jump")
    print("Motion tests failures: ",failures)
    quit(0 if failures==0 else 1)
