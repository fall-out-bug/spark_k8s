# Idea: Repository Documentation (Charts + How-To Guides)

**Created:** 2026-01-16  
**Status:** Draft  
**Author:** user + GPT-5.2 (agent)

---

## 1. Problem Statement

### Current State

The repository contains multiple Helm charts (Spark Connect “platform” and Spark Standalone “SA”) plus helper scripts.
However, a DevOps/DataOps user does not have a single concise entrypoint that explains:

- what charts exist
- what each chart deploys
- how to deploy them to a Kubernetes cluster
- how to validate a deployment using the provided smoke scripts

### Problem

DevOps pain: “сложное, дайте чарт”. Without a clear guide, adoption is slow and error-prone.

### Impact

- Harder onboarding for operators.
- Higher support load (“how to install/run/test?”).
- Risk of wrong values/profiles used in production-like environments.

---

## 2. Proposed Solution

### Description

Create a serious repository documentation package (EN + RU, minimal fluff) that provides:

- a “map” of the repo (what lives where)
- chart catalog (what charts exist and what they deploy)
- operator guides for deployment and validation
- clear statements of what has been tested (Minikube), and what is “prepared for” (OpenShift-like constraints)
- SDP workflow explanation and where SDP artifacts are stored

### Key Capabilities

1. **Chart catalog**: `spark-platform` vs `spark-standalone` with enabled components and typical values profiles.
2. **Deploy guides**:
   - Minikube quickstart (what we tested)
   - “any Kubernetes” quickstart (generic)
   - OpenShift notes (prepared for SCC/PSS, but not fully validated unless stated)
3. **Validation / smoke tests**:
   - Which scripts to run and what “green” means
4. **SDP navigation**:
   - how to work with `/idea`, `/design`, `/build`, `/review`
   - where drafts/workstreams/ADRs/issues/UAT live
5. **Values overlays**:
   - copy-pasteable overlays for “any k8s” and “prod-like” (as minimal YAML snippets and/or committed files)

---

## 3. User Stories

### Primary User: DevOps/DataOps

- As a DevOps engineer, I want a clear list of available charts and what they deploy so that I can choose the right chart quickly.
- As a DevOps engineer, I want a minimal step-by-step “from zero” deploy guide so that I can deploy Spark to any Kubernetes.
- As a DataOps engineer, I want to know how to run built-in smoke tests so that I can validate deployments consistently.

### Secondary User: Developers (contributors)

- As a contributor, I want to understand the SDP workflow and documentation layout so that I can add changes consistently.

---

## 4. Scope

### In Scope

- Documentation for **all charts** in `charts/`:
  - `charts/spark-platform`
  - `charts/spark-standalone`
- Clear explanation of repository structure:
  - `charts/`, `docker/`, `k8s/`, `scripts/`, `docs/`
- “How to deploy” for our Spark and helper services only (no generic Kubernetes education).
- Validation commands:
  - `helm lint`
  - runtime smoke scripts in `scripts/`
- Explicit statements:
  - tested in **Minikube**
  - prepared for **OpenShift-like** constraints (PSS/SCC concepts), with clear caveats
- SDP reference (Spec-Driven Protocol):
  - link to `https://github.com/fall-out-bug/sdp`
  - how SDP artifacts are stored in this repo
 - README as **index** that links to detailed guides under `docs/guides/` (EN + RU)

### Out of Scope

- Generic Kubernetes training.
- Non-Spark deployments not managed by this repo.
- Security hardening beyond what is already implemented (docs will describe, not invent new features).

### Future Considerations

- CI documentation checks (render smoke, link checker).
- Separate “production runbook” for OpenShift once validated in real cluster.

---

## 5. Success Criteria

### Acceptance Criteria

- [ ] A “repo map” section exists and is easy to scan (EN + RU).
- [ ] Both charts are documented:
  - what they deploy
  - what values knobs matter first
  - typical deploy commands
- [ ] A Minikube quickstart exists and matches what we actually tested.
- [ ] A generic “any Kubernetes” quickstart exists (no Minikube-specific steps).
- [ ] OpenShift notes exist: “prepared for SCC/PSS”, with explicit limitations/assumptions.
- [ ] `README.md` acts as an index and links to `docs/guides/` (EN + RU).
- [ ] Copy-pasteable values overlays exist (at minimum for “any k8s” and “prod-like”).
- [ ] Validation section exists and references current scripts:
  - `scripts/test-spark-standalone.sh`
  - `scripts/test-prodlike-airflow.sh`
  - `scripts/test-sa-prodlike-all.sh`
- [ ] SDP section exists:
  - explains `/idea` → `/design` → `/build` → `/review`
  - points to `docs/drafts`, `docs/workstreams`, `docs/adr`, `docs/issues`, `docs/uat`

### Metrics (if applicable)

- Operator onboarding: a new DevOps can deploy and validate SA using only the docs (qualitative).

---

## 6. Dependencies & Risks

### Dependencies

| Dependency | Type | Status |
|------------|------|--------|
| Repo structure and scripts remain stable | Soft | Ready |

### Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Docs drift from reality | Medium | High | Keep docs tied to scripts; prefer “run script” over long manual steps |
| Mixing “tested” vs “prepared” claims | Medium | Medium | Use explicit labels (“Tested on Minikube”, “Prepared for OpenShift”) |

---

## 7. Open Questions

- [x] README structure: `README.md` as index, detailed guides under `docs/guides/` (EN/RU).
- [x] Provide copy-pasteable sample `values` overlays for “any k8s” vs “prod-like”.

---

## 8. Notes

- Documentation should be EN + RU and minimal.
- This repository uses Spec-Driven Protocol (SDP): `https://github.com/fall-out-bug/sdp`.

---

## Next Steps

1. **Review draft** — confirm scope and doc structure.
2. **Run `/design idea-repo-documentation`** — create workstreams (docs structure + content).

