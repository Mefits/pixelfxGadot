extends SceneTree
# A/B harness only. The renderer receives finished world-space geometry.
const Rig = preload("res://lab/anatomy_rd/rig_049.gd")
const Ink = preload("res://lab/ink_051.gd")
const OUT = "res://../docs/body-raster-054/"
const CELL = Vector2i(96, 96)
const ORIGIN = Vector2(40, 66)
var engine
var cases: Array = []
var cfg = {"width":96, "height":96, "origin":[40,66], "density":1,
    "light":[-0.48,-0.64,0.6], "materials":[[0xffe1d7bf,0xffc0aaa0,0xff957b79,0xff585265]]}

class InkPose extends Node2D:
    var points: Dictionary
    var feet: Dictionary
    func _draw():
        Ink.actor(self, points, true, feet)

func _initialize():
    call_deferred("run")

func xyz(p:Vector2, z:float)->Array:
    return [p.x,p.y,z]

func segment(parts:Array, a:Vector2, b:Vector2, z:float, ra:float, rb:float):
    parts.append({"type":"sweep", "part_id":parts.size()+1, "material_id":0,
        "blend_group":1+int(parts.size()/2.0), "a":xyz(a,z), "b":xyz(b,z), "ra":ra, "rb":rb})

func geometry(q:Dictionary)->Array:
    var parts:Array=[]
    for side in ["far","near"]:
        var z:float=-4 if side=="far" else 4
        for limb in [["shoulder_","elbow_","hand_",2.1], ["thigh_","knee_","foot_",2.8]]:
            segment(parts,q[limb[0]+side],q[limb[1]+side],z,limb[3],1.8)
            segment(parts,q[limb[1]+side],q[limb[2]+side],z,1.8,1.3)
    segment(parts,q.hips,q.chest,0,3,3.8)
    segment(parts,q.chest,q.head,0,1.6,1.6)
    parts.append({"type":"ellipsoid","part_id":11,"material_id":0,"center":xyz(q.head,0),
        "basis":[1,0,0,0,1,0,0,0,1],"radii":[3.8,4.3,3.2]})
    return parts

func image_for(result:Dictionary)->Image:
    return Image.create_from_data(result.width,result.height,false,Image.FORMAT_RGBA8,result.rgba)

func capture(clips:Array)->bool:
    var rig=Rig.make()
    for clip in clips:
        var viewport=SubViewport.new()
        viewport.size=Vector2i(CELL.x*clip.samples.size(),CELL.y*3)
        viewport.disable_3d=true
        viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
        root.add_child(viewport)
        for col in clip.samples.size():
            var s=clip.samples[col]
            rig.evaluate(s.pose)
            var q={}
            for id in s.expected_xy:
                q[id]=rig.point(id)
            var parts=geometry(q)
            cases.append(parts)
            var result:Dictionary=engine.render(cfg,parts)
            if not result.get("ok") or result.body_pixels<50:return false
            var a=InkPose.new()
            a.points=q
            a.feet={"foot_far":s.pose.angles.get("foot_pitch_far",0),"foot_near":s.pose.angles.get("foot_pitch_near",0)}
            a.position=Vector2(col*CELL.x,0)+ORIGIN
            viewport.add_child(a)
            var b=Sprite2D.new()
            b.centered=false
            b.position=Vector2(col*CELL.x,CELL.y)
            b.texture=ImageTexture.create_from_image(image_for(result))
            b.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
            viewport.add_child(b)
            var organic_cfg=cfg.duplicate()
            organic_cfg.merge({"mode":"organic","smooth":1.0,"joins":[[0,1],[2,3],[4,5],[6,7]]})
            var joined:Dictionary=engine.render(organic_cfg,parts)
            if not joined.get("ok") or joined.rgba==result.rgba:return false
            var organic=b.duplicate()
            organic.position.y=CELL.y*2
            organic.texture=ImageTexture.create_from_image(image_for(joined))
            viewport.add_child(organic)
        await RenderingServer.frame_post_draw
        var img=viewport.get_texture().get_image()
        if img==null or img.save_png(OUT+clip.clip+".png")!=OK:return false
        viewport.queue_free()
    return true

