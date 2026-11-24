extends Node2D
## Shared player for pure time-driven native effects, with no per-cast disk loads.
const SURFACE=preload("res://addons/pixelfx/native/surface.gd")
signal finished
var surface
var effect
var duration: float=0.0
var fps: int=30
var looping: bool=false
var time: float=0.0
var playing: bool=false
var last_frame: int=-1
var update_ms: float=0.0

func _ready() -> void:
    surface=SURFACE.new()
    add_child(surface)
    set_process(false)

func prepare(value,size: Vector2i,pivot: Vector2i,length: float,rate: int=30,loop: bool=false) -> void:
    assert(surface!=null and size.x>0 and size.y>0 and length>0 and rate>0)
    effect=value
    duration=length
    fps=rate
    looping=loop
    surface.configure(size.x,size.y)
    surface.position=-Vector2(pivot)
    surface.painter.place(pivot.x,pivot.y)
    seek(0.0)

func play(restart: bool=true) -> void:
    if effect==null:
        return
    if restart:
        seek(0.0)
    playing=true
    set_process(true)

func pause() -> void:
    playing=false
    set_process(false)

func seek(seconds: float) -> void:
    if effect==null:
        return
    time=fposmod(seconds,duration) if looping else clampf(seconds,0.0,duration)
    last_frame=-1
    _render()

func _process(delta: float) -> void:
    time+=delta
    if looping:
        time=fposmod(time,duration)
    elif time>=duration:
        time=duration
        _render()
        pause()
        finished.emit()
        return
    _render()

func _render() -> void:
    var index: int=int(floor(time*fps+0.000001))
    if index==last_frame and time<duration:
        return
    last_frame=index
    var start: int=Time.get_ticks_usec()
    surface.painter.clear()
    if looping or time<duration:
        effect.draw(surface.painter,float(index)/fps)
    surface.present()
    update_ms=(Time.get_ticks_usec()-start)/1000.0
