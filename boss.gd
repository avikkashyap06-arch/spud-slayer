func _origin() -> Vector2:
	return position + Vector2(face * size.x * 0.25, -size.y * 0.1)

# ---------------------------------------------------------------- attacks
func _fan() -> void:
	var n := int((3 + int(tier * 6.0) + (phase - 1)) * volley)
	var vols := 1 + (1 if phase >= 2 else 0) + (1 if (phase == 3 and bool(d["final"])) else 0)
	for v in vols:
		_later(0.01 + v * 0.4, func(): _fan_once(n))

func _fan_once(n: int) -> void:
	var o := _origin()
	var base: float = (game.player.center() - o).angle()
	var spread := deg_to_rad(11.0)
	for i in n:
		var a := base + (float(i) - float(n - 1) * 0.5) * spread
		Hazard.bolt(game, o, Vector2.from_angle(a) * _bspeed(), 12.0, _dmg(), bolt_col)
	game.sfx.play("shoot", -8.0)

func _ring() -> void:
	var n := int((10 + int(tier * 10.0)) * volley)
	var vols := 1 + (1 if phase >= 2 else 0)
	for v in vols:
		_later(0.01 + v * 0.55, func(): _ring_once(n, v))

func _ring_once(n: int, v: int) -> void:
	var off := (0.5 if v % 2 == 1 else 0.0) * TAU / float(n)
	for i in n:
		var a := off + TAU * float(i) / float(n)
		Hazard.bolt(game, position, Vector2.from_angle(a) * _bspeed() * 0.78, 12.0, _dmg(), bolt_col)
	game.fx.ring(position, 120.0, bolt_col, 0.4)
	game.sfx.play("shoot", -6.0, 0.7)

func _rain(p) -> void:
	var n := 8 + int(tier * 8.0) + 2 * (phase - 1)
	for i in n:
		_later(0.01 + i * 0.14, func():
			var x: float = clampf(game.player.position.x + randf_range(-110.0, 110.0), 50.0, Cfg.W - 50.0) if i % 3 == 0 else randf_range(60.0, Cfg.W - 60.0)
			Hazard.bolt(game, Vector2(x, -20.0), Vector2(0.0, _bspeed() * 0.9), 14.0, _dmg(), bolt_col, {"grav": 650.0, "warn": true}))

func _homing() -> void:
	var n := 1 + (1 if phase >= 2 else 0) + (1 if phase == 3 else 0)
	for i in n:
		_later(0.01 + i * 0.5, func():
			var ang: float = (game.player.center() - _origin()).angle() + randf_range(-0.5, 0.5)
			Hazard.bolt(game, _origin(), Vector2.from_angle(ang) * (190.0 + 80.0 * tier), 20.0, _dmg(), bolt_col, {"turn": 1.5, "life": 6.0, "breakable": true})
			game.sfx.play("shoot", -8.0, 0.6))

func _wave() -> void:
	var h := 46.0 + 10.0 * (phase - 1)
	var spd := 340.0 + 180.0 * tier
	var rounds := 1 + (1 if phase >= 2 else 0)
	for r_i in rounds:
		_later(0.01 + r_i * 0.8, func():
			for s in [-1, 1]:
				Hazard.wave(game, position.x + s * 40.0, s * spd, h, _dmg(), bolt_col)
			game.sfx.play("boom", -8.0, 1.2)
			game.shake_add(5.0))

func _pillars(p) -> void:
	var n := 2 + int(tier * 3.0) + (phase - 1)
	for i in n:
		var x: float = p.position.x if i == 0 else p.position.x + (float(i) - float(n) * 0.5) * randf_range(120.0, 190.0)
		x = clampf(x, 50.0, Cfg.W - 50.0)
		_later(0.01 + i * 0.12, func():
			Hazard.pillar(game, x, 80.0, 0.95 - 0.1 * tier, 0.35, _dmg(), bolt_col, String(d["style"])))

