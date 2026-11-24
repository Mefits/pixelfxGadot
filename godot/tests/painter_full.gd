extends SceneTree
const P=preload("res://addons/pixelfx/native/painter.gd")
const PAL=preload("res://addons/pixelfx/native/palette.gd")

func _initialize() -> void:
    create_timer(20.0).timeout.connect(func(): quit(1))
    call_deferred("_run")

func _run() -> void:
    var cases: Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/painter.json"))
    if not cases is Array:
        quit(1)
        return
    var c: Array=PAL.fit(["#14243b","#3468a0","#65b8dd","#ffffff"],4)
    var bad: int=0
    for i in range(cases.size()):
        var p=P.new(104,88,-3,-5)
        p.place(48,40,i==1,0.34 if i==2 else 0.0)
        p.fade=.91
        p.light_k=.8
        var col: Callable=func(u: float,_v: float): return c[1] if u<.5 else c[2]
        var alpha: Callable=func(u: float,_v: float): return .35+.6*u
        p.disc(-22,-14,8,col,alpha)
        p.circle(-2,-14,9,col,alpha)
        p.ellipse(21,-14,9,5,col,alpha)
        p.ring(-22,8,8,4,col,alpha)
        p.arc(0,6,10,func(u: float): return 2+4*sin(PI*u),-.7,3.4,col,alpha)
        p.beam(12,1,29,11,5,col,alpha)
        p.line(-30,19,-10,25,func(u: float): return c[2] if u<.5 else c[3],func(u: float): return .3+.7*u)
        p.poly([[-8,20],[7,18],[1,30],[-10,28]],c[2],.86)
        p.tri(13,18,25,20,21,29,c[3],.72)
        p.shade(-5,-5,5,5,func(x: float,y: float,o: Dictionary):
            if x*x+y*y>20:
                return
            o["c"]=c[3]
            o["a"]=.7
            o["l"]=c[2]
            o["k"]=.4
        )
        p.glow_line(-15,-7,17,13,5,c[2],.55)
        p.glow_ring(2,1,15,5,c[1],.65)
        var m: Dictionary={"w":3,"h":3,"data":[0,1,0,1,1,1,0,1,0]}
        p.outline(m,-32,-32,c[1])
        p.mask(m,-32,-32,func(x: int,y: int): return c[(x+y)%4])
        p.sprite([".#o","o##"],{"#":"#ffffff","o":"#65b8dd"},22,-32,{"scale":2,"flip":true,"flipY":i==1})
        p.text("FX 21",0,-37,c[3],{"font":"mini","align":"center","outline":c[0],"shadow":c[1]})
        p.text("x!",26,29,c[2],{"font":"big","align":"right"})
        var diff: int=0
        for j in range(p.color.size()):
            if (p.color[j]&0xffffffff)!=int(cases[i]["color"][j]) or (p.light[j]&0xffffffff)!=int(cases[i]["light"][j]):
                diff+=1
        if p.measure("FX 21")!=cases[i]["measure"] or p.get_color(0,0)!=int(cases[i]["read"]):
            diff+=1
        print("Full Painter case ",i,": ",diff," differences")
        bad+=diff
    quit(0 if bad==0 else 1)
