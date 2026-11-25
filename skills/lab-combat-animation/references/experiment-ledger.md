# Журнал переносимых уроков

Состояние на 2026-11-25. Источник чисел: docs/MOTION_HANDOFF_RU.md (ссылки на нативные отчёты и исходники); это не новые измерения. Статусы обозначают степень проверки, а не универсальность.

| Эксперимент | Статус | Урок |
|---|---|---|
| 0.45 D / 0.46 F | Выбор владельца | Гибрид мокапа и ручной стилизации; F рабочая интенсивность 1.0, G возможный тяжёлый удар. Не весь бой должен быть одной интенсивности. |
| 0.46b | Технически проверено | F 39→18 линейных ключей, max error .496 rig px при 120Hz; это компрессия, не каденция. Частоту удержаний владелец не выбрал по одиночному удару. |
| 0.47 | Технически проверено, недостатки | Комбо без idle между ударами; первые/следующие удары разного происхождения. Дальний удар слабый, ноги неподвижны. |
| 0.48 | Диагностика | Направление кулака само по себе не увеличило дальность (gap 8.993→9.319); наклон тела помог (2.423), но дал чрезмерную сутулость. |
| 0.49 C | Выбор владельца | Независимый пояс плеч: gap 9.319→.506, при той же длине рук. Исправлять основание цепи, не растягивать кость. |
| 0.50 C | Выбор владельца | Независимый пояс таза: gap носка 7.114→0 при старом фиксированном ботинке. Это геометрия, не попадание. Биомеханика ещё неубедительна. |
| 0.51a C | Выбор владельца | Одинаковые анимационные payload; fitted оболочка убрала выступы бёдер/плеч. Некоторая угловатость остаётся. |
| 0.51b C | Технически проверено, рабочая база | Отрыв пятки 3.18 px, toe residual .355 px; движение голеностопа с фиксированным носком. Баланс не решён. |
| 0.51c | Заменено улучшением | Вначале входной угол груди не дал нужного наклона линии корпуса; исправлено по FK. Даже 58° lean/40° kick оказались далеки от желаемого силуэта. |
| 0.51c2 | Положительный отзыв владельца, конкретный финальный вариант не выбран | Чистая линия ноги и более собранная поза существенно улучшили впечатление. Сохранять для дальнейшей проверки. |

## Проверенный пример: высокий удар по фото

Оригинал — предоставленное владельцем фото с высоко поднятой ногой, заметным наклоном корпуса и почти вертикальной опорной ногой. Стопа опорной ноги обрезана. Не сохранено в Git; поза реконструирована вручную, не автоматическим landmark detector. Уточнение владельца: нужен более ровный угол и лёгкий наклон вперёд; в тесте это предварительно истолковано как вынос таза, меньший противонаклон и подготовительное движение вперёд. Не утверждать, что смысл окончательно установлен.

0.51c2 (refine051c в tools/mocap_style.py) — три дорожки одного комбо:

| Фактическая метрика | A старый | B aligned | C forward drive |
|---|---:|---:|---:|
| Наклон назад, ° | 58 | 49 | 34 |
| Подъём ноги, ° | 40 | 40 | 40 |
| Сгибание ударного колена, ° | 22.957 | 8.878 | 8.878 |
| Сгибание опорного колена, ° | 33.447 | 17.734 | 14.377 |
| Вынос бедра относительно голеностопа, rig px | .8 | 1.8 | 2.7 |
| Max toe residual, rig px | .706 | .354 | .354 |
| Горизонтальный зазор обуви до груши, rig px | +3.577 | -.908 | -3.192 |

Отрицательный зазор = визуальное пересечение статической груши, не физический контакт. Max bone error 3.82e-6 rig px, max sole penetration 1.79e-6 rig px. Атакующий ray .997 длины цепи в B/C; не применять это ко всем ударам. Три события в 20/38/60 ticks при 60Hz, 77 samples; тайминг тестовый. Фото не задаёт его.

Доказательство: commit 368ccda853774b300dc16cd840b333f5f0a0e5bd, [run 45675257826](https://github.com/Mefits/pixelfxGadot/actions/runs/45675257826), [artifact 15051751638](https://github.com/Mefits/pixelfxGadot/actions/runs/45675257826/artifacts/15051751638). Отзыв владельца после показа: «Воот, же сильно лучше». Ассистент предпочёл C; это не отдельное утверждение владельцем именно C. Следующий шаг — новые референсы, chamber/выброс/recovery, баланс и силуэт. Не переходить к N.

## Технические свидетельства

- 0.46b: [run 45662352400](https://github.com/Mefits/pixelfxGadot/actions/runs/45662352400).
- 0.49: [run 45667571240](https://github.com/Mefits/pixelfxGadot/actions/runs/45667571240). Editor startup fix 0a6eb6cfcc2e1b8a1f033a9f2a403b4b9d8dbae0.
- 0.50: [run 45669465344](https://github.com/Mefits/pixelfxGadot/actions/runs/45669465344).
- 0.51a: [run 45671156961](https://github.com/Mefits/pixelfxGadot/actions/runs/45671156961).
- 0.51b: [run 45671820298](https://github.com/Mefits/pixelfxGadot/actions/runs/45671820298).
- 0.51c: [run 45673439332](https://github.com/Mefits/pixelfxGadot/actions/runs/45673439332).

## Открытые вопросы

Динамическая опора и COM, анатомические joint limits, depth/occlusion, лопатки, передача импульса между поясами, целостность переходов, каденция и художественные деформации. Не считать их реализованными. Не обобщать метрики одного удара на универсальные ограничения.

## 0.52a2 — support-release discontinuity (technical evidence, not artistic acceptance)
When switching a planted foot to swing, authored ray may differ drastically from the last actual world-space ankle. In 0.52a B the release jumped 24.73 rig px in one sample. 0.52a2 B blends from the previous actual planted ankle to the free solution over six ticks while ramping support-root adjustment; bounds swing ray norm (not just its x component) and corrects pelvic lead. Max adjacent joint step falls to 11.74px, static bag overlap 8.00→.65px; contact knee flexion .34→19.87deg. These simultaneous changes are diagnostic, not proof of individual causal effects. Check release/landing continuity explicitly before applying artistic holds; C holds raise max step to 21.04px. A smooth endpoint transition can still generate a poor intermediate silhouette; inspect both. [Native run](https://github.com/Mefits/pixelfxGadot/actions/runs/45678557967), implementation 215615abcc73739071945e5e1bb0e5926ca68ea8. Await owner assessment.