func _judgment() -> void:
	var cols := 13
	var gap := randi_range(2, cols - 3)
	for i in cols:
		if i == gap or i == gap + 1:
			continue
		Hazard.pillar(game, 10.0 + i * 100.0, 100.0, 1.35, 0.5, _dmg(), bolt_col, String(d["style"]))
	game.sfx.play("roar", -8.0, 0.8)

func _spears() -> void:
	var n := 5 + int(tier * 4.0) + (phase - 1)
	for i in n:
		_later(0.01 + i * 0.22, func():
			Hazard.pillar(game, clampf(game.player.position.x + randf_range(-50.0, 50.0), 40.0, Cfg.W - 40.0), 26.0, 0.55, 0.22, _dmg(), Color(1.0, 0.92, 0.5), "spear"))


# ---------------------------------------------------------------- special abilities
func _sid() -> String:
	return arch if fam == "archangel" else fam

const SPECIALS := {
	"imp": "SWARM CALL", "wraith": "VEILSTEP", "hound": "HELLHOWL", "slime": "MOLTEN SPLIT",
	"duke": "GATE OF EMBERS", "torturer": "IRON CHAINS", "golem": "EARTHSHATTER", "seraph": "WHEEL OF FIRE",
	"cherub": "CHOIR SUMMON", "knight": "SHIELD WALL", "pillar": "COLLAPSE", "ophanim": "ALL-SEEING",
	"michael": "BLADE OF HEAVEN", "gabriel": "TRUMPET OF DOOM", "uriel": "SOLAR FLARE", "raphael": "MENDING LIGHT",
	"metatron": "CUBE OF TRUTH", "raguel": "SCALES OF JUDGMENT", "sariel": "ECLIPSE", "satan": "HELLSTORM", "god": "DIVINE WRATH",
}

func special_name() -> String:
	return String(SPECIALS.get(_sid(), "WRATH"))

func _spawn_adds(kind: String, n: int) -> void:
	if game.minion_count() >= 9:
		return
	for i in n:
		var off := Vector2(randf_range(-120.0, 120.0), randf_range(-60.0, 20.0))
		var fl: bool = Minion.TYPES[kind]["fly"]
		var pos := position + off
		if not fl:
			pos.y = Cfg.FLOOR - 20.0
		pos.x = clampf(pos.x, 60.0, Cfg.W - 60.0)
		_later(0.05 + i * 0.25, func(): game.add_minion(kind, pos, tier))

func _sweep_pillars(from_left: bool, n: int, gap: float) -> void:
	for i in n:
		var x := 60.0 + float(i if from_left else n - 1 - i) * gap
		_later(0.01 + i * 0.11, func():
			Hazard.pillar(game, clampf(x, 40.0, Cfg.W - 40.0), 70.0, 0.85, 0.35, _dmg(), bolt_col, String(d["style"])))

