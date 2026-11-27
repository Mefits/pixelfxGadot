"""Regression runner with explicit markers, logs and same-process/fresh-process checks."""
import hashlib,json,os,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"results"
OUT.mkdir(exist_ok=True)
BASE=[os.environ["GODOT"],"--headless","--path",str(ROOT/"godot"),"--audio-driver","Dummy"]
def run(script,label,args=(),marker=None):
    p=subprocess.run(BASE+["--script","res://"+script]+(["--",*map(str,args)] if args else []),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
    s=p.stdout.decode("utf-8","replace")
    (OUT/(label+".log")).write_text(s,encoding="utf-8")
    print(s,flush=True)
    if p.returncode or "SCRIPT ERROR" in s or "ERROR:" in s or (marker and marker not in s):raise RuntimeError(label+" failed")
    return s
def main():
    run("tests/body_fixture_verify.gd","fixtures")
    astra={}
    for hz in (60,120):
        traces=[]
        for i in range(2):
            s=run("tests/motion_authoring.gd",f"authoring-{hz}-{i}",[hz],"TRACE ")
            traces.append(next(l[6:] for l in s.splitlines() if l.startswith("TRACE ")))
        assert traces[0]==traces[1]
        astra[str(hz)]=traces[0]
    box2d=[]
    for i in range(2):
        folder=OUT/f"backend-{i}"
        folder.mkdir(exist_ok=True)
        run("tests/motionphysics_099d.gd",f"backend-{i}",[folder],"MOTIONPHYSICS_099D_TEST_OK")
        report=json.loads((folder/"qualification.json").read_text())
        (OUT/f"qualification-{i}.json").write_text(json.dumps(report,indent=2))
        assert report["qualified"],report["failures"]
        box2d.append({n:hashlib.sha256(json.dumps([r["state"] for r in json.loads((folder/(n+".json")).read_text())],separators=(",",":")).encode()).hexdigest() for n in ("profileA","profileB","profileC")})
    assert box2d[0]==box2d[1],"Box2D fresh process replay mismatch"
    (OUT/"trace-digests.json").write_text(json.dumps({"astra":astra,"box2d":box2d[0]},indent=2))
    run("tests/lab_integration_100.gd","lab","", "LAB_100_INTEGRATION_OK")
    run("tests/motionphysics_studio.gd","studio-headless",(),"MOTIONPHYSICS_STUDIO_OK")
    run("tests/motion_handoff.gd","motion-handoff",(),"MOTION_HANDOFF_OK")
    print("LAB_BOX2D_CI_OK")
if __name__=="__main__":main()
