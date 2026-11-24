extends Node2D
## Experimental interactive composition. Native source primitives are direct ports;
## the moving endpoint choreography is custom, not the original Chain Lightning effect.
const SURFACE=preload("res://addons/pixelfx/native/surface.gd")
const LIGHTNING=preload("res://addons/pixelfx/native/lightning.gd")
const RNG=preload("res://addons/pixelfx/native/rng.gd")
const PAL=preload("res://addons/pixelfx/native/palette.gd")
const PS=preload("res://addons/pixelfx/native/particles.gd")
const BATCH=preload("res://addons/pixelfx/native/batch.gd")
const LIGHTS=preload("res://addons/pixelfx/native/lights.gd")
const ORIGIN:=Vector2(160,124)
const SIZE:=Vector2i(320,180)
const START:=Vector2(46,98)
const FLOOR: float=150.0
const PIXEL_SCALE: float=2.0
var surface
var lightning
var particles
var lights
var batch
var rng
var colors: Array
var paths: Array=[]
var target:=Vector2(230,85)
var draw_clock: float=0.0
var shape_clock: float=0.0
var emit_clock: float=0.0
var tick: int=0
var active: bool=false
var crackle: bool=false
var bright: bool=false
var hud: Label
var stats: Label
var sample_times: Array[float]=[]
var stat_clock: float=0.0
var demo: bool=false
var t: float=0.0
var last_active: bool=false
var was_drawn: bool=false

func _ready() -> void:
    surface=SURFACE.new()
    add_child(surface)
    surface.position=ORIGIN
    surface.scale=Vector2.ONE*PIXEL_SCALE
    surface.configure(SIZE.x,SIZE.y)
    lightning=LIGHTNING.new()
    lightning.enable_acceleration()
    particles=PS.new(712,_ground,["#ffffff","#c8f8ff","#7ff3ff","#1ab8e6"])
    particles.capacity=96
    lights=LIGHTS.new()
    batch=BATCH.new()
    batch.enable_acceleration()
    colors=PAL.fit(LIGHTNING.VOLT,8)
    rng=RNG.new(77)
    demo=OS.get_cmdline_user_args().has("--demo-native")
    var layer:=CanvasLayer.new()
    add_child(layer)
    hud=Label.new()
    hud.position=Vector2(24,18)
    hud.text="PIXELFX / LIVE NATIVE LIGHTNING"
    hud.add_theme_font_size_override("font_size",22)
    layer.add_child(hud)
    var help:=Label.new()
    help.position=Vector2(24,56)
    help.text="Hold LMB | 1: stroke | 2: crackle | A: backend | B: background | Esc: export lab"
    layer.add_child(help)
    stats=Label.new()
    stats.position=Vector2(24,82)
    layer.add_child(stats)

func _ground(_x: float) -> float:
    return FLOOR

func _draw() -> void:
    draw_rect(Rect2(0,0,960,540),Color("#aaa99d") if bright else Color("#121824"))
    draw_rect(Rect2(ORIGIN,Vector2(SIZE)*PIXEL_SCALE),Color("#c8c7bb") if bright else Color("#182334"))
    var floor_y: float=ORIGIN.y+FLOOR*PIXEL_SCALE
    draw_rect(Rect2(ORIGIN.x,floor_y,Vector2(SIZE).x*PIXEL_SCALE,60),Color("#85877e") if bright else Color("#263448"))
    draw_line(Vector2(ORIGIN.x,floor_y),Vector2(ORIGIN.x+SIZE.x*PIXEL_SCALE,floor_y),Color("#57718b"))
    draw_circle(ORIGIN+START*PIXEL_SCALE,8,Color("#528c9e"))
    draw_circle(ORIGIN+target*PIXEL_SCALE,5,Color("#7fa5b1"),false,1.0)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_1: crackle=false
            KEY_2: crackle=true
            KEY_A:
                var enabled: bool=lightning.accelerator==null
                lightning.enable_acceleration(enabled)
                batch.enable_acceleration(enabled)
            KEY_B: bright=not bright
            KEY_ESCAPE: get_tree().change_scene_to_file("res://lab/main.tscn")
        queue_redraw()

func _process(delta: float) -> void:
    t+=delta
    active=Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or demo
    var mouse: Vector2=(get_global_mouse_position()-ORIGIN)/PIXEL_SCALE
    if demo:
        mouse=Vector2(210+60*sin(t*2),75+30*cos(t*3))
    target=Vector2(clampf(mouse.x,18,SIZE.x-18),clampf(mouse.y,18,FLOOR-4))
    if active and not last_active:
        lights.add(START.x,START.y,17,colors[5],0.9,0.22)
        lights.add(target.x,target.y,20,colors[5],0.8,0.18)
        shape_clock=1.0
        emit_clock=0.0
    last_active=active
    var dt: float=minf(delta,0.05)
    particles.advance(dt)
    lights.update(dt)
    if active:
        shape_clock+=dt
        emit_clock+=dt
        if shape_clock>=1.0/15.0:
            shape_clock=fmod(shape_clock,1.0/15.0)
            tick+=1
        if emit_clock>=1.0/30.0:
            emit_clock=fmod(emit_clock,1.0/30.0)
            for _i in range(3):
                particles.spawn(PS.SPARK,target.x,target.y,rng.between(-110,110),rng.between(-130,70),rng.between(0.15,0.48))
            var u: float=rng.next()
            particles.spawn(PS.SPARK,lerpf(START.x,target.x,u),lerpf(START.y,target.y,u),rng.between(-60,60),rng.between(-90,20),0.22)
    draw_clock+=delta
    var needs: bool=active or not particles.list.is_empty() or not lights.list.is_empty()
    if draw_clock>=1.0/30.0 and (needs or was_drawn):
        draw_clock=fmod(draw_clock,1.0/30.0)
        var start_us: int=Time.get_ticks_usec()
        var p=surface.painter
        p.clear()
        if active:
            # Same seed holds geometry detail for two frames; endpoints stay live.
            var shape_rng=RNG.new(RNG.hash32([77,tick]))
            paths=LIGHTNING.bowed(shape_rng,START.x,START.y,target.x,target.y,-12.0,0.2,0.35)
            if crackle:
                lightning.crackle(p,paths,0.95,colors,0.5)
            else:
                lightning.stroke(p,paths,0.85+0.15*sin(t*23.0),colors,0.8)
        var draw=batch.begin(p)
        if active:
            draw.glow(START.x,START.y,15,colors[4],0.6)
            draw.glow(target.x,target.y,18,colors[5],0.65)
            PS.sparkle(draw,target.x,target.y,2.0+absf(sin(t*37.0))*2.0,colors[6],colors[4],0.6)
        particles.draw(draw)
        lights.draw(draw)
        batch.finish()
        surface.present()
        sample_times.append((Time.get_ticks_usec()-start_us)/1000.0)
        was_drawn=needs
        queue_redraw()
    stat_clock+=delta
    if stat_clock>=0.5:
        sample_times.sort()
        var n: int=sample_times.size()
        var p95: float=sample_times[clampi(int(ceil(n*0.95))-1,0,n-1)] if n>0 else 0.0
        stats.text="FPS %d | native update p95 %.2f ms | %d sparks | %s | %s" % [Engine.get_frames_per_second(),p95,particles.list.size(),"crackle" if crackle else "stroke","C++" if lightning.accelerator!=null else "GDScript"]
        sample_times.clear()
        stat_clock=0.0
