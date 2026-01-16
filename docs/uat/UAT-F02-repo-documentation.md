## UAT: F02 Repository Documentation

### Overview

This feature provides comprehensive documentation for the repository, including:
- Charts catalog and operator guides (EN + RU)
- Copy-pasteable values overlays
- Validation runbooks and OpenShift notes
- Clear repository structure map

### Prerequisites

- Repository cloned
- Markdown viewer (or GitHub/GitLab web UI)

### Scenarios (5-10 min)

1. **Navigation**
   - Open `README.md` and verify it acts as a clean index.
   - Click "Repository map" link (`docs/PROJECT_MAP.md`) and verify it explains the repo structure.

2. **Chart Guides (EN)**
   - Open `docs/guides/en/charts/spark-standalone.md`.
   - Verify it contains:
     - Quickstart commands
     - Key configuration values
     - Reference to `values-prod-like.yaml`

3. **Chart Guides (RU)**
   - Open `docs/guides/ru/charts/spark-standalone.md`.
   - Verify it is a faithful translation of the EN guide.
   - Verify cross-links work (link back to EN version).

4. **Validation Runbook**
   - Open `docs/guides/en/validation.md`.
   - Verify it documents:
     - `test-spark-standalone.sh`
     - `test-prodlike-airflow.sh`
     - Expected outputs ("green" state)

5. **OpenShift Notes**
   - Open `docs/guides/en/openshift-notes.md`.
   - Verify it explicitly states "Tested on Minikube" vs "Prepared for OpenShift".
   - Verify it mentions PSS `restricted` compliance.

### Red Flags

- Broken links in `README.md` or cross-links between guides.
- "Tested on OpenShift" claims (should NOT exist; only "Prepared for").
- Missing "Quickstart" sections in guides.

### Sign-off

- [ ] All guides exist and render correctly
- [ ] Overlays are copy-pasteable
- [ ] No placeholder text ("TODO", "Lorem ipsum") in guides
