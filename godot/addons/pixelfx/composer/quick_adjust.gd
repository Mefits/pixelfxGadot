extends RefCounted
## Pure preset transform: no mutation of source, no change to timing markers.
## All values remain within the existing schema 1 bounds.
const P=preload("res://addons/pixelfx/composer/preset.gd")
static func scaled(source: Dictionary,size_factor: float,power: float,time_factor: float,hue_degrees: float) -> Dictionary:
    if not P.valid(source):return {}
    var out: Dictionary=source.duplicate(true)
    var s: float=clampf(size_factor,.25,2)
    var a: float=clampf(power,.25,2)
    var t: float=clampf(time_factor,.5,2)
    var hue: float=clampf(hue_degrees,-180,180)/360.0
    for l in out.layers:
        for key in ["size","end_size"]:
            l[key]=clampf(float(l[key])*s,.5,80)
        for key in ["alpha","end_alpha","glow"]:
            l[key]=clampf(float(l[key])*a,0,1)
        l.start=clampf(float(l.start)*t,0,5)
        l.duration=clampf(float(l.duration)*t,.05,5)
        for key in ["x","y"]:
            l[key]=clampf(float(l[key])*s,-100,100)
        for key in ["speed","end_speed"]:
            l[key]=clampf(float(l[key])*s/t,0,200)
        l.gravity=clampf(float(l.gravity)*s/(t*t),-200,300)
        if not is_zero_approx(hue):
            var color:=Color(l.color)
            l.color="#"+Color.from_hsv(fposmod(color.h+hue,1.0),color.s,color.v).to_html(false)
        if l.has("curves"):
            for channel in l.curves:
                var scale: float=s if channel=="size" else (s/t if channel=="speed" else a)
                var bounds: Array=P.RANGES[channel]
                for pt in l.curves[channel]:
                    pt[1]=clampf(float(pt[1])*scale,bounds[0],bounds[1])
        if l.has("emitter"):
            l.emitter.life=clampf(float(l.emitter.life)*t,.05,3)
            l.emitter.radius=clampf(float(l.emitter.radius)*s,0,40)
            l.emitter.rate=clampf(roundf(float(l.emitter.rate)/t),1,64)
        if l.has("trail"):
            l.trail.life=clampf(float(l.trail.life)*t,.05,1.5)
            l.trail.break_distance=clampf(float(l.trail.break_distance)*s,4,120)
            l.trail.jitter=clampf(float(l.trail.jitter)*s,0,12)
        if l.has("organic"):
            l.organic.length=clampf(float(l.organic.length)*s,4,96)
            l.organic.wave=clampf(float(l.organic.wave)*s,0,32)
            l.organic.frequency=clampf(float(l.organic.frequency)/t,0,6)
        if l.has("field"):
            l.field.length=clampf(float(l.field.length)*s,4,160)
            l.field.thickness=clampf(float(l.field.thickness)*s,.5,12)
            l.field.rotation=clampf(float(l.field.rotation)/t,-720,720)
    return out if P.valid(out) else {}