func stats(values:Array)->Array:
    values.sort()
    var out=[]
    for pct in [.5,.95,.99,1.0]:
        out.append(values[ceili(values.size()*pct)-1])
    return out

func bench(rows:Array, mode:String)->bool:
    cfg.mode=mode
    cfg.smooth=1 if mode=="organic" else 0
    cfg.joins=[[0,1],[2,3],[4,5],[6,7]] if mode=="organic" else []
    for density in [1,2,3]:
        # Fixed rig-space view. Exercise 64/128/192 px targets.
        cfg.merge({"density":density, "width":64*density, "height":64*density,
            "origin":[24*density,54*density]},true)
        for bodies in [1,4,8,16]:
            var textures=[]
            var engines=[]
            for i in bodies:
                engines.append(ClassDB.instantiate("PixelFXBodyRaster"))
                var init:Dictionary=engines[i].render(cfg,cases[0])
                textures.append(ImageTexture.create_from_image(image_for(init)))
            for changing in [false,true]:
                var cpu=[]
                var bridge=[]
                var submit=[]
                var work=[]
                var total=[]
                var growths=0
                var fields=[]
                for rep in range(-24,100):
                    var tc=0.0
                    var tb=0.0
                    var tu=0
                    var tested=0
                    var evaluations=0
                    for i in bodies:
                        var pose=cases[posmod(rep+i,cases.size()) if changing else 0]
                        var t=Time.get_ticks_usec()
                        var result:Dictionary=engines[i].render(cfg,pose)
                        var end=Time.get_ticks_usec()
                        if not result.ok:return false
                        tc+=result.cpu_us
                        tb+=end-t-result.cpu_us
                        var img=image_for(result)
                        var before=Time.get_ticks_usec()
                        textures[i].update(img)
                        tu+=Time.get_ticks_usec()-before
                        tb+=before-end
                        tested+=result.sample_tests
                        evaluations+=result.field_tests
                        if rep>=0:growths+=result.buffer_growths
                    if rep>=0:
                        cpu.append(tc)
                        bridge.append(tb)
                        submit.append(tu)
                        work.append(tested)
                        total.append(tc+tb+tu)
                        fields.append(evaluations)
                    if rep%10==0:await process_frame
                rows.append({"mode":mode,"buffer_growths":growths,"field_tests":stats(fields),"total_us":stats(total),"density":density,"bodies":bodies,"changing":changing,
                    "cpu_us":stats(cpu),"bridge_and_image_us":stats(bridge),
                    "texture_submit_us":stats(submit),"sample_tests":stats(work)})
    return true

func run():
    if not ClassDB.class_exists("PixelFXBodyRaster"):
        push_error("body extension missing")
        quit(1)
        return
    engine=ClassDB.instantiate("PixelFXBodyRaster")
    var p={"type":"sphere","part_id":7,"material_id":0,"center":[0,0,0],"radius":1,"frame_id":8}
    cfg.debug=true
    var result:Dictionary=engine.render(cfg,[p])
    var i=66*96+40
    if not result.get("ok") or result.depth[i]!=1 or result.part[i]!=7 or result.frame[i]!=8 or result.rgba.size()!=96*96*4:
        quit(1)
        return
    for bad in [{"radius":"1"},{"center":[NAN,0,0]},{"material_id":3},{"part_id":0}]:
        var copy=p.duplicate()
        copy.merge(bad,true)
        if engine.render(cfg,[copy]).ok:
            quit(1)
            return
    cfg.debug=false
    var source=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/body_raster/poses.json"))
    var rows=[]
    if not await capture(source.clips) or cases.size()!=18 or not await bench(rows,"reference") or not await bench(rows,"organic"):
        push_error("Body raster capture/benchmark failed")
        quit(1)
        return
    var file=FileAccess.open(OUT+"benchmark.json",FileAccess.WRITE)
    if not file:
        quit(1)
        return
    file.store_string(JSON.stringify(rows,"\t")+"\n")
    print("BODY_RASTER_OK poses=",cases.size()," sheets=3 benchmark_rows=",rows.size(),"")
    quit()
