#!/usr/bin/env python3
"""Verify effective project permissions without attempting resource mutations."""
import json
import os
import urllib.request

read = "resourcemanager.projects.get"
writes = {
    "run.services.create",
    "artifactregistry.repositories.create",
    "iam.serviceAccounts.create",
    "resourcemanager.projects.setIamPolicy",
    "secretmanager.versions.access",
}
request = urllib.request.Request(
    "https://cloudresourcemanager.googleapis.com/v1/projects/cloud-platform-engineering-hs:testIamPermissions",
    data=json.dumps({"permissions": sorted(writes | {read})}).encode(),
    headers={"Authorization": "Bearer " + os.environ["OAUTH_ACCESS_TOKEN"],
             "Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(request, timeout=30) as response:
    granted = set(json.load(response).get("permissions", []))
if read not in granted or granted & writes:
    raise SystemExit("FAIL: CI identity's effective project permissions differ from the plan-only boundary.")
print("PASS: project metadata read allowed; tested infrastructure writes, project IAM writes and secret payload access denied.")
