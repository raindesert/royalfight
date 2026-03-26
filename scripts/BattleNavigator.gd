class_name BattleNavigator
extends Node

const RIVER_Y := 600.0
const RIVER_HALF_HEIGHT := 36.0
const BRIDGE_WIDTH := 96.0
const BRIDGE_HEIGHT := 100.0
const BRIDGE_NAV_TOLERANCE := 8.0
const LANE_DEPLOY_HALF_WIDTH := 64.0
const PLAYER_DEPLOY_Y := 700.0
const ENEMY_DEPLOY_Y := 500.0

const LANE_LEFT := "left"
const LANE_RIGHT := "right"
const LANE_CENTER := "center"

const LANE_X := {
	LANE_LEFT: 210.0,
	LANE_RIGHT: 510.0,
	LANE_CENTER: 360.0
}

const BRIDGE_Y := {
	0: 650.0,
	1: 550.0
}

const FRONTLINE_Y := {
	0: 760.0,
	1: 440.0
}

const ARENA_RECT := Rect2(40, 110, 640, 980)

var _battle_buildings: Array[Node] = []


func init(battle_buildings: Array[Node]) -> void:
	_battle_buildings = battle_buildings


func get_bridge_rect(lane: String) -> Rect2:
	return Rect2(Vector2(LANE_X[lane] - BRIDGE_WIDTH * 0.5, RIVER_Y - BRIDGE_HEIGHT * 0.5), Vector2(BRIDGE_WIDTH, BRIDGE_HEIGHT))


func _get_lane_spawn_x(raw_x: float, lane: String) -> float:
	var lane_center_x: float = LANE_X[lane]
	return lane_center_x + clampf(raw_x - lane_center_x, -LANE_DEPLOY_HALF_WIDTH, LANE_DEPLOY_HALF_WIDTH)


func _get_player_deploy_position(world_pos: Vector2, lane: String) -> Vector2:
	var spawn_x: float = _get_lane_spawn_x(world_pos.x, lane)
	var spawn_y: float = clampf(world_pos.y, PLAYER_DEPLOY_Y + 22.0, ARENA_RECT.end.y - 24.0)
	return Vector2(spawn_x, spawn_y)


func _get_enemy_deploy_position(lane: String) -> Vector2:
	var spawn_x: float = _get_lane_spawn_x(float(LANE_X[lane]) + randf_range(-42.0, 42.0), lane)
	var spawn_y: float = randf_range(ARENA_RECT.position.y + 24.0, ENEMY_DEPLOY_Y - 20.0)
	return Vector2(spawn_x, spawn_y)


func get_navigation_target_for_unit(unit: Node, desired_target: Vector2) -> Vector2:
	if unit == null or unit.lane == LANE_CENTER:
		return desired_target
	var lane_x: float = float(LANE_X[unit.lane])
	if unit.team == 0 and desired_target.y < RIVER_Y - RIVER_HALF_HEIGHT:
		if unit.global_position.y > BRIDGE_Y[0] + BRIDGE_NAV_TOLERANCE:
			return Vector2(lane_x, BRIDGE_Y[0])
		if unit.global_position.y > BRIDGE_Y[1] + BRIDGE_NAV_TOLERANCE:
			return Vector2(lane_x, BRIDGE_Y[1])
	elif unit.team == 1 and desired_target.y > RIVER_Y + RIVER_HALF_HEIGHT:
		if unit.global_position.y < BRIDGE_Y[1] - BRIDGE_NAV_TOLERANCE:
			return Vector2(lane_x, BRIDGE_Y[1])
		if unit.global_position.y < BRIDGE_Y[0] - BRIDGE_NAV_TOLERANCE:
			return Vector2(lane_x, BRIDGE_Y[0])
	return desired_target


