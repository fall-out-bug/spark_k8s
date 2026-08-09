# Graph Processing (GraphX)

## Overview

GraphX is Spark's graph computation library. Use for:

- PageRank
- Connected components
- Triangle counting
- Shortest paths

## Example

```scala
import org.apache.spark.graphx._

val graph = GraphLoader.edgeListFile(sc, "path/to/edges")
val ranks = graph.pageRank(0.0001).vertices
```

## Kubernetes

Ensure sufficient executor memory for large graphs.
