import json, pathlib, subprocess, os, sys
from collections import defaultdict
root=pathlib.Path.cwd()
out=root/"audit-results"
out.mkdir(exist_ok=True)
engine=os.environ["GODOT"]
fields=["schema","hz","tick","gait","speed","stopped","settle","action","age","serial","duration","offsets","slopes","recoil","recoil_velocity","health","anchors","pose","previous","final_pose","paths","style","released","landing","signature"]
summary={}
for hz in (60,120):
    results={}
    for version in ("baseline","candidate","fixed"):
        project=root/version/"godot"
        (project/"tests"/"astra_audit.gd").write_bytes((root/"godot/tests/astra_audit.gd").read_bytes())
        path=out/f"{version}-{hz}.json"
        proc=subprocess.run([engine,"--headless","--path",str(project),"--audio-driver","Dummy","--script","res://tests/astra_audit.gd","--",str(hz),str(path)],stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60)
        log=proc.stdout.decode("utf-8","replace")
        print(version,hz,log,flush=True)
        (out/f"{version}-{hz}.log").write_text(log,encoding="utf-8")
        if proc.returncode or "ERROR:" in log or "SCRIPT ERROR" in log or not path.exists():
            raise RuntimeError(f"{version} {hz} failed")
        results[version]=json.loads(path.read_text(encoding="utf-8"))
    for version in ("candidate","fixed"):
        a,b=results["baseline"],results[version]
        assert len(a)==len(b)
        groups=defaultdict(lambda:{"ticks":0,"raw_equal":0,"semantic_equal":0,"diff_fields":{},"max_delta":{}})
        def delta(x,y):
            if isinstance(x,(float,int)) and isinstance(y,(float,int)) and not isinstance(x,bool) and not isinstance(y,bool):
                return abs(x-y)
            if isinstance(x,list) and isinstance(y,list) and len(x)==len(y):
                return max((delta(i,j) for i,j in zip(x,y)),default=0)
            if isinstance(x,dict) and isinstance(y,dict) and x.keys()==y.keys():
                return max((delta(x[k],y[k]) for k in x),default=0)
            return 0 if x==y else float("inf")
        for x,y in zip(a,b):
            assert (x["scenario"],x["tick"])==(y["scenario"],y["tick"])
            g=groups[x["scenario"]]
            g["ticks"]+=1
            g["raw_equal"]+=x["bytes"]==y["bytes"]
            xx=dict(zip(fields,x["state"])); yy=dict(zip(fields,y["state"]))
            for key in ("events","goals","points"):
                xx[key]=x[key];yy[key]=y[key]
            diffs=[k for k in xx if xx[k]!=yy[k]]
            g["semantic_equal"]+=not diffs
            for k in diffs:
                entry=g["diff_fields"].setdefault(k,{"count":0,"first_tick":x["tick"]})
                entry["count"]+=1
                d=delta(xx[k],yy[k])
                old=g["max_delta"].get(k,0)
                g["max_delta"][k]=max(old,d)
        summary.setdefault(version,{})[str(hz)]=dict(groups)
print("ASTRA_AUDIT_SUMMARY",json.dumps(summary,ensure_ascii=False),flush=True)
(out/"summary.json").write_text(json.dumps(summary,indent=2),encoding="utf-8")
# Do not hide regression behind green CI: semantic discrepancies fail the audit.
if any(g["ticks"]!=g["semantic_equal"] for v in summary["fixed"].values() for g in v.values()):
    sys.exit(1)
