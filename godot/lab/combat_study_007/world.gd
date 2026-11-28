extends "res://lab/combat_study_006/world.gd"
## Pure diagnostic subclass. Never changes a contact or the inherited snapshot.
var samples:Array=[]
var shown:Array=[]
var last_sample_tick:int=-100
var diagnostic:bool=true

func _init(gap:float=30.,stop_enabled:bool=true,profile:int=2,enabled:bool=true):
    super(gap,stop_enabled,profile)
    diagnostic=enabled

func step(left:Dictionary,right:Dictionary)->void:
    samples=[]
    super.step(left,right)
    if not samples.is_empty():
        shown=samples.duplicate(true)
        last_sample_tick=tick-1
    elif tick-1-last_sample_tick>6:
        shown=[]

func marker_event(ev:Dictionary,a:Vector2,b:Vector2,blocking:bool,kind:String)->Dictionary:
    ev=super.marker_event(ev,a,b,blocking,kind)
    if diagnostic:
        # Relative swept geometry actually used by 001/003/004, anchored
        # to the current target centre for the diagnostic picture.
        var target:int=ev.target
        var origin:Vector2=center(target)
        var extra:Vector2=Vector2(ev.get("end",ev.point))-Vector2(ev.point)
        var nearest:Vector2=Geometry2D.get_closest_point_to_segment(Vector2.ZERO,a,b) if a.distance_squared_to(b)>.000001 else a
        if extra.length_squared()>0.:
            var extension:Vector2=Geometry2D.get_closest_point_to_segment(Vector2.ZERO,b,b+extra)
            if extension.length_squared()<nearest.length_squared():nearest=extension
        samples.append({"id":ev.id,"tick":ev.tick,"attacker":ev.attacker,"target":target,"attack":ev.attack,"result":ev.result,"kind":kind,"origin":origin,"a":a,"b":b,"extra":extra,"nearest":nearest,"distance":ev.distance,"radius":RADIUS,"blocking":blocking,"front":(root_x(target)-root_x(ev.attacker))*facing(ev.attacker)>0.,"air":[airborne(int(ev.attacker)),airborne(target)]})
    return ev

func restore(bytes:PackedByteArray)->void:
    super.restore(bytes)
    samples=[]
    shown=[]
    last_sample_tick=-100