func _special(p) -> void:
	var ph := phase
	game.shake_add(6.0)
	game.sfx.play("roar", -4.0, 0.7)
	match _sid():
		"imp":
			_spawn_adds("ember_imp", 3 + ph)
			_ring_once(8 + ph * 2, 0)
		"wraith":
			var tx := clampf(p.position.x + (260.0 if p.position.x < Cfg.W * 0.5 else -260.0), 120.0, Cfg.W - 120.0)
			game.fx.burst(position, 16, acc, 220.0, 5.0, 0.5)
			position.x = tx
			game.fx.burst(position, 16, acc, 220.0, 5.0, 0.5)
			for k in 2:
				_later(0.2 + k * 0.5, func(): _ring_once(12 + 4 * ph, k))
		"hound":
			for k in 2 + ph:
				_later(0.01 + k * 0.55, func():
					for s in [-1, 1]:
						Hazard.wave(game, position.x + s * 40.0, s * (420.0 + 70.0 * k), 50.0, _dmg(), bolt_col)
					game.shake_add(8.0)
					game.sfx.play("boom", -6.0, 0.8))
		"slime":
			_spawn_adds("magma_blob", 3 + ph)
			_wave()
		"duke":
			_sweep_pillars(p.position.x > Cfg.W * 0.5, 12, 100.0)
			if ph >= 2:
				_later(0.9, func(): _sweep_pillars(p.position.x <= Cfg.W * 0.5, 12, 100.0))
		"torturer":
			for k in 9:
				_later(0.05 + k * 0.07, func():
					var dir := signf(position.x - game.player.position.x)
					game.player.position.x = clampf(game.player.position.x + dir * 26.0, 30.0, Cfg.W - 30.0)
					game.fx.burst(game.player.center(), 2, Color(0.6, 0.6, 0.65), 100.0, 3.0, 0.25))
			_later(0.8, func(): _wave())
			_later(1.3, func(): _pillars(game.player))
		"golem":
			for s in [-1, 1]:
				Hazard.wave(game, position.x + s * 60.0, s * 300.0, 60.0, _dmg(), bolt_col)
			game.shake_add(16.0)
			_rain(p)
			_rain(p)
		"seraph":
			var arms := 3
			var steps := 16
			for k in steps:
				_later(0.01 + k * 0.12, func():
					for a in arms:
						var ang := float(k) * 0.35 + TAU * float(a) / float(arms)
						Hazard.bolt(game, position, Vector2.from_angle(ang) * _bspeed() * 0.75, 11.0, _dmg(), bolt_col))
		"cherub":
			_spawn_adds("halo_sprite", 3)
			_fan()
		"knight":
			guard_t = 3.5
			game.fx.ring(position, 140.0, Color(0.8, 0.85, 1.0), 0.6)
			_later(1.5, func(): _fan_once(7 + ph))
			_later(2.6, func(): _wave())
		"pillar":
			for k in 9:
				_later(0.01 + k * 0.16, func():
					Hazard.pillar(game, randf_range(50.0, Cfg.W - 50.0), 70.0, 0.9, 0.4, _dmg(), bolt_col, String(d["style"])))
			_later(1.6, func(): _judgment())
		"ophanim":
			for k in 8:
				_later(0.01 + k * 0.14, func():
					var ang := TAU * float(k) / 8.0 + t
					Hazard.bolt(game, position + Vector2.from_angle(ang) * 60.0, Vector2.from_angle(ang) * 170.0, 15.0, _dmg(), bolt_col, {"turn": 1.6, "life": 6.0, "breakable": true}))
		"michael":
			for k in 14 + 2 * ph:
				_later(0.01 + k * 0.13, func():
					Hazard.pillar(game, clampf(game.player.position.x + randf_range(-160.0, 160.0), 40.0, Cfg.W - 40.0), 26.0, 0.5, 0.22, _dmg(), Color(1.0, 0.92, 0.5), "spear"))
		"gabriel":
			for k in 3:
				_later(0.01 + k * 0.5, func():
					for s in [-1, 1]:
						Hazard.wave(game, position.x + s * 40.0, s * (380.0 + 60.0 * k), 48.0, _dmg(), bolt_col)
					game.shake_add(6.0)
					game.sfx.play("boom", -8.0, 1.3))
		"uriel":
			for k in 6:
				_later(0.01 + k * 0.2, func():
					Hazard.pillar(game, 100.0 + k * 200.0, 120.0, 1.2, 0.6, _dmg(), bolt_col, "fire"))
		"raphael":
			if sp_heal_cd <= 0.0:
				sp_heal_cd = 22.0
				hp = minf(max_hp, hp + max_hp * 0.05)
				game.fx.popup(position + Vector2(0, -size.y * 0.5 - 10.0), "HEAL", Color(0.5, 1.0, 0.6))
			game.fx.ring(position, 160.0, Color(0.5, 1.0, 0.6), 0.6)
			_ring_once(14, 0)
			_later(0.6, func(): _ring_once(14, 1))
		"metatron":
			_ring_once(16, 0)
			_later(0.5, func(): _homing())
			_later(1.0, func(): _homing())
		"raguel":
			_judgment()
			_later(1.0, func(): _judgment())
		"sariel":
			game.dark_t = 3.0
			for k in 14:
				_later(0.01 + k * 0.12, func():
					Hazard.bolt(game, Vector2(randf_range(60.0, Cfg.W - 60.0), -20.0), Vector2(0.0, _bspeed()), 14.0, _dmg(), bolt_col, {"grav": 650.0}))
		"satan":
			for k in 16 + 4 * ph:
				_later(0.01 + k * 0.11, func():
					Hazard.bolt(game, Vector2(randf_range(60.0, Cfg.W - 60.0), -20.0), Vector2(randf_range(-80.0, 80.0), _bspeed() * 0.9), 16.0, _dmg(), Color(1.0, 0.4, 0.1), {"grav": 700.0, "warn": true}))
			_later(1.0, func(): _wave())
			_later(1.8, func(): _pillars(game.player))
		"god":
			_judgment()
			_later(0.9, func(): _spears())
			_later(1.6, func(): _ring_once(18 + 4 * ph, 0))
		_:
			_ring_once(12, 0)

