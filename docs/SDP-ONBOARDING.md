# SDP (Spec-Driven Protocol) — Onboarding

Проект использует [SDP](https://github.com/fall-out-bug/sdp) как обвязку для работы с AI-агентами (Claude Code, Cursor, OpenCode).

## Быстрый старт

```bash
# 1. Инициализация (после clone)
git submodule update --init --recursive
SDP_DIR=.sdp SDP_REF=main sh .sdp/scripts/install-project.sh

# 2. CLI (опционально, для sdp status, drift, memory, verify)
curl -sSL https://raw.githubusercontent.com/fall-out-bug/sdp/main/install.sh | sh -s -- --binary-only

# 3. Конфиг (если нет .sdp/config.yml)
sdp init --auto
# или: cp docs/sdp-config.yml.example .sdp/config.yml

# 4. Хуки (переустановить после обновления submodule)
./scripts/install-sdp-hooks.sh
# Устанавливает: pre-commit, pre-push (scripts/hooks), commit-msg (.sdp/hooks)
```

## Skills (команды)

| Skill | Назначение |
|-------|------------|
| `@feature` | Планирование фичи → workstreams |
| `@idea` | Сбор требований |
| `@design` | Декомпозиция в workstreams |
| `@build 00-XXX-YY` | Выполнение одного workstream (TDD) |
| `@oneshot <feature-id>` | Автономное выполнение всей фичи |
| `@review <feature-id>` | Ревью качества |
| `@deploy <feature-id>` | Мерж в main |
| `@debug` / `@hotfix` / `@bugfix` | Отладка и фиксы |

## SDP CLI (агенты)

| Команда | Назначение |
|---------|------------|
| `sdp status --text` | Состояние проекта (WS open/completed) |
| `sdp drift detect [ws-id]` | Дрейф код↔документация |
| `sdp memory search "X"` | Поиск по артефактам |
| `sdp verify <ws-id>` | Проверка завершения WS |
| `sdp guard activate <ws-id>` | Перед @build — ограничить scope |
| `sdp log show` | Evidence log |

Конфиг: `.sdp/config.yml`. Полный список: [MEMORIES.md](workstreams/MEMORIES.md) § SDP CLI.

## Структура

```
docs/
├── workstreams/
│   ├── backlog/     # Готовые к выполнению WS
│   ├── completed/   # Завершённые
│   └── MEMORIES.md  # Мета-библиотека, SDP CLI
.sdp/                # Субмодуль SDP (main)
├── config.yml       # Проектный конфиг (sdp init --auto)
.claude/skills -> .sdp/prompts/skills
.cursor/skills -> .sdp/prompts/skills
scripts/hooks/       # Проектные pre-commit, pre-push (Python/Helm)
```

## Workflow

```
@feature "Add X"  →  @oneshot F01  →  @review F01  →  @deploy F01
       │                  │               │
       ▼                  ▼               ▼
   Workstreams      Execute WS       APPROVED?
```

**Done** = @review APPROVED + @deploy completed.

## Quality Gates

- **Pre-commit:** pre-commit (ruff, black, mypy) или ruff
- **Pre-push:** pytest (fast tests)
- **Coverage:** ≥80%
- **Files:** <200 LOC

## Beads (опционально)

Трекинг задач для мультисессионной работы:

```bash
bd ready      # Доступные задачи
bd show <id>   # Детали
bd close <id>  # Закрыть
```

## Ссылки

- [CLAUDE.md](../CLAUDE.md) — интеграция с Claude Code
- [.cursorrules](../.cursorrules) — правила проекта
- [SDP PROTOCOL](https://github.com/fall-out-bug/sdp/blob/main/docs/PROTOCOL.md)
