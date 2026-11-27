extends SceneTree
const Training=preload("res://lab/training_control.gd")
const Punch=preload("res://lab/training_punch.gd")
const Asset=preload("res://lab/authoring/asset.gd")
var failures:Array=[]
func check(ok:bool,label:String)->void:
    if not ok:failures.append(label)
func _initialize():call_deferred("run")
func run():
    var docs:Dictionary={}
    for i in 3:
        docs[i+1]=Punch.default_doc(Punch.IDS[i])
        check(Asset.problem(docs[i+1])=="","valid punch "+str(i))
    for key in [1,2,3]:
        var f=Training.new(docs)
        f.press(key)
        for t in 80:f.step(0)
        check(f.starts==[key] and f.strikes==1 and f.active==0,"one press "+str(key))
        check(f.hits==0 and f.misses==1,"distant miss "+str(key))
    var f=Training.new(docs)
    f.press(1)
    check(not f.press(2),"early input rejected")
    for t in 13:f.step(0)
    check(not f.press(3),"wrong sequence rejected")
    check(f.press(2),"second buffered")
    while f.active==1:f.step(0)
    for t in 16:f.step(0)
    check(f.press(3),"third buffered")
    for t in 70:f.step(0)
    check(f.starts==[1,2,3] and f.strikes==3 and f.last_chain==3,"manual combo")
    var late=Training.new(docs)
    late.press(1)
    for t in 50:late.step(0)
    late.press(2)
    for t in 50:late.step(0)
    check(late.last_chain==1 and late.starts==[1,2],"late input standalone")
    for key in [1,2,3]:
        var close=Training.new(docs)
        for t in 60:close.step(1)
        close.press(key)
        for t in 70:close.step(0)
        check(close.hits==1 and close.strikes==1,"bag hit "+str(key))
    if failures.is_empty():print("TRAINING_CONTROL_OK")
    else:
        for failure in failures:push_error(failure)
    quit(0 if failures.is_empty() else 1)
