extends RefCounted
## Ordered Painter command batch. Existing particle formulas still run in GDScript.
## All commands share the Painter transform/fade for this batch. Never change
## that state, read buffers, or draw directly into the Painter until finish().
var accelerator: Object
var commands:=PackedFloat64Array()
var painter
var accelerated_calls: int=0
var rejected_calls: int=0
var recording: bool=false

func enable_acceleration(enabled: bool=true) -> bool:
    assert(not recording)
    accelerator=null
    if enabled and ClassDB.class_exists("PixelFXRaster"):
        var candidate: Object=ClassDB.instantiate("PixelFXRaster")
        if candidate!=null and candidate.has_method("render_batch"):
            accelerator=candidate
    return accelerator!=null

func begin(p):
    assert(not recording)
    if accelerator==null:
        return p
    painter=p
    commands.clear()
    recording=true
    return self

func _emit(op: int,x: float,y: float,u: float,v: float,c: int,a: float) -> void:
    commands.append(op)
    commands.append(x)
    commands.append(y)
    commands.append(u)
    commands.append(v)
    commands.append(c&0xffffffff)
    commands.append(a)
    commands.append(0.0)

func px(x: float,y: float,c: int) -> void:
    _emit(0,x,y,0,0,c,1.0)

func dot(x: float,y: float,c: int,a: float=1.0) -> void:
    _emit(0,x,y,0,0,c,a)

func blend(x: float,y: float,c: int,a: float) -> void:
    _emit(1,x,y,0,0,c,a)

func line(x: float,y: float,bx: float,by: float,c: int,a: float=1.0) -> void:
    _emit(2,x,y,bx,by,c,a)

func glow(x: float,y: float,r: float,c: int,k: float=0.5) -> void:
    _emit(3,x,y,r,0,c,k)

func circle(x: float,y: float,r: float,c: int,a: float=1.0) -> void:
    _emit(4,x,y,r,0,c,a)

func disc(x: float,y: float,r: float,c: int,a: float) -> void:
    _emit(5,x,y,r,0,c,a)

func finish() -> void:
    if not recording:
        return
    if not commands.is_empty():
        var p=painter
        var cfg:=PackedFloat64Array([p.width,p.height,p.ox,p.oy,p.tx,p.ty,p.mirror,p.cs,p.sn,p.fade,p.light_k])
        var out: Array=accelerator.render_batch(p.color,p.light,cfg,commands)
        if out.size()==2:
            p.color=out[0]
            p.light=out[1]
            accelerated_calls+=1
        else:
            rejected_calls+=1
            for i in range(0,commands.size(),8):
                var x: float=commands[i+1]
                var y: float=commands[i+2]
                var u: float=commands[i+3]
                var v: float=commands[i+4]
                var c: int=int(commands[i+5])
                var a: float=commands[i+6]
                match int(commands[i]):
                    0: p.dot(x,y,c,a)
                    1: p.blend(x,y,c,a)
                    2: p.line(x,y,u,v,c,a)
                    3: p.glow(x,y,u,c,a)
                    4: p.circle(x,y,u,c,a)
                    5: p.disc(x,y,u,c,a)
    painter=null
    recording=false
    commands.clear()
