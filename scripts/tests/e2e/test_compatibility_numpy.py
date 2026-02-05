"""
Library compatibility tests for PySpark with numpy.

Tests validate PySpark compatibility with different numpy versions.
"""
import pytest

test_feature = "compatibility"
test_library = "numpy"


@pytest.mark.e2e
@pytest.mark.timeout(300)
class TestNumpyCompatibility:
    """Test numpy compatibility with PySpark."""

    def test_numpy_conversion(
        self,
        spark_session,
        numpy_compatibility,
        library_versions
    ):
        """Test numpy array to Spark DataFrame conversion."""
        result = numpy_compatibility

        assert result["conversion_success"], \
            f"numpy conversion failed: {result.get('error', 'unknown error')}"
        assert result["row_count"] == result["expected_count"], \
            f"Row count mismatch: {result['row_count']} != {result['expected_count']}"

    def test_numpy_version_check(
        self,
        library_versions
    ):
        """Test that numpy version is detected."""
        versions = library_versions

        assert "numpy" in versions, "numpy version not detected"
        assert versions["numpy"] != "not_installed", "numpy is not installed"

        # Check version format
        version = versions["numpy"]
        parts = version.split(".")
        assert len(parts) >= 2, f"Invalid version format: {version}"

    def test_numpy_dtypes(
        self,
        spark_session
    ):
        """Test PySpark with numpy dtypes."""
        try:
            import numpy as np
            import pandas as pd

            # Create DataFrame with numpy dtypes
            data = pd.DataFrame({
                "int64": np.array([1, 2, 3], dtype=np.int64),
                "float64": np.array([1.5, 2.5, 3.5], dtype=np.float64),
                "bool": np.array([True, False, True], dtype=np.bool_)
            })

            # Convert to Spark
            sdf = spark_session.createDataFrame(data)
            row_count = sdf.count()

            assert row_count == 3, f"Expected 3 rows, got {row_count}"

        except ImportError:
            pytest.skip("numpy or pandas not installed")

    def test_numpy_array_operations(
        self,
        spark_session
    ):
        """Test PySpark operations on numpy arrays."""
        try:
            import numpy as np

            # Create 2D numpy array
            arr = np.array([
                [1, 2, 3],
                [4, 5, 6],
                [7, 8, 9]
            ])

            # Convert to Spark and verify
            sdf = spark_session.createDataFrame(arr, ["a", "b", "c"])
            result = sdf.agg({"a": "sum", "b": "sum", "c": "sum"}).collect()

            assert len(result) == 1, "Expected single aggregation result"
            assert result[0]["sum(a)"] == 12, f"Sum of 'a' should be 12, got {result[0]['sum(a)']}"

        except ImportError:
            pytest.skip("numpy not installed")