# ---------------------------------------------------------------- movement attacks
func _act(dt: float, p) -> void:
	match atk:
		"charge":
			var spd := (520.0 + 250.0 * tier) * (1.0 + 0.2 * (phase - 1))
			position.x += act_dir * spd * dt
			mode_t -= dt
			if position.x < 90.0 or position.x > Cfg.W - 90.0:
				position.x = clampf(position.x, 90.0, Cfg.W - 90.0)
				game.shake_add(9.0)
				game.sfx.play("boom", -6.0)
				game.fx.burst(Vector2(position.x, Cfg.FLOOR), 14, acc, 260.0, 5.0, 0.5)
				_end_attack(1.0)
				return
			if mode_t <= 0.0:
				_end_attack(0.9)
		"leap":
			vel.y += 2400.0 * dt
			position += vel * dt
			position.x = clampf(position.x, 80.0, Cfg.W - 80.0)
			if vel.y > 0.0 and position.y >= Cfg.FLOOR - size.y * 0.5:
				position.y = Cfg.FLOOR - size.y * 0.5
				game.shake_add(12.0)
				game.sfx.play("boom")
func _origin() -> Vector2:
	return position + Vector2(face * size.x * 0.25, -size.y * 0.1)

# ---------------------------------------------------------------- attacks
func _fan() -> void:
	var n := int((3 + int(tier * 6.0) + (phase - 1)) * volley)
	var vols := 1 + (1 if phase >= 2 else 0) + (1 if (phase == 3 and bool(d["final"])) else 0)
	for v in vols:
		_later(0.01 + v * 0.4, func(): _fan_once(n))

func _fan_once(n: int) -> void:
	var o := _origin()
	var base: float = (game.player.center() - o).angle()
	var spread := deg_to_rad(11.0)
	for i in n:
		var a := base + (float(i) - float(n - 1) * 0.5) * spread
		Hazard.bolt(game, o, Vector2.from_angle(a) * _bspeed(), 12.0, _dmg(), bolt_col)
	game.sfx.play("shoot", -8.0)

func _ring() -> void:
	var n := int((10 + int(tier * 10.0)) * volley)
	var vols := 1 + (1 if phase >= 2 else 0)
	for v in vols:
		_later(0.01 + v * 0.55, func(): _ring_once(n, v))

func _ring_once(n: int, v: int) -> void:
	var off := (0.5 if v % 2 == 1 else 0.0) * TAU / float(n)
	for i in n:
		var a := off + TAU * float(i) / float(n)
		Hazard.bolt(game, position, Vector2.from_angle(a) * _bspeed() * 0.78, 12.0, _dmg(), bolt_col)
	game.fx.ring(position, 120.0, bolt_col, 0.4)
	game.sfx.play("shoot", -6.0, 0.7)

func _rain(p) -> void:
	var n := 8 + int(tier * 8.0) + 2 * (phase - 1)
	for i in n:
		_later(0.01 + i * 0.14, func():
			var x: float = clampf(game.player.position.x + randf_range(-110.0, 110.0), 50.0, Cfg.W - 50.0) if i % 3 == 0 else randf_range(60.0, Cfg.W - 60.0)
			Hazard.bolt(game, Vector2(x, -20.0), Vector2(0.0, _bspeed() * 0.9), 14.0, _dmg(), bolt_col, {"grav": 650.0, "warn": true}))

