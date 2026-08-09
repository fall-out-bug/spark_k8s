# Scala Code Validation Guide

This guide describes the Scala code validation process used in CI/CD pipelines.

## Tools

### scalafmt

scalafmt is the code formatter for Scala.

**Installation:**
```bash
# Via coursier
cs install scalafmt

# Or manually
curl -L https://github.com/scalameta/scalafmt/releases/download/v3.8.0/scalafmt-linux -o scalafmt
chmod +x scalafmt
```

**Usage:**
```bash
# Check formatting
scalafmt --config configs/codestyle/scalafmt.conf --test <path>

# Auto-format
scalafmt --config configs/codestyle/scalafmt.conf <path>
```

**Configuration** (`configs/codestyle/scalafmt.conf`):
```scala
version = 3.8.0
maxColumn = 100
align.preset = most
rewrite.rules = [ImportSorter, SortImports, AsciiSortImports]
```

### scalastyle

scalastyle checks for Scala style guide violations.

**Installation:**
```bash
# Add to project/plugins.sbt
addSbtPlugin("org.scalastyle" %% "scalastyle-sbt-plugin" % "1.0.0")
```

**Usage:**
```bash
sbt scalastyle
```

**Configuration** (`configs/codestyle/scalastyle-config.xml`):
```xml
<scalastyle>
  <name>Scalastyle configuration</name>
  <check level="error" class="org.scalastyle.file.FileLengthChecker" enabled="true">
    <parameters>
      <parameter name="maxFileLength"><![CDATA[800]]></parameter>
    </parameters>
  </check>
</scalastyle>
```

## Anti-Patterns Detection

### Mutable Collections in val

Bad:
```scala
val data = mutable.ArrayBuffer(1, 2, 3)
```

Good:
```scala
val data = IndexedSeq(1, 2, 3)
```

### Empty Catch Blocks

Bad:
```scala
try {
  // something
} catch {
  case _: Exception =>  // Never do this!
}
```

Good:
```scala
try {
  // something
} catch {
  case e: IOException =>
    logger.error("Failed to read", e)
    throw e
}
```

### Return Statements

Bad:
```scala
def calculate(x: Int): Int = {
  return x * 2
}
```

Good:
```scala
def calculate(x: Int): Int = {
  x * 2
}
```

## CI/CD Integration

### Pre-commit Hook

Add to `.git/hooks/pre-commit`:

```bash
#!/bin/bash
./scripts/cicd/lint-scala.sh --dir src/main/scala --fix
```

### Pipeline Check

The CI/CD pipeline runs:

```bash
./scripts/cicd/lint-scala.sh --dir <module>
```

## Quality Gates

| Gate | Requirement |
|------|-------------|
| scalafmt | No formatting changes needed |
| scalastyle | No errors |
| Anti-patterns | No violations |

## Spark-Specific Guidelines

### UDF Performance

Bad:
```scala
val myUdf = udf((s: String) => s.toUpperCase)
```

Good:
```sparkSQL
-- Use built-in functions
SELECT upper(column_name) FROM table
```

### Resource Management

Always close resources:

```scala
val spark = SparkSession.builder()
  .appName("MyJob")
  .getOrCreate()

try {
  // Your job logic
} finally {
  spark.stop()
}
```

### Checkpointing

For long lineage:

```scala
df.checkpoint()  // Or: df.localCheckpoint()
```

## Reference

- [scalafmt documentation](https://scalameta.org/scalafmt/)
- [scalastyle documentation](http://www.scalastyle.org/)
- [Scala style guide](https://docs.scala-lang.org/style/)
- [Spark programming guide](https://spark.apache.org/docs/latest/programming-guide.html)
