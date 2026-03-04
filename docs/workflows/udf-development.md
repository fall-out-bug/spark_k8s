# UDF Development

## Python UDF

```python
from pyspark.sql.functions import udf
from pyspark.sql.types import StringType

@udf(returnType=StringType())
def normalize(s):
    return s.lower().strip() if s else None

df.withColumn("normalized", normalize("name"))
```

## Pandas UDF (Vectorized)

```python
import pandas as pd
from pyspark.sql.functions import pandas_udf

@pandas_udf("double")
def mean_udf(s: pd.Series) -> float:
    return s.mean()
```

## Scala UDF

Register in SparkSession and use from SQL.
