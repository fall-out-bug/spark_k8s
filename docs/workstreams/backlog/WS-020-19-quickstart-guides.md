## WS-020-19: Quickstart Guide EN + RU

### 🎯 Goal

**What should WORK after WS completion:**
- English guide `docs/guides/SPARK-4.1-QUICKSTART.md` exists
- Russian guide `docs/guides/SPARK-4.1-QUICKSTART-RU.md` exists
- Guides provide 5-minute deployment instructions for Spark 4.1.0
- Guides include: prerequisites, installation, verification, first Spark job

**Acceptance Criteria:**
- [ ] `docs/guides/SPARK-4.1-QUICKSTART.md` exists (~150 LOC)
- [ ] `docs/guides/SPARK-4.1-QUICKSTART-RU.md` exists (~150 LOC)
- [ ] Guides include: Minikube setup, Helm install commands, port-forward instructions, example PySpark code
- [ ] All commands are copy-pasteable
- [ ] Guides link to production guide for advanced config

**⚠️ WS is NOT complete until Goal is achieved (all AC ✅).**

---

### Context

Feature F04 requires comprehensive documentation for new users. Quickstart guides enable Data Scientists to deploy Spark 4.1.0 in 5 minutes.

### Dependency

WS-020-06 through WS-020-10 (all core components documented)

### Input Files

**Reference:**
- `docs/guides/SPARK-STANDALONE-QUICKSTART.md` — Existing quickstart pattern
- `docs/guides/SPARK-CONNECT-QUICKSTART.md` — Spark Connect guide

### Steps

1. **Create `docs/guides/SPARK-4.1-QUICKSTART.md`:**
   
   Structure:
   ```markdown
   # Spark 4.1.0 Quickstart (5 Minutes)
   
   Deploy Apache Spark 4.1.0 with Spark Connect and Jupyter on Minikube.
   
   ## Prerequisites
   - Minikube running
   - Helm 3.x installed
   - Docker images built (spark-custom:4.1.0, jupyter-spark:4.1.0)
   
   ## 1. Deploy Spark 4.1.0
   
   ```bash
   helm install spark-41 charts/spark-4.1 \
     --set spark-base.enabled=true \
     --set connect.enabled=true \
     --set jupyter.enabled=true \
     --set hiveMetastore.enabled=true \
     --set historyServer.enabled=true \
     --wait
   ```
   
   ## 2. Verify Deployment
   
   ```bash
   kubectl get pods -l app.kubernetes.io/instance=spark-41
   # All pods should be Running
   ```
   
   ## 3. Access Jupyter
   
   ```bash
   kubectl port-forward svc/spark-41-spark-41-jupyter 8888:8888
   # Open http://localhost:8888
   ```
   
   ## 4. Run Your First Spark Job
   
   In Jupyter, create a new notebook:
   
   ```python
   from pyspark.sql import SparkSession
   
   spark = SparkSession.builder \\
       .appName("Quickstart") \\
       .remote("sc://spark-41-spark-41-connect:15002") \\
       .getOrCreate()
   
   df = spark.range(1000000).selectExpr("id", "id * 2 as doubled")
   df.show()
   
   print(f"Spark version: {spark.version}")
   ```
   
   ## Next Steps
   
   - [Production Deployment Guide](SPARK-4.1-PRODUCTION.md)
   - [Celeborn Integration](CELEBORN-GUIDE.md)
   - [Spark Operator Guide](SPARK-OPERATOR-GUIDE.md)
   ```

2. **Create `docs/guides/SPARK-4.1-QUICKSTART-RU.md`:**
   
   Russian translation of the same content:
   ```markdown
   # Быстрый старт Spark 4.1.0 (5 минут)
   
   Развертывание Apache Spark 4.1.0 с Spark Connect и Jupyter в Minikube.
   
   ## Требования
   - Запущенный Minikube
   - Установленный Helm 3.x
   - Собранные Docker-образы (spark-custom:4.1.0, jupyter-spark:4.1.0)
   
   ## 1. Установка Spark 4.1.0
   
   ```bash
   helm install spark-41 charts/spark-4.1 \\
     --set spark-base.enabled=true \\
     --set connect.enabled=true \\
     --set jupyter.enabled=true \\
     --set hiveMetastore.enabled=true \\
     --set historyServer.enabled=true \\
     --wait
   ```
   
   ## 2. Проверка развертывания
   
   ```bash
   kubectl get pods -l app.kubernetes.io/instance=spark-41
   # Все поды должны быть в статусе Running
   ```
   
   ## 3. Доступ к Jupyter
   
   ```bash
   kubectl port-forward svc/spark-41-spark-41-jupyter 8888:8888
   # Откройте http://localhost:8888
   ```
   
   ## 4. Первое задание Spark
   
   В Jupyter создайте новый notebook:
   
   ```python
   from pyspark.sql import SparkSession
   
   spark = SparkSession.builder \\
       .appName("Quickstart") \\
       .remote("sc://spark-41-spark-41-connect:15002") \\
       .getOrCreate()
   
   df = spark.range(1000000).selectExpr("id", "id * 2 as doubled")
   df.show()
   
   print(f"Версия Spark: {spark.version}")
   ```
   
   ## Дальнейшие шаги
   
   - [Производственное развертывание](SPARK-4.1-PRODUCTION-RU.md)
   - [Интеграция с Celeborn](CELEBORN-GUIDE.md)
   - [Spark Operator](SPARK-OPERATOR-GUIDE.md)
   ```

3. **Update README.md to link new guides:**
   
   Add to `docs/guides/` section:
   ```markdown
   - [Spark 4.1.0 Quickstart (EN)](docs/guides/SPARK-4.1-QUICKSTART.md)
   - [Spark 4.1.0 Quickstart (RU)](docs/guides/SPARK-4.1-QUICKSTART-RU.md)
   ```

4. **Validate:**
   - Check all commands are copy-pasteable
   - Verify links to other guides are correct
   - Run through guide manually

### Expected Result

```
docs/guides/
├── SPARK-4.1-QUICKSTART.md       # ~150 LOC
└── SPARK-4.1-QUICKSTART-RU.md    # ~150 LOC
```

### Scope Estimate

- Files: 2 created, 1 modified (README.md)
- Lines: ~300 LOC (SMALL)
- Tokens: ~1400

### Completion Criteria

```bash
# Check guides exist
ls docs/guides/SPARK-4.1-QUICKSTART*.md

# Validate markdown
markdownlint docs/guides/SPARK-4.1-QUICKSTART*.md || echo "Linter not installed, skip"

# Manual walkthrough
# (Follow guide step-by-step to ensure accuracy)
```

### Constraints

- DO NOT include production configs (separate guide for that)
- DO NOT assume prior Spark knowledge (beginner-friendly)
- ENSURE all code blocks are tested
- USE consistent formatting (same style as existing guides)
