class_name Player
extends Node2D
## Spud. Position is at his feet.

const GRAV := 2300.0
const MOVE := 400.0
const JUMP_V := -900.0
const DJUMP_V := -800.0
const ROLL_T := 0.38
const ROLL_SPEED := 560.0
const DASH_T := 0.2
const DASH_SPEED := 780.0
const ROLL_COST := 28.0
const DASH_COST := 25.0
const ATTACK_T := 0.18
const ATTACK_CD := 0.30
const ATTACK_COST := 8.0

var game
var vel := Vector2.ZERO
var on_ground := false
var facing := 1
var max_hp := 1
var hp := 1
var max_stamina := 100.0
var stamina := 100.0
var stam_delay := 0.0
var max_energy := 100.0
var energy := 0.0
var damage := 10.0
var air_jumps_used := 0
var has_wings := false
var roll_t := 0.0
var roll_dir := 1
var dash_t := 0.0
var air_dashed := false
var iframes := 0.0
var attack_t := 0.0
var attack_cd := 0.0
var swing_hit := false
var swing_id := 0
var rune_cd := [0.0, 0.0, 0.0, 0.0]
var skin_t := 0.0
var locked := false
var prologue := false
var armor := false
var armor_shield := 0
var dead := false
var anim_t := 0.0
var squash := 0.0
var coyote := 0.0
var jump_buf := 0.0
var drop_t := 0.0
var hidden_body := false
var body_pts := PackedVector2Array()

func _ready() -> void:
	for i in 28:
		var a := TAU * float(i) / 28.0
		body_pts.append(Vector2(cos(a) * 24.0 * (1.0 + 0.06 * sin(3.0 * a)), sin(a) * 28.0 * (1.0 + 0.05 * cos(2.0 * a + 1.0))))

func center() -> Vector2:
	return position + Vector2(0, -30)

func hurt_rect() -> Rect2:
	if roll_t > 0.0:
		return Rect2(position.x - 18, position.y - 32, 36, 32)
	return Rect2(position.x - 17, position.y - 56, 34, 56)

func attack_rect() -> Rect2:
	var x := position.x + 6.0 if facing > 0 else position.x - 96.0
	return Rect2(x, position.y - 84, 90, 84)

func apply_upgrades() -> void:
	max_hp = 1 + game.hp_lvl
	max_stamina = 100.0 + 10.0 * game.sta_lvl
	damage = 10.0 + 3.0 * game.atk_lvl
	has_wings = game.wings

func full_heal() -> void:
	hp = max_hp
	stamina = max_stamina
	energy = 0.0
	iframes = 0.0
	skin_t = 0.0
	dead = false
	for i in 4:
		rune_cd[i] = 0.0

func spawn_at(x: float) -> void:
	position = Vector2(x, Cfg.FLOOR)
	vel = Vector2.ZERO
	facing = 1
	roll_t = 0.0
	dash_t = 0.0
	attack_t = 0.0
	on_ground = true
	dead = false
	locked = false
	hidden_body = false
	modulate.a = 1.0

