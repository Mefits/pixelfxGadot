extends RefCounted
## Rectangles are body proxies, not hurtboxes. Circles and sampled lines
## expose the real inherited contact geometry. No renderer feeds simulation.
const WIDTH:int=480
const HEIGHT:int=270
const FLOOR:int=212
const SCALE:float=3.7
const PALETTE:Array=[Color("#51a9ef"),Color("#f0a064")]
const HURT:Color=Color("#81e7bc")
const GRID:Color=Color("#293747")
const INK:Color=Color("#d6e1eb")

func screen(p:Vector2,mid:float)->Vector2i:
    return Vector2i(roundi(WIDTH*.5+(p.x-mid)*SCALE),roundi(FLOOR+p.y*SCALE))

func rect(im:Image,r:Rect2i,c:Color)->void:
    var q:Rect2i=r.intersection(Rect2i(0,0,WIDTH,HEIGHT))
    if q.has_area():im.fill_rect(q,c)

func line(im:Image,a:Vector2i,b:Vector2i,c:Color,thick:int=1)->void:
    var n:int=maxi(absi(b.x-a.x),absi(b.y-a.y))
    for i in range(n+1):
        var p:=Vector2(a).lerp(Vector2(b),float(i)/maxi(n,1))
        rect(im,Rect2i(roundi(p.x)-(thick >> 1),roundi(p.y)-(thick >> 1),thick,thick),c)

func outline(im:Image,r:Rect2i,c:Color)->void:
    rect(im,Rect2i(r.position,Vector2i(r.size.x,1)),c)
    rect(im,Rect2i(r.position+Vector2i(0,r.size.y-1),Vector2i(r.size.x,1)),c)
    rect(im,Rect2i(r.position,Vector2i(1,r.size.y)),c)
    rect(im,Rect2i(r.position+Vector2i(r.size.x-1,0),Vector2i(1,r.size.y)),c)

func ring(im:Image,p:Vector2i,r:float,c:Color)->void:
    var prev:=p+Vector2i(roundi(r),0)
    for i in range(1,49):
        var v:=p+Vector2i(roundi(cos(TAU*i/48.)*r),roundi(sin(TAU*i/48.)*r))
        line(im,prev,v,c)
        prev=v

func phase(w,i:int)->Dictionary:
    var s:Dictionary=w.actors[i]
    var action:String=str(s.action)
    var age:int=maxi(0,int(w.players[i].age)-1)
    var phase_name:String="IDLE"
    var total:int=0
    var marker:int=-1
    var left:int=0
    if s.hp<=0:phase_name="KO"
    elif s.stun>0:phase_name="STUN";left=s.stun
    elif not action.is_empty():
        total=w.bank[action].frames.size()
        var keys:Array=w.bank[action].markers.keys()
        if not keys.is_empty():marker=int(keys[0])
        if action=="parry":
            phase_name="PARRY" if age<w.PARRY_WINDOW else "RECOVERY"
            left=w.PARRY_WINDOW-age if age<w.PARRY_WINDOW else s.remaining
        elif action in ["dash","chase"]:
            phase_name=action.to_upper()
            left=s.remaining
        elif marker>=0:
            phase_name="STARTUP" if age<marker else ("ACTIVE" if age==marker else "RECOVERY")
            left=marker-age if age<marker else (1 if age==marker else s.remaining)
        elif w.Profiles.has_action(action):
            var g:Dictionary=w.Profiles.DATA[action].interaction
            phase_name="STARTUP" if age+1<int(g.first) else ("ACTIVE" if age+1<=int(g.last) else "RECOVERY")
            left=s.remaining
        else:phase_name="ACTION";left=s.remaining
    elif w.airborne(i):phase_name="AIR"
    elif s.guard:phase_name="GUARD"
    elif w.retreat_steps[i]>0. and w.freeze==0:phase_name="BACK"
    return {"phase":phase_name,"action":action,"age":age,"total":total,"marker":marker,"left":left,"hp":s.hp,"air":w.airborne(i),"escape":not s.escape_used,"buffer":str(s.buffer)}

func hud(w)->Dictionary:
    var sides:Array=[phase(w,0),phase(w,1)]
    var actual:Array=[]
    for e in w.samples:
        actual.append({"id":e.id,"tick":e.tick,"attack":e.attack,"result":e.result,"attacker":e.attacker,"distance":e.distance,"kind":e.kind})
    return {"tick":w.tick,"sides":sides,"gap":w.root_x(1)-w.root_x(0),"freeze":w.freeze,"events":actual}