func _homing() -> void:
	var n := 1 + (1 if phase >= 2 else 0) + (1 if phase == 3 else 0)
	for i in n:
		_later(0.01 + i * 0.5, func():
			var ang: float = (game.player.center() - _origin()).angle() + randf_range(-0.5, 0.5)
			Hazard.bolt(game, _origin(), Vector2.from_angle(ang) * (190.0 + 80.0 * tier), 20.0, _dmg(), bolt_col, {"turn": 1.5, "life": 6.0, "breakable": true})
			game.sfx.play("shoot", -8.0, 0.6))

func _wave() -> void:
	var h := 46.0 + 10.0 * (phase - 1)
	var spd := 340.0 + 180.0 * tier
	var rounds := 1 + (1 if phase >= 2 else 0)
	for r_i in rounds:
		_later(0.01 + r_i * 0.8, func():
			for s in [-1, 1]:
				Hazard.wave(game, position.x + s * 40.0, s * spd, h, _dmg(), bolt_col)
			game.sfx.play("boom", -8.0, 1.2)
			game.shake_add(5.0))

func _pillars(p) -> void:
	var n := 2 + int(tier * 3.0) + (phase - 1)
	for i in n:
		var x: float = p.position.x if i == 0 else p.position.x + (float(i) - float(n) * 0.5) * randf_range(120.0, 190.0)
		x = clampf(x, 50.0, Cfg.W - 50.0)
		_later(0.01 + i * 0.12, func():
			Hazard.pillar(game, x, 80.0, 0.95 - 0.1 * tier, 0.35, _dmg(), bolt_col, String(d["style"])))

func _judgment() -> void:
	var cols := 13
	var gap := randi_range(2, cols - 3)
	for i in cols:
		if i == gap or i == gap + 1:
			continue
		Hazard.pillar(game, 10.0 + i * 100.0, 100.0, 1.35, 0.5, _dmg(), bolt_col, String(d["style"]))
	game.sfx.play("roar", -8.0, 0.8)

func _spears() -> void:
	var n := 5 + int(tier * 4.0) + (phase - 1)
	for i in n:
		_later(0.01 + i * 0.22, func():
			Hazard.pillar(game, clampf(game.player.position.x + randf_range(-50.0, 50.0), 40.0, Cfg.W - 40.0), 26.0, 0.55, 0.22, _dmg(), Color(1.0, 0.92, 0.5), "spear"))


# ---------------------------------------------------------------- special abilities
func _sid() -> String:
	return arch if fam == "archangel" else fam

const SPECIALS := {
	"imp": "SWARM CALL", "wraith": "VEILSTEP", "hound": "HELLHOWL", "slime": "MOLTEN SPLIT",
	"duke": "GATE OF EMBERS", "torturer": "IRON CHAINS", "golem": "EARTHSHATTER", "seraph": "WHEEL OF FIRE",
	"cherub": "CHOIR SUMMON", "knight": "SHIELD WALL", "pillar": "COLLAPSE", "ophanim": "ALL-SEEING",
	"michael": "BLADE OF HEAVEN", "gabriel": "TRUMPET OF DOOM", "uriel": "SOLAR FLARE", "raphael": "MENDING LIGHT",
	"metatron": "CUBE OF TRUTH", "raguel": "SCALES OF JUDGMENT", "sariel": "ECLIPSE", "satan": "HELLSTORM", "god": "DIVINE WRATH",
}

func special_name() -> String:
	return String(SPECIALS.get(_sid(), "WRATH"))

func _spawn_adds(kind: String, n: int) -> void:
	if game.minion_count() >= 9:
		return
	for i in n:
		var off := Vector2(randf_range(-120.0, 120.0), randf_range(-60.0, 20.0))
		var fl: bool = Minion.TYPES[kind]["fly"]
		var pos := position + off
		if not fl:
			pos.y = Cfg.FLOOR - 20.0
		pos.x = clampf(pos.x, 60.0, Cfg.W - 60.0)
		_later(0.05 + i * 0.25, func(): game.add_minion(kind, pos, tier))

