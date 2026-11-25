extends Node2D
const ANATOMY=preload("res://addons/creature/anatomy.gd")
const SPECIAL=preload("res://addons/creature/physical_ability.gd")
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
var training:Dictionary={}
var special_preview:bool=false
var attempted:bool=false
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
    special_preview=e.kind=="ability" and SPECIAL.valid(e.payload)
    if e.kind=="creature" or special_preview:_reset_body()
    if e.kind=="animation":clip=e.payload.clip
    elif e.kind=="ability" and not special_preview:clip=A.compile(e.payload)
    time=0
    _render()
func _process(dt:float)->void:
    if entry.is_empty():return
    elapsed+=dt
    if elapsed<1.0/15:return
    time+=elapsed
    if physical!=null:
        if special_preview:
            if not attempted and physical.grounded:
                attempted=physical.special.begin(physical,training)
            physical.advance(minf(elapsed,.1),0.0,false)
            physical.special.drain_events()
            if time>3.5:
                time=0
                _reset_body()
        else:
            physical.advance(minf(elapsed,.1),1.0,false)
            if physical.body.point("front").x>203:_reset_body()
    elapsed=0
    _render()
func _reset_body()->void:
    var boxes:Array[Rect2]=[Rect2(-100,128,440,60)]
    var anatomy:Dictionary=entry.payload if not special_preview else ANATOMY.templates()[4 if entry.payload.type=="grab" else 0]
    physical=PHYS.new(Vector2(100,86),boxes,2,1,true,1.0,anatomy)
    attempted=false
    if special_preview:
        training={"id":"preview","p":Vector2(132 if entry.payload.type=="grab" else 147,108),"r":8.0,"hp":100}
        physical.attack.targets.append(training)
        physical.special.configure(entry.payload)

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

        if special_preview:
            draw_circle(training.p,training.r,Color("#ba8571"))
            draw_rect(Rect2(Vector2(training.p)+Vector2(-8,-12),Vector2(16*float(training.hp)/100,2)),Color("#dcb788"))
            if physical.special.active and physical.special.phase=="flight":
                draw_circle(physical.special.projectile,3,Color("#a8e675") if physical.special.profile.type=="acid" else Color("#a4eaff"))
