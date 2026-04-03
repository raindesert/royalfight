extends Node2D

var spell_id: String = ""
var spell_type: String = ""
var display_name: String = ""
var team: int = 0
var controller: Node = null
var cast_position: Vector2 = Vector2.ZERO
var radius: float = 0.0
var damage: float = 0.0
var freeze_duration: float = 0.0
var lightning_count: int = 0
var lightning_damage: float = 0.0

var _duration: float = 0.0
var _progress: float = 0.0
var _targets_hit: Array = []
var _lightning_chain: Array = []
var _lightning_timer: float = 0.0
var _lightning_index: int = 0
var _is_dead: bool = false

const TEAM_COLORS := {
	0: Color(0.28, 0.58, 1.0),
	1: Color(0.95, 0.35, 0.28)
}


func setup(config: Dictionary, team_id: int, game_controller: Node, target_pos: Vector2) -> void:
	controller = game_controller
	team = team_id
	spell_id = str(config.get("id", "spell"))
	display_name = str(config.get("ui_name", spell_id))
	spell_type = str(config.get("spell_effect", "damage"))
	cast_position = target_pos
	radius = float(config.get("spell_radius", 50.0))
	damage = float(config.get("spell_damage", 0.0))
	freeze_duration = float(config.get("spell_freeze_duration", 0.0))
	lightning_count = int(config.get("spell_lightning_count", 0))
	lightning_damage = float(config.get("spell_lightning_damage", 0.0))
	z_index = 10
	position = cast_position

	match spell_type:
		"damage":
			_duration = 0.6
			_apply_damage_effect()
		"freeze":
			_duration = 1.2
			_apply_freeze_effect()
		"lightning":
			_duration = 0.8
			_lightning_timer = 0.0
			_lightning_index = 0
			_build_lightning_chain()


func _apply_damage_effect() -> void:
	var entities: Array = controller.get_battle_entities()
	for entity in entities:
		if entity.is_dead or entity.team == team:
			continue
		var dist: float = cast_position.distance_to(entity.global_position)
		if dist <= radius:
			entity.take_damage(damage, self)
			controller.on_damage_dealt(entity, self)
			_targets_hit.append(entity)


func _apply_freeze_effect() -> void:
	var entities: Array = controller.get_battle_entities()
	for entity in entities:
		if entity.is_dead or entity.team == team:
			continue
		if entity.entity_kind != "unit":
			continue
		var dist: float = cast_position.distance_to(entity.global_position)
		if dist <= radius:
			if entity.has_method("apply_freeze"):
				entity.apply_freeze(freeze_duration)
			_targets_hit.append(entity)


func _build_lightning_chain() -> void:
	var entities: Array = controller.get_battle_entities()
	var candidates: Array = []
	for entity in entities:
		if entity.is_dead or entity.team == team:
			continue
		var dist: float = cast_position.distance_to(entity.global_position)
		if dist <= radius * 1.5:
			candidates.append({"entity": entity, "dist": dist})
	candidates.sort_custom(func(a, b): return a.dist < b.dist)
	var count: int = min(lightning_count, candidates.size())
	for i in range(count):
		_lightning_chain.append(candidates[i].entity)


func _process(delta: float) -> void:
	if _is_dead:
		return
	_progress += delta

	if spell_type == "lightning" and _lightning_index < _lightning_chain.size():
		_lightning_timer += delta
		var interval: float = 0.15
		while _lightning_timer >= interval and _lightning_index < _lightning_chain.size():
			_lightning_timer -= interval
			var target: Node = _lightning_chain[_lightning_index]
			if is_instance_valid(target) and not target.is_dead:
				target.take_damage(lightning_damage, self)
				controller.on_damage_dealt(target, self)
			_lightning_index += 1

	if _progress >= _duration:
		_is_dead = true
		queue_free()
		return

	queue_redraw()


func _draw() -> void:
	var t: float = clampf(_progress / maxf(_duration, 0.001), 0.0, 1.0)
	var team_color: Color = TEAM_COLORS.get(team, Color.WHITE)

	match spell_type:
		"damage":
			_draw_fireball(t, team_color)
		"freeze":
			_draw_freeze(t, team_color)
		"lightning":
			_draw_lightning(t, team_color)


