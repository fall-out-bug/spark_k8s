"""
IPython startup script for automatic Spark configuration
Loaded automatically when IPython starts
"""

import os
import sys

# Add Jupyter home to path for spark_config
sys.path.insert(0, os.path.expanduser('~/.jupyter'))

def _configure_spark_environment():
    """Configure Spark environment variables on startup."""

    # Print connection info if available
    connect_server = os.environ.get('SPARK_CONNECT_SERVER')
    if connect_server:
        print(f"Spark Connect server: {connect_server}")
        print("Use: from spark_config import get_spark_session; spark = get_spark_session()")
    else:
        print("Spark Connect server not configured.")
        print("Use: from spark_config import get_spark_session; spark = get_spark_session(local_mode=True)")

    # S3 configuration status
    s3_endpoint = os.environ.get('S3_ENDPOINT')
    if s3_endpoint:
        print(f"S3 endpoint: {s3_endpoint}")

    print("\nQuick start:")
    print("  from spark_config import get_spark_session")
    print("  spark = get_spark_session()")
    print("  import pyspark.pandas as ps  # pandas API on Spark")
    print("")

# Run configuration on import
_configure_spark_environment()
