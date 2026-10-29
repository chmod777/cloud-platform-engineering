import copy
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("guard", Path(__file__).resolve().parents[1] / "scripts/check-plan.py")
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


def deletion():
    return {"resource_changes": [{"mode": "managed", "address": "google_compute_instance.mgmt_vm[0]", "change": {"actions": ["delete"], "before": {"boot_disk": [{"auto_delete": True}]}}}]}


class PlanGuardTests(unittest.TestCase):
    def test_no_change_allowed_in_both_modes(self):
        for mode in ("start", "stop"):
            guard.check({"resource_changes": []}, mode)

    def test_vm_deletion_allowed(self):
        guard.check(deletion(), "stop")

    def test_network_change_rejected(self):
        p = deletion()
        p["resource_changes"][0]["address"] = "google_compute_network.platform_vpc"
        with self.assertRaises(ValueError):
            guard.check(p, "stop")

    def test_replacement_rejected(self):
        p = deletion()
        p["resource_changes"][0]["change"]["actions"] = ["delete", "create"]
        with self.assertRaises(ValueError):
            guard.check(p, "start")

    def test_retained_disk_rejected(self):
        p = deletion()
        p["resource_changes"][0]["change"]["before"]["boot_disk"][0]["auto_delete"] = False
        with self.assertRaises(ValueError):
            guard.check(p, "stop")

    def test_attached_disk_rejected(self):
        p = deletion()
        p["resource_changes"][0]["change"]["before"]["attached_disk"] = [{"source": "other"}]
        with self.assertRaises(ValueError):
            guard.check(p, "stop")

    def test_partial_plan_rejected(self):
        with self.assertRaises(ValueError):
            guard.check({"complete": False}, "stop")


if __name__ == "__main__":
    unittest.main()
