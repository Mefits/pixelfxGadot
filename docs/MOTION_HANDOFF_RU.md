# Передача проекта: Lab 0.45 — 25.11.2026

**Читать первым при переходе в новый чат.** Репозиторий Mefits/pixelfxGadot, активная ветка experiment/motion-temporal-rd. Последний проверенный код Lab 0.45: ef66930557602f33560d08650020bf1aa1e329fa. Этот документ — состояние решений владельца, не обещание готовой игровой анимации.

## Цель и ограничения

Lab — отдельный инструмент производства выразительных боевых анимаций для 2D Project N на Godot. Художественные ориентиры: Naruto Ultimate Ninja Storm (динамика и акценты, не копирование правил боя) и Guilty Gear. Не развивать универсальный генератор ценой качества одного движения. ИИ должен иметь воспроизводимый цикл: референс → позы/тайминг → нативный рендер → визуальный разбор → исправление → валидный SDK-клип. Владелец не хочет вручную выбирать из десятков библиотек, выполнять конвертацию или настраивать Godot. Показывать настоящие GIF в чате, обычный темп первым, затем половинный. Сохранять контрпримеры и контрольные варианты. Не использовать визуальный балл как критерий художественной готовности. Нельзя автоматически вливать изменения в main, старую preview-ветку или N.

## Решения владельца

- Новые правила сгиба суставов 0.44 выглядят значительно лучше. Старая скрюченная стойка и противоположный сгиб ног и рук искажали оценку работы Astra. Это не доказывает универсальную анатомическую корректность для всех ракурсов.
- Чистый мокап естественный, но для красивого аниме-боя его нужно стилизовать. Владелец не хочет сейчас продолжать поиск библиотек и позже допускает захват собственного видеореференса боя в Naruto; сейчас это НЕ задача.
- 0.45 D (гибрид) выбран владельцем: «Вариант Д самый лучший». D — контроль и направление разработки, НЕ финальное утверждение качества.
- Сохранить D без изменений. Следующий эксперимент: шея/плечи, дальняя рука, перенос веса, поворот корпуса; сравнить умеренную, сильную и экстремальную стилизацию на одном и том же ударе. Не переходить к массовому производству клипов до убедительного удара.

## История и проверенные контрольные точки

