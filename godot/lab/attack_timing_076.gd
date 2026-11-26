extends RefCounted
## Lab-only monotone source-time warp, in 60Hz tick units.
## Same clip, same authored contact times; no pose holds or skipped simulation ticks.
const WINDOWS=[[10.,20.],[23.,32.],[40.,50.]]
const STRENGTHS=[0.,.10,.18]

static func source_tick(t:float,variant:int)->float:
    var strength:float=STRENGTHS[variant]
    for window in WINDOWS:
        var a:float=window[0]
        var b:float=window[1]
        if t>a and t<b:
            var u:float=(t-a)/(b-a)
            # Delay the middle of preparation; accelerate the latter half.
            # Endpoints and their first derivatives stay unchanged.
            # Max |d(16*u^2*(1-u)^2)/du| = 16*sqrt(3)/9.
            return t-(b-a)*strength*16.*u*u*(1.-u)*(1.-u)
    return t
