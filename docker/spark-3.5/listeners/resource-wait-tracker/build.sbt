name := "resource-wait-tracker"

version := "1.0.0"

scalaVersion := "2.12.18"

libraryDependencies ++= Seq(
  "org.apache.spark" %% "spark-core" % "3.5.7" % "provided",
  "org.apache.spark" %% "spark-sql" % "3.5.7" % "provided",
  "io.dropwizard.metrics" % "metrics-core" % "4.2.19"
)

assembly / assemblyJarName := "resource-wait-tracker.jar"

assembly / assemblyOption  := (assembly / assemblyOption).value.copy(
  includeScala = false,
  includeDependency = false
)

assembly / assemblyMergeStrategy := {
  case PathList("META-INF", xs @ _*) => MergeStrategy.discard
  case x => MergeStrategy.first
}