| Версия | Коммит реализации | Нативная проверка | Результат |
|---|---|---|---|
| 0.42 до Astra | a787373cbec0b55f0d31fd57576311cd1ed40ebf | [45528540353](https://github.com/Mefits/pixelfxGadot/actions/runs/45528540353) | F — усиленные силуэты, старый риг; замороженная preview/lab-039-cadence |
| Astra Motion R&D | локальный архив на базе 0.42, НЕ отдельный Git-коммит | оригинальные GIF в архиве | IK, глубина, upstream 3D, BVH/landmarks, фиксация опоры, поиск поз. Неполный перенос в Git, см. ниже |
| 0.43 | d27a74a7ac81122230573c56461e59d5036bfc2f | [45640492835](https://github.com/Mefits/pixelfxGadot/actions/runs/45640492835/artifacts/15033513367) | Временные метрики и изменение траектории. Подсечка улучшена; прыжок набрал 1.0, но выглядит кукольно |
| 0.44 | af818214fac3618f7d30bc785a9f82762856e732 | [45642696051](https://github.com/Mefits/pixelfxGadot/actions/runs/45642696051/artifacts/15036501239) | Исправленный сгиб, парный удар/реакция, отдельный эксперимент оболочки. Длинная шея остаётся |
| 0.45 | ef66930557602f33560d08650020bf1aa1e329fa | [45656732943](https://github.com/Mefits/pixelfxGadot/actions/runs/45656732943/artifacts/15042302641) | Реальный правый джеб ACCAD, сравнение A/B/C/D, SDK-валидация пройдена |

Артефакты Actions истекают; код и метаданные сохраняются в Git, архивы ниже содержат фактические рендеры. Godot 4.4.1. Не утверждать ручную проверку на Windows или в игровой боевой сцене: её не было.

## Где лежит рабочий код

- `tools/mocap_style.py` — загрузка/декодирование BVH, выбор боковой проекции, выделение отрезка, ретайминг, стилизация, сборка GIF из нативных кадров.
- `godot/tests/mocap_style.gd` — применение целей IK с направлениями сгиба из записи, опорная коррекция, нативный захват, экспорт 4 SDK-клипов.
- `godot/lab/anatomy_rd/ink_readable.gd` — диагностическая оболочка 0.44, не финальный арт. `pose.gd` и `briefs.json` — сравнительный анатомический эксперимент.
- `tools/anatomy_rd.py`, `godot/tests/anatomy_rd.gd` — изолированная проверка стойки и парной атаки.
- `tools/temporal_rd.py`, `godot/tests/temporal_rd.gd`, `godot/lab/temporal_rd/` — прежние гипотезы и отрицательные контрпримеры. Не повторять без новой цели.
- `.github/workflows/mocap-style.yml` — точечный нативный захват на активной ветке; docs-only commit не требует нового запуска.

Воспроизведение из корня, Python с numpy и Pillow, Godot 4.4.1:

    python tools/mocap_style.py --godot godot --out review-045

Если источник уже скачан:

    python tools/mocap_style.py --godot godot --bvh /path/to/Male2_E2_JabRight.bvh --out review-045-local

Linux CI использует флаг --xvfb. Каталог --out должен отсутствовать. Использовать настоящий Godot, не рисовать замену в Python. Зафиксировать код/артефакт одного содержательного этапа, не запускать несколько одинаковых Actions.

## Точный контроль D

Исходник ACCAD / Ohio State University Open Motion Project: Male2_E2_JabRight.bvh, [официальная страница](https://accad.ohio-state.edu/research/motion-lab/mocap-system-and-data), [архив](https://accad.ohio-state.edu/sites/accad.osu.edu/files/Male2_bvh.zip). Лицензия в отчёте 0.45 — CC BY 3.0; сохранить атрибуцию и проверить условия для дальнейшего коммерческого релиза. SHA256 исходного BVH: 8a56bfb4422138f061a0e36148354a43dd62a5b9645cbdf6cee8122e5c40fde8. 86 исходных кадров, шаг 0.0333333 с, выбран отрезок 11–38 включительно, эвристический акцент кадр 24, подготовка кадр 20. Это не реальное измеренное попадание в противника, а автоматически выбранный пик выпрямления/скорости руки.

| Вариант | Длительность | Акцент | Ключи 60 Hz |
|---|---:|---:|---:|
| A RAW | 0.900 с | 0.433 с | 55 |
| B RHYTHM | 0.633 с | 0.333 с | 39 |
| C POSES | 0.900 с | 0.433 с | 55 |
| D HYBRID | 0.633 с | 0.333 с | 39 |

В D ритм [0, .23, .33, .38, .63] секунд сопоставляется с [0, prep, hit, hit, duration] исходного отрезка. Удержание акцента .05 с. Параметры D в variants(): w=exp(-((s-hit)/.075)^2), load=exp(-((s-prep)/.10)^2); tilt +=9*w-8*load; root.x +=2.8*w-1.5*load; hand.x +=.16*w-.11*load; hand.y *=1-.35*w. Пассивная рука пока берётся из источника. Исправление опоры меняло root до 5.99097 px, то есть это ретаргет, не неизменённая запись. Ветка содержит реализацию, не запечённые GIF/SDK-файлы. Для строгого сравнения восстановить D с указанного SHA и сохранить его экспорт отдельно перед изменениями.

## Следующий этап (0.46)

1. Зафиксировать D как контрольный клип/эталонный рендер. Сначала отдельно исправить пропорции шеи и плеч, проверить стойку/силуэт, не менять незаметно исходный контроль. Если меняется оболочка, сравнить старую и новую на одинаковых координатах.
2. Проверить видимость дальней руки, естественный локоть и перенос веса. Учитывать промежуточные суставы, а не только точки кистей и стоп. Избегать внезапной смены полюса около выпрямления.
3. На той же записи сравнить D и три силы стилизации. Явно описать изменения замаха, плеч/таза, пассивной руки и времени; сохранить исходную траекторию там, где она уже хороша. Не делать аниме-стиль простой мультипликацией амплитуды или ускорением всей записи.
4. Одинаковый масштаб, камера и персонаж для сравнимых вариантов; нативный GIF в обычном и половинном темпе. Сначала осмотреть движение, затем метрики. Контроль опоры/длины конечностей, положения суставов, видимости кисти, контактной позы, резких скачков, выходных ключей. Отдельно отмечать художественную оценку и геометрические тесты.
5. Только после принятия владельцем проверить перенос на один другой удар. Потом отдельная боeвая интеграция: симуляция N управляет root world, хитбоксами и событиями, анимационный клип управляет позой. Удар 0.633 с ещё не подходит напрямую для интервала комбо 0.13 с. Не переносить тайминги мокапа в боевые механики без согласования.

## Astra: сохранить, но не смешивать с рабочим runtime

Полный первоначальный архив `Lab042-Motion-RD.zip` (sha256 9dd2a72934c2648a3fa7c0b3b64b70527303306b13c6840561d23cbca5b9ffb7). Подготовленный набор из 27 новых файлов `Astra_Motion_RD_Git_Import.zip` (sha256 c80ffb7d87af34ba0771de63ab7c163e5eb1b7c5e845da5c2fc0cfd98da2b739). Содержит source/ с оригинальными путями, SHA256 manifest и astra-motion-rd-042.patch. **Эти 27 исходных файлов пока не были целиком загружены в Git.** Не утверждать обратное. Для восстановления запросить этот конкретный архив из файлов предыдущего чата/Library, если он не приложен. Полный последний переносимый архив `Lab045-Mocap-Style-RD.zip` (sha256 6ab0f9d73feb2c87fbd318eb257db4e8782194cd6a98e7f00cac6738d87122c9) сохраняет работы Astra и 0.43–0.45. Сам Git не содержит полного portable snapshot оригинального PixelFX; upstream закреплён подмодулем.

При переносе Astra использовать отдельную archive/astra-motion-rd-042 от a787373c или отдельный проверенный commit, без перезаписи существующего R&D. Патч: git apply --check astra-motion-rd-042.patch, затем git apply astra-motion-rd-042.patch. Не распространять сторонние данные без проверки лицензий. Важные пути из архива:
- tools/bvh_landmarks.py, tools/reference_motion.py, godot/lab/motion_rd/compile_landmarks.gd и pose_space.gd: сохранение BVH/landmarks, направления локтей/коленей из реальной записи, опора, упрощение ключей, SDK. 0.45 использует собственный декодер/решатель, не считать его буквальным импортом исходников Astra.
- depth_player.gd, depth_skin.gd, bake_depth.gd, upstream_motion.mjs: сохранить как альтернативы; повторная оценка только при конкретной гипотезе после исправления анатомии.
- motifs.json, ink_actor.gd, search_motifs.py, motif_search.gd: оставить контрпримерами; прежняя метрика не гарантирует движение. Видео → landmarks было написано, но не доказано на быстром боевом видео.
- docs/MOTION_RD.md и MOTION_AGENT.md в исходном архиве: исходный аудит и инструкции Astra, не заменять их новыми выводами.
- Прыжок Astra: CMU_13_11.bvh, 416 исходных отсчётов, 36 ключевых поз, 81 ключ после коррекции; исходник CMU, не путать с ACCAD. Не публиковать исходную запись/производные, пока не проверены условия лицензии и конкретной конвертации.

## Project N (отдельный проект, не изменять)

Mefits/Project-N, experiment/mobility-signs — отдельный геймплейный прототип M6.3, J рывок, K техника, H три удара, лёгкая инерция M4 всегда; урон снижен в 3 раза. AI по умолчанию выключен. Не сбрасывать параметры движения и не внедрять новые клипы без явного решения владельца. В этом R&D работаем только в Lab.

## Короткий запрос для продолжения

«Продолжи разработку Lab 0.46 в Mefits/pixelfxGadot, ветка experiment/motion-temporal-rd. Прочитай AGENTS.md и docs/MOTION_HANDOFF_RU.md; D из 0.45 — утверждённый контроль. Исправь пропорции и сравни три силы аниме-стилизации на том же ACCAD джебе. Покажи настоящие GIF Godot в обычном и половинном темпе. Не меняй Project N, не ищи новые библиотеки, не подменяй художественную проверку метрикой.»

## Дополнение владельца: каденция и сокращение ключей (25.11.2026)
Владелец отдельно заинтересован в сокращении ключей для резких ударов. Обязательный эксперимент 0.46 после проверки пропорций и сохранения D: объединить методы Astra (выделение поз, ограниченная геометрической ошибкой редукция ключей), Lab 0.41–0.42 (индивидуальное удержание/ступенчатая каденция) и 0.45 D (ретайминг и художественная стилизация мокапа). **Редукция ключей и limited animation — разные операции.** Первая приближает исходное движение с интерполяцией и измеряемой погрешностью, вторая намеренно меняет видимый ритм: сохраняет выразительные позы, пропускает часть переходов, удерживает акцент. Не считать простое удаление ключей при линейной интерполяции аниме-стилизацией.

Контроль: неизменный D; после исправления анатомии также создать контроль с той же новой оболочкой/скелетом и без изменения каденции. На одном клипе сравнить 24, 15 и 8 уникальных поз/с (не FPS вывода) и индивидуальное удержание: подготовка более плавная, короткая фаза разгона/удара с выбором выразительных ключей, читаемый акцент, восстановление. Это предложенные уровни, не утвержденные итоговые настройки. Не смешивать силу стилизации и каденцию в одном неконтролируемом эксперименте: сначала принять позы/ритм, затем сравнить каденцию при одинаковой длительности и одинаковых событиях. Для опорных ног и контакта сохранять необходимые ключи, границы фаз и событие удара; оценивать сохранение опоры, конечностей, отсутствие рывков в нежелательных местах. Симуляция, события, коллизии и хитбоксы работают независимо на прежней частоте; не уменьшать игровой tick rate, не менять N. SDK должен хранить корректные hold/step или запеченные выборки; проверить фактический sampler, не предполагать поддержку. Нативный GIF 60 FPS в обычном темпе + половинный; показать число уникальных поз, количество ключей SDK, время фаз, контакт и ограничения. Никаких заявлений о художественной победе до просмотра.

Техническая точка Astra: `godot/lab/motion_rd/compile_landmarks.gd` (pose_threshold по перемещению root-relative joints, фиксация event/support boundaries, деление интервалов по максимальной ошибке фактического CLIPS.sample, затем SDK validation) и `tools/reference_motion.py compile --pose-threshold ... --tolerance ... --plant`. Сначала прочитать эти исходники; применять к текущему D отдельным адаптером, не возвращать старый риг/оболочку. Удержание поз до фиксации стоп может породить дополнительные ключи; считать их отдельно. Старый D 0.42 (limited cadence) и D 0.45 (mocap hybrid) — разные контрольные клипы.


## Архивная ветка Astra — частичный проверенный импорт

Ветка [archive/astra-motion-rd-042](https://github.com/Mefits/pixelfxGadot/tree/archive/astra-motion-rd-042), коммит d279ad1081fdd7147dddaf19ba6f677a9e052e11. Проверены Git blob SHA: 8/8 исходников совпадают побайтово с оригинальным архивом. Сохранены compile_landmarks.gd (удержание, опора, геометрическая редукция ключей), pose_space.gd (IK и 2.5D), bvh_landmarks.py, reference_motion.py (включая видеоадаптер), depth_player.gd, depth_skin.gd, upstream_motion.mjs, docs/MOTION_AGENT.md. Читай их из архивной ветки, не объединяй её автоматически с активной. Ссылка на [манифест](https://github.com/Mefits/pixelfxGadot/blob/archive/astra-motion-rd-042/ASTRA_IMPORT_MANIFEST.json): 27 оригинальных путей с Git blob SHA, из них 19 пока остаются в полном архиве. Ветка не является полной копией Astra и не проверялась новым запуском Godot. Для 0.46 необходимые оригинальные инструменты выделения/удержания и сокращения ключей уже доступны непосредственно из Git. Старый архив Astra_Motion_RD_Git_Import.zip требуется для остальных файлов; не реконструировать их по памяти. Не использовать 2.5D автоматически, это сохранённая альтернатива.

## Lab 0.46a — captured, awaiting owner review
Implementation: b417e5972b2a1329a1948644679110541fcfc785. Native Godot 4.4.1 run [45660400749](https://github.com/Mefits/pixelfxGadot/actions/runs/45660400749), [artifact 15043689333](https://github.com/Mefits/pixelfxGadot/actions/runs/45660400749/artifacts/15043689333). Retrieved and inspected actual review PNG and selected GIF frames. Five validated 39-key clips, duration .63333 s, strike .33333 s; D original and D revised exported payloads identical; exact BVH SHA confirmed. 1200×255 GIFs normal/half, 1.05/2.10 s including presentation holds. Max sampled bone error 0.000003 px, support residual under 0.000005 px; max per-frame joint movement D/E/F/G 5.36/6.04/6.59/7.39 px. The shorter visual neck reads better, but the far arm remains occluded at important moments; F/G show increasingly deep leaning/weight shift, not necessarily better animation. No artistic acceptance claimed. The skin-only head shift does not correct SDK head anatomy. Next: owner reviews the five lanes; refine far-arm silhouette and pole continuity before choosing a pose baseline for the 24/15/8/authored cadence experiment. Do not alter N. Original upstream skill unavailable via submodule fetch in this environment; not edited.

## Решение владельца — F и серии атак (25.11.2026)
F (strength=1.0) выбран как рабочая база, не финальная анимация. G сохраняется как возможная интенсивность тяжёлых/завершающих ударов. Владелец подчеркнул, что в игре удары идут сериями. Не проектировать все клипы как обязательное возвращение в idle: предусмотреть входную/выходную позу, окно передачи инициативы следующей атаке, перенос веса и свободную руку, совместимость опор, возможность отменить восстановление. После оценки каденции провести отдельный нативный тест двух-трёх связанных ударов (не повтор одиночного джеба); сравнить полный возврат в стойку с переходом напрямую. Не переносить 633 мс или предлагаемые окна в игровой N без согласования.

0.46b: на неизменном F сравнить полный клип, 24/15/8 номинальных поз/с, индивидуальные удержания. Событие и границы опоры принудительно сохранены, поэтому фактическая частота может отличаться. Удержание всей визуальной позы с запечёнными почти ступенчатыми линейными ключами (переход 1/6000 с) сохраняет SDK схему без изменения runtime. Отдельно геометрическая редукция F методом Astra с проверкой фактического sampler при 120 Hz, tolerance 0.6 px. Нативный тест и визуальная оценка ожидаются. Сравнение на скорости 1.2 дополнительно к normal/half. N не изменять. Остаточная проблема видимости дальней руки остаётся в плане, намеренно не смешана с каденцией.

### Lab 0.46b — verified cadence capture
Implementation c8160be3852c27cf3d662b3521ec8ffb6fe35d46; Godot 4.4.1 [run 45662352400](https://github.com/Mefits/pixelfxGadot/actions/runs/45662352400), [artifact 15046211009](https://github.com/Mefits/pixelfxGadot/actions/runs/45662352400/artifacts/15046211009). Native capture passed and actual GIF frame sheet inspected. Same 0.63333 s duration and .33333 s strike, same contact wrist across all lanes. Full/24/15/8/authored exposure counts (including terminal pose) 39/16/11/7/13, SDK keys 39/31/21/13/25. Max 60Hz support residual <0.000005 px; does not certify continuous subframe support. Max joint step 6.59/15.71/17.08/20.91/11.79 rig px; authored holds preserve more visible anticipation than uniform 8. Separate Astra-inspired linear compression: 39→18 keys, maximum joint error .495742 px at 120Hz, tolerance .6. Compression is not limited animation. Full normal GIF 1050ms including presentation holds, half 2100ms; generated CI fast GIF 830ms, postprocessed browser-safe review 880ms with every second board frame including contact, no new drawn frames. Review visual cadence before adopting it. Far-arm readability remains unresolved. Next after cadence choice: connected two/three-strike Lab sequence, no N integration. Do not assert artistic acceptance or continuous-time collision correctness.

## Lab 0.47 — first linked combo, owner requested before choosing cadence
Owner found isolated cadence comparison inconclusive; evaluate on a combo. Same F jab through tick 22 (source ACCAD), then authored left cross and right rising uppercut, no idle reset. Second/third strikes are explicit authored IK target edits, NOT new mocap or a verified combat combo. All four cadence lanes share the same pose path, 65 samples, contacts ticks 20/32/46, total 64/60 s. Compare full, 24, 15, individually held; 8 retained in --stage 46b but omitted here to avoid overloading comparison. Lock original feet throughout; retain actual event and support boundaries. No hitboxes, opponent, damage, VFX or N changes. Preview at 1.2x and half speed. Native capture pending. Keep 0.45/46/46b reproducible via --stage. This is a visual prototype, not game timing approval.

### 0.47 verified combo capture
Implementation 6002122848b85780d52fb5fd3d91f236885ada51, Godot 4.4.1 [run 45663429484](https://github.com/Mefits/pixelfxGadot/actions/runs/45663429484), [artifact 15046297645](https://github.com/Mefits/pixelfxGadot/actions/runs/45663429484/artifacts/15046297645). Actual review.png opened; first jab and final rising punch distinct, far-arm cross visibly shorter in projection and partly occluded. Both feet fixed; movement lacks stepping, active depth/shoulder rotation and opponent reaction. All four SDK clips passed, 65/29/18/22 exposure counts incl terminal sample; SDK keys 65/57/35/43. All three event wrist coordinates exactly match across lanes at 60Hz; max support residual <0.000005 rig px, max joint step 10.22/16.61/24.17/27.27 px. Duration 1.06667 s, strike ticks 20,32,46. GIFs actual Godot, 960x255; normal 1480ms, half 2970ms, browser-safe fast 1250ms incl presentation holds (approximately 1.2x). No artistic acceptance or game timing approval. Await owner cadence and combo review; refine far-arm silhouette and stepping/weight transfer before N. No N edits.

## Lab 0.48 — target bag / reach experiment (owner request)
Owner: third blow acceptable, second weak/short; try a mannequin-height punching bag in front so attacks strive toward it, even if they do not reach. Future fast previews ×1.1 (browser-safe minimum 20ms, duration derived from native samples) and half speed as before. Three lanes with same 65 samples / event ticks: A unchanged 0.47 full combo plus stationary bag, B aim wrists toward fixed world targets after support solve, C same aim plus phase-local pelvis/chest and root drive for second strike. First/third corrections deliberately small; cross wrist target x33.5 y-33, bag face x36, uppercut target higher. No hand/bone scaling, no bag collision or reaction, no changes to N, no cadence decision. Record projected reach and residual gap, not a hit claim. Bag shell about 57 rig px tall, same scale in every lane. Native capture pending. Prior --stage options preserved.

### 0.48 verified bag experiment
Implementation a7dfe437e64a1b00f1ecc4b3907064fc7fa7566c, Godot 4.4.1 [run 45664523700](https://github.com/Mefits/pixelfxGadot/actions/runs/45664523700), [artifact 15047190260](https://github.com/Mefits/pixelfxGadot/actions/runs/45664523700/artifacts/15047190260). Retrieved and inspected actual review.png, checked A exported SDK payload equals 0.47 Full exactly. Three valid SDK clips. Horizontal projected fist-tip gap to bag face at second contact A 8.993, B 9.319, C 2.423 rig px. Shoulder x at second contact A/B 3.992, C 10.824; arm extension A 20.820, B/C 20.508, no bone stretch. First/third gaps A 1.170/8.702, B/C 1.516/7.079. C markedly improves reach but body leans and crouches much deeper; owner review needed, no claim of collision or optimal pose. Max support residual <0.000005 px; max step A/B/C 10.222/10.734/11.762 px. GIF 720x255, fast 1350ms (min delay 30ms), half 2970ms including presentation holds. Owner requested 1.1x going forward. Bag fixed; next refine shoulder/weight transfer according to owner feedback, retain third rising blow and F base. No N edits.

## Lab 0.48 editor handoff (owner wants manual editing)
Exported C SDK JSON from exact 0.48 capture, import in launcher library via Import JSON; edits are isolated from fighter banks. Editor adds bag toggle (same 0.48 diagnostic shell and fixed x36 by default for Lab 0.48 named template), bag distance, playback .5/1/1.1, and direct Export edits JSON. Export preserves edited keys, event anchors/times, duration and root; bag position and playback speed are preview-only, not part of SDK JSON. For handoff attach JSON (plus optionally note intended movement and bag distance). Test workflow opens imported C, edits far elbow at second event, exports and revalidates. Source package requires Godot 4.4.1, not a Windows standalone exe. No N change.

## Lab 0.49 — owner diagnosed asymmetric reach; minimal editor clips
Owner requests minimal editor key count next time, identifies far-side reach as fundamental problem. Confirmed rig.gd rest shoulder offsets ±5 x, equal arm length sqrt(116)+sqrt(101)=20.820; hand IK stops at shoulder, cannot translate its anchor. Prefer fix shoulder girdle rather than asymmetric bone scaling. Experiment Lab-only rig_049 uses latent shoulder bar halfwidth sqrt(50), projected x=halfwidth*sin(45°-turn), turn 0..90, thus exchanges lead shoulder at peak without tilting whole torso. Not full 3D, no actual depth collisions or occlusion order changes. Archive Astra pose_space.gd lift is inspiration, not directly reused. Compare A fixed, B centered, C turning, same 0.48 B frame path/aim/clock. New shoulder_turn angle channel accepted by SDK but only experimental rig interprets it; do NOT use exported file in N or legacy runtime. Editor Lab 0.49 templates activate special rig and shoulder turn control. Minimal 16 artist-selected keys including all strike events (not a fidelity guarantee); full baked clips remain for capture. Preview ×1.1/×.5. Native verification pending.
