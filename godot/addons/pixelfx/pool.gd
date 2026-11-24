extends Node2D
## Reusable fixed-capacity offline VFX pool. Prepare clips externally.
const PLAYER=preload("res://addons/pixelfx/player.gd")
@export_range(1,128) var capacity: int=32
var players: Array=[]
var cursor: int=0

func _ready() -> void:
    for _i in range(capacity):
        var p=PLAYER.new()
        add_child(p)
        players.append(p)

func play(clip,at: Vector2,facing: int=1,pixel_scale: float=1.0):
    if clip==null or players.is_empty():
        return null
    var selected: int=cursor
    for offset in range(players.size()):
        var i: int=(cursor+offset)%players.size()
        if not players[i].active:
            selected=i
            break
    cursor=(selected+1)%players.size()
    var p=players[selected]
    p.play_clip(clip,at,facing,pixel_scale)
    return p

func clear_all() -> void:
    for p in players:
        p.stop()

func active_count() -> int:
    var count: int=0
    for p in players:
        if p.active:
            count+=1
    return count
