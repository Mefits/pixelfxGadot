extends RefCounted
## Cosmetic avatar envelope from the real raster silhouette + secondary chains.
## All positions are in art pixels; no gameplay writes.
const Painter=preload("res://addons/pixelfx/native/painter.gd")
const WIDTH:int=264
const HEIGHT:int=120
const COUNT:int=WIDTH*HEIGHT
const INF_D:float=999.
const OUTER:int=0xff2350f5
const INNER:int=0xff569aff
const EDGE:int=0xff9fd9ff
var ink=Painter.new(WIDTH,HEIGHT)
var seed_mask=Painter.new(WIDTH,HEIGHT)
var tails:Array=[]
var last_root:=Vector2.ZERO
var velocity:=Vector2.ZERO
var ready:bool=false

func reset()->void:
    tails.clear()
    ready=false
    velocity=Vector2.ZERO

func update_chains(root:Vector2,facing:float,tick:int,mode:int)->void:
    if not ready:
        last_root=root
        ready=true
    velocity=velocity.lerp(root-last_root,.28)
    last_root=root
    var count:int=0 if mode<2 else mode-1
    while tails.size()<count:tails.append(PackedVector2Array())
    for k in count:
        var chain:PackedVector2Array=tails[k]
        var length:float=31. if k==0 else 23.
        if chain.size()!=13:
            chain.resize(13)
            for j in 13:chain[j]=root
        chain[0]=root
        for j in range(1,13):
            var u:float=float(j)/12.
            var wave:float=sin(float(tick)*.10-u*4.+float(k)*1.7)
            # Curved target grows behind the hip and curls back above it.
            var x:float=-facing*length*sin(u*PI*.86)
            var y:float=-length*(u*.92+.12*sin(u*PI))+float(k)*8.*u
            var goal:Vector2=root+Vector2(x,y)+Vector2(-velocity.x*5.*u,2.8*wave*u*u)
            var follow:float=lerpf(.62,.22,u)
            var next:Vector2=chain[j].lerp(goal,follow)
            var step:Vector2=next-chain[j-1]
            # Cosmetic chain, bounded segments; avoids disconnected islands on reversal.
            var max_step:float=length*.16
            chain[j]=chain[j-1]+step.limit_length(max_step)
        tails[k]=chain

func field(body_mask:PackedByteArray,root:Vector2,facing:float,tick:int,mode:int)->void:
    ink.clear()
    seed_mask.clear()
    if mode==0:return
    update_chains(root,facing,tick,mode)
    for k in range(tails.size()):
        if k>=mode-1:break
        var chain:PackedVector2Array=tails[k]
        for j in range(1,chain.size()):
            var a:Vector2=chain[j-1]
            var b:Vector2=chain[j]
            var steps:int=maxi(1,ceili(a.distance_to(b)*1.4))
            for s in range(steps+1):
                var f:float=float(s)/steps
                var u:float=(float(j-1)+f)/12.
                var p:Vector2=a.lerp(b,f)
                var radius:float=lerpf(5.7 if k==0 else 4.2,.7,u)*(1.+.10*sin(float(tick)*.12-u*7.))
                seed_mask.circle(p.x,p.y,radius,0xffffffff)
    var d:=PackedFloat32Array()
    d.resize(COUNT)
    for i in COUNT:d[i]=0. if body_mask[i]>0 or seed_mask.color[i]!=0 else INF_D
    # Two-pass chamfer dilation of exact body and tail mask. No new body rasterizer.
    for y in HEIGHT:
        for x in WIDTH:
            var i:int=y*WIDTH+x
            if d[i]==0.:continue
            if x>0:d[i]=minf(d[i],d[i-1]+1.)
            if y>0:
                d[i]=minf(d[i],d[i-WIDTH]+1.)
                if x>0:d[i]=minf(d[i],d[i-WIDTH-1]+1.4142)
                if x<WIDTH-1:d[i]=minf(d[i],d[i-WIDTH+1]+1.4142)
    for y in range(HEIGHT-1,-1,-1):
        for x in range(WIDTH-1,-1,-1):
            var i:int=y*WIDTH+x
            if d[i]==0.:continue
            if x<WIDTH-1:d[i]=minf(d[i],d[i+1]+1.)
            if y<HEIGHT-1:
                d[i]=minf(d[i],d[i+WIDTH]+1.)
                if x>0:d[i]=minf(d[i],d[i+WIDTH-1]+1.4142)
                if x<WIDTH-1:d[i]=minf(d[i],d[i+WIDTH+1]+1.4142)
    var base:float=[0.,2.3,3.3,4.6][mode]
    for y in HEIGHT:
        for x in WIDTH:
            var i:int=y*WIDTH+x
            var dist:float=d[i]
            if dist>base+5.:continue
            var wave:float=sin(float(x)*.42+float(y)*.24-float(tick)*.19)+.55*sin(float(x)*.91-float(y)*.54+float(tick)*.12)
            var back:float=clampf((root.x-float(x))*facing/25.,0.,1.)
            var rim:float=base+.65*wave+back*minf(1.6,absf(velocity.x)*.8)
            if body_mask[i]>0:
                ink.blend_px(x,y,INNER,.085+.035*sin(float(tick)*.15+float(y)*.27))
                continue
            if dist<=rim:
                var edge:float=smoothstep(maxf(.0,rim-1.3),rim+.1,dist)
                var core:float=.25+.07*sin(float(y)*.32-float(tick)*.17+float(x)*.18)
                var alpha:float=lerpf(core,.64,edge)
                if seed_mask.color[i]!=0:alpha=.42+.08*wave
                ink.blend_px(x,y,EDGE if edge>.55 else INNER,clampf(alpha,.08,.72))
                ink.add(x,y,OUTER,.13+.15*edge)
            elif dist<rim+3.5:
                var fade:float=1.-(dist-rim)/3.5
                ink.add(x,y,OUTER,.18*fade*fade)
    # Small rising embers from real upper-body anchor, not random circles around root.
    for n in range(9 if mode==1 else 15):
        var phase:float=fmod(float(tick)*.75+float(n)*7.13,35.)/35.
        var p:Vector2=root+Vector2(sin(float(n)*5.17)*8.-facing*phase*8.,-8.-phase*30.)
        if phase>.12 and phase<.9:
            ink.dot(p.x,p.y,EDGE,(1.-phase)*.68)
            if n%4==0:ink.glow(p.x,p.y,2.,OUTER,.22)
