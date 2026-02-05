"""
Library compatibility fixtures for E2E tests.

This module provides fixtures for testing PySpark compatibility
with different versions of pandas, numpy, and pyarrow.
"""
from typing import Dict, Any
import pytest


@pytest.fixture(scope="session")
def library_versions() -> Dict[str, str]:
    """
    Detect and return library versions in the test environment.

    Returns:
        Dict: Mapping of library names to version strings.
    """
    versions: Dict[str, str] = {}

    try:
        import pandas
        versions["pandas"] = pandas.__version__
    except ImportError:
        versions["pandas"] = "not_installed"

    try:
        import numpy
        versions["numpy"] = numpy.__version__
    except ImportError:
        versions["numpy"] = "not_installed"

    try:
        import pyarrow
        versions["pyarrow"] = pyarrow.__version__
    except ImportError:
        versions["pyarrow"] = "not_installed"

    try:
        import pyspark
        versions["pyspark"] = pyspark.__version__
    except ImportError:
        versions["pyspark"] = "not_installed"

    return versions


@pytest.fixture(scope="function")
def pandas_compatibility(spark_session: Any) -> Dict[str, Any]:
    """
    Test pandas to Spark DataFrame conversion.

    Validates that pandas DataFrames can be converted to/from PySpark.

    Args:
        spark_session: Spark session fixture.

    Returns:
        Dict: Compatibility test results.
    """
    try:
        import pandas as pd

        # Create test pandas DataFrame
        pandas_df = pd.DataFrame({
            "a": [1, 2, 3, 4, 5],
            "b": [1.0, 2.0, 3.0, 4.0, 5.0],
            "c": ["x", "y", "z", "w", "v"]
        })

        # Convert to Spark
        spark_df = spark_session.createDataFrame(pandas_df)
        spark_count = spark_df.count()

        # Convert back to pandas
        result_df = spark_df.toPandas()
        pandas_count = len(result_df)

        return {
            "pandas_version": pd.__version__,
            "conversion_success": True,
            "row_count": spark_count,
            "roundtrip_success": spark_count == pandas_count == 5
        }
    except ImportError:
        return {
            "pandas_version": "not_installed",
            "conversion_success": False,
            "error": "pandas not installed"
        }
    except Exception as e:
        return {
            "pandas_version": "unknown",
            "conversion_success": False,
            "error": str(e)
        }


@pytest.fixture(scope="function")
def numpy_compatibility(spark_session: Any) -> Dict[str, Any]:
    """
    Test numpy array to Spark DataFrame conversion.

    Validates that numpy arrays can be converted to PySpark DataFrames.

    Args:
        spark_session: Spark session fixture.

    Returns:
        Dict: Compatibility test results.
    """
    try:
        import numpy as np

        # Create test numpy array
        arr = np.array([
            [1, 2.0, "a"],
            [3, 4.0, "b"],
            [5, 6.0, "c"]
        ])

        # Convert to Spark
        spark_df = spark_session.createDataFrame(
            arr.tolist(),
            ["col1", "col2", "col3"]
        )
        row_count = spark_df.count()

        return {
            "numpy_version": np.__version__,
            "conversion_success": True,
            "row_count": row_count,
            "expected_count": 3
        }
    except ImportError:
        return {
            "numpy_version": "not_installed",
            "conversion_success": False,
            "error": "numpy not installed"
        }
    except Exception as e:
        return {
            "numpy_version": "unknown",
            "conversion_success": False,
            "error": str(e)
        }


@pytest.fixture(scope="function")
def pyarrow_compatibility(spark_session: Any) -> Dict[str, Any]:
    """
    Test PyArrow-enabled Spark operations.

    Validates that PyArrow can be used for efficient data transfer.

    Args:
        spark_session: Spark session fixture.

    Returns:
        Dict: Compatibility test results.
    """
    try:
        import pyarrow

        # Check if Arrow is enabled in Spark
        arrow_enabled = spark_session.conf.get(
            "spark.sql.execution.arrow.pyspark.enabled",
            "false"
        )

        return {
            "pyarrow_version": pyarrow.__version__,
            "arrow_enabled": arrow_enabled == "true",
            "compatibility_check": True
        }
    except ImportError:
        return {
            "pyarrow_version": "not_installed",
            "arrow_enabled": False,
            "compatibility_check": False,
            "error": "pyarrow not installed"
        }
    except Exception as e:
        return {
            "pyarrow_version": "unknown",
            "arrow_enabled": False,
            "compatibility_check": False,
            "error": str(e)
        }


@pytest.fixture(scope="function")
def type_compatibility(spark_session: Any) -> Dict[str, Any]:
    """
    Test data type compatibility between pandas/PySpark.

    Validates that common data types work correctly across libraries.

    Args:
        spark_session: Spark session fixture.

    Returns:
        Dict: Type compatibility test results.
    """
    try:
        import pandas as pd
        import numpy as np

        # Create DataFrame with various types
        test_data = pd.DataFrame({
            "int_col": [1, 2, 3],
            "float_col": [1.0, 2.0, 3.0],
            "str_col": ["a", "b", "c"],
            "bool_col": [True, False, True]
        })

        # Convert and check schema
        spark_df = spark_session.createDataFrame(test_data)
        schema = spark_df.schema

        type_mapping = {
            field.name: str(field.dataType)
            for field in schema.fields
        }

        return {
            "success": True,
            "type_mapping": type_mapping,
            "column_count": len(schema.fields)
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }


# Type alias for Spark session
Any = object
