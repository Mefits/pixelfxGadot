extends RefCounted
## PixelFX core/shapes.js, MIT Patch/Hugo Duprez.
static func bolt(r,x0: float,y0: float,x1: float,y1: float,jag: float=.22,depth: int=5) -> Array:
    var pts: Array=[[x0,y0],[x1,y1]]
    for _d in range(depth):
        var nxt: Array=[pts[0]]
        for i in range(1,pts.size()):
            var ax: float=pts[i-1][0]
            var ay: float=pts[i-1][1]
            var bx: float=pts[i][0]
            var by: float=pts[i][1]
            var dx: float=bx-ax
            var dy: float=by-ay
            var l: float=sqrt(dx*dx+dy*dy)
            var off: float=(r.next()*2-1)*jag*l
            var den: float=l if l!=0 else 1.0
            nxt.append([(ax+bx)/2+(-dy/den)*off,(ay+by)/2+(dx/den)*off])
            nxt.append(pts[i])
        pts=nxt
    return pts

static func forks(r,path: Array,count: int=3,length: float=20,jag: float=.3,spread: float=.9) -> Array:
    var out: Array=[]
    if path.size()<3:
        return out
    for _k in range(count):
        var i: int=1+int(floor(r.next()*(path.size()-2)))
        var x: float=path[i][0]
        var y: float=path[i][1]
        var a: float=atan2(y-path[i-1][1],x-path[i-1][0])+r.sign()*spread*(.4+.6*r.next())
        var l: float=length*(.4+.6*r.next())
        out.append(bolt(r,x,y,x+cos(a)*l,y+sin(a)*l,jag,3))
    return out

static func star(cx: float,cy: float,r0: float,r1: float,n: int=5,rot: float=-PI/2) -> Array:
    var pts: Array=[]
    for i in range(n*2):
        var a: float=rot+i*PI/n
        var r: float=r0 if i%2 else r1
        pts.append([cx+cos(a)*r,cy+sin(a)*r])
    return pts

static func ngon(cx: float,cy: float,r: float,n: int=6,rot: float=0) -> Array:
    var pts: Array=[]
    for i in range(n):
        var a: float=rot+i*TAU/n
        pts.append([cx+cos(a)*r,cy+sin(a)*r])
    return pts

static func trail(pos: Callable,t: float,n: int,dt: float) -> Array:
    var out: Array=[]
    for i in range(n):
        out.append(pos.call(maxf(0,t-i*dt)))
    return out
