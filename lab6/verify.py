#!/usr/bin/env python3
"""Exercise real Secret Manager authorization without printing payloads or tokens."""
import secrets
import subprocess
import tempfile
from pathlib import Path

PROJECT = "cloud-platform-engineering-hs"
IDENTITY = f"lab6-workload@{PROJECT}.iam.gserviceaccount.com"


def run(args, payload=None, impersonate=False):
    command = ["gcloud", "--quiet", f"--project={PROJECT}"]
    if impersonate:
        command.append(f"--impersonate-service-account={IDENTITY}")
    return subprocess.run(command + args, input=payload, capture_output=True)


def require_success(result, label):
    if result.returncode:
        raise SystemExit(f"FAIL: {label}; inspect cloud permissions and API status (payloads suppressed).")
    print(f"PASS: {label}")


def require_denial(result, label):
    if result.returncode == 0 or b"PERMISSION_DENIED" not in result.stderr:
        raise SystemExit(f"FAIL: {label}; expected PERMISSION_DENIED (payloads suppressed).")
    print(f"PASS: {label} returned PERMISSION_DENIED")


def main():
    values = {name: secrets.token_hex(32).encode() for name in ("allowed", "denied")}
    for name, value in values.items():
        require_success(run(["secrets", "versions", "add", f"lab6-{name}", "--data-file=-"], value),
                        f"operator created {name} canary version")
    with tempfile.TemporaryDirectory(prefix="lab6-") as private_dir:
        output = Path(private_dir) / "payload"
        result = run(["secrets", "versions", "access", "latest", "--secret=lab6-allowed",
                      f"--out-file={output}"], impersonate=True)
        require_success(result, "workload read allowed secret")
        if output.read_bytes() != values["allowed"]:
            raise SystemExit("FAIL: retrieved payload differs from canary")
    print("PASS: allowed payload matched in memory; value not logged")
    require_denial(run(["secrets", "versions", "access", "latest", "--secret=lab6-denied"], impersonate=True),
                   "workload read of second secret")
    require_denial(run(["secrets", "versions", "add", "lab6-allowed", "--data-file=-"],
                       secrets.token_bytes(32), impersonate=True), "workload write to allowed secret")
    require_denial(run(["secrets", "list"], impersonate=True), "workload project-wide secret listing")


if __name__ == "__main__":
    main()
