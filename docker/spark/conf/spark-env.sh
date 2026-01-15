#!/usr/bin/env bash

# Java 17 module access options required for Spark 3.5.x
JAVA17_OPENS="--add-opens=java.base/java.lang=ALL-UNNAMED \
--add-opens=java.base/java.lang.invoke=ALL-UNNAMED \
--add-opens=java.base/java.lang.reflect=ALL-UNNAMED \
--add-opens=java.base/java.io=ALL-UNNAMED \
--add-opens=java.base/java.net=ALL-UNNAMED \
--add-opens=java.base/java.nio=ALL-UNNAMED \
--add-opens=java.base/java.util=ALL-UNNAMED \
--add-opens=java.base/java.util.concurrent=ALL-UNNAMED \
--add-opens=java.base/java.util.concurrent.atomic=ALL-UNNAMED \
--add-opens=java.base/jdk.internal.ref=ALL-UNNAMED \
--add-opens=java.base/sun.nio.ch=ALL-UNNAMED \
--add-opens=java.base/sun.nio.cs=ALL-UNNAMED \
--add-opens=java.base/sun.security.action=ALL-UNNAMED \
--add-opens=java.base/sun.util.calendar=ALL-UNNAMED \
--add-opens=java.security.jgss/sun.security.krb5=ALL-UNNAMED \
-Djdk.reflect.useDirectMethodHandle=false \
-XX:+IgnoreUnrecognizedVMOptions"

# Apply to all Spark JVMs (driver, executor, etc.)
export SPARK_EXECUTOR_OPTS="${SPARK_EXECUTOR_OPTS:-} ${JAVA17_OPENS}"
export SPARK_DRIVER_OPTS="${SPARK_DRIVER_OPTS:-} ${JAVA17_OPENS}"
export SPARK_DAEMON_JAVA_OPTS="${SPARK_DAEMON_JAVA_OPTS:-} ${JAVA17_OPENS}"

# Also set for direct Java invocations
export _JAVA_OPTIONS="${_JAVA_OPTIONS:-} ${JAVA17_OPENS}"
