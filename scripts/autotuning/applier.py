"""Helm values generator for Spark autotuning.

Converts recommendations to Helm values overlay files.

Usage:
    python -m autotuning.applier --recommendations-file recs.json --output values.yaml
"""

from __future__ import annotations

import argparse
import json
import logging
import re
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any

import yaml

from autotuning.recommender import Recommendation, RecommendationSet

logger = logging.getLogger(__name__)

# Mapping from Spark config parameters to Helm values paths
RECOMMENDATION_TO_HELM = {
    # Executor resources
    "spark.executor.memory": "connect.executor.memory",
    "spark.executor.memoryOverhead": "connect.executor.memoryOverhead",
    "spark.executor.cores": "connect.executor.cores",
    "spark.executor.instances": "connect.replicas",

    # Spark SQL config
    "spark.sql.shuffle.partitions": "connect.sparkConf.spark.sql.shuffle.partitions",
    "spark.sql.autoBroadcastJoinThreshold": "connect.sparkConf.spark.sql.autoBroadcastJoinThreshold",
    "spark.sql.adaptive.advisoryPartitionSizeInBytes": "connect.sparkConf.spark.sql.adaptive.advisoryPartitionSizeInBytes",

    # Memory config
    "spark.memory.fraction": "connect.sparkConf.spark.memory.fraction",
    "spark.memory.storageFraction": "connect.sparkConf.spark.memory.storageFraction",

    # Adaptive Query Execution
    "spark.sql.adaptive.enabled": "connect.sparkConf.spark.sql.adaptive.enabled",
    "spark.sql.adaptive.coalescePartitions.enabled": "connect.sparkConf.spark.sql.adaptive.coalescePartitions.enabled",
    "spark.sql.adaptive.coalescePartitions.minPartitionSize": "connect.sparkConf.spark.sql.adaptive.coalescePartitions.minPartitionSize",
    "spark.sql.adaptive.skewJoin.enabled": "connect.sparkConf.spark.sql.adaptive.skewJoin.enabled",
    "spark.sql.adaptive.skewJoin.skewedPartitionFactor": "connect.sparkConf.spark.sql.adaptive.skewJoin.skewedPartitionFactor",
    "spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes": "connect.sparkConf.spark.sql.adaptive.skewJoin.skewedPartitionThresholdInBytes",
    "spark.sql.adaptive.localShuffleReader.enabled": "connect.sparkConf.spark.sql.adaptive.localShuffleReader.enabled",

    # Driver config
    "spark.driver.memory": "connect.driver.memory",
    "spark.driver.maxResultSize": "connect.sparkConf.spark.driver.maxResultSize",

    # Other
    "spark.sql.execution.arrow.pyspark.enabled": "connect.sparkConf.spark.sql.execution.arrow.pyspark.enabled",
}


def get_helm_path(spark_param: str) -> str:
    """Get Helm values path for a Spark config parameter.

    Args:
        spark_param: Spark configuration parameter name.

    Returns:
        Helm values path (dot-separated).
    """
    if spark_param in RECOMMENDATION_TO_HELM:
        return RECOMMENDATION_TO_HELM[spark_param]

    # Default: put in sparkConf
    return f"connect.sparkConf.{spark_param}"


@dataclass
class ValidationResult:
    """Result of Helm values validation."""

    valid: bool = True
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    def add_error(self, message: str) -> None:
        """Add validation error."""
        self.errors.append(message)
        self.valid = False

    def add_warning(self, message: str) -> None:
        """Add validation warning."""
        self.warnings.append(message)


def validate_helm_values(values_path: Path) -> ValidationResult:
    """Validate generated Helm values file.

    Args:
        values_path: Path to values YAML file.

    Returns:
        ValidationResult with errors and warnings.
    """
    result = ValidationResult()
    values_path = Path(values_path)

    if not values_path.exists():
        result.add_error(f"File not found: {values_path}")
        return result

    try:
        with open(values_path) as f:
            values = yaml.safe_load(f)
    except yaml.YAMLError as e:
        result.add_error(f"YAML syntax error: {e}")
        return result

    if values is None:
        result.add_warning("Empty values file")
        return result

    # Check for connect section
    if "connect" not in values:
        result.add_warning("Missing 'connect' section - may not work with spark chart")

    # Validate memory format
    memory = values.get("connect", {}).get("executor", {}).get("memory", "")
    if memory and not re.match(r"^\d+[GMK]i$", str(memory)):
        result.add_error(f"Invalid memory format: {memory} (expected: 4Gi, 512Mi)")

    # Validate cores is numeric
    cores = values.get("connect", {}).get("executor", {}).get("cores")
    if cores is not None:
        try:
            int(cores)
        except (ValueError, TypeError):
            result.add_error(f"Invalid cores value: {cores} (expected: integer)")

    return result