func _is_river_blocked_for_unit(unit: Node, candidate_position: Vector2) -> bool:
	if unit == null or unit.lane == LANE_CENTER:
		return false
	var river_top: float = RIVER_Y - RIVER_HALF_HEIGHT
	var river_bottom: float = RIVER_Y + RIVER_HALF_HEIGHT
	if candidate_position.y + unit.radius <= river_top or candidate_position.y - unit.radius >= river_bottom:
		return false
	var bridge_half_width: float = BRIDGE_WIDTH * 0.5 - maxf(6.0, unit.radius * 0.25)
	return abs(candidate_position.x - LANE_X[unit.lane]) > bridge_half_width


func constrain_unit_position(unit: Node, candidate_position: Vector2) -> Vector2:
	if unit == null:
		return candidate_position
	var constrained: Vector2 = candidate_position
	constrained.x = clampf(constrained.x, ARENA_RECT.position.x + unit.radius, ARENA_RECT.end.x - unit.radius)
	constrained.y = clampf(constrained.y, ARENA_RECT.position.y + unit.radius, ARENA_RECT.end.y - unit.radius)
	if _is_river_blocked_for_unit(unit, constrained):
		var bridge_half_width: float = BRIDGE_WIDTH * 0.5 - maxf(6.0, unit.radius * 0.25)
		constrained.x = clampf(constrained.x, LANE_X[unit.lane] - bridge_half_width, LANE_X[unit.lane] + bridge_half_width)
		if _is_river_blocked_for_unit(unit, constrained):
			constrained.y = RIVER_Y - RIVER_HALF_HEIGHT - unit.radius if constrained.y < RIVER_Y else RIVER_Y + RIVER_HALF_HEIGHT + unit.radius
	return constrained


func get_lane_path_for_unit(unit: Node) -> Array[Vector2]:
	var lane: String = unit.lane
	var lane_x: float = LANE_X[lane]
	var waypoints: Array[Vector2] = []
	var enemy_team: int = 1 if unit.team == 0 else 0
	if unit.team == 0:
		waypoints.append(Vector2(lane_x, FRONTLINE_Y[0]))
		waypoints.append(Vector2(lane_x, BRIDGE_Y[0]))
		waypoints.append(Vector2(lane_x, BRIDGE_Y[1]))
		var enemy_tower = get_lane_tower(enemy_team, lane)
		if enemy_tower != null:
			waypoints.append(enemy_tower.global_position)
		var enemy_king = get_king_tower(enemy_team)
		if enemy_king != null:
			waypoints.append(enemy_king.global_position)
	else:
		waypoints.append(Vector2(lane_x, FRONTLINE_Y[1]))
		waypoints.append(Vector2(lane_x, BRIDGE_Y[1]))
		waypoints.append(Vector2(lane_x, BRIDGE_Y[0]))
		var player_tower = get_lane_tower(enemy_team, lane)
		if player_tower != null:
			waypoints.append(player_tower.global_position)
		var player_king = get_king_tower(enemy_team)
		if player_king != null:
			waypoints.append(player_king.global_position)
	return waypoints


func get_lane_tower(team: int, lane: String) -> Node:
	for entity in _battle_buildings:
		if entity.entity_kind == "building" and not entity.is_dead and entity.team == team and entity.lane == lane and not entity.is_king:
			return entity
	return null


func get_king_tower(team: int) -> Node:
	for entity in _battle_buildings:
		if entity.entity_kind == "building" and not entity.is_dead and entity.team == team and entity.is_king:
			return entity
	return null


func can_move_to_position(unit: Node, candidate_position: Vector2, _battle_units: Array[Node]) -> bool:
	if unit == null:
		return false
	var constrained := constrain_unit_position(unit, candidate_position)
	if constrained.distance_to(candidate_position) > 0.05:
		return false
	for entity in _battle_units:
		if entity == unit:
			continue
		if entity.is_dead or entity.entity_kind != "unit" or entity.team != unit.team or entity.lane != unit.lane:
			continue
		var min_distance: float = unit.radius + entity.radius + 2.0
		if candidate_position.distance_to(entity.global_position) < min_distance:
			return false
	return true
