class_name Boss
extends Node2D
## A boss. Position is the CENTER of the body. Behaviour is data-driven by Lore.boss(i).

const WIND := {"fan": 0.5, "ring": 0.7, "rain": 0.5, "homing": 0.5, "wave": 0.5, "pillars": 0.6,
	"judgment": 1.0, "spears": 0.6, "charge": 0.6, "leap": 0.45, "dive": 0.6, "special": 1.1}

var game
var d: Dictionary = {}
var hp := 100.0
var max_hp := 100.0
var size := Vector2(100, 100)
var fly := false
var col := Color.RED
var acc := Color.ORANGE
var fam := "imp"
var arch := ""
var prologue := false
var phase := 1
var t := 0.0
var flash := 0.0
var face := -1
var mode := "move"          # move, wind, act, rest
var atk := ""
var last_atk := ""
var mode_t := 0.0
var wind_total := 0.5
var cd := 1.2
var vel := Vector2.ZERO
var dying := false
var die_t := 0.0
var queue: Array = []
var active := false         # false while the intro card is up
var contact := false
var act_dir := 1
var act_target := Vector2.ZERO
var dive_stage := 0
var tier := 0.0
var dmg := 1
var raise := 0.0            # God raising a hand (prologue beam)
var frozen := false
var p_spear_t := 1.0
var p_wave_t := 3.0
var bolt_col := Color.ORANGE
var minion_t := 5.0
var sp_cd := 6.0
var guard_t := 0.0
var sp_heal_cd := 0.0
var twists: Array = []
var melee_hits := 0
var blink_pending := false
var volley := 1.0

const TWISTS := {
	"enrage": "ENRAGED: attacks twice as fast below 30% health",
	"regen": "REGENERATING: slowly heals over time",
	"blink": "BLINKING: teleports after every attack",
	"thorns": "THORNED: every 5th melee hit burns you",
	"rapid_special": "ARCANE: special ability comes much sooner",
	"bulwark": "BULWARK: takes 15% less damage",
	"fleet": "FLEET: moves much faster",
	"volley": "BARRAGE: fires 40% more projectiles",
	"vampire": "VAMPIRIC: heals when you are hurt",
	"summoner": "SUMMONER: calls minions twice as often",
	"frenzy": "FRENZIED: shorter wind-ups in later phases",
}
const TWIST_KEYS := ["enrage", "regen", "blink", "thorns", "rapid_special", "bulwark", "fleet", "volley", "vampire", "summoner", "frenzy"]

func _roll_twists(i: int) -> void:
	twists = []
	var first: String = TWIST_KEYS[(i * 7 + 3) % TWIST_KEYS.size()]
	twists.append(first)
	if i >= 20:
		var second: String = TWIST_KEYS[(i * 5 + 1) % TWIST_KEYS.size()]
		if second == first:
			second = TWIST_KEYS[(i * 5 + 2) % TWIST_KEYS.size()]
		twists.append(second)
	if i == 25 or i == 50:
		twists = ["enrage", "summoner", "volley"]
	volley = 1.4 if "volley" in twists else 1.0

func has_twist(k: String) -> bool:
	return k in twists

func twist_text() -> String:
	var out := ""
	for k in twists:
		out += String(TWISTS[k]) + "\n"
	return out.strip_edges()

func on_player_hurt() -> void:
	if has_twist("vampire") and not dying and active:
		hp = minf(max_hp, hp + max_hp * 0.03)
		game.fx.popup(position + Vector2(0, -size.y * 0.5 - 10.0), "DRAIN", Color(0.9, 0.3, 0.4))

func setup(g, data: Dictionary) -> void:
	game = g
	d = data
	fam = data["family"]
	arch = data["arch"]
	size = data["size"]
	fly = data["fly"]
	col = data["col"]
	acc = data["acc"]
	tier = data["tier"]
	dmg = data["dmg"]
	max_hp = data["hp"]
	if int(data.get("index", 1)) == 1:
		max_hp *= 0.4
		d["cd"] = float(d.get("cd", 1.2)) * 1.6
	hp = max_hp
	prologue = data.get("prologue", false)
	if prologue:
		size = Vector2(260, 640)
		fly = false
	bolt_col = acc if not (fam == "archangel") else acc.lerp(col, 0.4)
	position = Vector2(1000.0, Cfg.FLOOR - size.y * 0.5)
	if fly:
		position = Vector2(1000.0, 380.0)
	if prologue:
		position = Vector2(1010.0, Cfg.FLOOR - size.y * 0.5)
	cd = 2.0 if int(data.get("index", 1)) == 1 else 1.2
	_roll_twists(int(d.get("index", 1)))
	if has_twist("rapid_special"):
		sp_cd = 3.0

func can_be_hit() -> bool:
	return not dying and (active or prologue)

func hurt_rect() -> Rect2:
	if prologue:
		return Rect2(position.x - 120.0, Cfg.FLOOR - 110.0, 240.0, 110.0)
	return Rect2(position.x - size.x * 0.5, position.y - size.y * 0.5, size.x, size.y)

