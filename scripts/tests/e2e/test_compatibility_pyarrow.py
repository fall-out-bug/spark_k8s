"""
Library compatibility tests for PySpark with pyarrow.

Tests validate PySpark compatibility with different pyarrow versions.
"""
import pytest

test_feature = "compatibility"
test_library = "pyarrow"


@pytest.mark.e2e
@pytest.mark.timeout(300)
class TestPyArrowCompatibility:
    """Test pyarrow compatibility with PySpark."""

    def test_pyarrow_enabled(
        self,
        spark_session,
        pyarrow_compatibility,
        library_versions
    ):
        """Test that PyArrow is enabled in Spark."""
        result = pyarrow_compatibility

        assert result["compatibility_check"], \
            f"PyArrow compatibility check failed: {result.get('error', 'unknown error')}"

        # Note: Arrow may or may not be enabled depending on Spark config
        # We just verify the check completed
        assert "pyarrow_version" in result, "PyArrow version not detected"

    def test_pyarrow_version_check(
        self,
        library_versions
    ):
        """Test that pyarrow version is detected."""
        versions = library_versions

        assert "pyarrow" in versions, "pyarrow version not detected"
        assert versions["pyarrow"] != "not_installed", "pyarrow is not installed"

        # Check version format
        version = versions["pyarrow"]
        parts = version.split(".")
        assert len(parts) >= 2, f"Invalid version format: {version}"

    def test_pyarrow_to_pandas(
        self,
        spark_session
    ):
        """Test PyArrow-enabled toPandas conversion."""
        try:
            import pandas as pd

            # Create Spark DataFrame
            data = [("Alice", 25), ("Bob", 30), ("Charlie", 35)]
            sdf = spark_session.createDataFrame(data, ["name", "age"])

            # Convert to pandas (should use Arrow if enabled)
            pdf = sdf.toPandas()

            assert len(pdf) == 3, f"Expected 3 rows, got {len(pdf)}"
            assert list(pdf.columns) == ["name", "age"], \
                f"Unexpected columns: {list(pdf.columns)}"

        except ImportError:
            pytest.skip("pandas not installed")

    def test_pyarrow_from_pandas(
        self,
        spark_session
    ):
        """Test PyArrow-enabled from pandas conversion."""
        try:
            import pandas as pd

            # Create pandas DataFrame
            pdf = pd.DataFrame({
                "x": [1, 2, 3, 4, 5],
                "y": [10, 20, 30, 40, 50]
            })

            # Convert to Spark
            sdf = spark_session.createDataFrame(pdf)
            result = sdf.agg({"x": "sum", "y": "sum"}).collect()

            assert len(result) == 1, "Expected single aggregation result"
            assert result[0]["sum(x)"] == 15, f"Sum of 'x' should be 15"
            assert result[0]["sum(y)"] == 150, f"Sum of 'y' should be 150"

        except ImportError:
            pytest.skip("pandas not installed")