# ------------------------------------------------------------------ tick
func tick(dt: float) -> void:
	anim_t += dt
	iframes = maxf(0.0, iframes - dt)
	attack_cd -= dt
	drop_t -= dt
	squash = move_toward(squash, 0.0, dt * 4.0)
	for i in 4:
		rune_cd[i] = maxf(0.0, rune_cd[i] - dt)
	if skin_t > 0.0:
		skin_t -= dt
	stam_delay -= dt
	if stam_delay <= 0.0:
		stamina = minf(max_stamina, stamina + 42.0 * dt)
	if not prologue:
		energy = minf(max_energy, energy + 3.0 * dt)
	coyote -= dt
	jump_buf -= dt

	var dir := 0.0
	if not locked and not dead:
		dir = Input.get_axis("move_left", "move_right")
		_actions(dir)

	if roll_t > 0.0:
		roll_t -= dt
		vel.x = roll_dir * ROLL_SPEED * (0.5 + 0.5 * roll_t / ROLL_T)
	elif dash_t > 0.0:
		dash_t -= dt
		vel = Vector2(roll_dir * DASH_SPEED, 0.0)
	else:
		var acc := 3400.0 if on_ground else 2100.0
		vel.x = move_toward(vel.x, dir * MOVE, acc * dt)
		if dir != 0.0 and attack_t <= 0.0:
			facing = 1 if dir > 0.0 else -1
	if dash_t <= 0.0:
		vel.y = minf(vel.y + GRAV * dt, 1100.0)

	var prev_y := position.y
	var was_ground := on_ground
	position += vel * dt
	position.x = clampf(position.x, 40.0, Cfg.W - 40.0)
	on_ground = false
	if position.y >= Cfg.FLOOR:
		position.y = Cfg.FLOOR
		vel.y = 0.0
		on_ground = true
	elif vel.y >= 0.0 and drop_t <= 0.0:
		for pr in game.arena.platforms:
			var rc: Rect2 = pr
			if position.x > rc.position.x - 6.0 and position.x < rc.end.x + 6.0 and prev_y <= rc.position.y + 2.0 and position.y >= rc.position.y:
				position.y = rc.position.y
				vel.y = 0.0
				on_ground = true
				break
	if on_ground:
		coyote = 0.1
		air_jumps_used = 0
		air_dashed = false
		if not was_ground:
			squash = 0.6
			game.fx.dust(position, 5)
	if attack_t > 0.0:
		attack_t -= dt
		if attack_t < ATTACK_T - 0.03:
			_swing_check()
	modulate.a = 0.35 if (iframes > 0.0 and int(anim_t * 22.0) % 2 == 0 and not locked) else 1.0
	queue_redraw()

func _actions(dir: float) -> void:
	if Input.is_action_just_pressed("jump"):
		jump_buf = 0.12
	if jump_buf > 0.0:
		if Input.is_action_pressed("move_down") and on_ground and position.y < Cfg.FLOOR - 1.0:
			drop_t = 0.25
			position.y += 4.0
			on_ground = false
			jump_buf = 0.0
		elif coyote > 0.0 and roll_t <= 0.0:
			vel.y = JUMP_V
			coyote = 0.0
			jump_buf = 0.0
			on_ground = false
			game.sfx.play("jump", -6.0)
			game.fx.dust(position, 4)
			squash = -0.4
		elif has_wings and air_jumps_used < 1 and not on_ground:
			vel.y = DJUMP_V
			air_jumps_used += 1
			jump_buf = 0.0
			game.sfx.play("jump", -4.0, 1.4)
			game.fx.burst(position + Vector2(0, -20), 14, Color(1.0, 0.5, 0.15), 200.0, 5.0, 0.5)
	if Input.is_action_just_released("jump") and vel.y < -300.0:
		vel.y *= 0.5
	if Input.is_action_just_pressed("roll"):
		_roll(dir)
	if Input.is_action_just_pressed("attack") and attack_cd <= 0.0 and roll_t <= 0.0 and stamina >= ATTACK_COST:
		_attack()
	if not prologue:
		for i in 4:
			if Input.is_action_just_pressed("rune%d" % (i + 1)):
				cast_rune(i)

func _roll(dir: float) -> void:
	if roll_t > 0.0 or dash_t > 0.0:
		return
	var d := int(signf(dir)) if dir != 0.0 else facing
	if on_ground and stamina >= ROLL_COST:
		roll_t = ROLL_T
		roll_dir = d
		facing = d
		stamina -= ROLL_COST
		stam_delay = 0.55
		game.sfx.play("roll", -4.0)
		game.fx.dust(position, 8)
	elif not on_ground and has_wings and not air_dashed and stamina >= DASH_COST:
		dash_t = DASH_T
		roll_dir = d
		facing = d
		air_dashed = true
		stamina -= DASH_COST
		stam_delay = 0.55
		vel.y = 0.0
		game.sfx.play("roll", -2.0, 1.5)
		game.fx.burst(position + Vector2(0, -28), 16, Color(1.0, 0.45, 0.1), 240.0, 5.0, 0.4)

