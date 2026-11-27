extends SceneTree
const Training=preload("res://lab/training_control.gd")
const Punch=preload("res://lab/training_punch.gd")
const Asset=preload("res://lab/authoring/asset.gd")
var failures:Array=[]
func check(ok:bool,label:String)->void:
    if not ok and not failures.has(label):failures.append(label)
func _initialize():call_deferred("run")
func run():
    var source:Dictionary=Punch.source()
    var docs:Dictionary={}
    for index in 3:
        var doc:Dictionary=Punch.default_doc(Punch.IDS[index])
        docs[index+1]=doc
        check(Asset.problem(doc)=="","valid stage "+str(index))
        check(doc.events[0].anchor==source.events[index].anchor,"source marker")
        check(roundi(doc.events[0].t*60.)+Punch.BOUNDARIES[index]==roundi(source.events[index].t*60.),"source contact time")
        for k in doc.keys:
            var tick:int=roundi(float(k.t)*60.)+Punch.BOUNDARIES[index]
            check(k.angles==source.keys[tick].pose.angles and k.root==source.keys[tick].pose.root,"source pose exact")
    for count in [1,2,3]:
        var f=Training.new(docs)
        for n in count:check(f.press(1),"fresh press")
        for tick in 170:f.step(0)
        check(f.starts.size()==count and f.strikes==count and f.last_chain==count and f.active==0,"exact count "+str(count))
        check(f.walker.action_name()=="walk_breathe","idle after attack")
    var chain=Training.new(docs)
    for n in 3:chain.press(1)
    for tick in range(1,77):
        chain.step(0)
        if tick>=6:
            var expected:Dictionary=source.keys[tick].pose
            for channel in expected.angles:check(absf(float(chain.walker.pose.angles[channel])-float(expected.angles[channel]))<.001,"runtime original angle")
            for axis in 2:check(absf(float(chain.walker.pose.root[axis])-float(expected.root[axis]))<.001,"runtime original root")
    check(chain.starts==[1,2,3] and chain.strikes==3,"three distinct stages")
    var late=Training.new(docs)
    late.press(1)
    for tick in 70:late.step(0)
    late.press(1)
    for tick in 70:late.step(0)
    check(late.starts==[1,1] and late.last_chain==1,"late restart")
    var cap=Training.new(docs)
    for n in 8:cap.press(1)
    for tick in 170:cap.step(0)
    check(cap.starts==[1,2,3] and cap.strikes==3,"bounded buffer")
    check(not cap.press(2) and not cap.press(3),"only one attack key")
    var best:int=0
    var best_x:float=0.
    for distance in range(-5,21):
        var f=Training.new(docs)
        f.walker.x=float(distance)
        for n in 3:f.press(1)
        for tick in 100:f.step(0)
        if f.hits>best:
            best=f.hits
            best_x=distance
    print("COMBO_BAG_MAX ",best," X ",best_x)
    check(best==3,"bag reachable by all original hits")
    var idle=Training.new(docs)
    var initial:Dictionary=idle.walker.pose.duplicate(true)
    for tick in 60:idle.step(0)
    check(idle.walker.action_name()=="walk_breathe" and idle.walker.pose!=initial and idle.walker.x==0.,"animated idle")
    if failures.is_empty():print("TRAINING_CONTROL_OK")
    else:
        for failure in failures:push_error(failure)
    quit(0 if failures.is_empty() else 1)
