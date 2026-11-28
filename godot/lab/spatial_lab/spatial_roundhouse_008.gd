extends "res://lab/spatial_lab/spatial_roundhouse_007.gd"
## All candidates keep C's pelvis yaw and source timing. Each adds one
## coordination layer. Rotations operate on complete subtrees, not points
## in isolation. No new gameplay contacts or native render primitives.
var coordination:int=0
var frozen_coordination:int=0

func begin(isolated,initial_yaw:int=0)->bool:
    if active:return false
    profile=2
    frozen_coordination=clampi(coordination,0,3)
    return super.begin(isolated,initial_yaw)

func rotate_chain(root:String,pivot:Vector3,rotation:Basis)->void:
    for id in desired.ids_in_order():
        var cursor:String=id
        while not cursor.is_empty() and cursor!=root:
            cursor=desired.parent_id(cursor)
        if cursor!=root:continue
        desired.joint_xyz[id]=pivot+rotation*(desired.point3(id)-pivot)
        desired.joint_basis[id]=rotation*Basis(desired.joint_basis[id])

func evaluate_target(authored:Dictionary,yaw:int,next:int)->void:
    super.evaluate_target(authored,yaw,next)
    if frozen_coordination==0:return
    var t:float=Tuning.source_tick(next,tuning,true)
    var side:String=Support.SIDES[striking]
    # During preparation, striking-side arm opens; opposite arm protects.
    # Through the strike the elbows lead a shorter counter-swing, then
    # gather into the original receiving guard. Angles are local deltas,
    # not absolute hand targets, so authored source length is retained.
    var frame:Basis=FK.yaw_basis(yaw)
    if frozen_coordination>=2:
        # Lean away from the outgoing leg, unwind through recovery.
        # Pivot the upper body around hips, leaving the leg targets intact.
        var lean:float=sample_keys([[0.,0.],[5.,0.],[10.,-7.],[13.,-13.],[17.,-10.],[22.,5.],[29.,3.],[36.,0.]],t)
        var roll:float=sample_keys([[0.,0.],[9.,5.],[13.,8.],[18.,-5.],[26.,-3.],[36.,0.]],t)
        var rotation:Basis=frame*Basis(Vector3.BACK,deg_to_rad(lean))*Basis(Vector3.RIGHT,deg_to_rad(roll*direction))*frame.inverse()
        rotate_chain("chest",desired.point3("hips"),rotation)
    for s in Support.SIDES:
        var lead:bool=s==side
        var upper:float=sample_keys([[0.,0.],[5.,0.],[10.,-24.],[13.,18.],[17.,32.],[22.,-12.],[29.,-5.],[36.,0.]],t) if lead else sample_keys([[0.,0.],[5.,0.],[10.,18.],[13.,-16.],[17.,-28.],[22.,10.],[29.,6.],[36.,0.]],t)
        var elbow:float=sample_keys([[0.,0.],[10.,16.],[13.,-21.],[17.,-12.],[23.,22.],[30.,7.],[36.,0.]],t) if lead else sample_keys([[0.,0.],[10.,-10.],[13.,14.],[17.,20.],[23.,-8.],[30.,-4.],[36.,0.]],t)
        var sweep:float=sample_keys([[0.,0.],[9.,-18.],[13.,24.],[18.,32.],[25.,-10.],[36.,0.]],t)*(1. if lead else -.65)
        var shoulder_id:String="shoulder_"+s
        var elbow_id:String="elbow_"+s
        var shoulder_basis:Basis=desired.joint_basis[shoulder_id]
        var upper_rotation:Basis=frame*Basis(Vector3.UP,deg_to_rad(sweep*direction))*frame.inverse()*shoulder_basis*Basis(Vector3.BACK,deg_to_rad(upper))*shoulder_basis.inverse()
        rotate_chain(shoulder_id,desired.point3(shoulder_id),upper_rotation)
        var elbow_basis:Basis=desired.joint_basis[elbow_id]
        rotate_chain(elbow_id,desired.point3(elbow_id),elbow_basis*Basis(Vector3.BACK,deg_to_rad(elbow))*elbow_basis.inverse())
    Entry.update_xy(desired)

func adjust_supported_target(next:int)->void:
    super.adjust_supported_target(next)
    if frozen_coordination<3:return
    var t:float=Tuning.source_tick(next,tuning,true)
    var towards:Vector3=anchor_xyz-desired.point3("hips")
    towards.y=0.
    var transfer:float=sample_keys([[0.,0.],[5.,0.],[9.,.7],[12.,1.],[16.,.75],[23.,.4],[30.,.1],[36.,0.]],t)
    # Small compression during loading, slight extension at strike, then
    # compression on recovery. Bounded to ~1 rig unit to avoid overstretch.
    var compress:float=sample_keys([[0.,0.],[7.,.65],[10.,.8],[13.,-.45],[17.,-.1],[25.,.65],[30.,.4],[36.,0.]],t)
    var shift:Vector3=towards.normalized()*minf(towards.length()*.12,1.)*transfer+Vector3(0.,compress,0.)
    for id in desired.ids_in_order():desired.joint_xyz[id]=desired.point3(id)+shift
    Entry.update_xy(desired)

func checkpoint()->Dictionary:
    var state:Dictionary=super.checkpoint()
    state["coordination"]=coordination
    state["frozen_coordination"]=frozen_coordination
    return state

func load_checkpoint(s:Dictionary)->void:
    super.load_checkpoint(s)
    coordination=int(s.get("coordination",0))
    frozen_coordination=int(s.get("frozen_coordination",0))
