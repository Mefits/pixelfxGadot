# N-KB — WORKFLOW

Статус: адаптированные исследовательские рекомендации, не утверждённые изменения. См. [INDEX](INDEX.md) и [полный источник](OPEN_GAME_INDEX_RU.md).

## OG-12 — Регламент разработки ИИ

**Источники:** [game-gates](https://github.com/nexu-io/opengame/blob/main/skills/openmotion-game/references/game-gates.md), [game-flow](https://github.com/nexu-io/opengame/blob/main/skills/openmotion-game/references/game-flow.md), [review-rubric](https://github.com/nexu-io/opengame/blob/main/skills/openmotion-game/references/review-rubric.md).

**Адаптация:** перед каждой задачей агент читает актуальный handoff и выбирает один основной вопрос эксперимента. Определяет 3–5 наиболее рискованных инвариантов, фиксирует baseline, проверяет настоящую сцену и получает доказательства по точному SHA. При неудаче исправляет причину; если выбранная гипотеза не работает, не маскирует недостаток декоративными эффектами. Разделяет результат, гипотезы, ограничения и художественную приёмку. Не вводить обязательную систему документов OpenGame поверх уже существующего handoff.

### Шаблон карточки эксперимента

```yaml
id: <lab-experiment-id>
knowledge_refs: [OG-02, OG-04, OG-05]
question: <один проверяемый вопрос>
baseline_sha: <точный SHA>
candidate_sha: <точный SHA>
scene: <actual Godot scene>
tick_hz: <actual>
input_trace: <fixture>
changes: <что меняется>
locked: <что должно остаться неизменным>
authoritative_fields: <если есть>
invariants: [<3–5 проверок>]
ci: <run URL + result + SHA>
artifacts: <actual PNG/GIF/MP4/JSON links>
mechanical_status: pending
visual_status: pending_owner_review
known_gaps: []
next_decision: <по результату>
```
