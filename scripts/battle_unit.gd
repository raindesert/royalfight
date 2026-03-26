extends Node2D

var entity_kind := "unit"
var controller: Node = null
var team: int = 0
var enemy_team: int = 1
var lane: String = "left"
var troop_id: String = ""
var display_name: String = ""
var max_hp: float = 1.0
var hp: float = 1.0
var speed: float = 0.0
var attack_range: float = 24.0
var damage: float = 1.0
var attack_cooldown: float = 1.0
var radius: float = 18.0
var color: Color = Color.WHITE
var targets_buildings_only: bool = false
var is_dead: bool = false
var current_target: Node = null
var icon_texture: Texture2D = null

var _attack_timer: float = 0.0
var _retarget_timer: float = 0.0
var _focus_target: Node = null
var _focus_timer: float = 0.0
var _lane_side_preference: float = 1.0
var _windup_timer: float = 0.0
var _windup_duration: float = 0.001
var _recovery_timer: float = 0.0
var _recovery_duration: float = 0.001
var _pending_target: Node = null
var _hitstun_timer: float = 0.0
var _knockback_velocity := Vector2.ZERO
var _attack_pose_dir := Vector2.UP
var _visual_dirty := false
var _last_hp: float = 0.0
var _projectile_pos := Vector2.ZERO
var _projectile_target := Vector2.ZERO
var _projectile_progress: float = 0.0
var _projectile_duration: float = 0.0
var _has_projectile: bool = false


func setup(config: Dictionary, team_id: int, game_controller: Node, spawn_position: Vector2) -> void:
	controller = game_controller
	team = team_id
	enemy_team = controller.ENEMY_TEAM if team == controller.PLAYER_TEAM else controller.PLAYER_TEAM
	lane = str(config.get("lane", controller.LANE_LEFT))
	troop_id = str(config.get("id", "unit"))
	display_name = str(config.get("name", troop_id))
	max_hp = float(config.get("hp", 100.0))
	hp = max_hp
	speed = float(config.get("speed", 70.0))
	attack_range = float(config.get("range", 24.0))
	damage = float(config.get("damage", 20.0))
	attack_cooldown = float(config.get("cooldown", 1.0))
	radius = float(config.get("radius", 18.0))
	color = config.get("color", Color.WHITE)
	targets_buildings_only = bool(config.get("targets_buildings_only", false))
	icon_texture = controller.load_svg_texture("res://assets/units/%s.svg" % troop_id, 1.65)
	position = spawn_position
	_lane_side_preference = -1.0 if int(get_instance_id()) % 2 == 0 else 1.0
	z_index = 5
	add_to_group("battle_entity")


func _process(delta: float) -> void:
	if is_dead or controller == null:
		return
	if current_target != null and not is_instance_valid(current_target):
		current_target = null
	if _focus_target != null and not is_instance_valid(_focus_target):
		_focus_target = null
	if _pending_target != null and not is_instance_valid(_pending_target):
		_pending_target = null
		_windup_timer = 0.0
		_visual_dirty = true

	_attack_timer = max(_attack_timer - delta, 0.0)
	_retarget_timer = max(_retarget_timer - delta, 0.0)
	_focus_timer = max(_focus_timer - delta, 0.0)
	_windup_timer = max(_windup_timer - delta, 0.0)
	_recovery_timer = max(_recovery_timer - delta, 0.0)
	_hitstun_timer = max(_hitstun_timer - delta, 0.0)
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, 520.0 * delta)
	position += _knockback_velocity * delta

	if _has_projectile:
		_projectile_progress += delta
		_visual_dirty = true
		if _pending_target != null and is_instance_valid(_pending_target) and not _pending_target.is_dead:
			_projectile_target = _pending_target.global_position - global_position
		if _projectile_progress >= _projectile_duration:
			if _pending_target != null and is_instance_valid(_pending_target) and not _pending_target.is_dead:
				_pending_target.take_damage(damage, self)
				controller.on_damage_dealt(_pending_target, self)
			_has_projectile = false
			_projectile_progress = 0.0

	if _focus_timer <= 0.0:
		_focus_target = null

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

	if _hitstun_timer > 0.0 or _recovery_timer > 0.0:
		_visual_dirty = true
		_request_redraw()
		return

	current_target = controller.update_unit_target(self, current_target, _retarget_timer <= 0.0)
	if _retarget_timer <= 0.0:
		_retarget_timer = 0.18

	if current_target != null:
		var target_radius: float = float(current_target.radius)
		var offset: Vector2 = current_target.global_position - global_position
		var distance: float = offset.length()
		var desired_distance: float = attack_range + radius + target_radius
		if distance <= desired_distance:
			if _attack_timer <= 0.0:
				_begin_attack(current_target)
		else:
			_move_toward_position(current_target.global_position, delta)
	else:
		_follow_lane_path(delta)

	_apply_separation(delta)
	_request_redraw()


func _request_redraw() -> void:
	if _visual_dirty or hp != _last_hp:
		_last_hp = hp
		_visual_dirty = false
		queue_redraw()


