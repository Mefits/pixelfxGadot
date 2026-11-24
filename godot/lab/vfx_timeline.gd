extends Control
signal seek_requested(time: float)
var preset: Dictionary={}
var time: float=0
var selected: int=0
const COLORS=[Color("#70b6df"),Color("#e1b46b"),Color("#9e92d5"),Color("#8bc1a0")]
func _draw() -> void:
    if preset.is_empty():return
    var end: float=maxf(.5,preload("res://addons/pixelfx/composer/preset.gd").duration(preset))
    var h: float=minf(13.0,(size.y-19)/maxi(1,preset.layers.size()))
    var font: Font=ThemeDB.fallback_font
    for i in range(5):
        var x: float=40+(size.x-44)*i/4.0
        draw_line(Vector2(x,14),Vector2(x,size.y),Color("#405064"),1)
        draw_string(font,Vector2(x-4,11),"%.1f"%(end*i/4),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("#a6b7c9"))
    for i in range(preset.layers.size()):
        var l: Dictionary=preset.layers[i]
        var y: float=17+i*h
        draw_string(font,Vector2(4,y+h-2),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,10)
        var x: float=40+float(l.start)/end*(size.x-44)
        var w: float=float(l.duration)/end*(size.x-44)
        var c: Color=COLORS[i%4] if l.enabled else Color("#45515c")
        draw_rect(Rect2(x,y,maxf(2,w),maxf(2,h-2)),c)
        if i==selected:draw_rect(Rect2(x,y,maxf(2,w),maxf(2,h-2)),Color.WHITE,false,1)
    var x: float=40+clampf(time/end,0,1)*(size.x-44)
    draw_line(Vector2(x,12),Vector2(x,size.y),Color("#ffffff"),1.5)
func _gui_input(e: InputEvent) -> void:
    if (e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT and e.pressed) or (e is InputEventMouseMotion and e.button_mask&MOUSE_BUTTON_MASK_LEFT):
        var end: float=maxf(.5,preload("res://addons/pixelfx/composer/preset.gd").duration(preset))
        seek_requested.emit(clampf((e.position.x-40)/(size.x-44),0,1)*end)
        accept_event()
