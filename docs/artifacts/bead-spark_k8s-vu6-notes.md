# Bead spark_k8s-vu6: WS-034-05 Green 96 k8s/no-gpu

**WS:** 00-034-05 (Test Matrix — 96 scenarios gpu=false, platform=k8s)

## Analysis

- **96 scenarios:** 48 baseline (no iceberg), 48 iceberg
- **Baseline:** Uses spark-custom:3.5.7|3.5.8|4.1.0|4.1.1 — PASS when image exists
- **Iceberg:** Uses spark-custom:*-iceberg — SKIP (image not built)

## Classification

- **Build:** 48/96 blocked by iceberg image build (F24/WS-024)
- **Test:** run-matrix smoke works for baseline
- **Infra:** Requires spark-infra

## AC Status

- AC1: 96/96 PASS — blocked (48 iceberg SKIP)
- AC2: Run time ~5–6h for smoke*96; ~15h for all*96
- AC3: Beads created via create-matrix-beads.sh; close via close-matrix-beads-from-log.sh

## Next Steps

- Build iceberg images (F24) to unblock 48 scenarios
- Or: close iceberg beads with --skip-too "SKIP - image not built"
