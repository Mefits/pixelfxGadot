extends SceneTree
const PS=preload("res://addons/pixelfx/native/particles.gd")
const BL=preload("res://addons/pixelfx/native/blazes.gd")
const S=preload("res://addons/pixelfx/native/sim_shapes.gd")
const P=preload("res://addons/pixelfx/native/painter.gd")
const PAL=preload("res://addons/pixelfx/native/palette.gd")
const BATCH=preload("res://addons/pixelfx/native/batch.gd")
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var samples: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/sim_helpers.json"))
    if not samples is Array:
        quit(1)
        return
    var cpp: bool=OS.get_cmdline_user_args().has("--cpp")
    var batch=BATCH.new()
    if cpp and not batch.enable_acceleration():
        quit(1)
        return
    var ps=PS.new(37,func(_x): return 0.0)
    var b=BL.new(ps)
    b.add(-13,0,1.2,.8)
    b.add(16,0,.8,1.1)
    var step: int=0
    var bad: int=0
    for sample in samples:
        while step<int(sample["step"]):
            b.update(1.0/120)
            ps.update(1.0/120)
            step+=1
        var p=P.new(144,104)
        p.place(72,78)
        var d=batch.begin(p)
        S.flare(d,-36,-34,14,.75,PAL.PALETTES["ice"])
        S.band(d,10,-38,19,.45,4,.72,PAL.PALETTES["ice"],func(a: float): return sin(a)>0,true)
        S.crystal(d,39,-2,30,12,-6,PAL.PALETTES["ice"],{"glint":.5,"a":.9})
        b.draw_back(d)
        ps.draw(d)
        batch.finish()
        if b.list.size()!=int(sample["blazes"]) or ps.list.size()!=int(sample["particles"]):
            bad+=1
        var diff: int=0
        for i in range(p.color.size()):
            if (p.color[i]&0xffffffff)!=int(sample["color"][i]) or (p.light[i]&0xffffffff)!=int(sample["light"][i]):
                diff+=1
        print("Sim helpers step ",step,": ",diff," differing pixels")
        bad+=diff
    if cpp and (batch.accelerated_calls!=samples.size() or batch.rejected_calls!=0):
        bad+=1
    print("Sim helpers failures: ",bad)
    quit(0 if bad==0 else 1)
