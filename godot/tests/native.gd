extends SceneTree
const RNG = preload("res://addons/pixelfx/native/rng.gd")
const PAL = preload("res://addons/pixelfx/native/palette.gd")
const PAINTER = preload("res://addons/pixelfx/native/painter.gd")
const LIGHTNING = preload("res://addons/pixelfx/native/lightning.gd")
var failures: int=0

func _initialize() -> void:
    call_deferred("_run")

func _check(v: bool,label: String) -> void:
    if not v:
        failures+=1
        push_error(label)

func _compare(actual: PackedInt32Array,expected: Array,label: String) -> void:
    if actual.size()!=expected.size():
        _check(false,label+" size")
        return
    var mismatches: int=0
    var max_delta: int=0
    for i in range(actual.size()):
        var a: int=actual[i]&0xffffffff
        var b: int=int(expected[i])&0xffffffff
        if a!=b:
            mismatches+=1
            for shift in [0,8,16,24]:
                max_delta=maxi(max_delta,absi(((a>>shift)&255)-((b>>shift)&255)))
    print(label,": ",mismatches," mismatched pixels, max channel delta ",max_delta)
    _check(mismatches==0,label+" exact parity")

func _run() -> void:
    var data: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/native.json"))
    if not data is Dictionary:
        quit(1)
        return
    for item in data["rngs"]:
        var r=RNG.new(int(item["seed"]))
        for value in item["values"]:
            _check(r.next_u32()==int(value),"RNG seed "+str(item["seed"]))
    for item in data["hashes"]:
        _check(RNG.hash32(item["ns"])==int(item["value"]),"hash parity")
    var c: Array=PAL.fit(LIGHTNING.VOLT,8)
    var p=PAINTER.new(80,64,-8,-8)
    p.place(10,12,true,.23)
    p.fade=.76
    p.light_k=.84
    p.dot(5,5,c[5],.8)
    p.line(-12,-4,13,15,c[7],.6)
    p.blend(1,1,c[4],.3)
    p.blend(1,1,c[5],.45)
    p.glow(2,3,9,c[4],.7)
    _compare(p.color,data["painter"]["color"],"Painter color")
    _compare(p.light,data["painter"]["light"],"Painter light")
    var lightning=LIGHTNING.new()
    if OS.get_cmdline_user_args().has("--cpp"):
        if not lightning.enable_acceleration():
            push_error("C++ accelerator missing")
            quit(1)
            return
        print("Testing C++ raster against original JS")
    for item in data["bolts"]:
        var r=RNG.new(int(item["seed"]))
        var f=PAINTER.new(128,96)
        f.place(12,48)
        var paths: Array=LIGHTNING.zigzag(r,0,0,77,-13,.27,.7)
        var expected: Array=item["paths"]
        _check(paths.size()==expected.size(),"path count")
        for i in range(mini(paths.size(),expected.size())):
            var a: Array=paths[i]["pts"]
            var b: Array=expected[i]["pts"]
            _check(a.size()==b.size(),"point count")
            for j in range(mini(a.size(),b.size())):
                _check(absf(a[j][0]-b[j][0])<0.00000001 and absf(a[j][1]-b[j][1])<0.00000001,"geometry")
        lightning.stroke(f,paths,.85,c,.85,{"a":.86})
        lightning.crackle(f,LIGHTNING.bowed(r,3,3,58,10,-9,.22,.4),.9,c,.35,.8)
        _compare(f.color,item["color"],"Bolt color seed "+str(item["seed"]))
        _compare(f.light,item["light"],"Bolt light seed "+str(item["seed"]))
    if OS.get_cmdline_user_args().has("--cpp"):
        _check(lightning.accelerated_calls==data["bolts"].size()*2,"All fixture strokes used C++")
        _check(lightning.rejected_calls==0,"No rejected C++ calls")
        print("C++ calls: ",lightning.accelerated_calls," rejected: ",lightning.rejected_calls)
    var bytes=PAINTER.new(1,1)
    bytes.put(0,0,0xff643214)
    bytes.add(0,0,0xff030201,1.0)
    _check(bytes.rgba_bytes()==PackedByteArray([20,50,100,255]),"color byte order")
    _check(bytes.rgba_bytes(true)==PackedByteArray([1,2,3,255]),"light byte order")
    print("Native reference failures: ",failures)
    quit(0 if failures==0 else 1)
