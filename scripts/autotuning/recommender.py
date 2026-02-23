"""Rule-based recommender for Spark autotuning.

Generates configuration recommendations based on analysis results.

Usage:
    python -m autotuning.recommender --analysis-file analysis.json --output recommendations.json
"""

from __future__ import annotations

import argparse
import json
import logging
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any

import yaml

from autotuning.analyzer import AnalysisResult, DetectedIssue

logger = logging.getLogger(__name__)

# Default config paths
DEFAULT_PROFILES_PATH = Path(__file__).parent / "config" / "profiles.yaml"
DEFAULT_BOUNDS_PATH = Path(__file__).parent / "config" / "bounds.yaml"

# Memory unit multipliers
MEMORY_UNITS = {
    "Ki": 1024,
    "Mi": 1048576,
    "Gi": 1073741824,
    "Ti": 1099511627776,
}


def parse_memory_value(value: str) -> int:
    """Parse memory value string to bytes.

    Args:
        value: Memory string like "4Gi", "512Mi", or raw bytes.

    Returns:
        Value in bytes.
    """
    if isinstance(value, (int, float)):
        return int(value)

    value = str(value).strip()

    # Check for unit suffix
    for unit, multiplier in MEMORY_UNITS.items():
        if value.endswith(unit):
            num = float(value[:-len(unit)])
            return int(num * multiplier)

    # Try parsing as raw number
    try:
        return int(float(value))
    except ValueError:
        return 0


def format_memory_value(bytes_value: int, unit: str = "Gi") -> str:
    """Format bytes to memory string.

    Args:
        bytes_value: Value in bytes.
        unit: Target unit (Ki, Mi, Gi, Ti).

    Returns:
        Formatted string like "4Gi".
    """
    if unit not in MEMORY_UNITS:
        unit = "Gi"

    value = bytes_value / MEMORY_UNITS[unit]
    # Round to reasonable precision
    if value >= 1:
        value = round(value)
    else:
        value = round(value, 1)

    return f"{int(value) if value == int(value) else value}{unit}"