func take_damage(amount: float, _melee: bool = false) -> void:
	if dying or not (active or prologue):
		return
	flash = 1.0
	if prologue:
		return
	if has_twist("bulwark"):
		amount *= 0.85
	if _melee and has_twist("thorns"):
		melee_hits += 1
		if melee_hits % 5 == 0:
			game.player.take_hit(1, position.x)
	if guard_t > 0.0:
		amount *= 0.15
		game.fx.burst(position + Vector2(-face * size.x * 0.4, -10), 4, Color(0.9, 0.9, 1.0), 200.0, 3.0, 0.3)
	hp -= amount
	game.fx.popup(position + Vector2(randf_range(-30, 30), -size.y * 0.5 - 6.0), str(int(amount)), Color(1, 1, 0.8))
	if hp <= 0.0:
		hp = 0.0
		dying = true
		die_t = 0.0
		queue.clear()
		game.on_boss_dead()

# ------------------------------------------------------------------ tick
func tick(dt: float) -> void:
	t += dt
	flash = maxf(0.0, flash - dt * 5.0)
	sp_cd -= dt
	guard_t = maxf(0.0, guard_t - dt)
	sp_heal_cd -= dt
	if has_twist("regen") and active and not dying:
		hp = minf(max_hp, hp + max_hp * 0.0008 * dt)
	if dying:
		die_t += dt
		modulate.a = clampf(1.0 - maxf(0.0, die_t - 1.0) / 1.2, 0.0, 1.0)
		if int(die_t * 20.0) % 3 == 0:
			game.fx.burst(position + Vector2(randf_range(-size.x, size.x) * 0.4, randf_range(-size.y, size.y) * 0.4), 3, acc, 220.0, 5.0, 0.5)
		queue_redraw()
		return
	if prologue:
		_tick_prologue(dt)
		queue_redraw()
		return
	if not active:
		queue_redraw()
		return
	_run_queue(dt)
	_check_phase()
	minion_t -= dt
	if minion_t <= 0.0 and mode != "act":
		minion_t = maxf(4.5, 10.0 - 5.0 * tier) * randf_range(0.8, 1.2) * (0.5 if has_twist("summoner") else 1.0)
		_spawn_minion_wave()
	var p = game.player
	if mode != "act" or atk == "leap":
		face = 1 if p.position.x > position.x else -1
	match mode:
		"move": _move(dt, p)
		"wind":
			_drift(dt)
			mode_t -= dt
			if mode_t <= 0.0:
				_execute()
		"act": _act(dt, p)
		"rest":
			_drift(dt)
			mode_t -= dt
			if mode_t <= 0.0:
				mode = "move"
				cd = float(d["cd"]) * (1.0 - 0.12 * (phase - 1)) * randf_range(0.8, 1.1) * (0.5 if (has_twist("enrage") and hp / max_hp < 0.3) else 1.0)
				if has_twist("blink"):
					_blink()
	queue_redraw()

func _run_queue(dt: float) -> void:
	if queue.is_empty():
		return
	var keep: Array = []
	for q in queue:
		q["t"] -= dt
		if q["t"] <= 0.0:
			q["f"].call()
		else:
			keep.append(q)
	queue = keep

func _later(delay: float, f: Callable) -> void:
	queue.append({"t": delay, "f": f})

func _check_phase() -> void:
	var ratio := hp / max_hp
	var np := 1
	if int(d["phases"]) == 2:
		np = 2 if ratio < 0.5 else 1
	else:
		np = 3 if ratio < 0.33 else (2 if ratio < 0.66 else 1)
	if np > phase:
		phase = np
		queue.clear()
		game.clear_hostile()
		game.on_boss_phase(phase)
		mode = "rest"
		contact = false
		mode_t = 1.1
		flash = 1.0
		minion_t = 0.8

func _spawn_minion_wave() -> void:
	var cap := 3 + int(tier * 6.0)
	if game.minion_count() >= cap:
		return
	var pool: Array = Minion.pool(bool(d["hell"]))
	var kinds: Array = [pool.pick_random(), pool.pick_random()]
	var n := mini(2 + int(tier * 3.0) + (phase - 1), cap - game.minion_count())
	game.sfx.play("roar", -10.0, 1.8)
	for i in n:
		var kind: String = kinds[i % 2]
		var fl: bool = Minion.TYPES[kind]["fly"]
		var left := (i % 2 == 0)
		var pos := Vector2(70.0 if left else Cfg.W - 70.0, 70.0 if fl else Cfg.FLOOR - 20.0)
		_later(0.01 + i * 0.35, func(): game.add_minion(kind, pos, tier))

func _drift(dt: float) -> void:
	if fly:
		position.y += sin(t * 3.0) * 10.0 * dt
	if mode == "rest" and not fly:
		position.y = Cfg.FLOOR - size.y * 0.5

func _move(dt: float, p) -> void:
	var spd := float(d["speed"]) * (1.0 + 0.2 * (phase - 1)) * (1.35 if has_twist("fleet") else 1.0)
	if fly:
		var tx := clampf(p.position.x + sin(t * 0.7) * 300.0, 120.0, 1160.0)
		var ty := 300.0 + sin(t * 1.3) * 45.0
		position.x = move_toward(position.x, tx, spd * 1.3 * dt)
		position.y = move_toward(position.y, ty, 140.0 * dt)
	else:
		var dx: float = p.position.x - position.x
		if absf(dx) > 150.0:
			position.x += signf(dx) * spd * dt
		position.y = Cfg.FLOOR - size.y * 0.5
	position.x = clampf(position.x, 80.0, Cfg.W - 80.0)
	cd -= dt
	if cd <= 0.0:
		_choose()

func _choose() -> void:
	var pool: Array = (d["pool"] as Array).duplicate()
	if phase >= 2:
		pool.append_array(d["p2"])
	if pool.size() > 1:
		pool = pool.filter(func(a): return a != last_atk)
	var a: String = pool.pick_random()
