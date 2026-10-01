"""Baseline scan of all installed Hermes skills with SkillSpector (static-only).

Usage: python3 scripts/baseline_scan.py /out/path/baseline.json
Scans every directory containing a SKILL.md under ~/.hermes/skills and
~/.hermes/plugins, 4 workers, writes {skill_path: {score, severity,
recommendation, max_issue_severity, issue_counts, complete}}.
"""
import json
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

BIN = "/home/ubuntu/.local/bin/skillspector"
ROOTS = [
    Path("/home/ubuntu/.hermes/skills"),
    Path("/home/ubuntu/.hermes/plugins"),
]


def skill_dirs(root):
    for p in sorted(root.rglob("SKILL.md")):
        yield p.parent


def scan(d):
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as tf:
        out_path = tf.name
    r = subprocess.run(
        [BIN, "scan", str(d), "--no-llm", "--format", "json", "--output", out_path],
        capture_output=True, text=True, timeout=600,
    )
    try:
        rep = json.loads(Path(out_path).read_text())
    except (json.JSONDecodeError, OSError):
        rep = {}
    finally:
        Path(out_path).unlink(missing_ok=True)
    ra = rep.get("risk_assessment", {})
    counts = {}
    for i in rep.get("issues", []):
        s = i.get("severity", "?")
        counts[s] = counts.get(s, 0) + 1
    return str(d), {
        "score": ra.get("score"),
        "severity": ra.get("severity"),
        "recommendation": ra.get("recommendation"),
        "max_issue_severity": ra.get("max_issue_severity"),
        "issue_counts": counts,
        "complete": rep.get("analysis_completeness", {}).get("is_complete"),
    }


def main():
    out = Path(sys.argv[1])
    dirs = [d for root in ROOTS if root.exists() for d in skill_dirs(root)]
    print(f"scanning {len(dirs)} skills ...", flush=True)
    results = {}
    with ThreadPoolExecutor(max_workers=4) as ex:
        for path, res in ex.map(scan, dirs):
            results[path] = res
            flag = "  <-- REVIEW" if isinstance(res.get("score"), int) and res["score"] >= 40 else ""
            print(f"{path}: {res.get('score')} {res.get('severity')} {res.get('recommendation')}{flag}", flush=True)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(results, indent=2))
    print(f"\nwrote {out}")


main()