func _begin_attack(target: Node) -> void:
	if target == null or not is_instance_valid(target) or target.is_dead:
		return
	_pending_target = target
	_windup_duration = min(0.28, attack_cooldown * 0.35)
	_windup_timer = _windup_duration
	_attack_pose_dir = (target.global_position - global_position).normalized()
	if _attack_pose_dir.length() <= 0.001:
		_attack_pose_dir = Vector2.UP if team == controller.PLAYER_TEAM else Vector2.DOWN
	_visual_dirty = true
	controller.play_attack_sfx(self)


func _resolve_attack() -> void:
	var resolved_target: Node = _pending_target
	if resolved_target == null or not is_instance_valid(resolved_target) or resolved_target.is_dead:
		_attack_timer = attack_cooldown
		_pending_target = null
		_windup_timer = 0.0
		return
	if attack_range > 40.0:
		_projectile_pos = Vector2.ZERO
		_projectile_target = resolved_target.global_position - global_position
		_projectile_progress = 0.0
		var distance: float = _projectile_target.length()
		_projectile_duration = max(0.12, distance / 480.0)
		_has_projectile = true
		_visual_dirty = true
	else:
		resolved_target.take_damage(damage, self)
		controller.on_damage_dealt(resolved_target, self)
	_attack_timer = attack_cooldown
	_recovery_duration = min(0.18, attack_cooldown * 0.22)
	_recovery_timer = _recovery_duration
	_pending_target = null
	_windup_timer = 0.0


func get_focus_target() -> Node:
	if _focus_target != null and is_instance_valid(_focus_target) and not _focus_target.is_dead:
		return _focus_target
	return null


func get_sight_radius() -> float:
	if targets_buildings_only:
		return 420.0
	return 250.0 if attack_range < 40.0 else 300.0


func remember_attacker(attacker: Node) -> void:
	if attacker == null:
		return
	if not is_instance_valid(attacker) or attacker.is_dead or attacker.team == team:
		return
	_focus_target = attacker
	_focus_timer = 2.2
	current_target = attacker
	_retarget_timer = 0.0


func _follow_lane_path(delta: float) -> void:
	var path: Array[Vector2] = controller.get_lane_path_for_unit(self)
	for waypoint in path:
		if global_position.distance_to(waypoint) > 14.0:
			_move_toward_position(waypoint, delta)
			return


func _move_toward_position(target_position: Vector2, delta: float) -> void:
	var offset: Vector2 = target_position - global_position
	var distance: float = offset.length()
	if distance <= 0.001:
		return
	var dir: Vector2 = offset / distance
	var blocker: Node = controller.get_friendly_blocker(self, dir)
	if blocker != null:
		var sidestep: Vector2 = Vector2(-dir.y, dir.x) * _lane_side_preference
		var around_dir: Vector2 = (dir * 0.35 + sidestep * 0.95).normalized()
		var around_position: Vector2 = global_position + around_dir * speed * delta
		if controller.can_move_to_position(self, around_position):
			position = around_position
			return
		sidestep = -sidestep
		around_dir = (dir * 0.35 + sidestep * 0.95).normalized()
		around_position = global_position + around_dir * speed * delta
		if controller.can_move_to_position(self, around_position):
			position = around_position
			_lane_side_preference *= -1.0
			return
		var blocker_gap: float = global_position.distance_to(blocker.global_position)
		if blocker_gap <= radius + blocker.radius + 2.0:
			return
	var candidate_position: Vector2 = global_position + dir * speed * delta
	if controller.can_move_to_position(self, candidate_position):
		position = candidate_position


func _apply_separation(delta: float) -> void:
	var push: Vector2 = controller.get_unit_separation(self)
	if push.length() > 0.001:
		position += push.limit_length(42.0 * delta)


func clear_target_reference(target: Node) -> void:
	if current_target == target:
		current_target = null
	if _focus_target == target:
		_focus_target = null
		_focus_timer = 0.0
	if _pending_target == target:
		_pending_target = null
		_windup_timer = 0.0


func take_damage(amount: float, attacker: Node = null) -> void:
	if is_dead:
		return
	hp -= amount
	_visual_dirty = true
	if attacker != null:
		remember_attacker(attacker)
		var kb_dir: Vector2 = (global_position - attacker.global_position).normalized()
		if kb_dir.length() <= 0.001:
			kb_dir = Vector2(0.0, -1.0 if attacker.team == controller.PLAYER_TEAM else 1.0)
		_knockback_velocity += kb_dir * 55.0
	_hitstun_timer = 0.11
	_recovery_timer = max(_recovery_timer, 0.06)
	_windup_timer = 0.0
	_pending_target = null
	if hp <= 0.0:
		hp = 0.0
		is_dead = true
		if controller != null:
			controller.on_entity_destroyed(self)
		queue_free()
	else:
		queue_redraw()


