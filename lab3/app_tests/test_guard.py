import json
import subprocess
import sys
from pathlib import Path
import pytest

@pytest.mark.parametrize("mode,address,actions,accepted", [
    ("prepare", "google_service_account.runtime", ["create"], True),
    ("clean", "google_service_account.runtime", ["delete"], True),
    ("prepare", "google_compute_network.platform_vpc", ["create"], False),
    ("deploy", "google_cloud_run_v2_service.api[0]", ["delete", "create"], False),
    ("prepare", "google_cloud_run_v2_service.api[0]", ["create"], False),
    ("clean", "google_service_account.runtime", ["create"], False),
])
def test_guard(tmp_path, mode, address, actions, accepted):
    plan = tmp_path / "plan.json"
    plan.write_text(json.dumps({"resource_changes": [{"address": address, "change": {"actions": actions, "after": {"project": "cloud-platform-engineering-hs"}}}]}))
    result = subprocess.run([sys.executable, str(Path(__file__).resolve().parents[1] / "guard.py"), mode, str(plan)], capture_output=True)
    assert (result.returncode == 0) == accepted
