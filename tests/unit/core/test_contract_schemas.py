#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
"""Validate contracts and hostile fixtures against draft 2020-12 (no network)."""
import copy
import json
from pathlib import Path
import unittest

from jsonschema import Draft202012Validator

ROOT = Path(__file__).resolve().parents[3]
SCHEMA = json.loads((ROOT / "schemas/dpp-hello-v1.schema.json").read_text())


def validator(name):
    schema = dict(SCHEMA, **{"$ref": f"#/$defs/{name}"})
    return Draft202012Validator(schema)


class Contracts(unittest.TestCase):
    def test_schema_valid(self):
        Draft202012Validator.check_schema(SCHEMA)

    def test_manifest_and_downgrade(self):
        good = {"id": "org.dot.hello", "sha256": "a" * 64,
                "protocol": 1, "profile": "org.dot.hello/v1", "assurance": "audit"}
        v = validator("manifest")
        self.assertTrue(v.is_valid(good))
        for key, value in [("sha256", "bad"), ("protocol", 2),
                           ("profile", "org.dot.general/v1"),
                           ("assurance", "os-enforced"), ("executable", "from-PATH")]:
            self.assertFalse(v.is_valid(dict(good, **{key: value})))

    def test_plan(self):
        absent = {"exists": False, "sha256": "", "mode": 0, "uid": 0, "gid": 0}
        after = dict(absent, exists=True, sha256="b" * 64, mode=384)
        plan = {"version": 1, "root_id": "d" * 64, "nonce": "a" * 64, "plugin_digest": "b" * 64,
                "proposal_id": "c" * 64, "operations": [
                    {"name": "hello.txt", "before": absent, "after": after}]}
        v = validator("plan")
        self.assertTrue(v.is_valid(plan))
        for name in ["../escape", "/absolute", "a/b.txt", "C:\\escape", "hello.txt\n"]:
            bad = copy.deepcopy(plan)
            bad["operations"][0]["name"] = name
            self.assertFalse(v.is_valid(bad), name)
        self.assertFalse(v.is_valid(dict(plan, effects=[{"shell": "touch /tmp/bad"}])))
        self.assertFalse(v.is_valid(dict(plan, operations=[])))

    def test_no_secret_payloads(self):
        ref = {"reference": "secret:provider", "audience": "org.dot.ai",
               "sensitivity": "secret-reference"}
        self.assertTrue(validator("secret_reference").is_valid(ref))
        for field in ["value", "token", "prompt"]:
            self.assertFalse(validator("secret_reference").is_valid(
                dict(ref, **{field: "CANARY_DO_NOT_LOG"})))
        event = {"schema_version": 1, "operation_id": "a" * 64,
                 "kind": "transaction", "state": "PREPARED"}
        self.assertTrue(validator("event").is_valid(event))
        self.assertFalse(validator("event").is_valid(dict(event, message="CANARY_DO_NOT_LOG")))

    def test_rpc_params_are_closed(self):
        request = {"jsonrpc": "2.0", "id": 1, "method": "dot.initialize",
                   "params": {"protocol": 1, "profile": "org.dot.hello/v1",
                              "required_assurance": "audit",
                              "capabilities": ["materialize", "plan", "validate"],
                              "nonce": "a" * 64}}
        self.assertTrue(validator("request").is_valid(request))
        request["params"]["token"] = "CANARY_DO_NOT_LOG"
        self.assertFalse(validator("request").is_valid(request))

    def test_identity_is_closed_and_exact(self):
        identity = {"protocol": 1, "profile": "org.dot.hello/v1", "assurance": "audit",
                    "capabilities": ["materialize", "plan", "validate"],
                    "nonce": "a" * 64, "id": "org.dot.hello"}
        v = validator("identity")
        self.assertTrue(v.is_valid(identity))
        for key, value in [("protocol", 0), ("profile", "org.dot.general/v1"),
                           ("assurance", "none"), ("capabilities", ["plan"]),
                           ("id", "org.dot.other"), ("token", "secret")]:
            self.assertFalse(v.is_valid(dict(identity, **{key: value})))


if __name__ == "__main__":
    unittest.main()