@dataclass
class Recommendation:
    """A single configuration recommendation."""

    parameter: str
    current_value: str
    recommended_value: str
    change_pct: float
    confidence: float
    rationale: str
    safety_check: str = "pass"  # pass, warning, capped, blocked
    source: str = ""  # Which issue triggered this

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary."""
        return {
            "parameter": self.parameter,
            "current_value": self.current_value,
            "recommended_value": self.recommended_value,
            "change_pct": round(self.change_pct, 1),
            "confidence": round(self.confidence, 2),
            "rationale": self.rationale,
            "safety_check": self.safety_check,
            "source": self.source,
        }


@dataclass
class RecommendationSet:
    """Set of recommendations for an application."""

    app_id: str
    workload_type: str
    recommendations: list[Recommendation]
    overall_confidence: float
    safety_issues: list[str]
    generated_at: datetime = field(default_factory=datetime.now)
    base_config: dict[str, str] = field(default_factory=dict)

    def to_dict(self) -> dict[str, Any]:
        """Convert to dictionary."""
        return {
            "app_id": self.app_id,
            "workload_type": self.workload_type,
            "recommendations": [r.to_dict() for r in self.recommendations],
            "overall_confidence": round(self.overall_confidence, 2),
            "safety_issues": self.safety_issues,
            "generated_at": self.generated_at.isoformat(),
            "base_config": self.base_config,
            "recommendation_count": len(self.recommendations),
        }

    def to_json(self) -> str:
        """Serialize to JSON string."""
        return json.dumps(self.to_dict(), indent=2, default=str)

    def save(self, path: Path) -> None:
        """Save recommendations to file."""
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(self.to_json())
        logger.info(f"Saved recommendations to {path}")


@dataclass
class BoundsCheckResult:
    """Result of safety bounds check."""

    recommended_value: str
    safety_check: str
    message: str = ""


def load_profiles_config(config_path: Path | None = None) -> dict[str, Any]:
    """Load profiles configuration."""
    if config_path is None:
        config_path = DEFAULT_PROFILES_PATH

    config_path = Path(config_path)
    if not config_path.exists():
        raise FileNotFoundError(f"Profiles config not found: {config_path}")

    with open(config_path) as f:
        return yaml.safe_load(f)


def load_bounds_config(config_path: Path | None = None) -> dict[str, Any]:
    """Load bounds configuration."""
    if config_path is None:
        config_path = DEFAULT_BOUNDS_PATH

    config_path = Path(config_path)
    if not config_path.exists():
        raise FileNotFoundError(f"Bounds config not found: {config_path}")

    with open(config_path) as f:
        return yaml.safe_load(f)


def apply_safety_bounds(
    parameter: str,
    value: str,
    current: str,
    bounds_config: dict[str, Any] | None = None,
) -> BoundsCheckResult:
    """Apply safety bounds to a recommended value.

    Args:
        parameter: Parameter name.
        value: Recommended value.
        current: Current value.
        bounds_config: Bounds configuration dict.

    Returns:
        BoundsCheckResult with potentially modified value.
    """
    if bounds_config is None:
        bounds_config = load_bounds_config()

    bounds = bounds_config.get("safety_bounds", {}).get(parameter, {})
    if not bounds:
        return BoundsCheckResult(value, "pass")

    param_format = bounds.get("format", "string")

    if param_format == "memory":
        return _apply_memory_bounds(value, current, bounds)
    elif param_format in ("integer", "float"):
        return _apply_numeric_bounds(value, current, bounds, param_format)
    else:
        return BoundsCheckResult(value, "pass")


def _apply_memory_bounds(
    value: str, current: str, bounds: dict[str, Any]
) -> BoundsCheckResult:
    """Apply bounds to memory parameter."""
    min_val = parse_memory_value(bounds.get("min", "0"))
    max_val = parse_memory_value(bounds.get("max", "999Ti"))
    max_increase_pct = bounds.get("max_increase_pct", 100)

    recommended_bytes = parse_memory_value(value)
    current_bytes = parse_memory_value(current)

    # Check max increase percentage
    if current_bytes > 0:
        max_allowed = current_bytes * (1 + max_increase_pct / 100)
        if recommended_bytes > max_allowed:
            recommended_bytes = int(max_allowed)
            result = BoundsCheckResult(
                format_memory_value(recommended_bytes, "Gi"),
                "capped",
                f"Capped to {max_increase_pct}% increase from current",
            )
        else:
            result = BoundsCheckResult(value, "pass")
    else:
        result = BoundsCheckResult(value, "pass")

    # Apply min/max bounds
    if recommended_bytes < min_val:
        return BoundsCheckResult(
            format_memory_value(min_val, "Gi"),
            "capped",
            f"Raised to minimum {bounds.get('min')}",
        )
    if recommended_bytes > max_val:
        return BoundsCheckResult(
            format_memory_value(max_val, "Gi"),
            "capped",
            f"Capped to maximum {bounds.get('max')}",
        )

    return result


def _apply_numeric_bounds(
    value: str, current: str, bounds: dict[str, Any], param_format: str
) -> BoundsCheckResult:
    """Apply bounds to numeric parameter."""
    min_val = bounds.get("min", 0)
    max_val = bounds.get("max", float("inf"))
    max_increase_pct = bounds.get("max_increase_pct", 100)

    try:
        recommended = float(value)
        current_num = float(current) if current else 0
    except ValueError:
        return BoundsCheckResult(value, "warning", "Could not parse numeric value")

    # Check max increase percentage
    if current_num > 0:
        max_allowed = current_num * (1 + max_increase_pct / 100)
        if recommended > max_allowed:
            recommended = max_allowed

    # Apply min/max bounds
    if recommended < min_val:
        recommended = min_val
    if recommended > max_val:
        recommended = max_val

    # Format output
    if param_format == "integer":
        output = str(int(recommended))
    else:
        output = str(recommended)

    safety = "capped" if recommended != float(value) else "pass"
    return BoundsCheckResult(output, safety)


class ConfigRecommender:
    """Generates Spark configuration recommendations."""

    def __init__(
        self,
        profiles_path: Path | None = None,
        bounds_path: Path | None = None,
    ):
        """Initialize recommender.

        Args:
            profiles_path: Path to profiles config.
            bounds_path: Path to bounds config.
        """
        self._profiles = None
        self._bounds = None
        self._profiles_path = profiles_path
        self._bounds_path = bounds_path

    @property
    def profiles(self) -> dict[str, Any]:
        """Lazy load profiles config."""
        if self._profiles is None:
            self._profiles = load_profiles_config(self._profiles_path)
        return self._profiles

    @property
    def bounds(self) -> dict[str, Any]:
        """Lazy load bounds config."""
        if self._bounds is None:
            self._bounds = load_bounds_config(self._bounds_path)
        return self._bounds

    def recommend(
        self,
        analysis: AnalysisResult,
        current_config: dict[str, str],
    ) -> RecommendationSet:
        """Generate recommendations based on analysis.

        Args:
            analysis: Analysis result from analyzer.
            current_config: Current Spark configuration.

        Returns:
            RecommendationSet with all recommendations.
        """
        logger.info(f"Generating recommendations for {analysis.app_id}")

        recommendations = []
        safety_issues = []
        processed_params = set()

        # Get workload profile
        profile = self._get_workload_profile(analysis.workload_type)

        # Generate recommendations from issues
        for issue in analysis.issues:
            issue_recs = self._generate_issue_recommendations(
                issue, current_config, analysis
            )
            for rec in issue_recs:
                if rec.parameter not in processed_params:
                    processed_params.add(rec.parameter)
                    recommendations.append(rec)
                else:
                    # Merge with existing recommendation (keep higher confidence)
                    existing = next(
                        r for r in recommendations if r.parameter == rec.parameter
                    )
                    if rec.confidence > existing.confidence:
                        recommendations.remove(existing)
                        recommendations.append(rec)

        # Apply safety bounds to all recommendations
        for i, rec in enumerate(recommendations):
            bounds_result = apply_safety_bounds(
                rec.parameter,
                rec.recommended_value,
                rec.current_value,
                self.bounds,
            )
            if bounds_result.safety_check != "pass":
                safety_issues.append(
                    f"{rec.parameter}: {bounds_result.message}"
                )
            recommendations[i] = Recommendation(
                parameter=rec.parameter,
                current_value=rec.current_value,
                recommended_value=bounds_result.recommended_value,
                change_pct=rec.change_pct,
                confidence=rec.confidence,
                rationale=rec.rationale,
                safety_check=bounds_result.safety_check,
                source=rec.source,
            )

        # Calculate overall confidence
        if recommendations:
            overall_confidence = sum(r.confidence for r in recommendations) / len(recommendations)
        else:
            overall_confidence = analysis.confidence

        return RecommendationSet(
            app_id=analysis.app_id,
            workload_type=analysis.workload_type,
            recommendations=recommendations,
            overall_confidence=overall_confidence,
            safety_issues=safety_issues,
            base_config=profile.get("base_config", {}),
        )

    def _get_workload_profile(self, workload_type: str) -> dict[str, Any]:
        """Get profile configuration for workload type."""
        profiles = self.profiles.get("profiles", {})
        return profiles.get(workload_type, profiles.get("etl_batch", {}))

    def _generate_issue_recommendations(
        self,
        issue: DetectedIssue,
        current_config: dict[str, str],
        analysis: AnalysisResult,
    ) -> list[Recommendation]:
        """Generate recommendations for a specific issue."""
        recommendations = []

        rules = self.profiles.get("recommendation_rules", {})
        rule = rules.get(issue.issue_type, {})

        actions = rule.get("actions", [])
        confidence_factor = rule.get("confidence_factor", 0.7)

        for action in actions:
            param = action.get("parameter")
            operation = action.get("operation")

            if not param or not operation:
                continue

            current = current_config.get(param, "")
            recommended = self._apply_operation(
                current, action, current_config
            )

            if recommended is None:
                continue

            # Calculate change percentage
            change_pct = self._calculate_change_pct(current, recommended)

            rec = Recommendation(
                parameter=param,
                current_value=str(current) if current else "not set",
                recommended_value=str(recommended),
                change_pct=change_pct,
                confidence=confidence_factor * (1.0 if issue.severity == "critical" else 0.8),
                rationale=action.get("rationale", f"Based on {issue.issue_type}"),
                source=issue.issue_type,
            )
            recommendations.append(rec)

        return recommendations

    def _apply_operation(
        self,
        current: str,
        action: dict[str, Any],
        current_config: dict[str, str],
    ) -> Any:
        """Apply an operation to generate recommended value."""
        operation = action.get("operation")
        param = action.get("parameter")

        if operation == "set":
            return action.get("value")

        elif operation == "multiply":
            factor = action.get("factor", 1.0)
            bounds = self.bounds.get("safety_bounds", {}).get(param, {})
            param_format = bounds.get("format", "string")

            if param_format == "memory":
                current_bytes = parse_memory_value(current) if current else parse_memory_value(
                    bounds.get("min", "1Gi")
                )
                return format_memory_value(int(current_bytes * factor), "Gi")
            else:
                try:
                    current_num = float(current) if current else 1
                    return current_num * factor
                except ValueError:
                    return current

        elif operation == "decrease":
            amount = action.get("amount", 1)
            bounds = self.bounds.get("safety_bounds", {}).get(param, {})
            min_val = bounds.get("min", 1)

            try:
                current_num = int(current) if current else min_val
                return max(current_num - amount, min_val)
            except ValueError:
                return current

        return None

    def _calculate_change_pct(self, current: str, recommended: Any) -> float:
        """Calculate percentage change from current to recommended."""
        if not current:
            return 100.0  # New value

        # Try memory comparison
        current_bytes = parse_memory_value(current)
        recommended_bytes = parse_memory_value(str(recommended))

        if current_bytes > 0 and recommended_bytes > 0:
            return ((recommended_bytes - current_bytes) / current_bytes) * 100

        # Try numeric comparison
        try:
            current_num = float(current)
            recommended_num = float(recommended)
            if current_num > 0:
                return ((recommended_num - current_num) / current_num) * 100
        except ValueError:
            pass

        return 0.0


def generate_recommendations(
    analysis_file: Path,
    output_path: Path | None = None,
    current_config: dict[str, str] | None = None,
    profiles_path: Path | None = None,
    bounds_path: Path | None = None,
) -> RecommendationSet:
    """Generate recommendations from analysis file.

    Args:
        analysis_file: Path to analysis JSON.
        output_path: Optional path to save results.
        current_config: Current Spark config.
        profiles_path: Path to profiles config.
        bounds_path: Path to bounds config.

    Returns:
        RecommendationSet with recommendations.
    """
    analysis_file = Path(analysis_file)
    if not analysis_file.exists():
        raise FileNotFoundError(f"Analysis file not found: {analysis_file}")

    with open(analysis_file) as f:
        data = json.load(f)

    # Reconstruct AnalysisResult
    issues = [
        DetectedIssue(
            issue_type=i["issue_type"],
            severity=i["severity"],
            metric_value=i["metric_value"],
            threshold=i["threshold"],
            recommendation=i.get("recommendation", ""),
            rationale=i.get("rationale", ""),
        )
        for i in data.get("issues", [])
    ]

    analysis = AnalysisResult(
        app_id=data.get("app_id", "unknown"),
        timestamp=datetime.fromisoformat(data["timestamp"]) if "timestamp" in data else datetime.now(),
        workload_type=data.get("workload_type", "etl_batch"),
        issues=issues,
        metrics_summary=data.get("metrics_summary", {}),
        duration_seconds=data.get("duration_seconds", 0),
        confidence=data.get("confidence", 0.5),
    )

    if current_config is None:
        current_config = {}

    recommender = ConfigRecommender(
        profiles_path=profiles_path,
        bounds_path=bounds_path,
    )
    result = recommender.recommend(
        analysis=analysis,
        current_config=current_config,
    )

    if output_path:
        result.save(output_path)

    return result


def main():
    """CLI entry point."""
    parser = argparse.ArgumentParser(
        description="Generate Spark configuration recommendations"
    )
    parser.add_argument(
        "--analysis-file", "-a",
        required=True,
        type=Path,
        help="Path to analysis JSON from analyzer",
    )
    parser.add_argument(
        "--output", "-o",
        type=Path,
        help="Output file path for recommendations JSON",
    )
    parser.add_argument(
        "--config",
        type=Path,
        help="Path to current Spark config JSON",
    )
    parser.add_argument(
        "--profiles",
        type=Path,
        help="Path to profiles config YAML",
    )
    parser.add_argument(
        "--bounds",
        type=Path,
        help="Path to bounds config YAML",
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

    # Load current config if provided
    current_config = {}
    if args.config and args.config.exists():
        with open(args.config) as f:
            current_config = json.load(f)

    # Generate recommendations
    result = generate_recommendations(
        analysis_file=args.analysis_file,
        output_path=args.output,
        current_config=current_config,
        profiles_path=args.profiles,
        bounds_path=args.bounds,
    )

    # Print summary
    print(f"\nRecommendations for {result.app_id}")
    print(f"Workload type: {result.workload_type}")
    print(f"Overall confidence: {result.overall_confidence:.0%}")
    print(f"Recommendations: {len(result.recommendations)}")

    if result.recommendations:
        print("\nConfiguration Changes:")
        for rec in result.recommendations:
            change_str = f"+{rec.change_pct:.0f}%" if rec.change_pct > 0 else f"{rec.change_pct:.0f}%"
            safety_str = f" [{rec.safety_check}]" if rec.safety_check != "pass" else ""
            print(f"  • {rec.parameter}: {rec.current_value} → {rec.recommended_value} ({change_str}){safety_str}")
            print(f"    Rationale: {rec.rationale}")

    if result.safety_issues:
        print("\nSafety Issues:")
        for issue in result.safety_issues:
            print(f"  ⚠ {issue}")

    if args.output:
        print(f"\nSaved to: {args.output}")


if __name__ == "__main__":
    main()
