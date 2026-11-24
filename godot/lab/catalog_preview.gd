extends Node2D
const P=preload("res://addons/pixelfx/composer/preset.gd")
const C=preload("res://addons/creature/clips.gd")
const A=preload("res://addons/creature/ability.gd")
const RIG=preload("res://addons/creature/rig.gd")
const SKIN=preload("res://addons/creature/skin.gd")
const SURFACE=preload("res://addons/pixelfx/native/surface.gd")
const R=preload("res://addons/pixelfx/composer/renderer.gd")
const V=preload("res://addons/creature/vfx_preview.gd")
var entry:Dictionary={}
var clip:Dictionary={}
var rig=RIG.humanoid()
var renderer=R.new()
var cue_preview=V.new()
var surface
var time:float=0
var elapsed:float=0
func _ready()->void:
    surface=SURFACE.new()
    add_child(surface)
    surface.configure(240,160)
    renderer.enable_acceleration()
    cue_preview.renderer.enable_acceleration()
func set_entry(e:Dictionary)->void:
    entry=e.duplicate(true)
    clip={}
    if e.kind=="animation":clip=e.payload.clip
    elif e.kind=="ability":clip=A.compile(e.payload)
    time=0
    _render()
func _process(dt:float)->void:
    if entry.is_empty():return
    elapsed+=dt
    if elapsed<1.0/15:return
    time+=elapsed
    elapsed=0
    _render()
func _anchor(name:String,t:float)->Vector2:
    if name=="hand":return Vector2(94+sin(t*4)*22,76-cos(t*4)*12)
    if name=="target":return Vector2(166,76)
    return Vector2(120,80)
func _render()->void:
    if surface==null:return
    surface.painter.clear()
    if entry.get("kind")=="vfx":
        var t:float=fposmod(time,P.duration(entry.payload)+.35)
        renderer.render(surface.painter,entry.payload,t,{},128,_anchor)
    elif not clip.is_empty():
        var t:float=fposmod(time,float(clip.duration)+.25)
        rig.evaluate(C.sample(clip,t,false))
        cue_preview.draw(surface.painter,clip,t,Vector2(112,125),Vector2(165,98))
    surface.present()
    queue_redraw()
func _draw()->void:
    draw_rect(Rect2(0,0,240,160),Color("#142231"))
    draw_line(Vector2(0,128),Vector2(240,128),Color("#526878"))
    if entry.is_empty():return
    if not clip.is_empty():SKIN.draw_body(self,rig,Vector2(112,125),1,Color("#84c7d9"),false)
    elif entry.kind=="creature":
        var p:Dictionary=entry.payload
        var a:=Vector2(144,111)
        var b:=Vector2(126,113)
        if p.limbs:
            for x in [126,144]:
                draw_polyline(PackedVector2Array([Vector2(x,113),Vector2(x-5,120),Vector2(x+5,128)]),Color("#8ab5a7"),3)
        draw_line(a,b,Color("#78a89b"),12)
        for i in range(int(p.tail)):
            var q:Vector2=b+Vector2(-7,0)
            draw_line(b,q,Color("#537b76"),maxf(3,8-i*.5))
            b=q
        draw_circle(a,7,Color("#81b3a0"))
        draw_circle(a+Vector2(3,-2),1.5,Color("#f8ebbb"))
