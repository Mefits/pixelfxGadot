# Дорожная карта Lab — 2026-11-26

Текущая цель — [Lab 1.0 RC1](LAB_100_RU.md), интеграция накопленных R&D технологий в инструментарий. Принятое ядро Astra 0.91, тело 069 C, бег 090 C; сохранить оба кандидата ткани 074. Реакции 092 C пока отдельный стенд. Не путать исследовательские номера и версии приложения.

- RC1: доступный из меню стенд, сохранение старых маршрутов, нативный smoke и документация.
- RC2: торможение, реакция/баланс и переходы внутри единого ядра, управляемое падение/полёт; сохранение rollback-состояния.
- Авторинг: формат целей и фаз, редактирование процедурных и авторских движений на общем исполнителе (вторая задача Astra отложена).
- Боевая приёмка: два бойца, реальные контакты, прерывания, производительность и replay. Сетевой транспорт и интеграция в Project N — отдельное решение.
- Релиз: переносимая сборка, Windows/Linux, визуальная приёмка и проверка пользователя.

## Историческая дорожная карта PixelFX (не удалять)

# Roadmap and gates
- M0: locked upstream, portable repository and agent contract.
- M1: original JS export, separate color/light, channel parity test against composite, Godot playback and lab. Verify with CI, then inspect rendered screenshots.
- M2: automated original versus Godot capture comparison on dark/bright backgrounds, stress benchmark and paging.
- M3: native Painter, 4x4 Bayer, palette, deterministic RNG, fixed-step simulation; reference pixel tests.
- M4: native Particles/Bits/Lights, then lightning, charge, explosion, acid, slash. Each effect must pass parity and frame-budget tests before more ports.
- M5: actor mask and poses, live collision hooks, authoring UI, installable add-on, versioned documentation.
No milestone is accepted simply because code exists. Record passed/failed/not-run separately. The original JS source is never replaced by a similar algorithm.