func _sweep_pillars(from_left: bool, n: int, gap: float) -> void:
	for i in n:
		var x := 60.0 + float(i if from_left else n - 1 - i) * gap
		_later(0.01 + i * 0.11, func():
			Hazard.pillar(game, clampf(x, 40.0, Cfg.W - 40.0), 70.0, 0.85, 0.35, _dmg(), bolt_col, String(d["style"])))

func _special(p) -> void:
	var ph := phase
	game.shake_add(6.0)
	game.sfx.play("roar", -4.0, 0.7)
	match _sid():
		"imp":
			_spawn_adds("ember_imp", 3 + ph)
			_ring_once(8 + ph * 2, 0)
		"wraith":
			var tx := clampf(p.position.x + (260.0 if p.position.x < Cfg.W * 0.5 else -260.0), 120.0, Cfg.W - 120.0)
			game.fx.burst(position, 16, acc, 220.0, 5.0, 0.5)
			position.x = tx
			game.fx.burst(position, 16, acc, 220.0, 5.0, 0.5)
			for k in 2:
				_later(0.2 + k * 0.5, func(): _ring_once(12 + 4 * ph, k))
		"hound":
			for k in 2 + ph:
				_later(0.01 + k * 0.55, func():
					for s in [-1, 1]:
						Hazard.wave(game, position.x + s * 40.0, s * (420.0 + 70.0 * k), 50.0, _dmg(), bolt_col)
					game.shake_add(8.0)
					game.sfx.play("boom", -6.0, 0.8))
		"slime":
			_spawn_adds("magma_blob", 3 + ph)
			_wave()
		"duke":
			_sweep_pillars(p.position.x > Cfg.W * 0.5, 12, 100.0)
			if ph >= 2:
				_later(0.9, func(): _sweep_pillars(p.position.x <= Cfg.W * 0.5, 12, 100.0))
		"torturer":
			for k in 9:
				_later(0.05 + k * 0.07, func():
					var dir := signf(position.x - game.player.position.x)
					game.player.position.x = clampf(game.player.position.x + dir * 26.0, 30.0, Cfg.W - 30.0)
					game.fx.burst(game.player.center(), 2, Color(0.6, 0.6, 0.65), 100.0, 3.0, 0.25))
			_later(0.8, func(): _wave())
			_later(1.3, func(): _pillars(game.player))
		"golem":
			for s in [-1, 1]:
				Hazard.wave(game, position.x + s * 60.0, s * 300.0, 60.0, _dmg(), bolt_col)
			game.shake_add(16.0)
			_rain(p)
			_rain(p)
		"seraph":
			var arms := 3
			var steps := 16
			for k in steps:
				_later(0.01 + k * 0.12, func():
					for a in arms:
						var ang := float(k) * 0.35 + TAU * float(a) / float(arms)
						Hazard.bolt(game, position, Vector2.from_angle(ang) * _bspeed() * 0.75, 11.0, _dmg(), bolt_col))
		"cherub":
			_spawn_adds("halo_sprite", 3)
			_fan()
		"knight":
			guard_t = 3.5
			game.fx.ring(position, 140.0, Color(0.8, 0.85, 1.0), 0.6)
			_later(1.5, func(): _fan_once(7 + ph))
			_later(2.6, func(): _wave())
		"pillar":
			for k in 9:
				_later(0.01 + k * 0.16, func():
					Hazard.pillar(game, randf_range(50.0, Cfg.W - 50.0), 70.0, 0.9, 0.4, _dmg(), bolt_col, String(d["style"])))
			_later(1.6, func(): _judgment())
		"ophanim":
			for k in 8:
				_later(0.01 + k * 0.14, func():
					var ang := TAU * float(k) / 8.0 + t
					Hazard.bolt(game, position + Vector2.from_angle(ang) * 60.0, Vector2.from_angle(ang) * 170.0, 15.0, _dmg(), bolt_col, {"turn": 1.6, "life": 6.0, "breakable": true}))
		"michael":
			for k in 14 + 2 * ph:
				_later(0.01 + k * 0.13, func():
					Hazard.pillar(game, clampf(game.player.position.x + randf_range(-160.0, 160.0), 40.0, Cfg.W - 40.0), 26.0, 0.5, 0.22, _dmg(), Color(1.0, 0.92, 0.5), "spear"))
		"gabriel":
			for k in 3:
				_later(0.01 + k * 0.5, func():
					for s in [-1, 1]:
						Hazard.wave(game, position.x + s * 40.0, s * (380.0 + 60.0 * k), 48.0, _dmg(), bolt_col)
					game.shake_add(6.0)
					game.sfx.play("boom", -8.0, 1.3))
		"uriel":
			for k in 6:
				_later(0.01 + k * 0.2, func():
					Hazard.pillar(game, 100.0 + k * 200.0, 120.0, 1.2, 0.6, _dmg(), bolt_col, "fire"))
		"raphael":
			if sp_heal_cd <= 0.0:
				sp_heal_cd = 22.0
				hp = minf(max_hp, hp + max_hp * 0.05)
				game.fx.popup(position + Vector2(0, -size.y * 0.5 - 10.0), "HEAL", Color(0.5, 1.0, 0.6))
			game.fx.ring(position, 160.0, Color(0.5, 1.0, 0.6), 0.6)
			_ring_once(14, 0)
			_later(0.6, func(): _ring_once(14, 1))
		"metatron":
			_ring_once(16, 0)
			_later(0.5, func(): _homing())
			_later(1.0, func(): _homing())
		"raguel":
			_judgment()
			_later(1.0, func(): _judgment())
		"sariel":
			game.dark_t = 3.0
			for k in 14:
				_later(0.01 + k * 0.12, func():
					Hazard.bolt(game, Vector2(randf_range(60.0, Cfg.W - 60.0), -20.0), Vector2(0.0, _bspeed()), 14.0, _dmg(), bolt_col, {"grav": 650.0}))
		"satan":
			for k in 16 + 4 * ph:
				_later(0.01 + k * 0.11, func():
					Hazard.bolt(game, Vector2(randf_range(60.0, Cfg.W - 60.0), -20.0), Vector2(randf_range(-80.0, 80.0), _bspeed() * 0.9), 16.0, _dmg(), Color(1.0, 0.4, 0.1), {"grav": 700.0, "warn": true}))
			_later(1.0, func(): _wave())
			_later(1.8, func(): _pillars(game.player))
		"god":
			_judgment()
			_later(0.9, func(): _spears())
			_later(1.6, func(): _ring_once(18 + 4 * ph, 0))
		_:
			_ring_once(12, 0)

