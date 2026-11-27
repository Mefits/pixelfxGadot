extends RefCounted
## Lab-only scheduler; counts simulation ticks, never queues overlapping attacks.
var enabled:bool=false
var remaining:int=0

func set_enabled(value:bool)->void:
    enabled=value
    remaining=0

func ready_tick(available:bool)->bool:
    if not enabled or not available:return false
    if remaining>0:
        remaining-=1
        return false
    return true

func launched(delay_seconds:float)->void:
    remaining=clampi(roundi(delay_seconds*60.),12,180)
