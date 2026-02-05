"""
NYC Taxi dataset fixtures for E2E tests.

This module provides fixtures for loading and managing the NYC Taxi dataset.
"""
import os
import subprocess
import tempfile
from pathlib import Path
from typing import Optional

import pytest


def generate_sample_dataset(
    output_path: str = "/tmp/nyc-taxi-sample.parquet",
    rows: int = 10000
) -> str:
    """
    Generate a sample NYC Taxi dataset for testing.

    Args:
        output_path: Path where to save the dataset.
        rows: Number of rows to generate.

    Returns:
        str: Path to the generated dataset.
    """
    script_path = Path(__file__).parent.parent.parent.parent / "data" / "generate-dataset.sh"

    if script_path.exists():
        # Call the existing dataset generation script
        size = "large" if rows >= 100000 else "medium" if rows >= 10000 else "small"
        result = subprocess.run(
            ["bash", str(script_path), size],
            capture_output=True,
            text=True,
            timeout=300
        )
        if result.returncode == 0:
            # Find the generated file
            expected_path = Path(output_path)
            if not expected_path.exists():
                # Try alternative location
                alt_path = Path(__file__).parent.parent.parent.parent / f"nyc-taxi-{size}.parquet"
                if alt_path.exists():
                    return str(alt_path)
            return output_path

    # Fallback: generate with Python if script fails
    return _generate_with_python(output_path, rows)


def _generate_with_python(output_path: str, rows: int) -> str:
    """Generate dataset using Python (fallback)."""
    try:
        import pandas as pd
        import numpy as np
        from datetime import datetime, timedelta

        # Generate synthetic data
        np.random.seed(42)
        base_time = datetime(2023, 1, 1, 12, 0, 0)

        data = {
            "VendorID": np.random.choice([1, 2], rows),
            "tpep_pickup_datetime": [
                base_time + timedelta(minutes=np.random.randint(0, 1440))
                for _ in range(rows)
            ],
            "tpep_dropoff_datetime": [
                base_time + timedelta(minutes=np.random.randint(15, 1440))
                for _ in range(rows)
            ],
            "passenger_count": np.random.randint(1, 7, rows),
            "trip_distance": np.random.uniform(0.5, 15.0, rows),
            "RatecodeID": np.random.choice([1, 2, 3, 4, 5, 6], rows),
            "store_and_fwd_flag": np.random.choice(["Y", "N"], rows, p=[0.01, 0.99]),
            "PULocationID": np.random.randint(1, 263, rows),
            "DOLocationID": np.random.randint(1, 263, rows),
            "payment_type": np.random.choice([1, 2, 3, 4, 5, 6], rows),
            "fare_amount": np.random.uniform(3.0, 100.0, rows),
            "extra": np.random.choice([0.0, 0.5, 1.0, 1.5], rows),
            "mta_tax": np.random.choice([0.0, 0.5], rows, p=[0.1, 0.9]),
            "tip_amount": np.random.uniform(0.0, 20.0, rows),
            "tolls_amount": np.random.uniform(0.0, 15.0, rows),
            "improvement_surcharge": np.random.choice([0.0, 0.3], rows, p=[0.05, 0.95]),
        }

        df = pd.DataFrame(data)
        df["total_amount"] = (
            df["fare_amount"] + df["extra"] + df["mta_tax"] +
            df["tip_amount"] + df["tolls_amount"] + df["improvement_surcharge"]
        )

        # Ensure output directory exists
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)

        # Save to Parquet
        df.to_parquet(output_path, index=False)

        return output_path

    except ImportError:
        pytest.skip("Cannot generate dataset: pandas not available")
    except Exception as e:
        pytest.skip(f"Cannot generate dataset: {e}")


def ensure_dataset_available(
    full_path: Optional[str] = None,
    sample_path: Optional[str] = None
) -> str:
    """
    Ensure a dataset is available, generate if needed.

    Args:
        full_path: Path to full dataset (11GB).
        sample_path: Path to sample dataset (1GB).

    Returns:
        str: Path to available dataset (or generates sample).
    """
    # Check full dataset first
    full_path = full_path or os.environ.get("NYC_TAXI_FULL_PATH", "/tmp/nyc-taxi-full.parquet")
    if Path(full_path).exists():
        return full_path

    # Check sample dataset
    sample_path = sample_path or os.environ.get("NYC_TAXI_SAMPLE_PATH", "/tmp/nyc-taxi-sample.parquet")
    if Path(sample_path).exists():
        return sample_path

    # Generate sample dataset
    return generate_sample_dataset(sample_path, 10000)


@pytest.fixture(scope="session")
def nyc_taxi_sample_path() -> str:
    """
    Path to NYC Taxi sample dataset.

    Generates the dataset if it doesn't exist.

    Returns:
        str: Path to the sample dataset.
    """
    return ensure_dataset_available()