func _draw_fireball(t: float, team_color: Color) -> void:
	var expand: float = radius * (0.3 + t * 0.7)
	var alpha: float = (1.0 - t) * 0.8
	for ring in range(3):
		var ring_r: float = expand * (1.0 + ring * 0.3)
		var ring_a: float = alpha * (1.0 - ring * 0.25)
		var ring_color := Color(1.0, 0.5 + ring * 0.15, 0.1, ring_a)
		draw_circle(Vector2.ZERO, ring_r, ring_color, false, 4.0 - ring)
	draw_circle(Vector2.ZERO, expand * 0.4, Color(1.0, 0.9, 0.5, alpha * 0.7))
	for particle in range(8):
		var angle: float = float(particle) * TAU / 8.0 + t * 2.0
		var dist: float = expand * (0.5 + t * 0.5)
		var px: float = cos(angle) * dist
		var py: float = sin(angle) * dist
		var particle_a: float = (1.0 - t) * 0.6
		draw_circle(Vector2(px, py), 3.0 * (1.0 - t), Color(1.0, 0.6, 0.2, particle_a))


func _draw_freeze(t: float, team_color: Color) -> void:
	var alpha: float = (1.0 - t) * 0.7
	var current_radius: float = radius * (0.5 + t * 0.5)
	draw_circle(Vector2.ZERO, current_radius, Color(0.4, 0.7, 1.0, alpha * 0.3))
	draw_circle(Vector2.ZERO, current_radius, Color(0.6, 0.85, 1.0, alpha * 0.5), false, 3.0)
	for crystal in range(6):
		var angle: float = float(crystal) * TAU / 6.0
		var cx: float = cos(angle) * current_radius * 0.7
		var cy: float = sin(angle) * current_radius * 0.7
		var crystal_a: float = alpha * (0.8 - t * 0.3)
		draw_circle(Vector2(cx, cy), 8.0 * (1.0 - t * 0.5), Color(0.7, 0.9, 1.0, crystal_a))
		draw_circle(Vector2(cx, cy), 4.0, Color(0.9, 1.0, 1.0, crystal_a * 0.8))
	for ring in range(2):
		var ring_r: float = current_radius * (0.3 + ring * 0.35)
		var ring_a: float = alpha * (0.6 - ring * 0.2)
		draw_circle(Vector2.ZERO, ring_r, Color(0.5, 0.8, 1.0, ring_a), false, 2.0)


func _draw_lightning(t: float, team_color: Color) -> void:
	var alpha: float = (1.0 - t) * 0.9
	var lightning_color := Color(1.0, 0.95, 0.5, alpha)
	var origin: Vector2 = cast_position
	for i in range(_lightning_index):
		if i >= _lightning_chain.size():
			break
		var target: Node = _lightning_chain[i]
		if not is_instance_valid(target) or target.is_dead:
			continue
		var target_pos: Vector2 = target.global_position
		var end_pos: Vector2 = to_local(target_pos)
		_draw_lightning_bolt(origin, end_pos, lightning_color, 3.0)
		draw_circle(end_pos, 8.0 * (1.0 - t), Color(1.0, 1.0, 0.8, alpha * 0.8))
		origin = end_pos


func _draw_lightning_bolt(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var segments: int = 8
	var offset: Vector2 = to - from
	var seg_len: float = offset.length() / float(segments)
	var dir: Vector2 = offset.normalized()
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var jitter: float = 18.0
	var prev: Vector2 = from
	for i in range(segments):
		var t: float = float(i + 1) / float(segments)
		var jitter_amount: float = (1.0 - absf(t - 0.5) * 2.0) * jitter
		var point: Vector2 = from + offset * t + perp * randf_range(-jitter_amount, jitter_amount)
		if i == segments - 1:
			point = to
		draw_line(prev, point, color, width)
		draw_line(prev, point, Color(1.0, 1.0, 1.0, color.a * 0.5), width * 0.4)
		prev = point
