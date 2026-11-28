# Internal knowledge

Начальные записи из проектной документации; не новый CI.

- Hybrid 0.91: фиксированный тик, снимки, локальная история и переигрывание; ограниченная проверка межплатформенных хешей. [Документ](https://github.com/Mefits/pixelfxGadot/blob/feature/lab-motion-v21/docs/HYBRID_MOTION_091_RU.md).
- Body Raster: caller owns pose; raster consumes explicit geometry, stable IDs and depth. [Контракт](https://github.com/Mefits/pixelfxGadot/blob/feature/lab-motion-v21/docs/BODY_RASTER_CONTRACT.md).
- Box2D: same-platform replay прошёл; cross-platform exact не прошёл. [CI](https://github.com/Mefits/pixelfxGadot/actions/runs/45916872981). Не считать backend пригодным для авторитетного lockstep.

Новая запись: дата, ветка/SHA, сценарий, измерения и артефакты, граница применимости, статус.

## Combat Lab 0.01–0.05 — 2026-11-28

Технически проверено, не художественная приёмка. Все ветки изолированы; код в main не переносился.

- 0.01 [CI 46141700045](https://github.com/Mefits/pixelfxGadot/actions/runs/46141700045), SHA `003b290281340c3293ed966c8757ff605cf9a0c7`: два Hybrid091, относительный swept-contact на маркере, hit/block/miss/trade, буфер, local restore. Один маркер не полноценное active-window. 
- 0.02 [CI 46142216772](https://github.com/Mefits/pixelfxGadot/actions/runs/46142216772), SHA `65cbc764b5b30b74807953dbe864381b223d2449`: A/B/C, jab→kick оставляет 4 свободных тика; число отмен не равно true combo. C имеет больше маршрутов, окончательно не выбран.
- 0.03 [CI 46142825692](https://github.com/Mefits/pixelfxGadot/actions/runs/46142825692), SHA `df2e1f8cb6f087b270cf77ff2d9c90a515c726f0`: pulse/dash/launch; при чрезмерном сближении gap14 удар проходит мимо. 0.04 [CI 46143524447](https://github.com/Mefits/pixelfxGadot/actions/runs/46143524447), SHA `a6404452eef6061ad2a280b01302133a5157735d`: ограничение фактического travel включая инерцию, gap26, dash→jab hit8. Наземный маршрут30 HP; воздушный B/C 43 HP/4 контакта, посадки58/60, один juggle. A 29 HP. Это временные правила, не автоматическое притягивание.
- 0.05 [CI 46143984366](https://github.com/Mefits/pixelfxGadot/actions/runs/46143984366), SHA `cd940fee03480548f8f89fdea50e95ca73140140`, [артефакт](https://github.com/Mefits/pixelfxGadot/actions/runs/46143984366/artifacts/15262802787): 4-тактовое парирование jab28, cross42 наносит14 HP; раннее/позднее парирование пропускает8 HP; pulse31 на рекавери jab наносит10 HP; air escape35 снижает урон43→20 за счёт выхода из геометрии контакта (evades=0). Локальный replay, зеркальные тесты, регрессии001–004, failures=[]; 900 нативных PNG, GIF3с и 180-кадровые MP4 проверены CI, контактный лист осмотрен. Активный C rush/reactive HP100:70, 15:3 команд атак, пассивность бота ограничивает выводы о балансе. Не утверждать превосходство C, финальную экономику выхода, полноценные защитные/воздушные позы, кроссплатформенность или P2P. 
- Общий вывод: отдельно измерять реальный контакт, окно ответа, управление дистанцией и количество команд. Не маскировать проблему геометрии увеличением hurtbox или гарантированным контактом. 0.06 — отдельное исследование компактного управления и отступления; Ability/Choreography параллельны, не изменять их ветки.