func _attack() -> void:
	attack_t = ATTACK_T
	attack_cd = ATTACK_CD
	stamina -= ATTACK_COST
	stam_delay = maxf(stam_delay, 0.3)
	swing_hit = false
	swing_id += 1
	game.sfx.play("slash", -6.0)

func _swing_check() -> void:
	var rc := attack_rect()
	var b = game.boss
	if not swing_hit and b != null and b.can_be_hit() and rc.intersects(b.hurt_rect()):
		swing_hit = true
		b.take_damage(damage, true)
		energy = minf(max_energy, energy + 8.0)
		game.hitstop(0.05)
		game.shake_add(3.0)
		game.sfx.play("hit", -4.0)
		var hp_pos := Vector2(clampf(b.position.x, rc.position.x, rc.end.x), rc.position.y + 40.0)
		game.fx.burst(hp_pos, 10, Color(1, 0.95, 0.7), 260.0, 4.0, 0.35)
		if prologue:
			game.on_prologue_hit()
	if game.damage_minions_rect(rc, damage, swing_id):
		energy = minf(max_energy, energy + 3.0)
		game.hitstop(0.03)
		game.sfx.play("hit", -8.0, 1.3)
	for hz in game.hazards.get_children():
		if hz is Hazard and hz.breakable and not hz.friendly and not hz.dead and rc.grow(hz.r).has_point(hz.position):
			hz.dead = true
			energy = minf(max_energy, energy + 4.0)
			game.fx.burst(hz.position, 14, hz.col, 220.0, 4.0, 0.4)
			game.sfx.play("hit", -8.0, 1.5)

# ------------------------------------------------------------------ runes
func cast_rune(i: int) -> void:
	if not game.runes[i] or rune_cd[i] > 0.0 or game.state != game.S.FIGHT:
		return
	var info: Dictionary = Lore.RUNES[i]
	if energy < float(info["cost"]):
		game.ui_flash_msg("Not enough Rune Energy")
		return
	var b = game.boss
	if i != 3 and (b == null or not b.can_be_hit()):
		return
	energy -= float(info["cost"])
	rune_cd[i] = float(info["cd"])
	game.sfx.play("rune", -3.0)
	match i:
		0:
			for k in 3:
				Hazard.spike(game, clampf(b.position.x + (k - 1) * 130.0, 60.0, Cfg.W - 60.0), 0.18 + k * 0.12, int(damage * 2.2))
		1:
			var spawn := position + Vector2(facing * 30.0, -34.0)
			Hazard.bolt(game, spawn, Vector2(facing * 640.0, 0.0), 17.0, int(damage * 3.0), Color(1.0, 0.42, 0.1), {"friendly": true, "life": 3.0})
			game.fx.burst(spawn, 12, Color(1, 0.5, 0.1), 200.0, 5.0, 0.4)
		2:
			Hazard.smite(game, b.position.x, int(damage * 6.0))
		3:
			skin_t = 8.0
			game.fx.ring(center(), 70.0, Color(0.7, 0.72, 0.78), 0.5)
			game.sfx.play("stone", -2.0)

