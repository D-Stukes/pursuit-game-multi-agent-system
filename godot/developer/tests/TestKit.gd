extends SceneTree
## Shared base for headless verify_* suites: PASS/FAIL lines and the totals each
## suite prints in its <NAME>_RESULT line. Frame and input helpers stay in each
## suite because their timing differs on purpose.
var checks: int = 0
var failures: int = 0

func check(label: String, ok: bool, detail: Variant = "") -> void:
	checks += 1
	if not ok: failures += 1
	print("PASS " if ok else "FAIL ", label, " ", detail)