# ---------------------------------------------------------------- movement attacks
func _act(dt: float, p) -> void:
	match atk:
		"charge":
			var spd := (520.0 + 250.0 * tier) * (1.0 + 0.2 * (phase - 1))
			position.x += act_dir * spd * dt
			mode_t -= dt
			if position.x < 90.0 or position.x > Cfg.W - 90.0:
				position.x = clampf(position.x, 90.0, Cfg.W - 90.0)
				game.shake_add(9.0)
				game.sfx.play("boom", -6.0)
				game.fx.burst(Vector2(position.x, Cfg.FLOOR), 14, acc, 260.0, 5.0, 0.5)
				_end_attack(1.0)
				return
			if mode_t <= 0.0:
				_end_attack(0.9)
		"leap":
			vel.y += 2400.0 * dt
			position += vel * dt
			position.x = clampf(position.x, 80.0, Cfg.W - 80.0)
			if vel.y > 0.0 and position.y >= Cfg.FLOOR - size.y * 0.5:
				position.y = Cfg.FLOOR - size.y * 0.5
				game.shake_add(12.0)
				game.sfx.play("boom")
				game.fx.burst(Vector2(position.x, Cfg.FLOOR), 20, acc, 300.0, 6.0, 0.6)
				for s in [-1, 1]:
					Hazard.wave(game, position.x + s * 50.0, s * (300.0 + 150.0 * tier), 42.0, _dmg(), bolt_col)
				_end_attack(0.8)
		"dive":
			mode_t -= dt
			if dive_stage == 0:
				var to := act_target - position
				var step := (760.0 + 200.0 * tier) * dt
				if to.length() <= step or mode_t <= 0.0:
					dive_stage = 1
					game.fx.burst(position, 12, acc, 240.0, 5.0, 0.4)
				else:
					position += to.normalized() * step
			else:
				position.y = move_toward(position.y, 320.0, 520.0 * dt)
				if position.y <= 330.0:
					_end_attack(0.6)
	if contact and hurt_rect().intersects(p.hurt_rect()):
		p.take_hit(_dmg(), position.x)

