extends Node2D

var entity_kind := "building"
var controller: Node = null
var team: int = 0
var lane: String = "center"
var building_id: String = ""
var display_name: String = ""
var max_hp: float = 1.0
var hp: float = 1.0
var attack_range: float = 0.0
var damage: float = 0.0
var attack_cooldown: float = 1.0
var radius: float = 34.0
var color: Color = Color.WHITE
var shoots_units_only: bool = true
var is_king: bool = false
var is_dead: bool = false
var icon_texture: Texture2D = null

var _attack_timer: float = 0.0
var _windup_timer: float = 0.0
var _windup_duration: float = 0.001
var _recovery_timer: float = 0.0
var _recovery_duration: float = 0.001
var _pending_target: Node = null
var _hitflash_timer: float = 0.0
var _visual_dirty := false
var _last_hp: float = 0.0
var _projectile_pos := Vector2.ZERO
var _projectile_target := Vector2.ZERO
var _projectile_progress: float = 0.0
var _projectile_duration: float = 0.0
var _has_projectile: bool = false
var _projectile_target_node: Node = null


func setup(config: Dictionary, team_id: int, game_controller: Node, spawn_position: Vector2) -> void:
	controller = game_controller
	team = team_id
	lane = str(config.get("lane", controller.LANE_CENTER))
	building_id = str(config.get("id", "tower"))
	display_name = str(config.get("name", building_id))
	max_hp = float(config.get("hp", 1000.0))
	hp = max_hp
	attack_range = float(config.get("range", 0.0))
	damage = float(config.get("damage", 0.0))
	attack_cooldown = float(config.get("cooldown", 1.0))
	radius = float(config.get("radius", 34.0))
	color = config.get("color", Color.WHITE)
	shoots_units_only = bool(config.get("shoots_units_only", true))
	is_king = bool(config.get("is_king", false))
	icon_texture = controller.load_svg_texture("res://assets/buildings/%s.svg" % ("king_tower" if is_king else "crown_tower"), 1.7)
	position = spawn_position
	z_index = 3
	add_to_group("battle_entity")


func _process(delta: float) -> void:
	if is_dead or controller == null or damage <= 0.0 or attack_range <= 0.0:
		return
	if _pending_target != null and not is_instance_valid(_pending_target):
		_pending_target = null
		_windup_timer = 0.0
		_visual_dirty = true
	if _projectile_target_node != null and not is_instance_valid(_projectile_target_node):
		_projectile_target_node = null
	if _has_projectile:
		_projectile_progress += delta
		_visual_dirty = true
		if _projectile_target_node != null and is_instance_valid(_projectile_target_node) and not _projectile_target_node.is_dead:
			_projectile_target = _projectile_target_node.global_position
		if _projectile_progress >= _projectile_duration:
			if _projectile_target_node != null and is_instance_valid(_projectile_target_node) and not _projectile_target_node.is_dead:
				_projectile_target_node.take_damage(damage, self)
				controller.on_damage_dealt(_projectile_target_node, self)
			_has_projectile = false
			_projectile_progress = 0.0
			_projectile_target_node = null
	if is_king and not controller.is_king_tower_awake(team):
		_request_redraw()
		return
	_attack_timer = max(_attack_timer - delta, 0.0)
	_windup_timer = max(_windup_timer - delta, 0.0)
	_recovery_timer = max(_recovery_timer - delta, 0.0)
	_hitflash_timer = max(_hitflash_timer - delta, 0.0)

	if _pending_target != null:
		if _windup_timer > 0.0:
			_visual_dirty = true
			_request_redraw()
			return
		if not _has_projectile:
			_resolve_attack()
			_visual_dirty = true
			_request_redraw()
			return
		else:
			_request_redraw()
			return

	if _recovery_timer > 0.0:
		_visual_dirty = true
		_request_redraw()
		return

	var target: Node = controller.choose_target_for_building(self)
	if target == null:
		_request_redraw()
		return
	var distance: float = global_position.distance_to(target.global_position)
	if distance <= attack_range + target.radius:
		if _attack_timer <= 0.0:
			_pending_target = target
			_windup_duration = min(0.22, attack_cooldown * 0.28)
			_windup_timer = _windup_duration
			_visual_dirty = true
			controller.play_attack_sfx(self)
	_request_redraw()


func _request_redraw() -> void:
	if _visual_dirty or hp != _last_hp:
		_last_hp = hp
		_visual_dirty = false
		queue_redraw()


func _resolve_attack() -> void:
	var resolved_target: Node = _pending_target
	if resolved_target == null or not is_instance_valid(resolved_target) or resolved_target.is_dead:
		_attack_timer = attack_cooldown
		_pending_target = null
		_windup_timer = 0.0
		_projectile_target_node = null
		return
	_projectile_pos = global_position
	_projectile_target = resolved_target.global_position
	_projectile_target_node = resolved_target
	_projectile_progress = 0.0
	var distance: float = _projectile_pos.distance_to(_projectile_target)
	_projectile_duration = max(0.15, distance / 420.0)
	_has_projectile = true
	_attack_timer = attack_cooldown
	_recovery_duration = min(0.16, attack_cooldown * 0.2)
	_recovery_timer = _recovery_duration
	_pending_target = null
	_windup_timer = 0.0


func clear_target_reference(target: Node) -> void:
	if _pending_target == target:
		_pending_target = null
		_windup_timer = 0.0
	if _projectile_target_node == target:
		_projectile_target_node = null


