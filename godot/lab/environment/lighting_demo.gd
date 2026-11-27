extends Node2D
## Actual native PixelFX Chain Lightning; the environmental adapter reads its existing Lights.
const ARENA = preload("res://lab/environment/cosmic_ruins.tscn")
const FX = preload("res://addons/pixelfx/effects/chain_lightning.gd")
const SURFACE = preload("res://addons/pixelfx/native/surface.gd")
const PERIOD: float = 6.0
const WARM = ["#311319","#702720","#b44922","#e57730","#ff9a47","#ffd07a","#fff0c6","#ffffff"]
const COOL = ["#101344","#282268","#493da5","#7669e4","#9a8bff","#bdb3ff","#e2e3ff","#ffffff"]
@export var autoplay: bool = true
@export var internal_width: int = 640
var arena
var surface
var fx
var clock: float = 0.0
var cast_index: int = -2
var ticks: int = 0
var last_draw: int = -1
var origin := Vector2.ZERO
var lighting_enabled: bool = true

func _ready() -> void:
    arena = ARENA.instantiate()
    arena.animate = false
    arena.internal_width = internal_width
    add_child(arena)
    surface = SURFACE.new()
    arena.world.add_child(surface)
    surface.configure(FX.SIZE.x,FX.SIZE.y)
    surface.hide()
    seek(0.0)

func _process(dt: float) -> void:
    if autoplay:
        seek(clock+dt)

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode==KEY_L:
            lighting_enabled = not lighting_enabled
            arena.combat_lighting.set_enabled(lighting_enabled)
        elif event.keycode==KEY_SPACE:
            seek(0.0)

func seek(seconds: float) -> void:
    clock = fposmod(seconds,PERIOD)
    arena.set_time(clock*2.0)
    var index: int = -1
    var age: float = 0.0
    if clock>=0.5 and clock<2.3:
        index = 0
        age = clock-0.5
    elif clock>=3.2 and clock<5.0:
        index = 1
        age = clock-3.2
    if index<0:
        if cast_index!=-1:
            surface.hide()
            arena.publish_combat_lights([])
            cast_index=-1
        return
    var target_ticks: int = int(floor(age*120.0+0.00001))
    if cast_index!=index or target_ticks<ticks:
        fx=FX.new({"seed":19+index,"palette":WARM if index==0 else COOL,
            "sparks":["#ffffff","#fff0c6","#ffba74","#ff813c"] if index==0 else ["#ffffff","#e2e3ff","#bdb3ff","#7669e4"]})
        fx.enable_acceleration(true)
        origin=Vector2(78,317) if index==0 else Vector2(371,317)
        surface.position=origin-Vector2(FX.PIVOT)
        cast_index=index
        ticks=0
        last_draw=-1
        surface.show()
    while ticks<target_ticks:
        fx.update(1.0/120.0)
        ticks+=1
    # Original effect has 30 fps ink timing; environment reacts at every 60 fps sample.
    var draw_frame: int = ticks/4
    if draw_frame!=last_draw:
        var p=surface.painter
        p.clear()
        p.place(FX.PIVOT.x,FX.PIVOT.y)
        fx.draw_back(p,fx.t)
        fx.draw(p,fx.t)
        surface.present()
        last_draw=draw_frame
    var sustained: Array = []
    var tint := Color(WARM[4] if index==0 else COOL[4])
    for i in range(3):
        var power: float = FX.level(i,fx.t)
        if power>0.0:
            var h: Array = FX.HOPS[i]
            sustained.append({"position":origin+Vector2(h[0],h[1]),"radius":85.0,"color":tint,"energy":0.28*power})
    arena.publish_combat_lights([{"lights":fx.lights,"origin":origin,"scale":1.0,"reach":2.1}],sustained)
