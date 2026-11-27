extends SceneTree
const Walk=preload("res://lab/walk_control.gd")
const IK=preload("res://lab/support_adaptation_077.gd")
func _initialize():call_deferred("run")
func run():
    var w=Walk.new()
    var valid:bool=true
    for t in 280:
        var cmd:int=1 if t<60 else (-1 if t<180 else (0 if t<200 else 1))
        var old:float=w.x
        var prev:Dictionary={}
        for i in 2:
            var side:String=["near","far"][i]
            prev[side]=Vector2(w.paths[i].toe)+Vector2.RIGHT*w.x
        var stance:Array=w.paths.map(func(p):return p.stance)
        w.step(cmd)
        if cmd==0 and w.x!=old:valid=false
        if absf(w.x)>Walk.LIMIT or w.FACING!=1:valid=false
        for i in 2:
            if not w.paths[i].toe.is_finite():valid=false
            if stance[i] and w.paths[i].stance and w.activity==1.:
                var side:String=["near","far"][i]
                if absf((Vector2(w.paths[i].toe)+Vector2.RIGHT*w.x).x-prev[side].x)>.01:valid=false
    var p=Walk.new()
    for t in 40:p.step(1)
    for t in 40:p.step(-1)
    if not is_zero_approx(p.x) or not is_equal_approx(p.phase_distance,1.):valid=false
    for t in 8:p.step(0)
    if p.activity!=0. or p.action_name()!="idle":valid=false
    if not valid:push_error("walk control geometry or input")
    else:print("WALK_CONTROL_OK")
    quit(0 if valid else 1)