# ------------------------------------------------------------------ damage
func take_hit(d: int, src_x: float) -> bool:
	if dead or locked or iframes > 0.0 or roll_t > 0.0 or dash_t > 0.0:
		return false
	if skin_t > 0.0:
		skin_t = 0.0
		iframes = 0.8
		game.fx.burst(center(), 20, Color(0.7, 0.72, 0.78), 280.0, 5.0, 0.6)
		game.fx.ring(center(), 90.0, Color(0.8, 0.82, 0.88), 0.4)
		game.sfx.play("stone", 0.0, 0.7)
		game.shake_add(4.0)
		game.fx.popup(position + Vector2(0, -80), "BLOCKED", Color(0.8, 0.82, 0.9))
		return true
	if armor_shield > 0 and not prologue:
		armor_shield -= 1
		iframes = 1.0
		game.fx.burst(center(), 18, Color(0.85, 0.88, 0.95), 280.0, 4.0, 0.5)
		game.fx.ring(center(), 70.0, Color(0.9, 0.9, 1.0), 0.35)
		game.sfx.play("stone", 0.0, 1.1)
		game.shake_add(5.0)
		game.fx.popup(position + Vector2(0, -80), "ARMOUR", Color(0.85, 0.9, 1.0))
		return true
	hp -= d
	if game.boss != null and game.boss.has_method("on_player_hurt"):
		game.boss.on_player_hurt()
	if prologue:
		hp = maxi(hp, 1)
	iframes = 1.3
	var s := 1.0 if position.x >= src_x else -1.0
	vel = Vector2(s * 320.0, -380.0)
	on_ground = false
	game.hitstop(0.08)
	game.shake_add(11.0)
	game.red_flash = 0.45
	game.sfx.play("hurt")
	game.fx.burst(center(), 16, Color(0.8, 0.55, 0.3), 300.0, 5.0, 0.6)
	if hp <= 0:
		dead = true
		game.on_player_dead()
	return true

