extends RefCounted
## Original PixelFX core/sim.js flare, band, crystal, MIT Patch/Hugo Duprez.
const PAL=preload("res://addons/pixelfx/native/palette.gd")
const WHITE: int=0xffffffff

static func flare(p,x: float,y: float,length: float,k: float,ramp: Array) -> void:
    if length<1 or ramp.size()<3:
        return
    var r: Array=PAL.fit(ramp,ramp.size())
    var n: int=r.size()
    for i in range(8):
        var an: float=i*PI/4
        var l: float=length if i%4==0 else (length*.6 if i%2==0 else length*.3)
        var ca: float=cos(an)
        var sa: float=sin(an)
        var d: float=0
        while d<=l:
            var u: float=d/l
            p.dot(x+ca*d,y+sa*d,WHITE if u<.35 else (r[n-2] if u<.7 else r[n-3]),1.0 if u<.6 else k*1.5*(1-u)+.2)
            d+=.5

static func band(p,cx: float,cy: float,radius: float,sy: float,th: float,k: float,ramp: Array,keep: Callable=Callable(),hot: bool=false) -> void:
    if radius<=0 or k<=0 or th<=0 or ramp.size()<4:
        return
    var r: Array=PAL.fit(ramp,ramp.size())
    var n: int=r.size()
    var m: int=int(ceil(radius*TAU*1.2))
    for j in range(m):
        var ang: float=float(j)/m*TAU
        var ca: float=cos(ang)
        var sa: float=sin(ang)
        if keep.is_valid() and not keep.call(ang):
            continue
        var o: float=th
        while o>=0:
            var u: float=o/th
            var col: int=(WHITE if hot else r[n-1]) if u<.15 else (r[n-2] if u<.4 else (r[n-3] if u<.7 else r[n-4]))
            p.dot(cx+ca*(radius-o),cy+sa*(radius-o)*sy,col,k*(1.2 if u<.4 else 1.15-u))
            o-=.5

static func _inside(px: int,py: int,x: float,base: float,h: float,w: float,lean: float) -> bool:
    var u: float=(base-(py+.5))/h
    return u>=0 and u<=1 and absf(px+.5-(x+lean*u))<=w/2*(1-u)+.35

static func _col(r: Array,i: int) -> int:
    return r[maxi(0,r.size()-1-i)]

static func crystal(p,x: float,base: float,h: float,w: float,lean: float,ramp: Array,opts: Dictionary={}) -> void:
    if h<1.5 or ramp.size()<6:
        return
    var r: Array=PAL.fit(ramp,ramp.size())
    var n: int=r.size()
    var a: float=opts.get("a",1.0)
    var top: float=base-h
    var ridge0: float=x-w*.14
    var glint: float=opts.get("glint",-1)
    for py in range(int(floor(top))-1,int(ceil(base))):
        for px in range(int(floor(x-w/2-absf(lean)-2)),int(ceil(x+w/2+absf(lean)+2))+1):
            if not _inside(px,py,x,base,h,w,lean):
                if _inside(px-1,py,x,base,h,w,lean) or _inside(px+1,py,x,base,h,w,lean) or _inside(px,py+1,x,base,h,w,lean) or (_inside(px,py-1,x,base,h,w,lean) and py<base-1):
                    p.dot(px,py,r[0],a)
                continue
            if opts.get("white",false):
                p.dot(px,py,WHITE,a)
                continue
            var u: float=(base-(py+.5))/h
            var rx: float=ridge0+(x+lean-ridge0)*u
            var c: float=x+lean*u
            var hw: float=w/2*(1-u)+.35
            var fx: float=px+.5
            var col: int
            if u>.9:
                col=WHITE
            elif absf(fx-rx)<.55:
                col=_col(r,1)
            elif fx<rx:
                col=_col(r,1) if fx-(c-hw)<1 else (_col(r,2) if (fx-(c-hw))/maxf(1,rx-(c-hw))>.55 else _col(r,3))
            else:
                col=_col(r,mini(n-2,6)) if c+hw-fx<1.2 else (_col(r,5) if (fx-rx)/maxf(1,c+hw-rx)>.5 else _col(r,4))
            if glint>=0 and fx<=rx+.6:
                var g: float=absf(u-glint)
                if g<.05:
                    col=WHITE
                elif g<.1:
                    col=_col(r,1)
            p.dot(px,py,col,a)
