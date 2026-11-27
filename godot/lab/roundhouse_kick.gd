extends "res://lab/sparse_kick.gd"
## Independent L attack, sharing the exact K receiver and MotionEntry.
const RoundKeys=preload("res://lab/roundhouse_kick_poses.gd")
const ROUND_CHAMBER:int=10
const ROUND_HIT:int=13
const ROUND_RETRACT:int=26
const ROUND_END:int=36

func _init()->void:
    chamber_tick=ROUND_CHAMBER
    hit_tick=ROUND_HIT
    retract_tick=ROUND_RETRACT
    end_tick=ROUND_END
    tuning=Tuning.defaults(true)

func is_roundhouse()->bool:return true

func sample_key(tick:int)->Dictionary:
    return Tuning.shape_key(RoundKeys.sample(authored_tick(tick),float(tuning.acceleration_scale)),tuning)

func contact_end()->int:
    return mini(end_tick,hit_tick+maxi(1,roundi(3.*float(tuning.return_ticks)/13.)))

func phase_name()->String:
    if age<chamber_tick:return "Скручивание / подъём колена"
    if age<=hit_tick:return "Круговой выброс"
    if authored_tick(age)<=18.:return "Продолжение дуги"
    if age<=retract_tick:return "Сборка ноги"
    return "Восстановление"

# Distal shin, not the toe or heel. Use the actual solved segment, and
# the same point in the swept-contact query on every tick.
func strike_tip(w)->Vector2:
    var s:String=side(striking)
    var knee:Vector2=w.rig.point("knee_"+s)
    var ankle:Vector2=w.rig.point("foot_"+s)
    return knee.lerp(ankle,.9)+Vector2.RIGHT*w.x
