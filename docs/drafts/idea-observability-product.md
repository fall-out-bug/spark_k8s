# Feature: Observability as Product (F31)

## Overview

Собрать observability-стек конструктора spark_k8s в **рецепты для пользователей** и защитить от регрессий при разработке. Аудит проекта и взгляд на него как на продукт.

**Заказчик:** Техлид (primary), важны все 4+ персоны.

---

## Problem Statement

1. **Не собрано в рецепты** — компоненты (Loki, Prometheus, Grafana, OTEL, demo-metrics) есть, но нет понятных гайдов «как понять, что с системой, за 5 минут» для каждой роли.
2. **Агенты ломают при разработке** — дашборды, метрики, старые демо и сценарии теряются или ломаются.
3. **Нет product view** — observability воспринимается как инфраструктура, а не как продукт для пользователей конструктора.

---

## User Personas

| Персона | Цель | Ключевой вопрос |
|---------|------|-----------------|
| **DevOps** | Всё зелёное, ничего не падает | «Система в порядке?» |
| **DataOps** | Трейсы и даши по джобам | «Как идут джобы? Где bottleneck?» |
| **Tech Lead** | Состояние пайплайнов | «Что работает, что упало, почему?» |
| **Data Engineer** | Прослеживаемость данных | «Где ошибка: Airflow или Spark? Почему опоздала задача?» |
| **Data Scientist (DS)** | Чтоб работало | «Мой ноутбук/модель запускается?» |

---

## Success Criteria

1. **5-min guides** — каждый персонаж за 5 минут понимает состояние системы по своему срезу.
2. **Runbooks** — гайды и ранбуки «как понять, что с системой».
3. **PR gate** — сценарии тестов перед PR конструктора, защита от регрессий observability.
4. **Примеры** — примеры отчётов и алертов приветствуются.

---

## Stakeholders

- **Tech Lead** — primary stakeholder
- **DevOps, DataOps, Data Engineer, DS** — все важны

---

## Technical Context

### Существующее (F16, observability-full-stack-plan)

- Loki + Promtail (логи)
- Prometheus (метрики Spark Master/Worker, OTEL, demo-metrics)
- Grafana (Tech Lead dashboard, Logs Explorer)
- OTEL Collector (Spark phase metrics)
- demo-metrics-exporter (History API → Prometheus)
- DAGs с OTEL: nyc_taxi_ml_full_pipeline

### Пробелы

- Нет рецептов per-persona
- Нет PR gate для observability
- Нет консолидированного runbook index по персонам
- Агенты могут сломать даши/метрики без проверки

---

## Deliverables

1. **Audit** — инвентарь: дашборды, метрики, логи, демо, сценарии.
2. **Persona recipes** — 5-min guide для каждой персоны (DevOps, DataOps, Tech Lead, Data Engineer, DS).
3. **PR gate** — тест-сценарии observability (smoke: Loki up, Prometheus scrape, Grafana dashboards load).
4. **Example alerts/reports** — примеры алертов и отчётов.
5. **Runbook consolidation** — индекс по персонам, ссылки на рецепты.

---

## Out of Scope

- Новые компоненты observability (Loki, Prometheus и т.д. уже есть).
- Изменение архитектуры стека.

---

## Dependencies

- F16 Observability Stack (completed)
- tests/observability/* (Loki, Promtail, Prometheus, Grafana configs)
- docs/plans/observability-full-stack-plan.md
- tests/demo-runbook-shared-infra.md

---

## Risks

- Агенты продолжают ломать без PR gate — митигация: WS-031-07 (PR gate) в критическом пути.
