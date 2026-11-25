"""Independent standard JSON Schema verification of engine-generated fixtures."""
import json
import sys
from pathlib import Path
from jsonschema import Draft202012Validator
schema=json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
Draft202012Validator.check_schema(schema)
validator=Draft202012Validator(schema)
files=sorted(Path(sys.argv[2]).glob("*.json"))
assert len(files)==37, f"Expected 37 builtin fixtures, got {len(files)}"
for f in files:
    validator.validate(json.loads(f.read_text(encoding="utf-8")))
print(f"Standard Draft 2020-12 schema: {len(files)} fixtures valid")
