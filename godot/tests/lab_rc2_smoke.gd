extends SceneTree
const Original=preload("res://addons/pixelfx/original_runtime.gd")
const Painter=preload("res://addons/pixelfx/native/painter.gd")
func _initialize():call_deferred("run")
func fail(message:String):
    push_error(message)
    quit(1)
func run():
    if not ClassDB.class_exists("PixelFXBodyRaster") or not ClassDB.class_exists("MotionPhysics099D") or not ClassDB.class_exists("PixelFXOriginal"):
        fail("missing native component")
        return
    var r=Original.new()
    if not r.open() or r.entries.size()<200:
        fail("original catalog "+r.error)
        return
    var painter=Painter.new(192,192)
    var id:String="lightning/chain-lightning"
    var h:int=r.create(id,{"x":96,"y":96},"act")
    if h==0:
        fail("original act "+r.error)
        return
    var visible:bool=false
    for i in 12:
        painter.clear()
        if not r.draw(h,painter,"",true) or not r.update(h,1./30.):
            fail("original draw "+r.error)
            return
        for k in painter.rgba_bytes(false):
            if k!=0:visible=true;break
    r.destroy(h)
    if not visible:
        fail("original output blank")
        return
    var editor=load("res://lab/authoring/editor.tscn").instantiate()
    root.add_child(editor)
    await process_frame
    if not editor.raster or not editor.last_image or editor.last_image.get_used_rect().size.x<1:
        fail("workshop body missing")
        return
    print("RC2_SMOKE_OK original_count=",r.entries.size())
    quit()
