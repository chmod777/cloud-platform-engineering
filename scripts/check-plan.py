#!/usr/bin/env python3
"""Reject every managed change except the expected VM creation/deletion."""
import json
import sys


def check(plan, mode):
    if plan.get("errored") or plan.get("complete") is False or plan.get("deferred_changes"):
        raise ValueError("Plan incomplet ou en erreur")
    expected = ["create"] if mode == "start" else ["delete"]
    for change in plan.get("resource_changes", []):
        actions = change["change"]["actions"]
        if actions == ["no-op"]:
            continue
        if (change.get("mode") != "managed" or
            change["address"] != "google_compute_instance.mgmt_vm[0]" or
            actions != expected):
            raise ValueError("Changement interdit : " + change["address"] + " " + str(actions))
        if mode == "stop":
            before = change["change"]["before"]
            if (len(before.get("boot_disk", [])) != 1 or
                before["boot_disk"][0].get("auto_delete") is not True or
                before.get("attached_disk")):
                raise ValueError("Suppression refusée : risque de disque conservé")
        if mode == "start":
            vm = change["change"]["after"]
            nic = vm["network_interface"]
            disk = vm["boot_disk"][0]
            if (vm.get("project") != "cloud-platform-engineering-hs" or
                vm.get("name") != "vm-mgmt-01" or
                vm.get("zone") != "europe-west1-b" or
                vm.get("machine_type") != "e2-micro" or
                len(nic) != 1 or nic[0].get("access_config") or
                nic[0].get("subnetwork") != "projects/cloud-platform-engineering-hs/regions/europe-west1/subnetworks/mgmt-subnet-be" or
                disk.get("auto_delete") is not True or
                disk["initialize_params"][0].get("size") != 10 or
                disk["initialize_params"][0].get("type") != "pd-standard"):
                raise ValueError("Configuration VM hors du périmètre autorisé")


if __name__ == "__main__":
    try:
        if sys.argv[1] not in ("start", "stop"):
            raise ValueError("Mode invalide")
        with open(sys.argv[2]) as source:
            check(json.load(source), sys.argv[1])
    except (ValueError, KeyError, IndexError, TypeError) as error:
        sys.exit("Plan refusé : " + str(error))
