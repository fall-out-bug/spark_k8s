#!/usr/bin/env python3
import os
import sys

import yaml
from run_matrix_steps import run_scenario
from run_matrix_support import ensure_shared_infra_ready, matches_filters, parse_filters, scenario_plan


def main():
    matrix_file, filter_str, levels_arg, results_dir, project_root, dry_arg, shared_arg = sys.argv[1:8]
    with open(matrix_file) as fh:
        scenarios = yaml.safe_load(fh).get("scenarios", [])
    levels = levels_arg.split()
    dry_run = dry_arg == "1"
    shared_infra = shared_arg == "1"
    shared_infra_ns = os.environ.get("SHARED_INFRA_NS", "spark-infra")
    allow_shared_with_demo = os.environ.get("MATRIX_ALLOW_DEMO_INFRA", "0") == "1"
    shared_infra_values = os.path.join(project_root, "tests", "shared-infra-values.yaml")
    filters = parse_filters(filter_str)
    filtered = [scenario for scenario in scenarios if matches_filters(scenario, filters)]
    if not filtered:
        print("No scenarios match filter", file=sys.stderr)
        sys.exit(1)
    ensure_shared_infra_ready(project_root, dry_run, shared_infra, shared_infra_ns, allow_shared_with_demo)
    print(f"Running {len(filtered)} scenarios: {', '.join(levels)}", flush=True)
    any_failed = False
    for idx, scenario in enumerate(filtered, 1):
        chart, helm_args, img_tag, deploy_mode = scenario_plan(
            scenario,
            project_root,
            shared_infra,
            shared_infra_values,
            shared_infra_ns,
        )
        any_failed = (
            run_scenario(
                idx,
                len(filtered),
                scenario,
                levels,
                results_dir,
                project_root,
                dry_run,
                shared_infra,
                shared_infra_ns,
                chart,
                helm_args,
                img_tag,
                deploy_mode,
            )
            or any_failed
        )
    if any_failed:
        sys.exit(1)


if __name__ == "__main__":
    main()
