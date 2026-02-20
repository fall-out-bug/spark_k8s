# Feature: NYC Taxi ML Pipeline (F031)

## Overview
ML-пайплайн для предсказания выручки и количества поездок NYC такси на 7 дней вперёд с использованием Airflow, Spark и CatBoost.

## Business Value
- Прогнозирование нагрузки на такси по зонам
- Оптимизация распределения водителей
- Планирование revenue на неделю вперёд

## Data Sources
- **NYC TLC Trip Records** (2 года данных)
  - Source: https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page
  - Format: Parquet
  - Storage: MinIO `s3a://nyc-taxi/raw/`

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        MINIKUBE CLUSTER                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐     ┌──────────────────────────────────────┐ │
│  │   Airflow    │────▶│  Spark Standalone Master:7077       │ │
│  │   (DAG)      │     │  ┌─────────┐  ┌─────────┐           │ │
│  │              │     │  │ Worker1 │  │ Worker2 │           │ │
│  │  5+ stages   │     │  └─────────┘  └─────────┘           │ │
│  │  branching   │     └──────────────────────────────────────┘ │
│  └──────────────┘                    │                         │
│         │                            ▼                         │
│         │              ┌──────────────────────────────────────┐ │
│         │              │           MINIO                      │ │
│         │              │  ┌─────────────────────────────────┐ │ │
│         │              │  │ s3a://nyc-taxi/raw/ (parquet)   │ │ │
│         │              │  │ s3a://nyc-taxi/features/ (iceberg)│ │ │
│         │              │  │ s3a://ml-models/taxi-predictor/ │ │ │
│         │              │  └─────────────────────────────────┘ │ │
│         │              └──────────────────────────────────────┘ │
│         │                                                       │
│  ┌──────────────┐     ┌──────────────────────────────────────┐ │
│  │   Jupyter    │────▶│  Spark Connect:15002                │ │
│  │   Notebook   │     │  (Pandas API on Spark)              │ │
│  │              │     └──────────────────────────────────────┘ │
│  │  Exploration │                                               │
│  │  Training    │                                               │
│  └──────────────┘                                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Airflow DAG Structure (5+ Stages)

```
                    ┌─────────────────┐
                    │  1. Data Ingest │
                    │  (download TLC) │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │ 2. Feature Prep │
                    │  (Spark ETL)    │
                    └────────┬────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
   ┌──────▼──────┐    ┌──────▼──────┐    ┌──────▼──────┐
   │ 3a. Train   │    │ 3b. Train   │    │ 3c. Train   │
   │ Manhattan   │    │ Brooklyn    │    │ Queens      │
   │ (CatBoost)  │    │ (CatBoost)  │    │ (CatBoost)  │
   └──────┬──────┘    └──────┬──────┘    └──────┬──────┘
          │                  │                  │
          └──────────────────┼──────────────────┘
                             │
                    ┌────────▼────────┐
                    │   4. Validate   │
                    │   (MAPE/RMSE)   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │ 5. Predict+Save │
                    │  (7-day forecast│
                    │   to MinIO)     │
                    └─────────────────┘
```

## Features

### Temporal Features
- `hour_of_day` (0-23)
- `day_of_week` (0-6)
- `is_weekend` (bool)
- `is_holiday` (bool)
- `month` (1-12)
- `is_rush_hour` (bool)

### Geospatial Features
- `pickup_zone_id` (TLC zone)
- `dropoff_zone_id` (TLC zone)
- `trip_distance` (miles)
- `avg_speed`

### Historical Aggregates
- `avg_trips_zone_hour` (avg trips per zone per hour last 30 days)
- `avg_revenue_zone_day` (avg revenue per zone per day last 30 days)
- `trips_same_day_last_week`
- `trips_same_day_last_year`

## Target Variables (Multi-target)
- `total_amount_7d` - суммарная выручка на 7 дней вперёд по зоне
- `trip_count_7d` - количество поездок на 7 дней вперёд по зоне

## CatBoost Integration

### Approach: pandas UDF
```python
# Обучение отдельных моделей по borough на Spark workers
@pandas_udf("model_id string, model_binary binary")
def train_catboost_partition(df: pd.DataFrame) -> pd.DataFrame:
    from catboost import CatBoostRegressor

    model = CatBoostRegressor(iterations=100, depth=6)
    model.fit(df[features], df[target])

    return pd.DataFrame({
        "model_id": [f"model_{df['zone_id'].iloc[0]}"],
        "model_binary": [pickle.dumps(model)]
    })
```

## Storage Schema

### MinIO Buckets
```
s3a://nyc-taxi/
├── raw/                    # Исходные parquet файлы TLC
│   ├── yellow_tripdata_2023-01.parquet
│   ├── yellow_tripdata_2023-02.parquet
│   └── ...
├── features/               # Iceberg таблица с фичами
│   └── taxi_features/
│       ├── metadata/
│       └── data/
└── predictions/            # Предсказания
    └── 7day_forecast/

s3a://ml-models/
└── taxi-predictor/
    ├── v20260220/
    │   ├── manhattan.cbm
    │   ├── brooklyn.cbm
    │   └── queens.cbm
    └── latest/
        └── ...
```

## Workstreams

| ID | Title | Description |
|----|-------|-------------|
| WS-031-01 | Data Ingestion | Download NYC TLC data, upload to MinIO |
| WS-031-02 | Feature Engineering | Spark pipeline for feature generation |
| WS-031-03 | Airflow DAG | 5-stage DAG with branching |
| WS-031-04 | CatBoost Training | pandas UDF training per borough |
| WS-031-05 | Jupyter Notebook | Interactive analysis with Spark Connect |
| WS-031-06 | Prediction Pipeline | 7-day forecast generation |

## Quality Gates
- Feature coverage ≥ 90%
- Model MAPE ≤ 15%
- DAG execution time ≤ 30 min
- Prediction latency ≤ 5 min

## Risks
| Risk | Mitigation |
|------|------------|
| Large dataset (2 years) | Sample/downsample for dev, full for prod |
| CatBoost native libs | Pre-install in spark-custom image |
| Airflow dependencies | Use existing spark-35-airflow-sa namespace |

---

**Created:** 2026-02-20
**Status:** Design
**Target:** minikube deployment
