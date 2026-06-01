import importlib.machinery
import importlib.util
import json
import subprocess
import sys
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
KAUDIT_PATH = REPO_ROOT / "overlay" / ".omx" / "kernel-audit" / "bin" / "kaudit"


def load_kaudit():
    loader = importlib.machinery.SourceFileLoader("kaudit_under_test", str(KAUDIT_PATH))
    spec = importlib.util.spec_from_loader(loader.name, loader)
    if spec is None:
        raise RuntimeError("could not create kaudit module spec")
    module = importlib.util.module_from_spec(spec)
    sys.modules[loader.name] = module
    loader.exec_module(module)
    return module


class KauditContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.kaudit = load_kaudit()

    def test_top_level_subcommands_are_unique(self):
        parser = self.kaudit.build_parser()
        subparsers = next(action for action in parser._actions if getattr(action, "choices", None))
        names = [choice.dest for choice in subparsers._choices_actions]
        self.assertEqual(sorted(names), sorted(set(names)))

    def test_repro_cycle_parser_exposes_runtime_contract(self):
        args = self.kaudit.build_parser().parse_args(
            [
                "repro-cycle",
                "--target",
                "kctf",
                "--jobs",
                "7",
                "--repro-workers",
                "4",
                "--no-auto-public-report",
            ]
        )

        self.assertEqual(args.command, "repro-cycle")
        self.assertEqual(args.target, "kctf")
        self.assertEqual(args.jobs, 7)
        self.assertEqual(args.repro_workers, 4)
        self.assertFalse(args.auto_public_report)

    def test_team_preflight_uses_real_entrypoint_and_target(self):
        ctx = self.kaudit.KernelAuditContext(Path("/kernel"), "net")
        task = self.kaudit.team_preflight_task(ctx, jobs=8, target="net")

        self.assertIn("./.omx/kernel-audit/bin/kaudit refresh --target net --syzbot --cve", task)
        self.assertIn("./.omx/kernel-audit/bin/kaudit build init --target net --jobs 8", task)
        self.assertIn("./.omx/kernel-audit/bin/kaudit status --target net", task)
        self.assertNotIn("./.omx/kernel-audit/bin/kernel-audit", task)

    def test_common_worker_contract_fails_closed(self):
        contract = self.kaudit.worker_common_contract("verify")

        self.assertIn("Base every claim on repository source", contract)
        self.assertIn("Fail closed", contract)
        self.assertIn("use reject or manual_only instead of repro_ready", contract)
        self.assertIn("Return JSON matching the provided schema only", contract)

    def test_overlay_json_templates_parse(self):
        template_dir = REPO_ROOT / "overlay" / ".omx" / "kernel-audit" / "templates"
        for path in sorted(template_dir.glob("*.json")):
            with self.subTest(path=path.name):
                json.loads(path.read_text(encoding="utf-8"))

    def test_help_surface_is_usable(self):
        result = subprocess.run(
            [str(KAUDIT_PATH), "--help"],
            cwd=str(REPO_ROOT),
            text=True,
            capture_output=True,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr or result.stdout)
        self.assertIn("orchestrate", result.stdout)
        self.assertIn("repro-cycle", result.stdout)


if __name__ == "__main__":
    unittest.main()
