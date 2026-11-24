extends Node2D
const PHYS=preload("res://addons/creature/physical_creature.gd")
const P=preload("res://addons/pixelfx/composer/preset.gd")
const C=preload("res://addons/creature/clips.gd")
const A=preload("res://addons/creature/ability.gd")
const RIG=preload("res://addons/creature/rig.gd")
const SKIN=preload("res://addons/creature/skin.gd")
const SURFACE=preload("res://addons/pixelfx/native/surface.gd")
const R=preload("res://addons/pixelfx/composer/renderer.gd")
const V=preload("res://addons/creature/vfx_preview.gd")
var physical
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
    physical=null
    if e.kind=="creature":_reset_body()
    if e.kind=="animation":clip=e.payload.clip
    elif e.kind=="ability":clip=A.compile(e.payload)
    time=0
    _render()
func _process(dt:float)->void:
    if entry.is_empty():return
    elapsed+=dt
    if elapsed<1.0/15:return
    time+=elapsed
    if physical!=null:
        physical.advance(minf(elapsed,.1),1.0,false)
        if physical.body.point("front").x>203:_reset_body()
    elapsed=0
    _render()
func _reset_body()->void:
    var boxes:Array[Rect2]=[Rect2(-100,128,440,60)]
    physical=PHYS.new(Vector2(100,86),boxes,2,1,true,1.0,entry.payload)

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
    elif physical!=null:
        var body=physical.body
        if physical.limbs.enabled:
            for l in physical.limbs.legs:
                var hip:Vector2=body.nodes[l.parent].p
                draw_polyline(PackedVector2Array([hip,l.knee,l.get("tip",l.foot)]),Color("#8ab5a7") if l.side>0 else Color("#46736e"),2)
        for link in body.links:
            var a:Dictionary=body.nodes[link.a]
            var b:Dictionary=body.nodes[link.b]
            draw_line(a.p,b.p,Color("#537b76"),minf(a.r,b.r)*2)
        for i in range(body.nodes.size()-1,-1,-1):
            var n:Dictionary=body.nodes[i]
            draw_circle(n.p,n.r,Color("#81b3a0") if i<2 else Color("#537b76"))
        draw_circle(body.point("front")+Vector2(3,-2),1.5,Color("#f8ebbb"))
