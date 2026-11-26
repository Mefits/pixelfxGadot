extends SceneTree
const Common=preload("res://lab/ragdoll_common_099.gd")
func _initialize():call_deferred("run")
func write_json(path:String,data)->void:
    var f=FileAccess.open(path,FileAccess.WRITE)
    f.store_string(JSON.stringify(data))
    f.close()

func run():
    var args=OS.get_cmdline_user_args()
    if args.size()!=2:
        quit(2)
        return
    var out:String=args[0]
    var mode:String=args[1]
    var m=Common.make_model()
    if mode=="custom":
        Common.export_spec(m,out.path_join("model.txt"))
        var e:Dictionary=Common.event(m)
        var b:Dictionary=m.bodies[e.idx]
        b.v=Vector2(b.v)+Vector2(e.impulse)*float(b.inv)
        b.w=float(b.w)+(Vector2(e.point)-Vector2(b.p)).cross(e.impulse)*float(b.ii)
        var rows:Array=[]
        for step in Common.N*2:
            var begin:int=Time.get_ticks_usec()
            for child in m.bodies:
                if int(child.parent)<0:continue
                var a:Dictionary=m.bodies[child.parent]
                var j:float=Common.control(a,child,step)
                a.w=float(a.w)-j*float(a.ii)
                child.w=float(child.w)+j*float(child.ii)
            m.substep()
            var elapsed:int=Time.get_ticks_usec()-begin
            rows.append({"us":elapsed,"state":Common.state(m)})
        write_json(out.path_join("custom.json"),rows)
    elif mode=="godot":
        await run_godot(m,out)
    else:
        quit(2)
        return
    print("PHYSICS_099_SIM_OK ",mode)
    quit()

func run_godot(m,out:String)->void:
    Engine.physics_ticks_per_second=120
    await physics_frame
    var material=PhysicsMaterial.new()
    material.friction=Common.MU
    material.bounce=0.
    var ground=StaticBody2D.new()
    ground.collision_layer=1
    ground.collision_mask=2
    ground.physics_material_override=material
    ground.position=Vector2(0,m.floor_y+50.)
    var shape=CollisionShape2D.new()
    var rect=RectangleShape2D.new()
    rect.size=Vector2(20000,100)
    shape.shape=rect
    ground.add_child(shape)
    root.add_child(ground)
    var nodes:Array[RigidBody2D]=[]
    for b in m.bodies:
        var body=RigidBody2D.new()
        body.name="Segment_"+String(b.id)
        body.position=b.p
        body.rotation=b.a
        body.collision_layer=2
        body.collision_mask=1
        body.mass=b.mass
        body.inertia=1./float(b.ii)
        body.center_of_mass_mode=RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
        body.center_of_mass=Vector2.ZERO
        body.gravity_scale=Common.G/float(ProjectSettings.get_setting("physics/2d/default_gravity"))
        body.linear_damp_mode=RigidBody2D.DAMP_MODE_REPLACE
        body.angular_damp_mode=RigidBody2D.DAMP_MODE_REPLACE
        body.linear_damp=Common.DAMP
        body.angular_damp=Common.DAMP
        body.physics_material_override=material
        body.can_sleep=false
        for s in b.samples:
            var collider=CollisionShape2D.new()
            var circle=CircleShape2D.new()
            circle.radius=float(s[1])
            collider.shape=circle
            collider.position=Vector2(s[0])-Vector2(b.com)
            body.add_child(collider)
        root.add_child(body)
        nodes.append(body)
    for i in range(1,nodes.size()):
        var b:Dictionary=m.bodies[i]
        var joint=PinJoint2D.new()
        joint.position=m.pivot(b)
        # In 4.4.1 the native limit measures the angle of the world-space
        # line between body origins, not the relative bone rotations.
        # Use native pin anchors + the shared bounded angular stop instead.
        joint.angular_limit_enabled=false
        joint.motor_enabled=false
        root.add_child(joint)
        joint.node_a=joint.get_path_to(nodes[b.parent])
        joint.node_b=joint.get_path_to(nodes[i])
    var e:Dictionary=Common.event(m)
    nodes[e.idx].apply_impulse(e.impulse,Vector2(e.point)-Vector2(m.bodies[e.idx].p))
    var rows:Array=[]
    for step in Common.N*2:
        var begin:int=Time.get_ticks_usec()
        for i in range(1,nodes.size()):
            var b:Dictionary=m.bodies[i]
            var a:Dictionary=m.bodies[b.parent]
            var j:float=Common.control(a,b,step)
            nodes[b.parent].apply_torque_impulse(-j)
            nodes[i].apply_torque_impulse(j)
        var control_us:int=Time.get_ticks_usec()-begin
        var tick:int=Engine.get_physics_frames()
        await physics_frame
        assert(Engine.get_physics_frames()==tick+1,"not one physics step")
        for i in nodes.size():
            var body:RigidBody2D=nodes[i]
            var tr:Transform2D=PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_TRANSFORM)
            var b:Dictionary=m.bodies[i]
            b.p=tr.origin
            b.a=tr.get_rotation()
            b.v=PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY)
            b.w=PhysicsServer2D.body_get_state(body.get_rid(),PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY)
        # Engine monitor is whole physics-process time, not isolated solver time.
        rows.append({"us":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000000.,"control_us":control_us,"state":Common.state(m)})
    write_json(out.path_join("godot.json"),rows)
