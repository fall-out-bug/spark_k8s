#!/usr/bin/env python3
"""
Matrix Generator for Load Testing
Part of WS-013-07: Test Matrix Definition & Template System

Generates all test artifacts (Helm values, scenario scripts, Argo workflows)
from the priority matrix configuration.

Usage:
    python generate-matrix.py --tier p0_smoke
    python generate-matrix.py --tier p1_core --parallel
    python generate-matrix.py --tier p2_full --validate
"""

import argparse
import itertools
import json
import os
import sys
from pathlib import Path
from typing import Any, Dict, List, Tuple

import jinja2
import yaml


# Default paths
SCRIPT_DIR = Path(__file__).parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent.parent.parent
MATRIX_FILE = SCRIPT_DIR.parent / "priority-matrix.yaml"
TEMPLATES_DIR = SCRIPT_DIR.parent / "templates"
OUTPUT_BASE = PROJECT_ROOT / "scripts" / "tests" / "output"


def load_matrix_config(matrix_file: Path) -> Dict[str, Any]:
    """Load the priority matrix configuration."""
    with open(matrix_file) as f:
        return yaml.safe_load(f)


def generate_combinations(tier_config: Dict[str, Any]) -> List[Dict[str, str]]:
    """
    Generate all test combinations for a tier.

    Args:
        tier_config: Tier configuration from matrix

    Returns:
        List of test combination dictionaries
    """
    dimensions = {
        'spark_version': tier_config['spark_versions'],
        'orchestrator': tier_config['orchestrators'],
        'mode': tier_config['modes'],
        'extensions': tier_config['extensions'],
        'operation': tier_config['operations'],
        'data_size': tier_config['data_sizes'],
    }

    combinations = []
    for values in itertools.product(*dimensions.values()):
        combo = dict(zip(dimensions.keys(), values))
        combinations.append(combo)

    return combinations


def generate_test_name(
    tier: str,
    spark_version: str,
    orchestrator: str,
    mode: str,
    extensions: str,
    operation: str,
    data_size: str,
) -> str:
    """Generate standardized test name."""
    # Format: {tier}_{spark_ver}_{orchestrator}_{mode}_{exts}_{op}_{data_size}
    # Clean up version number (remove dots for filename safety)
    spark_ver_clean = spark_version.replace('.', '')
    exts_clean = extensions.replace('+', '-plus-')

    return f"{tier}_{spark_ver_clean}_{orchestrator}_{mode}_{exts_clean}_{operation}_{data_size}"


def generate_helm_values(
    combo: Dict[str, str],
    tier: str,
    env: jinja2.Environment,
    output_dir: Path,
) -> Path:
    """
    Generate Helm values file for a combination.

    Args:
        combo: Test combination dictionary
        tier: Priority tier name
        env: Jinja2 environment
        output_dir: Output directory

    Returns:
        Path to generated file
    """
    template = env.get_template("test-values.jinja2.yaml")

    test_name = generate_test_name(
        tier, combo['spark_version'], combo['orchestrator'],
        combo['mode'], combo['extensions'], combo['operation'], combo['data_size']
    )

    content = template.render(
        spark_ver=combo['spark_version'],
        orchestrator=combo['orchestrator'],
        mode=combo['mode'],
        extensions=combo['extensions'],
        operation=combo['operation'],
        data_size=combo['data_size'],
    )

    output_file = output_dir / f"{test_name}-values.yaml"
    output_file.parent.mkdir(parents=True, exist_ok=True)
    output_file.write_text(content)

    return output_file


def generate_scenario_script(
    combo: Dict[str, str],
    tier: str,
    tier_config: Dict[str, Any],
    env: jinja2.Environment,
    output_dir: Path,
) -> Path:
    """
    Generate bash scenario script for a combination.

    Args:
        combo: Test combination dictionary
        tier: Priority tier name
        tier_config: Tier configuration (for timeout)
        env: Jinja2 environment
        output_dir: Output directory

    Returns:
        Path to generated file
    """
    template = env.get_template("load-scenario.jinja2.sh")

    test_name = generate_test_name(
        tier, combo['spark_version'], combo['orchestrator'],
        combo['mode'], combo['extensions'], combo['operation'], combo['data_size']
    )

    # Calculate timeout based on operation and data size
    base_timeout = tier_config['timeout_minutes'] * 60
    if combo['data_size'] == '11gb':
        timeout_sec = base_timeout * 3
    else:
        timeout_sec = base_timeout

    # Add per-operation multiplier
    operation_multipliers = {
        'read': 1.0,
        'aggregate': 1.5,
        'join': 2.0,
        'window': 1.8,
        'write': 1.3,
    }
    timeout_sec = int(timeout_sec * operation_multipliers.get(combo['operation'], 1.0))

    content = template.render(
        test_name=test_name,
        spark_ver=combo['spark_version'],
        orchestrator=combo['orchestrator'],
        mode=combo['mode'],
        extensions=combo['extensions'],
        operation=combo['operation'],
        data_size=combo['data_size'],
        timeout_sec=timeout_sec,
    )

    output_file = output_dir / f"{test_name}.sh"
    output_file.parent.mkdir(parents=True, exist_ok=True)
    output_file.write_text(content)
    output_file.chmod(0o755)

    return output_file


