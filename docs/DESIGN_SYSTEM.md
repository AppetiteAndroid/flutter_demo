# Design system handoff

Designers should create Figma Variables using these exact semantic paths.
Flutter uses the corresponding camelCase `AppColors` property. Rebrand by
changing `AppPalette` primitives and the two `AppColors` mappings—not screens.

| Figma | Dart | Light | Dark |
|---|---|---:|---:|
| brand.primary | brandPrimary | #635BFF | #8B85FF |
| brand.secondary | brandSecondary | #06B6D4 | #22D3EE |
| background.primary | backgroundPrimary | #FFFFFF | #020617 |
| background.secondary | backgroundSecondary | #F8FAFC | #0F172A |
| surface.primary | surfacePrimary | #FFFFFF | #0F172A |
| surface.secondary | surfaceSecondary | #F1F5F9 | #334155 |
| surface.elevated | surfaceElevated | #FFFFFF | #334155 |
| text.primary | textPrimary | #0F172A | #F8FAFC |
| text.secondary | textSecondary | #334155 | #CBD5E1 |
| text.tertiary | textTertiary | #64748B | #64748B |
| text.inverse | textInverse | #FFFFFF | #0F172A |
| text.disabled | textDisabled | #64748B | #64748B |
| icon.primary / secondary / inverse / disabled | iconPrimary / iconSecondary / iconInverse / iconDisabled | #0F172A / #64748B / #FFFFFF / #CBD5E1 | #F8FAFC / #CBD5E1 / #0F172A / #64748B |
| border.primary / secondary / focused | borderPrimary / borderSecondary / borderFocused | #CBD5E1 / #F1F5F9 / #635BFF | #334155 / #0F172A / #8B85FF |
| status.success / warning / error / info | success / warning / error / info | #22C55E / #F59E0B / #EF4444 / #3B82F6 | same |
| state.disabled / pressed / overlay | stateDisabled / statePressed / stateOverlay | #F1F5F9 / #4338CA / #00000014 | #334155 / #4338CA / #FFFFFF24 |

Typography follows Material roles: display.large 57/64 w400 -0.25; display.medium
45/52 w400 0; headline.large 32/40 w400 0; headline.medium 28/36 w400 0;
title.large 22/28 w400 0; title.medium 16/24 w500 0.15; title.small 14/20
w500 0.1; body.large 16/24 w400 0.5; body.medium 14/20 w400 0.25;
body.small 12/16 w400 0.4; label.large 14/20 w500 0.1; label.medium 12/16
w500 0.5; label.small 11/16 w500 0.5. The default family is the system font;
licensed Gilroy is primary and Cera Round accent when installed.

| Scale | Values |
|---|---|
| spacing | xxs 4, xs 8, sm 12, md 16, lg 24, xl 32, xxl 48 |
| radius | xs 4, sm 8, md 12, lg 16, xl 24, full 999 |
| icon | small 16, medium 24, large 32 |

Rebranding checklist: update primitive palette; review both semantic mappings;
verify contrast and component states; update Figma Variables; run Light/Dark
theme tests; install fonts only with redistribution rights.
