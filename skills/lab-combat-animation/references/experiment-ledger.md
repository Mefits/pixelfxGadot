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

## 0.53a — six-tile reference locomotion (technical evidence)
Owner supplied six Naruto run tiles, three repeating silhouettes with swapped leg roles. Direct manual projected segment-angle reconstruction on fixed-length rig preserves key silhouette independently of endpoint IK. A six poses, B continuous interpolation, C twelve exposures, exact closing pose. Separate source timing (unknown) from authored cycle (0.6s). At key samples variants identical; choose cadence by motion review, not static sheet. In-place floor correction from rotated sole prevents penetration, but does not ensure world-space no-slip; do not use it as proof of locomotion integration. [Native run](https://github.com/Mefits/pixelfxGadot/actions/runs/45682325807). Artistic acceptance pending.

## 0.54a — original renderer baseline
Unmodified locked PixelFX JS rig via verified QuickJS artifact, endpoint retargeting of 0.53a C; actual capture proves renderer works in Godot, but geometry and pixel resolution differ from Lab. Volume and per-pixel depth are real; armor seams remain. Preserve exact Lab joint poses in next skin comparison rather than interpreting endpoint retarget mismatch as a renderer flaw. [Native run](https://github.com/Mefits/pixelfxGadot/actions/runs/45684752375). Artistic approval pending.

## 0.54c — first native organic skin comparison
Same Naruto Run pose data, original C++ reference versus fuller organic geometry with seams disabled at density 1 and 3. B/C share geometry. Actual capture C visibly reduces stair-step contour; disabling all seams can lose depth cues and joins across depths are not supported. Do not call it seamless everywhere. Preserve unchanged FK and compare density independently of shape. [Native run](https://github.com/Mefits/pixelfxGadot/actions/runs/45692175229), a484b69476a1f941b27d9f2a98baa3627432c518. Artistic approval pending.

## 0.54d — isolate raster density and normalize outline
Use same organic primitives at densities 1/2/3/4; match nominal outline in rig space by outline_pixels=density, display scale=3/density. Black outline is owner preference, no artificial internal seams. At current preview scale x3→x4 gives small visual gain but kernel p95 1.758→3.231ms on same Linux capture. Density is configurable, not permanent artistic decision. [Native run](https://github.com/Mefits/pixelfxGadot/actions/runs/45694757882). Await owner review.

## 0.55a — procedural character geometry
Owner chose density ×3, black outline 3 raster px, adjustable later. A fitted, B shinobi vest, C loose costume use same FK and material/volume recipes in body_style_055.gd. Native Godot capture passed, actual review inspected. More clothing volume changes silhouette without reauthoring the animation; small details are obscured by pose, and rigid scarf is not cloth physics. Test neutral and combat poses before art acceptance. [Run](https://github.com/Mefits/pixelfxGadot/actions/runs/45695496484). Await owner review.

## 0.55b — character-specific geometry test
Classic Sasuke Part I as fan-art reference. Native procedural recipe adds material/volume details to unchanged FK. Recognizable overall silhouette and palette in actual Godot capture; hair, high collar, angular clothing cut and face still need art refinement. Fixed camera crops high-kick extremity; avoid interpreting as geometry failure. Density 3, outline 3 retained. [Run](https://github.com/Mefits/pixelfxGadot/actions/runs/45696364357). Owner review pending.

## 0.55c — separate garment geometry from anatomy
Owner pointed out curved neutral legs and balloon-like clothing. Corrected only neutral pose using fixed rest offsets; old pose retained. New native cut_tube gives tapered flat axial ends and adjustable cross-section (2/4 in comparison), preserves z buffer. Actual Godot image shows clear flatter shorts and cuffs, but shoulder gaps and excessively rigid shirt need correction. Do not interpret static pose approval as dynamic acceptance. [Run](https://github.com/Mefits/pixelfxGadot/actions/runs/45697691674). No rig/N changes.

## 0.56 — connected surface prototype
Owner rejected 0.55c and emphasized that rounded anatomy attachments also need work. Native triangle input works with common Z-buffer and outline; old oracle passed. Pose-space strips remove shoulder/hip bulges and are faster to rasterize, but still show thin neck/torso and angular pelvis transitions. This is proof of raster architecture, not artistic acceptance or full skinning. Next investigate indexed bind-pose mesh, explicit weights and joint correctives rather than more separate primitives. See docs/BODY_SURFACE_RD.md and [native run](https://github.com/Mefits/pixelfxGadot/actions/runs/45699553309).

## 0.57 — weighted skin test
Generic indexed mesh with 2-bone weights, bounded correction on elbow/knee rows; native capture passed. Art not accepted. Bind identity exact; 17.54 mean projected orientation reversals and max edge ratio 56.09 (diagnostic, short rest edges amplify). C lowers mean collapsed faces 1.97→1.59 but does not fix shoulder/hip/neck distortion. Do not equate zero bind error with good deformation. Recommend architecture work on anatomical joint frames, depth and corrective constraints before clothing. [Run](https://github.com/Mefits/pixelfxGadot/actions/runs/45700158471).

## 0.59 — anatomical loft profiles
Owner authorized three anatomy variants on Astra 0.58. OLD exact 0.58; A lean, B athletic, C anime. Shared shortened visual neck (head geometry only), trapezius and hip profiles, flat sole foot loft. Native 192 pose test passed, 19 pose volume proxy and actual captures verified. Silhouettes connected, proportion differences subtle; shoulders and pelvis still have visible shading seams. Do not conflate geometric overlap with seamless normals. Preserve render-head offset when adding details. [Run](https://github.com/Mefits/pixelfxGadot/actions/runs/45704261733). No owner approval yet.

## 0.60 — reference-guided pelvis
Owner identified narrow waist and laterally attached thighs. Manual front silhouette measurements documented in docs/body-pelvis-060-reference.json; 3/4 qualitative only. OLD 059 C, A broadened trunk and hip, B additionally inserts proximal thigh with inward width offset and reduced local depth bias. 192 native poses verified; B min pelvic overlap 26.807 vs 18.652 baseline (19-pose sample), zero disconnected masks, but central lower torso protrudes in extreme kick and shading seams remain. Do not equate overlap with smooth shading. [Run](https://github.com/Mefits/pixelfxGadot/actions/runs/45707647719). Owner review pending.

## 0.61 — isolate joint shading
On 0.60 B, same-ray normal mixing only between explicit linked same-material lofts with near front depths. Opt-in depth band .65/1.4 rig units. Verified exact depth/ownership/material/frame/alpha invariance across 192 native poses. Median RGB changes only 22/54.5 pixels; visual improvement subtle, central hip still segmented. Native raster p95 1.679/1.904/1.909ms. Do not mistake blending normals for geometry union. [Run](https://github.com/Mefits/pixelfxGadot/actions/runs/45709346263). Owner review pending.


## 0.62 — geometry, not shading (pending)
Owner rejected 061 lighting. Test same-ray bounded smooth maximum for explicit pelvis connections on 060 B; preserve original mask, ownership and FK. Distinguish corrected front depth from 3D union, no silhouette expansion. Recompute normals from geometry, preserve lighting model. Compare .9/1.8 rig-unit bands, then reference digitization and rig audit. No aesthetic or technical acceptance yet.

0.62 reference audit: explicit slice data and source-derived trunk/root check in docs/BODY_PELVIS_062_DIAGNOSTIC.md. Projected root near trunk edge at extreme turn; visual z proxy distinct from real FK. Never infer actual joint centers from silhouette; do not treat trunk-only containment as whole-body intersection.


### 0.62 native verification
Implementation 4bce0007918a166b689f4f9d95ad81ee621d05ef; [run 45711989886](https://github.com/Mefits/pixelfxGadot/actions/runs/45711989886), [artifact 15067698113](https://github.com/Mefits/pixelfxGadot/actions/runs/45711989886/artifacts/15067698113). Native oracle/Loft tests, native build, frozen FK, 061 regression capture and 062 capture steps passed. Actual Godot 4.4.1 BODY_062_OK, 192 poses, max FK error 5.3948e-6; zero disconnected frames and mask changes, original part/material/frame/alpha and closure preserved. B/C max front-depth gain .22495/.44995 rig units; median changed depth pixels 170/330.5, RGB 17/34, p95 RGB 33.45/66.45. p95 raster A/B/C 1.8768/2.8893/3.1205 ms; prepare .2489/.274/.2899 ms; debug bridge .4884/.4717/.9293 ms (Linux CI, not owner hardware). GIFs verified 864x266, 94 exposures each, 2850/6270ms. Actual stand, enlarged pelvic crop and five pose sheet inspected. B slightly softens bright lateral stripe; C makes small patchy shading, still obvious separate thighs, same narrow silhouette and low pelvic bulge in kick. Front smooth maximum does not improve silhouette and has appreciable overhead. Do not continue tuning it as primary solution. Default off; owner art review pending. Next use measured reference profile and separate visual proxy experiment per diagnostic doc. No changes to rig, clips, Project N, lighting model or original modes. No merge.


## 0.63 — anatomical envelope vs visual hip roots (pending CI)
Owner agreed after 062 to stop coefficient tuning. A exact 060 B; B reference-guided trunk lower section and medially biased proximal thighs + shorter central pelvis in raised-leg poses; C same B section rows with render-only thigh origin interpolated 27% toward true hips XY, 22% toward zero depth (and linked connector endpoint), knee endpoint and all non-pelvis primitives exact. Reference width targets are combined envelope, not individual radii or measured bone centers; depth remains art estimate. No smooth union or normal blend. Tests: 192 historical poses, original FK, loop closure, bounds, unchanged unrelated primitives/knees, bounded proxy displacement, geometry and mask changes, independent interval metrics, separate diagnostic turn45 stance and source FK/visual axes over actual capture. No rig, clips, N, C++ or merge. Await actual results before selecting variant.


### 0.63 native verification (owner art decision pending)
Implementation 8bcea0142cde1bf7231a6698511d2906fd1ddca2; [CI 45712790233](https://github.com/Mefits/pixelfxGadot/actions/runs/45712790233), [artifact 15067638883](https://github.com/Mefits/pixelfxGadot/actions/runs/45712790233/artifacts/15067638883). Godot 4.4.1 BODY_063_OK, 192 poses, max error versus frozen FK 5.3948e-6, source FK unchanged, loop closure exact; unrelated primitive dictionaries and knee endpoints identical, B/C section rows equal, original outline/light. Actual stand, pelvis crop, combat sheet and skeleton overlay inspected. GIFs 864x266, 94 exposures, 2850/6270 ms verified. 19-pose independent interval sample: visual thigh roots outside trunk-only volume A/B/C 16/16/0 of 38; max excess .893/.501/0; minimum pelvic overlap 26.807/26.279/29.328 rig px^3, all masks connected and interval oracle matches captured masks. C maximum proxy displacement XY 1.080001, Z .725969; median silhouette differences B/C 135/258.5 pixels versus A, median body area 4631/4486/4397 pixels. Raster p95 A/B/C 1.646/1.588/1.575ms, prepare .223/.206/.270ms, debug bridge .278/.746/.842ms, CI Linux, not laptop and no speedup claim beyond measured raster. C makes hips more continuous and slimmer; central lower trunk still appears as separate flat shade patch and bulges remain in high kick, visually not a solved anatomical body. B alone still looks segmented; C is a candidate, not owner-approved. Further improvement likely requires localized pelvic envelope/central-to-thigh transition and comparison of shape in flexion, not 062 union tuning or altering game rig. No N or Astra involvement, no merge. Diagnostic overlay colors white FK, pink visual axis, cyan trunk, gold hip, green thigh. Side angle is 45-degree projected girdle diagnostic, not independent 3D reconstruction.


## 0.64 — shoulder girdle on approved 063 C (pending CI)
Owner explicitly approved 063 C ("Шикарно именно то что я хотел увидеть"; buttocks slightly thin, leave for now), requested shoulder correction. Freeze pelvis, legs, all FK/IK, clips and lower trunk rows <= .70. A exact 063 C; B adjusted clavicular shelf/trapezius and neck base, raised medial shoulder connector with tapered distal end, proximal upper-arm profiles; C same B with render-only root moved 24% toward chest in XY and z scaled .76, elbow and all distal arm geometry unchanged. All parameters art hypotheses, no reconstructed shoulder depth or anatomical joint centers. No normal blend/union. 192 original poses plus four diagnostic captures (45-degree girdle and three raised-arm angles), overlay of FK, visual axes and loft contours. Distinguish root containment in trunk-only interval from actual connected shoulder anatomy. No changes to native kernel or N, no merge.

### 0.64 native verification (owner art decision pending)
Implementation a3ba1da801d27b032003ede0640b5d65ecd3fad6; [CI 45714025048](https://github.com/Mefits/pixelfxGadot/actions/runs/45714025048), [artifact 15069485847](https://github.com/Mefits/pixelfxGadot/actions/runs/45714025048/artifacts/15069485847). Godot 4.4.1 BODY_064_OK: 192 historical poses plus four diagnostic captures, source FK unchanged, frozen FK maximum error 5.3948e-6; no disconnected masks, interval oracle mask difference zero. Approved 063 C lower body primitives and lower trunk profile rows preserved; elbows and distal parts identical. Actual stand, shoulder close-up, raised arm sheet and combat sheet inspected. GIFs 864x266, 94 exposures, 2850/6270 ms verified. Root outside main trunk-only volume in 19-pose interval sample A/B/C 38/38/2 of 38; of those, projected roots outside XY 9/8/0; C max residual depth excess .236, proxy displacement XY 1.224, Z .792 rig px. Minimum shoulder connection interval overlap A/B/C 13.354/7.189/9.921 rig px^3: C improves B but remains below A, so do not equate root containment with better attachment everywhere. Raster p95 A/B/C 1.622/1.591/1.576 ms, preparation .253/.246/.312 ms, debug bridge .286/.498/.745 ms on Linux CI, not owner hardware. Neutral C has a cleaner continuous neck-to-shoulder line, fewer separate shoulder humps, narrower silhouette. B retains notches around neck/shoulders; C still has a stylized steep trapezius slope and some visible shading separation in combat. Raised-arm poses remain connected; no claim of fully anatomical 3D shoulder mechanics. Await owner choice. No Astra, N, native kernel or rig changes. Owner approved 063 C explicitly; buttocks noted slightly thin, deferred at owner's request.


## 0.65 — isolated trapezius refinement (pending verification)
Owner agreed with 064 visual critique including steep trapezius. Use 064 C as working control; not yet explicit final shoulder art acceptance. A exact 064 C; B changes only upper trunk rows above .84, broadening clavicular shelf at t=1.04/1.09 and retaining neck endpoint; C same B plus bounded pose-aware upward bias and depth increase at central shoulder connector sections. No endpoint/root moves, no change to neck or arm primitives, no lower-body/rig/lighting/native-kernel changes. C depth correction is local geometric profile (not normal blend); not full 3D. Preserve previous 192 poses + four diagnostic poses, validate unchanged axes and all unrelated geometry; compare actual Godot capture and sampled overlaps, not root containment alone. Owner previously approved 063 C pelvis, defer buttocks. No N or Astra or merge.

### 0.65 native verification (owner art decision pending)
Implementation 7166f8335ae4cdbe0d5e40351a23b388d983478d; [CI 45715284604](https://github.com/Mefits/pixelfxGadot/actions/runs/45715284604), [artifact 15068879691](https://github.com/Mefits/pixelfxGadot/actions/runs/45715284604/artifacts/15068879691). Godot 4.4.1 BODY_065_OK, 192 historical poses + four diagnostics, max frozen FK error 5.3948e-6; all axes unchanged, unrelated primitives unchanged, no disconnected masks and interval oracle mask difference zero. 19-pose sample A/B/C root outside counts 2/0/0 of 38, minimum shoulder overlap 9.920625/9.920625/11.259522 rig px^3. C improves overlap by 13.5% versus A, still below pre-064 A (13.354). B/C mask difference stats identical (median 19, max 30 px versus A); C additional connector changes predominantly internal/visible shading, not a materially different outer contour. Raster p95 1.611/1.591/1.611ms; preparation .299/.292/.382ms; debug bridge .320/.557/.825ms; Linux CI, not laptop. Actual stand, shoulder closeup, raised arm and combat sheets inspected. GIFs 864x266, 94 frames, 2850/6270ms. Visually B/C slightly fill upper shoulder silhouette, C softens the isolated shoulder highlight into broader patch but overall trapezius remains conspicuously sloped; improvement modest and not solved. Potential next experiment: isolate proximal upper-arm visual profile near shoulder to create an actual shoulder crest, not further increasing central trapezius thickness. Do not change source FK or owner-approved pelvis. No N, Astra or merge. Owner agreed with previous visual critique but did not explicitly approve 064 C as final; awaiting selection.
