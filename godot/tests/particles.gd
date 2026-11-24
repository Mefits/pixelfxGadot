extends SceneTree
const PS=preload("res://addons/pixelfx/native/particles.gd")
const LIGHTS=preload("res://addons/pixelfx/native/lights.gd")
const PAINTER=preload("res://addons/pixelfx/native/painter.gd")
var failures: int=0
var landed: Array=[]

func _initialize() -> void:
    call_deferred("_run")

func _ground(_x: float) -> float:
    return 0.0

func _land(x: float,y: float) -> void:
    landed.append([x,y])

func _run() -> void:
    var d: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/particles.json"))
    if not d is Dictionary:
        quit(1)
        return
    var ps=PS.new(int(d["seed"]),_ground,d["sparks"])
    ps.haze=int(d["col"])
    ps.on_land=_land
    for s in d["specs"]:
        ps.spawn(int(s[0]),s[1],s[2],s[3],s[4],s[5],int(s[6]),s[7],s[8],int(s[9]))
    var ls=LIGHTS.new()
    ls.add(2,-20,12,int(d["col"]),0.7,0.5)
    ls.add(-14,-6,7,int(d["col"]),0.8,0.35)
    var step: int=0
    for sample in d["samples"]:
        while step<int(sample["step"]):
            ps.update(1.0/120.0)
            ls.update(1.0/120.0)
            step+=1
        var expected: Array=sample["particles"]
        var expected_landed: Array=sample["landed"]
        if landed.size()!=expected_landed.size():
            failures+=1
        for i in range(mini(landed.size(),expected_landed.size())):
            if absf(landed[i][0]-expected_landed[i][0])>0.00000001 or absf(landed[i][1]-expected_landed[i][1])>0.00000001:
                failures+=1
        if ps.list.size()!=expected.size():
            failures+=1
        for i in range(mini(ps.list.size(),expected.size())):
            for key in ["x","y","vx","vy","life","max","seed","delay","size"]:
                if absf(float(ps.list[i][key])-float(expected[i][key]))>0.00000001:
                    failures+=1
            for key in ["k","col","flag"]:
                if int(ps.list[i][key])!=int(expected[i][key]):
                    failures+=1
        var p=PAINTER.new(128,96)
        p.place(64,72)
        ps.draw(p,"back")
        ps.draw(p,"front")
        ls.draw(p)
        var bad: int=0
        for i in range(p.color.size()):
            if (p.color[i]&0xffffffff)!=int(sample["color"][i]) or (p.light[i]&0xffffffff)!=int(sample["light"][i]):
                bad+=1
        print("Particles step ",step," count ",ps.list.size()," mismatched pixels ",bad)
        failures+=bad
    print("Particle parity failures: ",failures)
    quit(0 if failures==0 else 1)