func take_damage(amount: float, _attacker: Node = null) -> void:
	if is_dead:
		return
	hp -= amount
	_visual_dirty = true
	_hitflash_timer = 0.12
	if hp <= 0.0:
		hp = 0.0
		is_dead = true
		if controller != null:
			controller.on_entity_destroyed(self)
		queue_free()
	else:
		if is_king and controller != null:
			controller.wake_king_tower(team)
		queue_redraw()


func _draw() -> void:
	var draw_offset := Vector2.ZERO
	var draw_scale := Vector2.ONE
	if _pending_target != null and _windup_duration > 0.0:
		var windup_t := 1.0 - (_windup_timer / _windup_duration)
		var eased := windup_t * windup_t * (3.0 - 2.0 * windup_t)
		draw_offset += Vector2(0.0, 5.0 * eased)
		draw_scale = Vector2(1.0 + 0.05 * eased, 1.0 - 0.08 * eased)
	elif _recovery_timer > 0.0 and _recovery_duration > 0.0:
		var recovery_t := _recovery_timer / _recovery_duration
		draw_offset += Vector2(0.0, -6.0 * recovery_t)
		draw_scale = Vector2(1.0 - 0.04 * recovery_t, 1.0 + 0.06 * recovery_t)
	draw_set_transform(draw_offset, 0.0, draw_scale)

	var body_color := color if team == controller.PLAYER_TEAM else color.darkened(0.2)
	if is_king and not controller.is_king_tower_awake(team):
		body_color = body_color.darkened(0.45)
	if _hitflash_timer > 0.0:
		body_color = body_color.lightened(0.18)
	if _pending_target != null:
		body_color = body_color.lightened(0.08)
	var stone_dark := body_color.darkened(0.55)
	var roof_color := body_color.lightened(0.16)

	draw_circle(Vector2(0.0, radius * 0.72), radius * 0.9, Color(0.03, 0.05, 0.07, 0.22))
	var body_rect := Rect2(Vector2(-radius * 0.95, -radius * 0.82), Vector2(radius * 1.9, radius * 1.72))
	var inner_rect := body_rect.grow(-4.0)
	draw_rect(body_rect, stone_dark)
	draw_rect(inner_rect, body_color)
	var roof_rect := Rect2(Vector2(-radius * 0.78, -radius * 1.04), Vector2(radius * 1.56, radius * 0.32))
	draw_rect(roof_rect, roof_color)
	for crenel in range(3):
		var crenel_x := -radius * 0.72 + crenel * radius * 0.56
		draw_rect(Rect2(Vector2(crenel_x, -radius * 1.16), Vector2(radius * 0.26, radius * 0.2)), roof_color.darkened(0.08))
	if icon_texture != null:
		var icon_rect := Rect2(Vector2(-radius * 0.72, -radius * 0.94), Vector2(radius * 1.44, radius * 1.3))
		draw_texture_rect(icon_texture, icon_rect, false, Color(1.0, 1.0, 1.0, 0.97))
	if is_king:
		if not controller.is_king_tower_awake(team):
			draw_line(Vector2(-12, -10), Vector2(12, 10), Color(0.13, 0.14, 0.17, 0.85), 3.0)
			draw_line(Vector2(-12, 10), Vector2(12, -10), Color(0.13, 0.14, 0.17, 0.85), 3.0)
	else:
		var lane_mark_x := -radius * 0.7 if lane == controller.LANE_LEFT else radius * 0.44
		draw_rect(Rect2(Vector2(lane_mark_x, -radius * 0.26), Vector2(radius * 0.22, radius * 0.78)), Color(1.0, 0.97, 0.85, 0.2))
	if _pending_target != null:
		draw_arc(Vector2.ZERO, radius + 8.0, -PI * 0.5, -PI * 0.5 + PI * 1.7, 18, Color(1.0, 0.84, 0.3), 3.0)
	var bar_width := radius * 2.0
	var bar_rect := Rect2(Vector2(-radius, -radius - 14.0), Vector2(bar_width, 7.0))
	draw_rect(bar_rect, Color(0.15, 0.15, 0.18, 0.9))
	var hp_ratio := 0.0 if max_hp <= 0.0 else hp / max_hp
	draw_rect(Rect2(bar_rect.position, Vector2(bar_width * hp_ratio, 7.0)), Color(0.36, 0.9, 0.42))

	if _has_projectile and _projectile_duration > 0.0:
		var t: float = clampf(_projectile_progress / _projectile_duration, 0.0, 1.0)
		var arc_height: float = 45.0
		var current_world_pos: Vector2 = _projectile_pos.lerp(_projectile_target, t)
		current_world_pos += Vector2(0.0, -arc_height * sin(t * PI))
		var current_pos: Vector2 = to_local(current_world_pos)
		var proj_dir: Vector2 = (_projectile_target - _projectile_pos).normalized()
		if proj_dir.length() > 0.001:
			var angle: float = proj_dir.angle()
			var arrow_color := Color(1.0, 0.9, 0.4) if team == controller.PLAYER_TEAM else Color(1.0, 0.6, 0.3)
			draw_circle(current_pos, 6.0, arrow_color)
			draw_line(current_pos, current_pos - proj_dir * 16.0, arrow_color, 5.0)
			var arrowhead := Vector2(cos(angle), sin(angle)) * 14.0
			draw_line(current_pos - proj_dir * 10.0, current_pos + arrowhead.rotated(2.6) - proj_dir * 4.0, arrow_color, 4.0)
			draw_line(current_pos - proj_dir * 10.0, current_pos + arrowhead.rotated(-2.6) - proj_dir * 4.0, arrow_color, 4.0)
