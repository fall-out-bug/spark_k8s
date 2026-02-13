# Migrate Spark 3.5 to 4.1

## Property Renames (Spark 4.x)

Spark 4.x deprecates several properties. Update your `sparkConf` when migrating:

| 3.5 (deprecated) | 4.x (use) |
|------------------|-----------|
| `spark.blacklist.enabled` | `spark.excludeOnFailure.enabled` |
| `spark.blacklist.timeout` | `spark.excludeOnFailure.timeout` |

**Example:**

```yaml
# Before (3.5)
connect:
  sparkConf:
    spark.blacklist.enabled: "true"
    spark.blacklist.timeout: "30m"

# After (4.1)
connect:
  sparkConf:
    spark.excludeOnFailure.enabled: "true"
    spark.excludeOnFailure.timeout: "30m"
```

Spark 3.5 configs keep the old property names (still valid). Only Spark 4.x charts use the new names.

See also: [version-upgrade.md](../../migration/version-upgrade.md)
