# Матрица 32 вариантов (4×2×2×2)

## Размерности

| Размерность | Значения |
|-------------|----------|
| spark_version | 3.5.7, 3.5.8, 4.1.0, 4.1.1 |
| connect | true, false |
| k8s_mode | native, standalone |
| platform | k8s, restricted |

## Запуск

```bash
# 32 сценария (минимальная конфигурация: без gpu, iceberg, shuffle, openlineage)
./scripts/run-matrix-32.sh --shared-infra all

# Или напрямую
./scripts/run-matrix.sh --filter "gpu=false,iceberg=false,shuffle_service=false,openlineage=false" --shared-infra all
```

## Список 32 сценариев

SCENARIO-0016, 0032, 0036, 0040, 0056, 0072, 0076, 0080 (3.5.7)
SCENARIO-0096, 0112, 0116, 0120, 0136, 0152, 0156, 0160 (3.5.8)
SCENARIO-0176, 0192, 0196, 0200, 0216, 0232, 0236, 0240 (4.1.0)
SCENARIO-0256, 0272, 0276, 0280, 0296, 0312, 0316, 0320 (4.1.1)
