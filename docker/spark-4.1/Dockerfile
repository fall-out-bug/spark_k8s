FROM eclipse-temurin:17 AS builder

ARG SPARK_VERSION=4.1.0

WORKDIR /build

RUN apt-get update && apt-get install -y \
    wget \
    curl \
    git \
    maven \
  && rm -rf /var/lib/apt/lists/*

RUN wget https://archive.apache.org/dist/spark/spark-${SPARK_VERSION}/spark-${SPARK_VERSION}.tgz \
  && tar -xzf spark-${SPARK_VERSION}.tgz \
  && mv spark-${SPARK_VERSION} /opt/spark

WORKDIR /opt/spark

RUN ./dev/make-distribution.sh \
    -Pconnect \
    -Pkubernetes \
    -Phadoop-3 \
    -Phadoop-cloud \
    -Phive \
    -DskipTests

RUN mkdir -p /opt/spark-dist \
  && cp -r /opt/spark/dist/* /opt/spark-dist/

FROM python:3.10-slim-bookworm

RUN apt-get update && apt-get install -y \
    openjdk-17-jre-headless \
    tini \
    procps \
  && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/spark-dist /opt/spark

ENV SPARK_HOME=/opt/spark
ENV PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin
ENV PYTHONPATH=$SPARK_HOME/python:$SPARK_HOME/python/lib/py4j-*.zip

COPY deps/pom.xml /tmp/deps/pom.xml
RUN apt-get update && apt-get install -y maven \
  && mvn dependency:copy-dependencies \
       -f /tmp/deps/pom.xml \
       -DoutputDirectory=$SPARK_HOME/jars \
  && apt-get remove -y maven \
  && apt-get autoremove -y \
  && rm -rf /var/lib/apt/lists/* /root/.m2

COPY deps/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt

COPY conf/* $SPARK_HOME/conf/
COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

RUN groupadd -g 185 spark \
  && useradd -u 185 -g 185 -d /home/spark -m spark \
  && chown -R spark:spark /opt/spark

RUN mkdir -p /tmp/spark-events /tmp/spark-logs /tmp/spark-ivy \
  && chown -R spark:spark /tmp/spark-events /tmp/spark-logs /tmp/spark-ivy

USER 185
WORKDIR /home/spark

ENTRYPOINT ["/usr/bin/tini", "--", "/opt/entrypoint.sh"]
