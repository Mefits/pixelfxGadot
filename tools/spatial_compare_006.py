import json, pathlib, math
root=pathlib.Path("comparison")
def read(name):
    files=list((root/name).rglob("trace.json"))
    assert len(files)==1, (name, files)
    return json.loads(files[0].read_text())
a,b=read("replay-Linux"),read("replay-Windows")
assert len(a)==len(b)==130
fields=("tick","serial","age","active","fired","leg","yaw","planted","events")
discrete=[]; exact=[]; grid=[]; max_error=0.0
for x,y in zip(a,b):
    if any(x[k]!=y[k] for k in fields): discrete.append(x["tick"])
    if x["exact"]!=y["exact"]: exact.append(x["tick"])
    if x["grid"]!=y["grid"]: grid.append(x["tick"])
    assert len(x["points"])==len(y["points"])
    for p,q in zip(x["points"],y["points"]): max_error=max(max_error,math.dist(p,q))
report={"ticks":len(a),"discrete_mismatch_ticks":discrete,"exact_mismatch_count":len(exact),"grid_mismatch_count":len(grid),"max_joint_xyz_error":max_error,"first_exact_mismatch":exact[0] if exact else None,"first_grid_mismatch":grid[0] if grid else None}
print("SPATIAL_CROSS_OS_006",json.dumps(report))
(root/"cross-os.json").write_text(json.dumps(report,indent=2))
# Exact/grid mismatch is recorded, not hidden or called deterministic.
# Gate only the tested discrete outcomes and a declared spatial tolerance.
assert not discrete and max_error<=0.001, report
