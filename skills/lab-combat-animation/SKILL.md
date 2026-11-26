---
name: lab-combat-animation
description: Создание, перенос с референсов, постановка и проверка выразительной 2D/2.5D боевой анимации в Godot Lab; ключевые позы, IK, биомеханика, связные комбо, стилизация, каденция и нативные GIF. Использовать для animation R&D, а не для изменения Project N.
---

# Lab Combat Animation — рабочий skill студии

Версия 1.2 · 2026-11-25. Это накопленный практический опыт, не обученная модель и не универсальный анатомический стандарт.

## Перед работой

- Прочитай корневой AGENTS.md, актуальный docs/MOTION_HANDOFF_RU.md, skills/creature-sdk/SKILL.md и SDK.md/schema. Последние решения владельца приоритетнее исторических сравнений.
- Прочитай [проверенные решения](references/experiment-ledger.md) и [перенос поз](references/reference-to-motion.md). Не начинай новый эксперимент, пока не определил контрольную версию, изменяемую переменную и критерий.
- Работай только в experiment/motion-temporal-rd. Не переноси экспериментальный риг, кожу или клипы в N без явного разрешения. Не меняй upstream, общие runtime/SDK ради обхода ограничений.
- База на момент 1.0: F стилизация, 0.49 C плечи, 0.50 C таз, 0.51a C оболочка. 0.51b C стопы — рабочий эксперимент, 0.51c2 — получено положительное сравнение владельца, но конкретная финальная дорожка и вся техника не утверждены. Не путай повторяющиеся буквы A/B/C разных тестов.

## Рабочий конвейер

1. **Поиск в архиве до авторинга.** Сначала найди подходящие движения/фазы в доступном архиве владельца, предыдущих клипах и материалах Astra; открой конкретные кадры или треки. Сравни направление, опору, замах, контакт и выход. Не ограничивайся именем файла или попаданием одного кадра. Если нет доступа, явно сообщи и не выдавай ручную догадку за перенос. Затем **референс и задача.** Выдели читаемый момент и направление усилия, опорную и атакующую сторону, силуэт, относительные положения суставов. Фото задаёт позу, не тайминг или 3D глубину. Не выдумывай скрытые суставы; маркируй оценки и неизвестное.
2. **Контактная поза.** Построй скелет от опоры и таза к груди, плечам, коленям/локтям и кистям/стопам. Сначала решай целостную позу, потом IK. Проверяй фактические FK точки, не только входные углы. При необходимости сравни 2–3 осмысленных варианта с прежним контролем.
3. **Движение.** Подготовка, загрузка опоры, ускорение, акцент, сбор и выход. Перекрывай фазы; не навязывай обязательное возвращение в idle между ударами. Пассивные конечности должны участвовать в балансе/защите, а не висеть или пересекать силуэт.
4. **Стилизация.** Выразительная поза важнее буквального мокапа. Мокап полезен для естественных переходов; не называй вручную сочинённые движения мокапом. Сначала добейся убедительности без VFX, потом усиливай художественно.
5. **Каденция.** Отдельно от геометрии, хореографии и событий. Сокращение линейных ключей не равно held poses. Не выбирай универсальную частоту по одиночному джебу; сравнивай на комбо.
6. **Проверка.** SDK-валидация, реальные точки sampler, длины костей, опора/пол, суставные углы, акценты, направление к груше и силуэт. Затем настоящий захват Godot и визуальный просмотр. Только человек подтверждает художественную приёмку.
7. **Сохранение.** Запиши коммит, точный источник, вариант, результаты, ограничения, отзыв владельца и следующий шаг в handoff. Обнови этот skill/ledger только если извлечён переносимый урок или изменилось устойчивое решение.

## Приоритеты при проблеме с позой

- Дальняя конечность короткая: сначала позиция её основания и разворот соответствующего пояса; не удлинять кость и не наклонять весь корпус автоматически.
- Неубедительный удар: проверяй всю цепь, опорную ногу и направление колена, а не только попадание endpoint.
- Плохая линия ноги: оценить сгибание по фактическим трём точкам, ориентацию стопы, вынос таза и угол тела. Не переносить числа одного высокого удара на все техники.
- Выпирающие плечи/бедра: отделить геометрию рига от отрисовки; сохранить анимационные данные, сравнить оболочки. Избегать крупных круглых caps в месте крепления.
- Неестественный переход: проверить смену опоры, порядок фаз, пассивную руку, скорость между ключами и изгибы углов; не исправлять только контактный кадр.
- Попадание по груше: статическая груша — визуальная цель, не доказательство столкновения. Допустимый промах в R&D не хуже ложного контакта за счёт растяжения.
- Баланс: положение таза над опорой — кинематический proxy, а не измеренный COM или симуляция сил.

## Вывод и проверка

Активный путь: tools/mocap_style.py → godot/tests/mocap_style.gd → .github/workflows/mocap-style.yml. Godot 4.4.1. Воспроизводимые старые --stage не ломать. При наличии локального Godot запусти непосредственно; иначе один осмысленный CI checkpoint. Проверь SHA, статус, логи (MOCAP_STYLE_OK, отсутствие SCRIPT ERROR), фактический артефакт и сам рендер. Не подменяй нативное изображение схемой.

В чат: реальные GIF ×1.1 и ×0.5, короткая легенда, при необходимости контактный кадр. Fast GIF должен избегать браузерного замедления 10ms кадров; проверяй фактическую длительность и сохраняй кадры ударных событий. Архив редактора не отправлять, пока владелец не попросит. При запросе — минимальное число осмысленных ключей, экспорт JSON, проверка roundtrip и объяснение отличий интерполяции. Базовая анимация может содержать 60Hz запечённые ключи, но это не редакторская версия.