func render(w)->Image:
    var im:=Image.create(WIDTH,HEIGHT,false,Image.FORMAT_RGBA8)
    im.fill(Color("#131c28"))
    var mid:float=(w.root_x(0)+w.root_x(1))*.5
    # Spatial grid in world units; camera follows midpoint without zoom.
    for k in range(-8,9):
        var x:int=roundi(WIDTH*.5+k*10*SCALE)
        rect(im,Rect2i(x,53,1,FLOOR-53),GRID)
    rect(im,Rect2i(0,FLOOR,WIDTH,2),Color("#778b9f"))
    rect(im,Rect2i(0,FLOOR+2,WIDTH,HEIGHT-FLOOR-2),Color("#202c38"))
    for i in 2:
        var s:Dictionary=w.actors[i]
        var p:Dictionary=phase(w,i)
        var root:Vector2i=screen(Vector2(w.root_x(i),float(s.y)),mid)
        var center:Vector2i=screen(w.center(i),mid)
        var top:int=mini(root.y-40,center.y-roundi(w.RADIUS*SCALE)-4)
        var r:=Rect2i(center.x-28,top,56,maxi(40,root.y-top))
        var col:Color=PALETTE[i]
        if p.phase=="STUN":col=col.lerp(Color("#f7df98"),.55)
        elif p.phase=="GUARD" or p.phase=="PARRY":col=col.lerp(HURT,.45)
        rect(im,r,col.darkened(.43))
        outline(im,r,col)
        # Direction and floor projection; no anatomy drawn.
        rect(im,Rect2i(center.x+int(w.facing(i))*20-2,top+5,4,10),col)
        rect(im,Rect2i(root.x-4,FLOOR-3,8,3),col)
        ring(im,center,w.RADIUS*SCALE,HURT)
        # Frame progress bar: actual local age, no fake active window.
        var px:int=14 if i==0 else 254
        rect(im,Rect2i(px,31,212,7),GRID)
        if p.total>0:
            rect(im,Rect2i(px,31,clampi(roundi(212.*float(p.age+1)/float(p.total)),0,212),7),col)
            if p.marker>=0:rect(im,Rect2i(px+roundi(211.*float(p.marker)/float(p.total)),29,2,11),Color("#f77a72"))
        rect(im,Rect2i(px,12,212,10),GRID)
        rect(im,Rect2i(px,12,roundi(212.*float(s.hp)/100.),10),col)
        if not s.escape_used:rect(im,Rect2i(px,24,9,4),HURT)
    # Hold event traces for six ticks for legibility. Muted traces are
    # explicitly historical, not persistent active hitboxes.
    for e in w.shown:
        var current:bool=int(e.tick)==w.tick-1
        var col:Color=Color("#ff6868") if e.result=="hit" else (Color("#85d9ff") if e.result in ["block","parry","evade"] else Color("#f5bf66"))
        if not current:col=col.darkened(.40)
        var origin:Vector2=e.origin
        var a:Vector2i=screen(origin+Vector2(e.a),mid)
        var b:Vector2i=screen(origin+Vector2(e.b),mid)
        if e.kind=="utility":
            rect(im,Rect2i(b-Vector2i(3,3),Vector2i(7,7)),col)
            continue
        ring(im,screen(origin,mid),float(e.radius)*SCALE,col.darkened(.30))
        line(im,a,b,col,3 if current else 1)
        if Vector2(e.extra).length_squared()>0.:line(im,b,screen(origin+Vector2(e.b)+Vector2(e.extra),mid),col,3 if current else 1)
        var nearest:Vector2i=screen(origin+Vector2(e.nearest),mid)
        rect(im,Rect2i(nearest-Vector2i(2,2),Vector2i(5,5)),col)
    for e in w.entities:
        if e.spent:continue
        var p:Dictionary=w.Profiles.DATA[e.attack]
        var g:Dictionary=p.interaction
        var hand:Vector2=w.tip(e.owner,p.motion.anchor)
        var col:Color=Color("#8ccfff") if e.owner==0 else Color("#ffb06c")
        if g.kind=="projectile" and e.detached:
            var pos:Vector2i=screen(e.p,mid)
            ring(im,pos,float(g.radius)*SCALE,col)
            line(im,pos-Vector2i(5,0),pos+Vector2i(5,0),col,3)
        elif g.kind=="blade" and e.age>=g.first and e.age<=g.last:
            var elbow:Vector2=w.point(e.owner,str(p.motion.anchor).replace("hand_","elbow_"))
            var end:Vector2=w.blade_end(hand,elbow,w.facing(e.owner),g.length)
            line(im,screen(hand,mid),screen(end,mid),col,5)
        elif g.kind=="hand" and e.age>=g.first and e.age<=g.last:
            ring(im,screen(hand,mid),float(g.radius)*SCALE,col)
    if w.freeze>0:rect(im,Rect2i(0,HEIGHT-4,WIDTH,4),Color("#f9d784"))
    return im