# ------------------------------------------------------------------ draw
func _rot(pts: PackedVector2Array, ang: float, origin: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(origin + (p - origin).rotated(ang))
	return out

func _draw() -> void:
	if hidden_body:
		return
	var stretch := clampf(-vel.y / 1800.0, -0.18, 0.22)
	var sc := Vector2(1.0 - stretch * 0.5 + squash * 0.25, 1.0 + stretch - squash * 0.25)
	var rot := 0.0
	if roll_t > 0.0:
		rot = (1.0 - roll_t / ROLL_T) * TAU * roll_dir
	draw_set_transform(Vector2(0, -28.0 * sc.y), rot, Vector2(sc.x * facing, sc.y))
	# ember wings
	if has_wings:
		var fl := sin(anim_t * 18.0) * 6.0
		var wing := PackedVector2Array([Vector2(-14, -8), Vector2(-52, -34 + fl), Vector2(-40, -6), Vector2(-56, 10 + fl), Vector2(-14, 8)])
		draw_colored_polygon(wing, Color(1.0, 0.4, 0.08, 0.75))
	# boots
	Art.shape(self, Art.P([-18, 20, -4, 20, -2, 30, -20, 30]), Color(0.16, 0.11, 0.08), 0.0, 2.0)
	Art.shape(self, Art.P([4, 20, 18, 20, 22, 30, 4, 30]), Color(0.16, 0.11, 0.08), 0.0, 2.0)
	# pixel-art body (hand-placed sprite)
	PixSprite.draw(self, PixSprite.SPUD, Vector2(0, -1), 3.0, hurt_flash())
	if armor:
		draw_arc(Vector2.ZERO, 26.0, PI * 0.9, PI * 2.1, 14, Color(0.3, 0.42, 0.2), 6.0)
		draw_circle(Vector2(-18, -18), 7.0, Color(0.3, 0.42, 0.2))
		draw_circle(Vector2(18, -18), 7.0, Color(0.3, 0.42, 0.2))
	# stone skin
	if skin_t > 0.0:
		var st := body_pts.duplicate()
		for i in st.size():
			st[i] = st[i] * 1.12
		draw_colored_polygon(st, Color(0.55, 0.58, 0.63, 0.82))
		draw_line(Vector2(-8, -20), Vector2(2, -4), Color(0.3, 0.32, 0.36), 2.0)
		draw_line(Vector2(2, -4), Vector2(14, 6), Color(0.3, 0.32, 0.36), 2.0)
		draw_circle(Vector2(8, -6), 5.0, Color.WHITE)
		draw_circle(Vector2(10, -6), 2.4, Color.BLACK)
		draw_circle(Vector2(-3, -6), 4.0, Color.WHITE)
		draw_circle(Vector2(-1, -6), 2.0, Color.BLACK)
	# earned armour pieces (tiers from boss drops)
	if game != null and not prologue:
		_draw_armor_pieces()
	# Root-Blade
	var swing := 0.0
	if attack_t > 0.0:
		swing = 1.0 - attack_t / ATTACK_T
	var ang := -0.7 + (swing * 2.2 - 0.9 if attack_t > 0.0 else 0.0)
	var base := Vector2(18, 6)
	var blade := PackedVector2Array([base + Vector2(0, 4), base + Vector2(10, -2), base + Vector2(46, -14), base + Vector2(58, -30), base + Vector2(40, -4), base + Vector2(8, 8)])
	draw_colored_polygon(_rot(blade, ang, base), Color("2f4a22"))
	draw_polyline(_rot(PackedVector2Array([base + Vector2(10, -2), base + Vector2(46, -14), base + Vector2(58, -30)]), ang, base), Color("9fd070"), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# slash arc
	if attack_t > 0.0:
		var k := 1.0 - attack_t / ATTACK_T
		var a0 := -1.5 if facing > 0 else PI + 1.5
		var a1 := 0.9 if facing > 0 else PI - 0.9
		var cc := Vector2(facing * 6.0, -34.0)
		draw_arc(cc, 66.0, a0, lerpf(a0, a1, minf(1.0, k * 1.6)), 14, Color(0.85, 1.0, 0.65, 0.85 * (1.0 - k * 0.6)), 7.0)

const TIER_COLS := [Color(0.45, 0.4, 0.36), Color(0.5, 0.5, 0.55), Color(0.6, 0.62, 0.68), Color(0.35, 0.55, 0.75), Color(0.3, 0.65, 0.45), Color(0.8, 0.65, 0.25), Color(0.85, 0.35, 0.25), Color(0.7, 0.4, 0.85), Color(0.95, 0.9, 0.6)]

func _tc(slot: int) -> Color:
	var t: int = int(game.armor_tiers[slot])
	return TIER_COLS[clampi(t - 1, 0, 8)]

func _draw_armor_pieces() -> void:
	var tiers: Array = game.armor_tiers
	if int(tiers[4]) > 0:   # greaves
		var c := _tc(4)
		Art.shape(self, Art.P([-19, 19, -3, 19, -2, 31, -21, 31]), c, 0.0, 2.0)
		Art.shape(self, Art.P([3, 19, 19, 19, 23, 31, 3, 31]), c, 0.0, 2.0)
	if int(tiers[2]) > 0:   # cuirass
		var c := _tc(2)
		Art.shape(self, Art.P([-15, -8, 15, -8, 17, 12, 0, 18, -17, 12]), c, 0.0, 2.2)
		draw_line(Vector2(0, -8), Vector2(0, 17), Art.INK, 1.5)
	if int(tiers[1]) > 0:   # pauldrons
		var c := _tc(1)
		Art.shape(self, Art.P([-24, -14, -10, -18, -8, -6, -22, -2]), c, 0.0, 2.0)
		Art.shape(self, Art.P([10, -18, 24, -14, 22, -2, 8, -6]), c, 0.0, 2.0)
		if int(tiers[1]) >= 4:
			Art.shape(self, Art.P([-20, -14, -18, -26, -14, -15]), c.darkened(0.2), 0.0, 1.6)
			Art.shape(self, Art.P([14, -15, 18, -26, 20, -14]), c.darkened(0.2), 0.0, 1.6)
	if int(tiers[0]) > 0:   # helm (over the top of the tuber)
		var c := _tc(0)
		Art.shape(self, Art.P([-16, -14, -12, -26, 0, -30, 12, -26, 16, -14, 8, -15, 0, -17, -8, -15]), c, 0.0, 2.2)
		if int(tiers[0]) >= 3:
			Art.shape(self, Art.P([-2, -30, 2, -30, 4, -42, -4, -42]), Color(0.7, 0.1, 0.1), 0.0, 1.5)
	if int(tiers[3]) > 0:   # gauntlet on the sword hand
		var c := _tc(3)
		Art.shape(self, Art.P([14, 2, 26, 0, 28, 12, 15, 14]), c, 0.0, 2.0)

func hurt_flash() -> float:
	return 0.0