def load_recommendations(rec_file: Path) -> RecommendationSet:
    """Load recommendations from JSON file.

    Args:
        rec_file: Path to recommendations JSON.

    Returns:
        RecommendationSet object.

    Raises:
        FileNotFoundError: If file doesn't exist.
    """
    rec_file = Path(rec_file)
    if not rec_file.exists():
        raise FileNotFoundError(f"Recommendations file not found: {rec_file}")

    with open(rec_file) as f:
        data = json.load(f)

    recommendations = [
        Recommendation(
            parameter=r["parameter"],
            current_value=r["current_value"],
            recommended_value=r["recommended_value"],
            change_pct=r["change_pct"],
            confidence=r["confidence"],
            rationale=r.get("rationale", ""),
            safety_check=r.get("safety_check", "pass"),
            source=r.get("source", ""),
        )
        for r in data.get("recommendations", [])
    ]

    return RecommendationSet(
        app_id=data.get("app_id", "unknown"),
        workload_type=data.get("workload_type", "etl_batch"),
        recommendations=recommendations,
        overall_confidence=data.get("overall_confidence", 0.5),
        safety_issues=data.get("safety_issues", []),
        generated_at=(
            datetime.fromisoformat(data["generated_at"])
            if "generated_at" in data
            else datetime.now()
        ),
        base_config=data.get("base_config", {}),
    )


class HelmValuesGenerator:
    """Generates Helm values files from recommendations."""

    def __init__(self):
        """Initialize generator."""
        pass

    def generate_overlay(self, rec_set: RecommendationSet) -> str:
        """Generate Helm values overlay YAML.

        Args:
            rec_set: RecommendationSet with recommendations.

        Returns:
            YAML string with Helm values.
        """
        # Build nested dict from recommendations
        values = self._build_values_dict(rec_set)

        # Add metadata
        values["autotuning"] = {
            "generatedAt": rec_set.generated_at.isoformat(),
            "appId": rec_set.app_id,
            "confidence": round(rec_set.overall_confidence, 2),
            "workloadType": rec_set.workload_type,
            "recommendationCount": len(rec_set.recommendations),
        }

        # Generate YAML with header
        header = self._generate_header(rec_set)
        yaml_content = yaml.dump(
            values,
            default_flow_style=False,
            sort_keys=False,
            allow_unicode=True,
        )

        return header + yaml_content

    def _build_values_dict(self, rec_set: RecommendationSet) -> dict[str, Any]:
        """Build nested values dict from recommendations."""
        values: dict[str, Any] = {}

        # Add base config from profile
        if rec_set.base_config:
            for param, value in rec_set.base_config.items():
                self._set_nested_value(
                    values, get_helm_path(param), str(value)
                )

        # Add recommendations
        for rec in rec_set.recommendations:
            helm_path = get_helm_path(rec.parameter)
            value = self._format_value(rec.recommended_value, rec.parameter)
            self._set_nested_value(values, helm_path, value)

        return values

    def _format_value(self, value: str, param: str) -> Any:
        """Format value appropriately for parameter type."""
        # Memory values - keep as string with suffix
        if any(x in param.lower() for x in ["memory", "size", "threshold"]):
            if re.match(r"^\d+[GMK]i$", str(value)):
                return str(value)
            if re.match(r"^\d+$", str(value)):
                # Convert bytes to human readable
                num = int(value)
                if num >= 1073741824:
                    return f"{num // 1073741824}Gi"
                elif num >= 1048576:
                    return f"{num // 1048576}Mi"
                return str(value)

        # Boolean values
        if str(value).lower() in ("true", "false"):
            return str(value).lower() == "true"

        # Numeric values
        try:
            if "." in str(value):
                return float(value)
            return int(value)
        except ValueError:
            return str(value)

    def _set_nested_value(
        self, values: dict[str, Any], path: str, value: Any
    ) -> None:
        """Set a value in nested dict using dot-separated path.

        Special handling for sparkConf: the spark config parameter name
        (which contains dots) is used as a single key, not split.
        """
        # Special case: sparkConf parameters have dots in the key name
        if "sparkConf." in path:
            # Split only up to sparkConf, rest is the Spark parameter name
            parts = path.split("sparkConf.")
            prefix = parts[0][:-1] if parts[0].endswith(".") else parts[0]  # Remove trailing dot
            spark_param = parts[1]  # The full Spark parameter name with dots

            # Navigate to the sparkConf dict
            if prefix:
                keys = prefix.split(".")
                current = values
                for key in keys:
                    if key not in current:
                        current[key] = {}
                    current = current[key]
            else:
                current = values

            # Ensure sparkConf exists
            if "sparkConf" not in current:
                current["sparkConf"] = {}

            # Set with full Spark parameter name as key
            current["sparkConf"][spark_param] = value
        else:
            # Normal nested path
            keys = path.split(".")
            current = values

            for key in keys[:-1]:
                if key not in current:
                    current[key] = {}
                current = current[key]

            current[keys[-1]] = value

    def _generate_header(self, rec_set: RecommendationSet) -> str:
        """Generate YAML header with comments."""
        lines = [
            "# Generated by spark-autotuner v0.3.0",
            f"# App ID: {rec_set.app_id}",
            f"# Workload Type: {rec_set.workload_type}",
            f"# Confidence: {rec_set.overall_confidence:.0%}",
            f"# Generated At: {rec_set.generated_at.isoformat()}",
            "",
            f"# Recommendations ({len(rec_set.recommendations)} changes)",
        ]

        for rec in rec_set.recommendations:
            change = f"+{rec.change_pct:.0f}%" if rec.change_pct > 0 else f"{rec.change_pct:.0f}%"
            lines.append(f"#   {rec.parameter}: {rec.current_value} -> {rec.recommended_value} ({change})")

        lines.append("")
        return "\n".join(lines)

    def save_overlay(
        self,
        rec_set: RecommendationSet,
        output_path: Path,
    ) -> ValidationResult:
        """Generate and save overlay to file.

        Args:
            rec_set: RecommendationSet with recommendations.
            output_path: Path to save YAML file.

        Returns:
            ValidationResult after saving.
        """
        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)

        yaml_content = self.generate_overlay(rec_set)
        output_path.write_text(yaml_content)

        logger.info(f"Saved Helm values overlay to {output_path}")

        return validate_helm_values(output_path)

    def generate_from_file(
        self,
        rec_file: Path,
        output_path: Path,
    ) -> ValidationResult:
        """Load recommendations and generate overlay.

        Args:
            rec_file: Path to recommendations JSON.
            output_path: Path to save YAML file.

        Returns:
            ValidationResult after saving.
        """
        rec_set = load_recommendations(rec_file)
        return self.save_overlay(rec_set, output_path)