def generate_workflow(
    tier: str,
    tier_config: Dict[str, Any],
    env: jinja2.Environment,
    output_dir: Path,
) -> Path:
    """
    Generate Argo workflow definition for a tier.

    Args:
        tier: Priority tier name
        tier_config: Tier configuration
        env: Jinja2 environment
        output_dir: Output directory

    Returns:
        Path to generated file
    """
    template = env.get_template("workflow-template.jinja2.yaml")

    content = template.render(
        tier=tier,
        timeout_minutes=tier_config['timeout_minutes'],
        parallelism=min(len(tier_config['spark_versions']) * 2, 10),
        spark_versions=tier_config['spark_versions'],
        orchestrators=tier_config['orchestrators'],
    )

    output_file = output_dir / f"{tier}-workflow.yaml"
    output_file.parent.mkdir(parents=True, exist_ok=True)
    output_file.write_text(content)

    return output_file


def generate_summary(
    tier: str,
    combinations: List[Dict[str, str]],
    artifacts: List[Tuple[str, Path]],
    output_dir: Path,
) -> Path:
    """
    Generate summary of generated artifacts.

    Args:
        tier: Priority tier name
        combinations: List of test combinations
        artifacts: List of (type, path) tuples
        output_dir: Output directory

    Returns:
        Path to summary file
    """
    summary = {
        'tier': tier,
        'total_combinations': len(combinations),
        'combinations': combinations,
        'artifacts': {
            'helm_values': [str(p) for t, p in artifacts if t == 'helm'],
            'scenarios': [str(p) for t, p in artifacts if t == 'scenario'],
            'workflows': [str(p) for t, p in artifacts if t == 'workflow'],
        },
    }

    output_file = output_dir / f"{tier}-summary.json"
    output_file.parent.mkdir(parents=True, exist_ok=True)

    with open(output_file, 'w') as f:
        json.dump(summary, f, indent=2)

    return output_file


def main():
    parser = argparse.ArgumentParser(
        description="Generate test matrix artifacts"
    )
    parser.add_argument(
        '--tier', type=str, required=True,
        choices=['p0_smoke', 'p1_core', 'p2_full'],
        help='Priority tier to generate'
    )
    parser.add_argument(
        '--matrix-file', type=Path,
        default=MATRIX_FILE,
        help='Path to matrix configuration'
    )
    parser.add_argument(
        '--output-dir', type=Path,
        default=OUTPUT_BASE,
        help='Base output directory'
    )
    parser.add_argument(
        '--validate', action='store_true',
        help='Validate matrix configuration before generation'
    )
    parser.add_argument(
        '--parallel', action='store_true',
        help='Use parallel processing for large matrices'
    )

    args = parser.parse_args()

    # Load configuration
    print(f"Loading matrix configuration from {args.matrix_file}")
    config = load_matrix_config(args.matrix_file)

    # Validate if requested
    if args.validate:
        print("Validating matrix configuration...")
        # Import validator
        sys.path.insert(0, str(SCRIPT_DIR / 'generators'))
        from validate_matrix import validate_matrix_config
        errors = validate_matrix_config(config)
        if errors:
            print(f"Validation failed with {len(errors)} errors:")
            for error in errors:
                print(f"  - {error}")
            return 1
        print("Validation passed")

    # Get tier configuration
    tier_config = config['matrix']['priority_tiers'][args.tier]
    print(f"Generating {args.tier} tier (timeout: {tier_config['timeout_minutes']}min)")

    # Generate combinations
    combinations = generate_combinations(tier_config)
    print(f"Generated {len(combinations)} test combinations")

    # Setup Jinja2 environment
    env = jinja2.Environment(
        loader=jinja2.FileSystemLoader(TEMPLATES_DIR),
        trim_blocks=True,
        lstrip_blocks=True,
    )

    # Generate artifacts
    artifacts = []
    print("Generating artifacts...")

    for combo in combinations:
        test_name = generate_test_name(
            args.tier,
            combo['spark_version'], combo['orchestrator'],
            combo['mode'], combo['extensions'], combo['operation'], combo['data_size']
        )

        # Generate Helm values
        helm_file = generate_helm_values(
            combo, args.tier, env,
            args.output_dir / 'helm-values'
        )
        artifacts.append(('helm', helm_file))

        # Generate scenario script
        scenario_file = generate_scenario_script(
            combo, args.tier, tier_config, env,
            args.output_dir / 'scenarios'
        )
        artifacts.append(('scenario', scenario_file))

        print(f"  Generated: {test_name}")

    # Generate workflow
    workflow_file = generate_workflow(
        args.tier, tier_config, env,
        args.output_dir / 'workflows'
    )
    artifacts.append(('workflow', workflow_file))
    print(f"  Generated workflow: {workflow_file.name}")

    # Generate summary
    summary_file = generate_summary(
        args.tier, combinations, artifacts,
        args.output_dir
    )
    print(f"  Generated summary: {summary_file.name}")

    print(f"\nGeneration complete!")
    print(f"  Combinations: {len(combinations)}")
    print(f"  Helm values: {len([a for a, _ in artifacts if a == 'helm'])}")
    print(f"  Scenarios: {len([a for a, _ in artifacts if a == 'scenario'])}")
    print(f"  Workflows: {len([a for a, _ in artifacts if a == 'workflow'])}")
    print(f"  Summary: {summary_file}")

    return 0


if __name__ == '__main__':
    sys.exit(main())
