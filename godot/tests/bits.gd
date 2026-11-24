extends SceneTree
const BITS=preload("res://addons/pixelfx/native/bits.gd")
const BATCH=preload("res://addons/pixelfx/native/batch.gd")
const PAINTER=preload("res://addons/pixelfx/native/painter.gd")

func _initialize() -> void:
    call_deferred("_run")

func _ground(_x: float) -> float:
    return 0.0

func _run() -> void:
    var d: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/bits.json"))
    if not d is Dictionary:
        quit(1)
        return
    var batch=BATCH.new()
    var cpp: bool=OS.get_cmdline_user_args().has("--cpp")
    if cpp and not batch.enable_acceleration():
        quit(1)
        return
    var bits=BITS.new(_ground)
    for s in d["specs"]:
        bits.add(s)
    var step: int=0
    var failures: int=0
    for sample in d["samples"]:
        while step<int(sample["step"]):
            bits.update(1.0/120.0)
            step+=1
        var expected: Array=sample["bits"]
        if bits.list.size()!=expected.size():
            failures+=1
        for i in range(mini(bits.list.size(),expected.size())):
            for k in ["x","y","vx","vy","a","va","life","max","s","g","drag","bounce"]:
                if absf(float(bits.list[i][k])-float(expected[i][k]))>0.00000001:
                    failures+=1
            if bool(bits.list[i]["rest"])!=bool(expected[i]["rest"]):
                failures+=1
        var p=PAINTER.new(128,96)
        p.place(64,72)
        bits.draw(batch.begin(p))
        batch.finish()
        var bad: int=0
        for i in range(p.color.size()):
            if (p.color[i]&0xffffffff)!=int(sample["color"][i]):
                bad+=1
        print("Bits step ",step," count ",bits.list.size()," mismatched pixels ",bad)
        failures+=bad
    if cpp and (batch.accelerated_calls==0 or batch.rejected_calls!=0):
        failures+=1
    print("Bits batch calls ",batch.accelerated_calls," rejected ",batch.rejected_calls)
    print("Bits parity failures: ",failures)
    quit(0 if failures==0 else 1)
