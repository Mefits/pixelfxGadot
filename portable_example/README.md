# Creature & PixelFX — экспорт шаблона v0.31

Распакуйте архив в новую папку. Откройте project.godot в Godot 4.4.1 и нажмите F5. A/D — движение, W — прыжок, E — способность, R — сброс. Для VFX и клипов пример воспроизводится автоматически.

- content/template.json: выбранный шаблон, все его вложенные пресеты и параметры, пригоден для обратного импорта в библиотеку.
- content/manifest.json: версия, тип, список файлов.
- addons/creature и addons/pixelfx/native, composer: общий независимый GDScript runtime.
- example/: минимальный пример. Нет редакторов, исходного JS-каталога, атласов или обязательной DLL.

## В существующую игру

Сначала проверьте пример в отдельном проекте. Затем перенесите addons/ и content/template.json, сохранив пути res://. Не перезаписывайте существующие файлы без сравнения версий. project.godot и example/ переносить необязательно.

API: res://addons/creature/kit_api.gd. API.read(path) проверяет шаблон; API.create_creature(entry, at, obstacles) создаёт физическое тело; API.attach_ability(entry, creature) проверяет совместимость. Вызывайте creature.advance(dt, axis, jump), creature.special.begin(creature, target) и drain_events(). Мишень — общий словарь id, p (Vector2), r, hp; при захвате runtime обновляет p. Адаптируйте к своим объектам и синхронизации; физика использует статические Rect2, не произвольные Godot CollisionShape2D.

Для анимации: API.animation_bank(entry) возвращает банк с выбранным клипом; CLIPS.sample(clip,t) и RIG.evaluate(pose). Для гуманоидной способности: API.compile_ability(entry) либо fighter.set_ability(entry.payload), combat.step(dt, input_a, input_b). Для эффекта: RENDERER.render(painter, entry.payload, t, anchors, floor_y, provider); surface.present() после заполнения цветового и светового буферов. Все примеры смотрите в example/demo.gd.

Физическая симуляция — 120 Гц. Скин примера диагностический, не готовая графика игры. C++ не входит в минимальный пакет; это чистый GDScript fallback. Для ускорения используйте совместимую сборку полного инструментария. Сохраните приложенные лицензии. Экспорт не изменяет ваш исходный игровой проект.

Для ИИ и разработчиков: addons/creature/SDK.md, template.schema.json и sdk_validate.gd содержат строгий контракт авторских данных и диагностические проверки. CLI будет добавлен отдельно.
