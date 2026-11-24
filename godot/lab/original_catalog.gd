extends Node2D
const R=preload("res://addons/pixelfx/original_runtime.gd")
const S=preload("res://addons/pixelfx/native/surface.gd")
var runtime=R.new()
var surface
var menu:OptionButton
var status:Label
var mode_button:CheckButton
var entries:Array=[]
var handle:int=0
var selected:int=0
var clock:float=0.0
var fps:float=30.0
var bright:bool=false
var base_position:Vector2
var idle:float=0.0
func _ready() -> void:
    surface=S.new()
    add_child(surface)
    var ui:=CanvasLayer.new()
    add_child(ui)
    menu=OptionButton.new()
    menu.position=Vector2(24,50)
    menu.size=Vector2(390,38)
    ui.add_child(menu)
    mode_button=CheckButton.new()
    mode_button.text="Original choreography"
    mode_button.position=Vector2(434,50)
    ui.add_child(mode_button)
    status=Label.new()
    status.position=Vector2(24,102)
    ui.add_child(status)
    var title:=Label.new()
    title.text="PIXELFX / ORIGINAL JS CATALOG | Space: replay | B: background | Esc: back"
    title.position=Vector2(24,16)
    ui.add_child(title)
    if not runtime.open():
        status.text=runtime.error
        set_process(false)
        return
    entries=runtime.entries
    for e in entries:
        menu.add_item(str(e.id))
    menu.item_selected.connect(_select)
    mode_button.toggled.connect(func(_v:bool):_select(selected))
    var first:int=0
    for i in range(entries.size()):
        if entries[i].id=="lightning/chain-lightning":
            first=i
    menu.select(first)
    _select(first)
func _draw() -> void:
    draw_rect(Rect2(0,0,960,540),Color("#aaa99d") if bright else Color("#121824"))
func _select(i:int) -> void:
    if handle:
        runtime.destroy(handle)
    selected=i
    var e:Dictionary=entries[i]
    var m:Dictionary=e.meta
    var act:bool=mode_button.button_pressed and e.act
    var w:int=int(m.size[0])
    var h:int=int(m.size[1])
    var x:int=int(m.origin[0])
    var y:int=int(m.origin[1])
    if act:
        var b:Dictionary=runtime.bounds(e.id)
        if not b.is_empty():
            w=int(b.x1-b.x0+16)
            h=int(b.y1-b.y0+16)
            x=8-int(b.x0)
            y=8-int(b.y0)
    surface.configure(w,h)
    var zoom:float=minf(5.0,minf(900.0/w,390.0/h))
    if zoom>=1.0:
        zoom=floor(zoom)
    surface.scale=Vector2.ONE*zoom
    base_position=Vector2(480-w*zoom/2,330-h*zoom/2)
    surface.position=base_position
    fps=clampf(float(m.get("fps",30)),1,60)
    handle=runtime.create(e.id,{"x":x,"y":y},"act" if act else "fx")
    clock=1.0/fps
    idle=0
    if handle==0:
        status.text=runtime.error
func _process(delta:float) -> void:
    if handle==0:
        return
    clock+=delta
    if clock<1.0/fps:
        return
    var dt:float=minf(clock,0.1)
    clock=0
    var state:Dictionary=runtime.state(handle)
    if state.is_empty():
        status.text=runtime.backend.last_error()
        return
    if state.done:
        idle+=dt
        if idle>0.3:
            _select(selected)
        return
    var start:int=Time.get_ticks_usec()
    surface.painter.clear()
    if not runtime.draw(handle,surface.painter,"",true):
        status.text=runtime.error
        runtime.destroy(handle)
        handle=0
        return
    surface.present()
    surface.position=base_position+Vector2(float(state.shake[0]),float(state.shake[1]))*surface.scale
    status.text="%d originals | %s | %.2f ms render+upload | t %.2f | %s"%[entries.size(),entries[selected].id,(Time.get_ticks_usec()-start)/1000.0,float(state.t),"hit stop" if state.frozen else ""]
    if not runtime.update(handle,dt):
        status.text=runtime.error
        runtime.destroy(handle)
        handle=0
func _unhandled_input(e:InputEvent) -> void:
    if e is InputEventKey and e.pressed and not e.echo:
        match e.keycode:
            KEY_ESCAPE:get_tree().change_scene_to_file("res://lab/main.tscn")
            KEY_SPACE:
                if not entries.is_empty():
                    _select(selected)
            KEY_B:
                bright=not bright
                queue_redraw()
