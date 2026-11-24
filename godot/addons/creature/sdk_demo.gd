extends Node2D
## Small integration sample, intentionally free of toolkit editor code.
const API=preload("res://addons/creature/kit_api.gd")
const SKIN=preload("res://addons/creature/skin.gd")
const RIG=preload("res://addons/creature/rig.gd")
const CLIPS=preload("res://addons/creature/clips.gd")
const WORLD=preload("res://addons/creature/combat.gd")
const VFX=preload("res://addons/creature/vfx_runtime.gd")
const CUE=preload("res://addons/creature/vfx_preview.gd")
const R=preload("res://addons/pixelfx/composer/renderer.gd")
const SURFACE=preload("res://addons/pixelfx/native/surface.gd")
const P=preload("res://addons/pixelfx/composer/preset.gd")
var entry:Dictionary={}
var anatomy_override:Dictionary={}
var manual:bool=false
var target_start:=Vector2.ZERO
var last_events:Array=[]
var max_penetration:float=0
var max_constraint_error:float=0
var creature
var world
var surface
var rig=RIG.humanoid()
var renderer=R.new()
var cues=CUE.new()
var target:Dictionary={}
var clip:Dictionary={}
var clock:float=0
var smoke:bool=false
var ticks:int=0
var attempted:bool=false
var info:Label
func _ready()->void:
    smoke=not manual and "--smoke" in OS.get_cmdline_user_args()
    if entry.is_empty():entry=API.read("res://content/template.json")
    if entry.is_empty():push_error("Invalid exported template");get_tree().quit(1);return
    surface=SURFACE.new()
    add_child(surface)
    surface.configure(320,180)
    info=Label.new()
    info.position=Vector2(6,4)
    info.add_theme_font_size_override("font_size",10)
    add_child(info)
    _reset()
    if manual:set_physics_process(false)
func _reset()->void:
    creature=null
    world=null
    clip={}
    clock=0
    attempted=false
    last_events=[]
    max_penetration=0
    max_constraint_error=0
    var boxes:Array[Rect2]=[Rect2(-100,146,520,100)]
    match entry.kind:
        "creature":creature=API.create_creature(entry,Vector2(85,110),boxes)
        "animation":clip=entry.payload.clip.duplicate(true)
        "ability":
            if entry.payload.get("engine","")=="physical":
                var p:Dictionary=anatomy_override if not anatomy_override.is_empty() else API.ANATOMY.templates()[4 if entry.payload.type=="grab" else 0]
                creature=API.PHYS.new(Vector2(85,110),boxes,2,1,true,1.0,p)
                if not API.attach_ability(entry,creature):push_error("Ability incompatible");get_tree().quit(1);return
                target={"id":"example","p":Vector2(114 if entry.payload.type=="grab" else 135,125),"r":8.0,"hp":100}
                target_start=target.p
                creature.attack.targets.append(target)
            else:
                world=WORLD.new(CLIPS.defaults())
                world.custom_vfx=VFX.new()
                world.a.pos.x=90
                world.b.pos.x=145
                if not world.a.set_ability(entry.payload):push_error("Invalid compiled ability");get_tree().quit(1);return
    info.text=str(entry.name)+" | A/D, W, E, R"
func _anchor(name:String,t:float)->Vector2:
    if name=="hand":return Vector2(120+sin(t*4)*22,86-cos(t*4)*12)
    if name=="target":return Vector2(205,86)
    return Vector2(160,90)
func _physics_process(dt:float)->void:
    if entry.is_empty():return
    var axis:float=float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A))
    var trigger:bool=Input.is_physical_key_pressed(KEY_E)
    advance_frame(dt,axis,trigger,Input.is_physical_key_pressed(KEY_W))