func _draw() -> void:
	var draw_offset := Vector2.ZERO
	var draw_rotation := 0.0
	var draw_scale := Vector2.ONE
	if _pending_target != null and _windup_duration > 0.0:
		var windup_t := 1.0 - (_windup_timer / _windup_duration)
		var eased := windup_t * windup_t * (3.0 - 2.0 * windup_t)
		draw_offset -= _attack_pose_dir * (5.0 * eased)
		draw_scale = Vector2(1.0 - 0.08 * eased, 1.0 + 0.14 * eased)
		draw_rotation = _attack_pose_dir.x * -0.08 * eased
	elif _recovery_timer > 0.0 and _recovery_duration > 0.0:
		var recovery_t := _recovery_timer / _recovery_duration
		draw_offset += _attack_pose_dir * (4.0 * recovery_t)
		draw_scale = Vector2(1.0 + 0.10 * recovery_t, 1.0 - 0.12 * recovery_t)
		draw_rotation = _attack_pose_dir.x * 0.06 * recovery_t
	if _hitstun_timer > 0.0:
		var stun_t := _hitstun_timer / 0.11
		draw_scale += Vector2(0.08 * stun_t, -0.10 * stun_t)
		draw_offset += _knockback_velocity.normalized() * (2.0 * stun_t)
	draw_set_transform(draw_offset, draw_rotation, draw_scale)

	var plate_color := color if team == controller.PLAYER_TEAM else color.darkened(0.22)
	var plate_outer := plate_color.darkened(0.52)
	var plate_inner := plate_color.darkened(0.12)
	if _hitstun_timer > 0.0:
		plate_inner = plate_inner.lightened(0.18)
	if _pending_target != null:
		plate_inner = plate_inner.lightened(0.08)

	var team_ring_color := Color(0.28, 0.58, 1.0) if team == controller.PLAYER_TEAM else Color(1.0, 0.38, 0.32)
	if team == controller.ENEMY_TEAM:
		team_ring_color = Color(0.95, 0.35, 0.28)
		plate_inner = plate_inner.darkened(0.08)

	draw_circle(Vector2(0.0, radius * 0.62), radius * 0.94, Color(0.03, 0.05, 0.07, 0.2))
	draw_circle(Vector2.ZERO, radius + 3.0, plate_outer)
	draw_circle(Vector2.ZERO, radius, plate_inner)
	draw_circle(Vector2.ZERO, radius + 5.5, team_ring_color, false, 3.0)
	draw_circle(Vector2(-radius * 0.18, -radius * 0.22), radius * 0.56, Color(1.0, 1.0, 1.0, 0.08))
	if current_target != null:
		draw_circle(Vector2.ZERO, radius + 6.0, Color(1.0, 0.95, 0.45, 0.18))
	if _pending_target != null:
		draw_arc(Vector2.ZERO, radius + 8.0, -PI * 0.5, -PI * 0.5 + PI * 1.6, 18, Color(1.0, 0.85, 0.35), 3.0)
	if icon_texture != null:
		var icon_rect := Rect2(Vector2(-radius * 0.78, -radius * 0.92), Vector2(radius * 1.56, radius * 1.56))
		draw_texture_rect(icon_texture, icon_rect, false, Color(1.0, 1.0, 1.0, 0.98))
	var lane_mark_x := -radius * 0.9 if lane == controller.LANE_LEFT else radius * 0.56
	draw_rect(Rect2(Vector2(lane_mark_x, -radius * 0.72), Vector2(radius * 0.3, radius * 1.44)), Color(1.0, 0.96, 0.86, 0.18))
	var bar_width := radius * 2.0
	var bar_rect := Rect2(Vector2(-radius, -radius - 12.0), Vector2(bar_width, 6.0))
	draw_rect(bar_rect, Color(0.15, 0.15, 0.18, 0.9))
	var hp_ratio := 0.0 if max_hp <= 0.0 else hp / max_hp
	draw_rect(Rect2(bar_rect.position, Vector2(bar_width * hp_ratio, 6.0)), Color(0.36, 0.9, 0.42))

	if _has_projectile:
		var t: float = _projectile_progress / _projectile_duration
		var arc_height: float = 35.0
		var current_pos: Vector2 = _projectile_pos.lerp(_projectile_target, t)
		current_pos += Vector2(0.0, -arc_height * sin(t * PI))
		var proj_dir: Vector2 = (_projectile_target - _projectile_pos).normalized()
		if proj_dir.length() > 0.001:
			var angle: float = proj_dir.angle()
			var arrow_color := Color(1.0, 0.9, 0.4) if team == controller.PLAYER_TEAM else Color(1.0, 0.6, 0.3)
			draw_circle(current_pos, 5.0, arrow_color)
			draw_line(current_pos, current_pos - proj_dir * 14.0, arrow_color, 4.0)
			var arrowhead := Vector2(cos(angle), sin(angle)) * 12.0
			draw_line(current_pos - proj_dir * 8.0, current_pos + arrowhead.rotated(2.6) - proj_dir * 3.0, arrow_color, 3.5)
			draw_line(current_pos - proj_dir * 8.0, current_pos + arrowhead.rotated(-2.6) - proj_dir * 3.0, arrow_color, 3.5)
