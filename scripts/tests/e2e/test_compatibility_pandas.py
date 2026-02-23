"""
Library compatibility tests for PySpark with pandas.

Tests validate PySpark compatibility with different pandas versions.
"""
import pytest

test_feature = "compatibility"
test_library = "pandas"


@pytest.mark.e2e
@pytest.mark.timeout(300)
class TestPandasCompatibility:
    """Test pandas compatibility with PySpark."""

    def test_pandas_conversion(
        self,
        spark_session,
        pandas_compatibility,
        library_versions
    ):
        """Test pandas to Spark DataFrame conversion."""
        result = pandas_compatibility

        assert result["conversion_success"], \
            f"pandas conversion failed: {result.get('error', 'unknown error')}"
        assert result["roundtrip_success"], "Roundtrip conversion failed"
        assert result["row_count"] == 5, f"Expected 5 rows, got {result['row_count']}"

    def test_pandas_types(
        self,
        spark_session,
        type_compatibility
    ):
        """Test pandas data type compatibility."""
        result = type_compatibility

        assert result["success"], f"Type compatibility test failed: {result.get('error')}"
        assert result["column_count"] == 4, \
            f"Expected 4 columns, got {result['column_count']}"

    def test_pandas_version_check(
        self,
        library_versions
    ):
        """Test that pandas version is detected."""
        versions = library_versions

        assert "pandas" in versions, "pandas version not detected"
        assert versions["pandas"] != "not_installed", "pandas is not installed"

        # Check version format (major.minor.micro or similar)
        version = versions["pandas"]
        parts = version.split(".")
        assert len(parts) >= 2, f"Invalid version format: {version}"

    def test_pandas_dataframe_operations(
        self,
        spark_session
    ):
        """Test PySpark operations on pandas-converted DataFrames."""
        try:
            import pandas as pd

            # Create pandas DataFrame
            pdf = pd.DataFrame({
                "group": ["A", "A", "B", "B", "C"],
                "value": [10, 20, 30, 40, 50]
            })

            # Convert to Spark and run operations
            sdf = spark_session.createDataFrame(pdf)

            # Test aggregation
            result = sdf.groupBy("group").agg({"value": "sum"}).collect()
            assert len(result) == 3, f"Expected 3 groups, got {len(result)}"

            # Test filtering
            filtered = sdf.filter(sdf.value > 25).collect()
            assert len(filtered) == 3, f"Expected 3 rows, got {len(filtered)}"

        except ImportError:
            pytest.skip("pandas not installed")