def generate_helm_overlay(
    recommendations_file: Path,
    output_path: Path | None = None,
) -> str:
    """Generate Helm values overlay from recommendations file.

    Args:
        recommendations_file: Path to recommendations JSON.
        output_path: Optional path to save YAML.

    Returns:
        YAML string content.
    """
    rec_set = load_recommendations(recommendations_file)
    generator = HelmValuesGenerator()
    yaml_content = generator.generate_overlay(rec_set)

    if output_path:
        output_path = Path(output_path)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(yaml_content)
        logger.info(f"Saved overlay to {output_path}")

    return yaml_content


def apply_recommendations(
    recommendations_file: Path,
    output_path: Path,
    validate: bool = True,
) -> ValidationResult:
    """Apply recommendations and generate Helm values.

    Args:
        recommendations_file: Path to recommendations JSON.
        output_path: Path to save YAML file.
        validate: Whether to validate output.

    Returns:
        ValidationResult.
    """
    generator = HelmValuesGenerator()
    result = generator.generate_from_file(recommendations_file, output_path)

    if validate and not result.valid:
        logger.warning(f"Validation issues: {result.errors}")

    return result


def main():
    """CLI entry point."""
    parser = argparse.ArgumentParser(
        description="Generate Helm values from autotuning recommendations"
    )
    parser.add_argument(
        "--recommendations-file", "-r",
        required=True,
        type=Path,
        help="Path to recommendations JSON from recommender",
    )
    parser.add_argument(
        "--output", "-o",
        required=True,
        type=Path,
        help="Output path for Helm values YAML",
    )
    parser.add_argument(
        "--validate",
        action="store_true",
        default=True,
        help="Validate generated values (default: True)",
    )
    parser.add_argument(
        "--no-validate",
        action="store_true",
        help="Skip validation",
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Enable verbose logging",
    )

    args = parser.parse_args()

    # Configure logging
    logging.basicConfig(
        level=logging.DEBUG if args.verbose else logging.INFO,
        format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    )

    # Generate values
    validate = not args.no_validate
    result = apply_recommendations(
        recommendations_file=args.recommendations_file,
        output_path=args.output,
        validate=validate,
    )

    # Print summary
    print(f"\nGenerated Helm values: {args.output}")

    if result.valid:
        print("Validation: PASSED")
    else:
        print("Validation: FAILED")
        for error in result.errors:
            print(f"  ERROR: {error}")

    for warning in result.warnings:
        print(f"  WARNING: {warning}")

    # Load and show summary
    rec_set = load_recommendations(args.recommendations_file)
    print(f"\nApp ID: {rec_set.app_id}")
    print(f"Workload: {rec_set.workload_type}")
    print(f"Recommendations: {len(rec_set.recommendations)}")
    print(f"Confidence: {rec_set.overall_confidence:.0%}")

    if rec_set.recommendations:
        print("\nChanges:")
        for rec in rec_set.recommendations:
            change = f"+{rec.change_pct:.0f}%" if rec.change_pct > 0 else f"{rec.change_pct:.0f}%"
            print(f"  • {rec.parameter}: {rec.current_value} → {rec.recommended_value} ({change})")


if __name__ == "__main__":
    main()
