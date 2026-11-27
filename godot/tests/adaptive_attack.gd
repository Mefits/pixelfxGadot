extends SceneTree
const Adapt=preload("res://lab/attack_adaptation.gd")
const Training=preload("res://lab/training_control.gd")
const Punch=preload("res://lab/training_punch.gd")
const Walk=preload("res://lab/walk_control.gd")
const Motion=preload("res://lab/walk_motion.gd")
const Asset=preload("res://lab/authoring/asset.gd")
var failures:Array=[]
func check(ok:bool,label:String)->void:
    if not ok and not failures.has(label):failures.append(label)
func _initialize()->void:call_deferred("run")
func run()->void:
    var docs:Dictionary={}
    for i in 3:docs[i+1]=Punch.default_doc(Punch.IDS[i])
    var fingerprint:String=JSON.stringify(docs)
    var source:Dictionary=Punch.source()
    for lead in [0,1]:
        var f=Training.new(docs)
        f.walker.guard_lead=lead
        f.walker.set_intent(f.walker.guard_intent(f.walker.programs.walk_idle,0.))
        var entry:Dictionary=f.walker.pose.duplicate(true)
        var entry_toes:Array=Motion.toes(f.walker.rig,entry)
        for n in 3:f.press(1)
        check(f.binding.lead==lead and f.binding.swapped==(lead==1),"actual starting lead")
        check(Adapt.sample(docs[1],0.,f.walker.rig,f.binding)==entry,"entry exact")
        check(f.binding.prepare_ticks==0,"no stance reset before adaptive attack")
        check(f.binding.planted,"stationary first punch detected")
        var anchors:Array=[]
        for tick in range(1,65):
            if tick in [1,29,39]:anchors.append(f.strike_anchor)
            if tick==29:check(f.binding.planted,"stationary second punch detected")
            f.step(0)
            var toes:Array=Motion.toes(f.walker.rig,f.walker.pose)
            if tick<=38:
                check(Walk.lead_of(toes,lead)==lead,"punch retains actual leading foot")
                for i in 2:check(Vector2(toes[i]).distance_to(entry_toes[i])<.02,"planted toes throughout both punches")
                if (tick>=6 and tick<=28) or tick>=30:
                    var expected:Dictionary=Adapt.mapped_pose(source.keys[tick].pose,f.walker.rig,lead==1)
                    for k in ["shoulder_near","shoulder_far","elbow_near","elbow_far","shoulder_turn","chest","head"]:
                        check(absf(angle_difference(deg_to_rad(float(expected.angles[k])),deg_to_rad(float(f.walker.pose.angles[k]))))<.0001,"punch authored upper body exact")
            elif tick>=44 and tick<=52:
                var expected:Dictionary=Adapt.mapped_pose(source.keys[tick].pose,f.walker.rig,lead==1)
                for k in expected.angles:check(absf(float(expected.angles[k])-float(f.walker.pose.angles[k]))<.001,"kick authored or remapped angles exact")
                for i in 2:check(absf(float(expected.root[i])-float(f.walker.pose.root[i]))<.001,"kick authored root exact")
        check(anchors==(["hand_near","hand_far","foot_far"] if lead==0 else ["hand_far","hand_near","foot_near"]),"strike anchors follow role")
        check(f.active==0 and f.strikes==3 and f.starts==[1,2,3],"three strikes, release on landing")
        for n in 45:f.step(0)
        check(f.walker.guard_lead==1-lead and f.walker.idle_active,"return to new landing guard")
        f=Training.new(docs)
        f.walker.guard_lead=lead
        f.walker.set_intent(f.walker.guard_intent(f.walker.programs.walk_idle,0.))
        # Fixed hand identity must not pull the legs back into canonical stance.
        for hand_role in ["near","far","leading","trailing","auto"]:
            var punch:Dictionary=docs[1].duplicate(true)
            punch.id="future_punch"
            punch.limb_role=hand_role
            var b:Dictionary=Adapt.bind(punch,f.walker.rig,f.walker.pose,lead)
            check(b.planted and b.prepare_ticks==0 and b.target_lead==lead,"independent hand and support role "+hand_role)
            for tick in range(1,29):
                var p:Dictionary=Adapt.sample(punch,float(tick)/60.,f.walker.rig,b)
                var toes:Array=Motion.toes(f.walker.rig,p)
                for i in 2:check(Vector2(toes[i]).distance_to(b.entry_toes[i])<.02,"fixed hand stance stays planted")
        # Future custom ID, all policies, fixed-side mismatch preparation.
        for role in Adapt.ROLES:
            var d:Dictionary=docs[3].duplicate(true)
            d.id="future_kick"
            d.limb_role=role
            check(Asset.problem(d)=="","new attack metadata valid")
            var b:Dictionary=Adapt.bind(d,f.walker.rig,f.walker.pose,lead)
            var expected_anchor:String="foot_far"
            if role=="near" or (role=="leading" and lead==0) or (role in ["trailing","auto"] and lead==1):expected_anchor="foot_near"
            check(b.anchor==expected_anchor,"role "+role+" lead "+str(lead))
            check(b.events[0].t==d.events[0].t and b.events[0].anchor==b.anchor,"remapped event")
            if b.prepare_ticks>0:
                check(Adapt.prepare_pose(f.walker.rig,b,0)==b.entry,"preparation starts exact")
                check(Adapt.prepare_pose(f.walker.rig,b,b.prepare_ticks)==b.start,"preparation ends exact")
        # Explicit far kick from a far-leading guard: preserve the authored
        # physical limb and allow preparation without counting a strike.
        if lead==1:
            var fixed:Dictionary=docs[3].duplicate(true)
            fixed.limb_role="far"
            f.docs[3]=fixed
            f.begin(3,1)
            check(f.strike_anchor=="foot_far" and f.binding.prepare_ticks==Adapt.PREP_TICKS,"fixed far kick")
            var old_strikes:int=f.strikes
            for n in Adapt.PREP_TICKS:f.step(0)
            check(f.age==0 and f.strikes==old_strikes,"no early hit during preparation")
            for n in 38:f.step(0)
            check(f.strikes==old_strikes+1 and f.active==0,"fixed far kick finishes")
    check(JSON.stringify(docs)==fingerprint,"documents immutable")
    if failures.is_empty():print("ADAPTIVE_ATTACK_OK")
    else:
        for failure in failures:push_error(failure)
    quit(0 if failures.is_empty() else 1)
