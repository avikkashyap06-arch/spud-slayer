# SPUD: WRATH OF THE SOIL

2D side-view action-RPG boss rush for **Godot 4.3+** (GDScript, GL Compatibility renderer).
Everything is drawn procedurally and all sound effects are synthesized at startup, so there are **no asset files**.

Open the folder in Godot 4.3+ and press **F5** (main scene: `main.tscn`).

## Controls (modelled on Runic Curse)
| Action | Keys |
|---|---|
| Move | A / D or arrows |
| Jump (double jump after Act I) | Space / W / Up |
| Drop through a platform | S / Down + jump |
| Roll (i-frames) / Air Dash (after Act I) | Shift or K |
| Root-Blade slash | Left mouse, J or Z |
| Runes (quick slots 1-4) | 1 2 3 4 (or U I O L) |
| Pause | Esc (Q = back to title) |
| Menus | W/S or arrows, Enter |

Gamepad: stick, A jump, X slash, B roll, Y / LB / RB / R3 runes.

Slashing, rolling and dashing cost **stamina**; runes cost **rune energy** (fills slowly, and from hits and kills).

## Structure
- Prologue: The Throne of Light (20 s or 3 ankle hits, Judgment Beam, fall, title card)
- Act I (bosses 1-25): Ash Pits 1-10, Infernal Citadel 11-24, Satan 25 (Hellfire Wings: Double Jump + Air Dash)
- Act II (bosses 26-50): Outer Clouds 26-39, High Sanctuary 40-49 (Seven Archangels, last three return Wrathful), God 50
- Roots of Renewal shrine between every boss: spend Soul Ash on Max HP, Stamina, Attack
- Runes: Bramble Spike (start), Brimstone Wrath (after boss 4), Petrified Skin (after boss 8), Divine Smite (after boss 26)
- Every boss summons waves of weak creatures (16 kinds, 8 Hell / 8 Heaven). Kill them for Soul Ash, rune energy, and sometimes a healing sprout.
- Progress is saved at every shrine (`user://spud_save.json`).

## Files
| File | What it is |
|---|---|
| `scripts/lore.gd` | **The lore bible**: premise, exact quotes, runes, 50-boss table, HP/difficulty formulas |
| `scripts/main.gd` | game flow / state machine, save, input map |
| `scripts/boss.gd` | boss AI (11 attack patterns), phases, all boss art |
| `scripts/minion.gd` | the 16 weak creatures |
| `scripts/player.gd`, `hazard.gd`, `pickup.gd` | Spud, projectiles/zones, drops |
| `scripts/arena.gd`, `ui.gd`, `fx.gd`, `sfx.gd` | backgrounds, HUD/menus, particles, sound |

## Tuning
- **Fight length**: `Lore.TARGET_FIGHT_SECONDS` (default 300 = ~5 minutes per boss for an average player). Final bosses use 1.5x.
- Creature frequency: `minion_t` logic in `boss.gd` (`_spawn_minion_wave`).
- Upgrade prices: `Lore.upgrade_cost`.

## Lore note
Quotes taken verbatim from your bible: God's prologue and rematch lines, the title card, Satan's intro. Intro/outro lines for all other bosses
(and Satan's / God's outros) are original filler in the same voice. Edit them in `lore.gd`.

## Dev tools
`godot --headless --path . -- --autotest` plays the whole game with a bot (damage boosted) and prints `AUTOTEST_OK`.
`godot --headless --path . -- --drawtest` draws every boss/creature once to catch drawing errors.