func _tick_prologue(dt: float) -> void:
	_run_queue(dt)
	if frozen:
		return
	var p = game.player
	p_spear_t -= dt
	if p_spear_t <= 0.0:
		p_spear_t = 1.5
		Hazard.pillar(game, p.position.x, 26.0, 0.8, 0.22, 1, Color(1.0, 0.92, 0.5), "spear")
		Hazard.pillar(game, clampf(p.position.x + randf_range(-240.0, 240.0), 40.0, 900.0), 26.0, 0.8, 0.22, 1, Color(1.0, 0.92, 0.5), "spear")
	p_wave_t -= dt
	if p_wave_t <= 0.0:
		p_wave_t = 4.6
		Hazard.wave(game, position.x - 100.0, -330.0, 46.0, 1, Color(1.0, 0.88, 0.4))
		game.sfx.play("boom", -8.0)
		game.shake_add(5.0)

func _c(base: Color) -> Color:
	return base.lerp(Color.WHITE, flash * 0.7)

func _poly(cx: float, cy: float, rx: float, ry: float, n: int = 20, wob: float = 0.0, ph: float = 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		var k := 1.0 + wob * sin(a * 3.0 + ph)
		pts.append(Vector2(cx + cos(a) * rx * k, cy + sin(a) * ry * k))
	return pts

func _mirror(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(pts.size() - 1, -1, -1):
		out.append(Vector2(-pts[i].x, pts[i].y))
	return out

func _eyes(y: float, gap: float, r: float, c: Color) -> void:
	draw_circle(Vector2(-gap, y), r * 1.7, Color(c.r, c.g, c.b, 0.3))
	draw_circle(Vector2(gap, y), r * 1.7, Color(c.r, c.g, c.b, 0.3))
	draw_circle(Vector2(-gap, y), r, c)
	draw_circle(Vector2(gap, y), r, c)
	draw_circle(Vector2(-gap, y), r * 0.4, Color.BLACK)
	draw_circle(Vector2(gap, y), r * 0.4, Color.BLACK)

func _draw() -> void:
	var wob := Vector2.ZERO
	if dying:
		wob = Vector2(randf_range(-6, 6), randf_range(-4, 4))
	var bob := sin(t * 2.2) * 4.0 if fly or prologue else 0.0
	draw_set_transform(wob + Vector2(0, bob), 0.0, Vector2(-1.0 if face > 0 else 1.0, 1.0))
	var wr := wind_ratio()
	if wr > 0.0:
		var gr := maxf(size.x, size.y) * 0.62
		draw_circle(Vector2.ZERO, gr * (0.6 + 0.5 * wr), Color(acc.r, acc.g, acc.b, 0.22 * wr))
	if contact:
		draw_circle(Vector2.ZERO, maxf(size.x, size.y) * 0.58, Color(acc.r, acc.g, acc.b, 0.15))
	BossArt.draw(self)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if phase > 1 and not dying:
		draw_arc(Vector2.ZERO, maxf(size.x, size.y) * 0.62, 0.0, TAU, 40, Color(acc.r, acc.g, acc.b, 0.25 + 0.15 * sin(t * 6.0)), 3.0)

func _blink() -> void:
	var tx := clampf(game.player.position.x + (randf_range(220.0, 420.0) * (1.0 if randf() < 0.5 else -1.0)), 100.0, Cfg.W - 100.0)
	game.fx.burst(position, 14, acc, 220.0, 5.0, 0.4)
	position.x = tx
	game.fx.burst(position, 14, acc, 220.0, 5.0, 0.4)