func advance_frame(dt:float,axis:float=0,trigger:bool=false,jump:bool=false)->void:
    if entry.is_empty():return
    ticks+=1
    clock+=dt
    if creature!=null:
        if entry.kind=="creature":
            if smoke:axis=1
        elif not attempted and (trigger or (smoke and creature.grounded)):
            if manual:
                var head:Vector2=creature.body.point("front")
                var distance:float=29 if entry.payload.type=="grab" else (22 if entry.payload.type=="claw" else 35)
                target.p=head+Vector2(distance,0)
                target_start=target.p
            attempted=creature.special.begin(creature,target)
        creature.advance(dt,axis,jump)
        max_penetration=maxf(max_penetration,creature.body.penetration())
        max_constraint_error=maxf(max_constraint_error,creature.body.max_error)
        for e in creature.special.drain_events():
            if last_events.size()<64:
                if e.get("p") is Vector2:e.p=[e.p.x,e.p.y]
                last_events.append(e)
    if world!=null:world.step(dt,{"ability":trigger or (smoke and ticks==1),"move":axis},{})
    surface.painter.clear()
    if entry.kind=="vfx":
        renderer.render(surface.painter,entry.payload,fposmod(clock,P.duration(entry.payload)+.3),{},146,_anchor)
    elif not clip.is_empty():
        var t:float=fposmod(clock,float(clip.duration)+.25)
        rig.evaluate(CLIPS.sample(clip,t,false))
        cues.draw(surface.painter,clip,t,Vector2(160,146),Vector2(220,110))
    elif world!=null:world.custom_vfx.draw(surface.painter,146)
    surface.present()
    queue_redraw()
    if smoke and ticks>=180:
        var ok:bool=true
        if creature!=null:ok=creature.body.finite() and creature.body.penetration()<.1
        if entry.kind=="ability":ok=ok and (attempted if creature!=null else world.a.attacks_started==1)
        if not ok:push_error("DEMO_SMOKE_FAILED");get_tree().quit(1);return
        print("DEMO_SMOKE_OK ",entry.kind," ",entry.get("id",""))
        get_tree().quit()
func _unhandled_input(e:InputEvent)->void:
    if e is InputEventKey and e.pressed and not e.echo:
        if e.physical_keycode==KEY_R:_reset()
func _draw()->void:
    draw_rect(Rect2(0,0,320,180),Color("#142231"))
    draw_line(Vector2(0,146),Vector2(320,146),Color("#526878"))
    if creature!=null:
        var body=creature.body
        if creature.limbs.enabled:
            for l in creature.limbs.legs:
                draw_polyline(PackedVector2Array([body.nodes[l.parent].p,l.knee,l.get("tip",l.foot)]),Color("#88b6a3"),2)
        for link in body.links:
            var a:Dictionary=body.nodes[link.a]
            var b:Dictionary=body.nodes[link.b]
            draw_line(a.p,b.p,Color("#537b76"),minf(a.r,b.r)*2)
        for n in body.nodes:draw_circle(n.p,n.r,Color("#81b3a0"))
        if entry.kind=="ability":
            draw_circle(target.p,target.r,Color("#ba8571"))
            if creature.special.active and creature.special.phase=="pull":
                var chain:Array=creature.branches[creature.special.branch]
                draw_line(body.nodes[chain[-1]].p,target.p,Color("#c6e9b1"),1)
            draw_rect(Rect2(Vector2(target.p)+Vector2(-8,-12),Vector2(16*float(target.hp)/100,2)),Color("#dcb788"))
            if creature.special.active and creature.special.phase=="flight":draw_circle(creature.special.projectile,3,Color("#a4eaff"))
    elif world!=null:
        SKIN.draw_body(self,world.a.rig,world.a.pos,world.a.facing,world.a.tint)
        SKIN.draw_body(self,world.b.rig,world.b.pos,world.b.facing,world.b.tint)
    elif not clip.is_empty():SKIN.draw_body(self,rig,Vector2(160,146),1,Color("#84c7d9"))

func diagnostics()->Dictionary:
    var result:Dictionary={"time":clock,"ticks":ticks}
    if creature!=null:
        result.merge({"finite":creature.body.finite(),"max_penetration":max_penetration,"max_constraint_error":max_constraint_error,"body_nodes":creature.body.nodes.size(),"legs":creature.limbs.legs.size(),"tentacles":creature.branches.size(),"ability_started":attempted,"hits":creature.special.hits+creature.attack.hit_count,"target_hp":target.get("hp",100),"target_moved":Vector2(target.get("p",Vector2.ZERO)).distance_to(target_start),"events":last_events.duplicate(true)})
    elif world!=null:result.merge({"attacks":world.a.attacks_started,"hits":world.hits,"target_hp":world.b.hp,"sim_steps":world.sim_steps})
    return result
