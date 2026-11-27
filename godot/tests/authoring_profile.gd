extends SceneTree
const Asset=preload("res://lab/authoring/asset.gd")
const Motion=preload("res://lab/hybrid091/motion.gd")
const Kernel=preload("res://lab/hybrid091/kernel.gd")
const Body=preload("res://lab/body_ankle_069.gd")
const Grid=preload("res://lab/hybrid091/precision.gd")
func _initialize():
    var d:=Asset.read(Asset.DIR+"jab.json")
    var sample=Asset.player(d,60)
    var source:Dictionary=Asset.read(Asset.FIX+"combo052a2_B.json").payload.clip
    var original:=Motion.compile(source,0,31,Asset.CHANNELS,60)
    var reduced:Dictionary=sample.bank.jab
    var max_angle:=0.
    for i in 32:
        for id in Asset.CHANNELS:max_angle=maxf(max_angle,absf(original.frames[i][id]-reduced.frames[i][id]))
    var costs:Array=[[],[],[]]
    var wrist_error:=0.
    var peak_error:=0.
    var point_at_hit:Vector2
    var d2:=d.duplicate(true)
    for t in 51:sample.step({"speed":0.,"action":"jab" if t==30 else ""})
    point_at_hit=sample.rig.point("hand_near")
    d2.goals=[{"joint":"hand_near","xy":[point_at_hit.x-3.,point_at_hit.y-5.],"weight":1.,"priority":1,"clock":"action","center":20./31.,"width":.22}]
    for run in 15:
        var old=Kernel.new(Body.make_rig(),Asset.run_clip,{"jab":original},Asset.guard,60)
        var new=Asset.player(d,60)
        var edited=Asset.player(d2,60)
        var players:=[old,new,edited]
        for t in 80:
            var cmd={"speed":0.,"action":"jab" if t==30 else ""}
            for i in 3:
                var start:=Time.get_ticks_usec()
                players[i].step(cmd)
                if run>0:costs[i].append(Time.get_ticks_usec()-start)
            if t>=30 and t<=61:
                wrist_error=maxf(wrist_error,old.rig.point("hand_near").distance_to(new.rig.point("hand_near")))
                if t==50:peak_error=old.rig.point("hand_near").distance_to(new.rig.point("hand_near"))
    var p95:Array=[]
    for c in costs:
        c.sort()
        p95.append(c[floori(.95*(c.size()-1))])
    print(JSON.stringify({"old_keys":source.keys.size(),"source_slice":32,"sparse":d.keys.size(),"max_angle_deg":max_angle,"max_near_wrist_units":wrist_error,"contact_wrist_error":peak_error,"p95_us_old_sparse_edit":p95}))
    quit()