## Как обновлять skill

- Обновляй в том же рабочем цикле, когда появился переносимый результат; не заводи автономные задачи и не обещай фоновые обновления.
- Различай статусы: подтверждено владельцем; проверено технически; рабочая гипотеза; отвергнуто/заменено.
- Новое правило подкрепляй точным коммитом, тестом или отзывом. Старые решения не стирай бесследно: ledger фиксирует, что их заменило. Не записывай единичный удачный угол как биомеханическую норму.
- Храни конкретные настройки и метрики в references, а краткий SKILL.md — как навигацию и порядок действий.
- Если изменяется только документация, не запускай Godot заново ради отчёта; проверь пути и Git diff/содержимое после записи.

## Contact-pose-first (уточнение владельца)
Приоритет поиска — выразительная поза в момент ударного акцента. Полная запись движения полезна, но не обязательна. Сначала архив владельца (особенно Naruto sprite sheets), затем поиск подходящего открытого референса в сети, если в архиве нет подходящей позы. Для каждого удара выбрать конкретный кадр и перенести его на риг, проверить силуэт и FK до сочинения переходов. При наличии нескольких кадров использовать их для chamber/recovery; не требовать полного готового комбо. Не считать хороший контактный кадр доказательством хорошего перехода. Чужие спрайты — визуальный референс, не игровые ассеты для распространения; фиксировать источник и кадр, не коммитить исходные листы без прав.


### Owner presentation preference (2026-11-26)
For subsequent Lab animation comparisons, export normal playback at exactly ×1.0 (not ×1.1), plus slow playback ×0.5. Use the actual source clip duration; label normal playback ×1, and prefer `comparison-1x.gif` for new experiments. This is a presentation/export change, not a change to animation timing or existing historical captures.


## Owner direction 2026-11-26 — 60 FPS hybrid motion
Combat should use full 60 Hz pose evaluation by default. Limited 15/25 Hz exposure is an optional stylistic experiment, not a global requirement. Keep authored attack/contact choreography; use procedural transition, support/IK and secondary physics for adaptation. Separate transition smoothness from strike dynamics; do not smooth away contact or delay gameplay inputs merely for aesthetics. See docs/MOTION_CONTINUITY_075.md for the isolated experiment, not a production runtime change.


## Owner requirement — stable guard recovery (2026-11-26)
Do not use arbitrary clip terminal pose as idle. Maintain a separate stance preference and support state; recover a usable base using deliberate steps and weight transfer, not sliding both feet to an absolute template. Keep authored attacks/60Hz timing, permit procedural adaptation. See docs/STANCE_RECOVERY_078.md; this first grounded test is not a dynamic balance solver.


## Owner requirement — interruptible actions (2026-11-26)
A new allowed movement must transition from the actual displayed pose and its motion/support history, including mid-transition interruption; no mandatory neutral/guard pose in between. Guard recovery only when no command continues motion. Keep authored technique/event timing separate from transition; cancelled future markers cannot fire and completed markers cannot repeat. See docs/ACTION_INTERRUPT_079.md. Actual cancel policy for gameplay is not yet approved.


## Adaptive transitions (owner direction 2026-11-26)
Use movement-dependent correction duration; do not use universal 100ms. Bound by incoming contact/event deadline, keep source and event timeline independent. Measure real transition path and support feasibility; do not reward suppressing deliberate attack dynamics. Lab 080 compares fixed, heuristic and predictive methods; no production default selected.


## Leg regression — owner screenshot 2026-11-26
Validate geometric knee bend (include rig rest offsets) and shin-relative ankle orientation, not raw Euler signs. Avoid forcing unreachable or anatomically invalid IK branch. Preserve source attack/contact poses, 60Hz timing and sparse planning budget. See docs/LEG_CONSTRAINTS_082.md.


## Owner locomotion direction (2026-11-26)
Minimum game movement set: fast walk and fast run. Do not optimize for photorealistic human movement; dynamic stylized silhouette and long expressive sprint steps take priority. Maintain 60Hz, valid anatomy, support and explicit rollback-compatible state. Do not sacrifice style for purely numerical smoothness. Preserve prior profiles; see docs/DISTANCE_GAIT_087.md.


## Принятое гибридное ядро (2026-11-26)
Владелец одобрил правую дорожку Astra Hybrid 0.91. Новое движение разрабатывать на основе `experiment/hybrid-motion-091` и его контракта, а не создавать конкурирующее ядро; старые эксперименты сохранять. Это актуализирует прежнюю инструкцию о ветке. См. docs/HYBRID_MOTION_091_RU.md и docs/MOTION_HANDOFF_RU.md. Интеграция в интерфейс Lab ещё не выполнена. Точные исходники и проверенные ограничения — ledger. Не изменять N и не сливать автоматически.


## Интеграция Lab 1.0 RC1
Рабочая интеграционная ветка `feature/lab-1.0-integration`; актуальные маршруты, исходники и границы описаны в docs/LAB_100_RU.md. Новое ядро Astra — принятое основание, 092 остаётся отдельным стендом. Не маркировать RC1 как финальную 1.0 без технической и художественной приёмки. Для дальнейших R&D выбирать отдельную ветку от актуального принятого интеграционного checkpoint и фиксировать точный SHA.
