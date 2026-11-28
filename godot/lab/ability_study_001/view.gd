extends "res://lab/combat_study_005/view.gd"
const Painter=preload("res://addons/pixelfx/native/painter.gd")
const Profiles=preload("profiles.gd")
# Existing native reference primitives, no new rasterizer.
var ink=Painter.new(214,110)
var enabled:bool=true

func screen(w,p:Vector2)->Vector2:
    return Vector2(106.6667+p.x-(w.root_x(0)+w.root_x(1))*.5,93.+p.y)

func energy(a:Vector2,b:Vector2,width:float,outer:int,core:int)->void:
    ink.beam(a.x,a.y,b.x,b.y,width,outer)
    ink.beam(a.x,a.y,b.x,b.y,maxf(1.,width*.45),core)
    ink.glow(b.x,b.y,width*2.,outer,.55)

func render(w)->Image:
    var out:Image=super.render(w)
    if out==null or not enabled:return out
    ink.clear()
    for e in w.entities:
        if e.spent:continue
        var p:Dictionary=Profiles.DATA[e.attack]
        var hand:Vector2=w.tip(e.owner,"hand_near")
        var a:Vector2=screen(w,hand)
        var g:Dictionary=p.interaction
        if e.detached:
            a=screen(w,e.p)
            var tail:Vector2=a-Vector2(w.facing(e.owner)*10.,0.)
            energy(tail,a,4.,0xffff9b38,0xfff4ffff)
            ink.glow(a.x,a.y,10.,0xffffb45f,.9)
            ink.circle(a.x,a.y,g.radius,0xffffbd65)
            ink.circle(a.x,a.y,g.radius*.55,0xfff8ffff)
        elif g.kind=="blade" and e.age>=g.first and e.age<=g.last:
            var end:Vector2=screen(w,w.blade_end(hand,w.point(e.owner,"elbow_near"),w.facing(e.owner),g.length))
            energy(a,end,g.radius*2.,0xfff1a16b,0xfff6ffff)
            ink.glow(a.x,a.y,6.,0xffe99d74,.75)
        elif g.kind=="hand" and e.age>=p.movement.first and e.age<=p.movement.last:
            var tail:Vector2=a-Vector2(w.facing(e.owner)*12.,0.)
            energy(tail,a,3.,0xff67d5ff,0xffeaffff)
            ink.glow(a.x,a.y,7.,0xff67d5ff,.75)
        elif e.age<g.first:
            var radius:float=1.+3.*float(e.age)/float(g.first)
            ink.ring(a.x,a.y,radius,1.,0xfff1d48a)
            ink.glow(a.x,a.y,radius*2.,0xfff1d48a,.5)
    for ev in w.contacts:
        if not ev.has("entity") or ev.result not in ["hit","block","parry"] or w.tick-int(ev.tick)>6:continue
        var a:Vector2=screen(w,ev.point)
        var age:float=float(w.tick-int(ev.tick))
        var color:int=0xffe0f1ff if ev.result=="block" else 0xff78c7ff
        for j in 7:
            var v:Vector2=Vector2.from_angle(float(j)*TAU/7.+float(ev.entity))*(3.+age*1.6)
            var b:Vector2=a+v
            ink.line(a.x,a.y,b.x,b.y,color,maxf(.1,1.-age/7.))
        ink.glow(a.x,a.y,12.,color,.9)
    # Preserve separate color/light buffers, then composite for a capture.
    var rgb:=Image.create_from_data(214,110,false,Image.FORMAT_RGBA8,ink.rgba_bytes())
    rgb.resize(642,330,Image.INTERPOLATE_NEAREST)
    out.blend_rect(rgb,Rect2i(0,0,640,330),Vector2i.ZERO)
    for y in 110:
        for x in 214:
            var value:int=ink.light[y*214+x]
            if value==0:continue
            var light:=Color(float(value&255)/255.,float((value>>8)&255)/255.,float((value>>16)&255)/255.)
            for dy in 3:
                for dx in 3:
                    var px:int=x*3+dx
                    var py:int=y*3+dy
                    if px>=640:continue
                    var c:Color=out.get_pixel(px,py)
                    out.set_pixel(px,py,Color(minf(1.,c.r+light.r),minf(1.,c.g+light.g),minf(1.,c.b+light.b),1.))
    return out
