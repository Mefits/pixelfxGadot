extends SceneTree
# Frozen historical inputs, not a new animation or IK solve.
const RIG=preload("res://lab/anatomy_rd/rig_049.gd")
func _initialize()->void:
    call_deferred("run")
func run()->void:
    var f:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/body_raster/poses.json"))
    var rig=RIG.make()
    var max_error:float=0.0
    var samples:int=0
    for clip in f.clips:
        for sample in clip.samples:
            rig.evaluate(sample.pose)
            for id in sample.expected_xy:
                var p:Array=sample.expected_xy[id]
                max_error=maxf(max_error,rig.point(id).distance_to(Vector2(p[0],p[1])))
            samples+=1
    if samples!=18 or max_error>.001:
        push_error("Body fixture mismatch "+str(samples)+" "+str(max_error))
        quit(1)
        return
    print("BODY_FIXTURES_OK samples=",samples," max_xy_error=",max_error)
    quit()
