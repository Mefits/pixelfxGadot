# Internal knowledge

Начальные записи из проектной документации; не новый CI.

- Hybrid 0.91: фиксированный тик, снимки, локальная история и переигрывание; ограниченная проверка межплатформенных хешей. [Документ](https://github.com/Mefits/pixelfxGadot/blob/feature/lab-motion-v21/docs/HYBRID_MOTION_091_RU.md).
- Body Raster: caller owns pose; raster consumes explicit geometry, stable IDs and depth. [Контракт](https://github.com/Mefits/pixelfxGadot/blob/feature/lab-motion-v21/docs/BODY_RASTER_CONTRACT.md).
- Box2D: same-platform replay прошёл; cross-platform exact не прошёл. [CI](https://github.com/Mefits/pixelfxGadot/actions/runs/45916872981). Не считать backend пригодным для авторитетного lockstep.

Новая запись: дата, ветка/SHA, сценарий, измерения и артефакты, граница применимости, статус.