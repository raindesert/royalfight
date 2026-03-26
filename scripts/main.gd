extends Node2D

const BattleUnit = preload("res://scripts/battle_unit.gd")
const BattleBuilding = preload("res://scripts/battle_building.gd")

const PLAYER_TEAM := 0
const ENEMY_TEAM := 1
const SCREEN_SIZE := Vector2(720, 1280)
const ARENA_RECT := Rect2(40, 110, 640, 980)
const RIVER_Y := 600.0
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
	PLAYER_TEAM: 650.0,
	ENEMY_TEAM: 550.0
}
const FRONTLINE_Y := {
	PLAYER_TEAM: 760.0,
	ENEMY_TEAM: 440.0
}

var troop_defs := {
	"knight": {
		"id": "knight",
		"name": "Knight",
		"cost": 3,
		"hp": 620.0,
		"speed": 92.0,
		"range": 20.0,
		"damage": 78.0,
		"cooldown": 1.05,
		"radius": 18.0,
		"color": Color(0.24, 0.61, 0.98)
	},
	"archer": {
		"id": "archer",
		"name": "Archer",
		"cost": 3,
		"hp": 260.0,
		"speed": 82.0,
		"range": 165.0,
		"damage": 52.0,
		"cooldown": 0.9,
		"radius": 15.0,
		"color": Color(0.39, 0.83, 0.56)
	},
	"giant": {
		"id": "giant",
		"name": "Giant",
		"cost": 5,
		"hp": 1650.0,
		"speed": 58.0,
		"range": 24.0,
		"damage": 155.0,
		"cooldown": 1.35,
		"radius": 25.0,
		"color": Color(0.93, 0.66, 0.24),
		"targets_buildings_only": true
	},
	"mini_pekka": {
		"id": "mini_pekka",
		"name": "Mini P.E.K.K.A",
		"cost": 4,
		"hp": 720.0,
		"speed": 98.0,
		"range": 20.0,
		"damage": 185.0,
		"cooldown": 1.2,
		"radius": 18.0,
		"color": Color(0.77, 0.42, 0.99)
	}
}

var player_deck: Array[String] = ["knight", "archer", "giant", "mini_pekka"]
var enemy_deck: Array[String] = ["knight", "archer", "giant", "mini_pekka"]

var player_elixir := 5.0
var enemy_elixir := 5.0
var max_elixir := 10.0
var elixir_regen := 0.9
var selected_card_id := ""
var battle_over := false
var winner_text := ""
var status_text := "Select a card, then click left or right lane on your side."
var ai_play_timer := 2.0
var king_awake := {
	PLAYER_TEAM: false,
	ENEMY_TEAM: false
}

var ui_layer: CanvasLayer
var elixir_label: Label
var enemy_elixir_label: Label
var status_label: Label
var selected_label: Label
var restart_button: Button
var card_buttons: Dictionary = {}
var card_icon_textures: Dictionary = {}
var _svg_texture_cache: Dictionary = {}
var _card_style_cache: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0
var _attack_sfx_light: AudioStreamWAV
var _attack_sfx_heavy: AudioStreamWAV
var _hit_sfx_light: AudioStreamWAV
var _hit_sfx_heavy: AudioStreamWAV


func _ready() -> void:
	randomize()
	_setup_audio()
	_load_card_icons()
	_setup_ui()
	_spawn_towers()
	queue_redraw()


func _process(delta: float) -> void:
	if battle_over:
		_update_ui()
		queue_redraw()
		return
	player_elixir = min(max_elixir, player_elixir + delta * elixir_regen)
	enemy_elixir = min(max_elixir, enemy_elixir + delta * elixir_regen)
	ai_play_timer -= delta
	if ai_play_timer <= 0.0:
		_enemy_play()
	_check_victory()
	_update_ui()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SCREEN_SIZE), Color(0.09, 0.27, 0.18))
	draw_rect(ARENA_RECT, Color(0.72, 0.78, 0.56))
	draw_rect(Rect2(ARENA_RECT.position.x, RIVER_Y - 36.0, ARENA_RECT.size.x, 72.0), Color(0.2, 0.58, 0.9))
	draw_line(Vector2(ARENA_RECT.position.x, RIVER_Y), Vector2(ARENA_RECT.end.x, RIVER_Y), Color(0.76, 0.9, 1.0), 4.0)
	draw_line(Vector2(ARENA_RECT.position.x, PLAYER_DEPLOY_Y), Vector2(ARENA_RECT.end.x, PLAYER_DEPLOY_Y), Color(1.0, 1.0, 1.0, 0.35), 2.0)
	draw_line(Vector2(360, ARENA_RECT.position.y), Vector2(360, ARENA_RECT.end.y), Color(1.0, 1.0, 1.0, 0.12), 2.0)
	draw_rect(Rect2(40, 1110, 640, 140), Color(0.11, 0.12, 0.16, 0.96), true)
	draw_rect(Rect2(40, 1110, 640, 140), Color(1, 1, 1, 0.08), false, 2.0)
	_draw_lane_guides()
	_draw_bridges()


func _draw_lane_guides() -> void:
	for lane in [LANE_LEFT, LANE_RIGHT]:
		var lane_x: float = LANE_X[lane]
		draw_line(Vector2(lane_x, ARENA_RECT.position.y), Vector2(lane_x, ARENA_RECT.end.y), Color(1.0, 1.0, 1.0, 0.08), 3.0)
		draw_circle(Vector2(lane_x, FRONTLINE_Y[PLAYER_TEAM]), 7.0, Color(0.44, 0.78, 1.0, 0.55))
		draw_circle(Vector2(lane_x, FRONTLINE_Y[ENEMY_TEAM]), 7.0, Color(1.0, 0.45, 0.42, 0.55))


func _draw_bridges() -> void:
	var bridge_width := 96.0
	var bridge_height := 100.0
	for lane in [LANE_LEFT, LANE_RIGHT]:
		var bridge_x: float = LANE_X[lane] - bridge_width * 0.5
		var bridge_rect := Rect2(bridge_x, RIVER_Y - bridge_height * 0.5, bridge_width, bridge_height)
		draw_rect(bridge_rect, Color(0.61, 0.48, 0.32))
		draw_rect(bridge_rect, Color(0.32, 0.22, 0.1, 0.85), false, 3.0)
		for plank in range(5):
			var plank_y := bridge_rect.position.y + 8.0 + plank * 18.0
			draw_line(Vector2(bridge_rect.position.x, plank_y), Vector2(bridge_rect.end.x, plank_y), Color(0.42, 0.28, 0.14), 3.0)


func _unhandled_input(event: InputEvent) -> void:
	if battle_over:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_player_deploy(event.position)


func _load_card_icons() -> void:
	for card_id in player_deck:
		card_icon_textures[card_id] = load_svg_texture("res://assets/units/%s.svg" % card_id, 1.35)


func load_svg_texture(asset_path: String, raster_scale: float = 1.0) -> Texture2D:
	var cache_key := "%s@%.2f" % [asset_path, raster_scale]
	if _svg_texture_cache.has(cache_key):
		return _svg_texture_cache[cache_key]
	if not FileAccess.file_exists(asset_path):
		return null
	var svg_text := FileAccess.get_file_as_string(asset_path)
	if svg_text.is_empty():
		return null
	var image := Image.new()
	var err := image.load_svg_from_string(svg_text, raster_scale)
	if err != OK:
		return null
	var texture := ImageTexture.create_from_image(image)
	_svg_texture_cache[cache_key] = texture
	return texture


func _setup_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var title := Label.new()
	title.text = "RoyalFight Dual Lane"
	title.position = Vector2(170, 18)
	title.size = Vector2(380, 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	ui_layer.add_child(title)
	status_label = Label.new()
	status_label.position = Vector2(48, 58)
	status_label.size = Vector2(624, 48)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 18)
	ui_layer.add_child(status_label)
	enemy_elixir_label = Label.new()
	enemy_elixir_label.position = Vector2(40, 118)
	enemy_elixir_label.size = Vector2(220, 30)
	enemy_elixir_label.add_theme_font_size_override("font_size", 18)
	ui_layer.add_child(enemy_elixir_label)
	elixir_label = Label.new()
	elixir_label.position = Vector2(40, 1068)
	elixir_label.size = Vector2(200, 32)
	elixir_label.add_theme_font_size_override("font_size", 22)
	ui_layer.add_child(elixir_label)
	selected_label = Label.new()
	selected_label.position = Vector2(280, 1068)
	selected_label.size = Vector2(400, 32)
	selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	selected_label.add_theme_font_size_override("font_size", 18)
	ui_layer.add_child(selected_label)
	var x := 48.0
	for card_id in player_deck:
		var button := Button.new()
		button.position = Vector2(x, 1130)
		button.size = Vector2(145, 100)
		button.icon = card_icon_textures.get(card_id, null)
		button.add_theme_font_size_override("font_size", 15)
		button.pressed.connect(_on_card_button_pressed.bind(card_id))
		ui_layer.add_child(button)
		card_buttons[card_id] = button
		x += 155.0
	restart_button = Button.new()
	restart_button.text = "Restart Battle"
	restart_button.position = Vector2(250, 520)
	restart_button.size = Vector2(220, 54)
	restart_button.visible = false
	restart_button.pressed.connect(_on_restart_pressed)
	ui_layer.add_child(restart_button)
	_update_ui()


func _update_ui() -> void:
	status_label.text = winner_text if battle_over else status_text
	elixir_label.text = "Elixir: %.1f / %.0f" % [player_elixir, max_elixir]
	enemy_elixir_label.text = "Enemy Elixir: %.1f / %.0f" % [enemy_elixir, max_elixir]
	selected_label.text = "Selected: %s" % (troop_defs[selected_card_id]["name"] if selected_card_id != "" else "None")
	restart_button.visible = battle_over
	for card_id in player_deck:
		var button: Button = card_buttons[card_id]
		var cost := int(troop_defs[card_id]["cost"])
		var disabled := battle_over or player_elixir < float(cost)
		var selected := card_id == selected_card_id
		var style_key := "%s:%s:%s" % [card_id, selected, disabled]
		button.text = "%s\nCost %d" % [troop_defs[card_id]["name"], cost]
		button.icon = card_icon_textures.get(card_id, null)
		button.disabled = disabled
		button.modulate = Color.WHITE
		var current_style_key := str(button.get_meta("style_key")) if button.has_meta("style_key") else ""
		if current_style_key != style_key:
			_apply_card_styles(button, card_id, selected, disabled)
			button.set_meta("style_key", style_key)


func _apply_card_styles(button: Button, card_id: String, selected: bool, disabled: bool) -> void:
	var accent: Color = troop_defs[card_id]["color"]
	var border := Color(1.0, 0.93, 0.58) if selected else Color(1.0, 1.0, 1.0, 0.18)
	var style_prefix := "%s:%s:%s" % [card_id, selected, disabled]
	button.add_theme_stylebox_override("normal", _get_card_stylebox("%s:normal" % style_prefix, accent.darkened(0.36), border))
	button.add_theme_stylebox_override("hover", _get_card_stylebox("%s:hover" % style_prefix, accent.darkened(0.28), border.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", _get_card_stylebox("%s:pressed" % style_prefix, accent.darkened(0.5), Color(1.0, 0.9, 0.66)))
	button.add_theme_stylebox_override("disabled", _get_card_stylebox("%s:disabled" % style_prefix, accent.darkened(0.62), Color(1.0, 1.0, 1.0, 0.08)))
	button.add_theme_color_override("font_color", Color(0.98, 0.97, 0.93))
	button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_pressed_color", Color(1.0, 1.0, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.86, 0.86, 0.86, 0.65))
	button.self_modulate = Color(1.0, 1.0, 1.0, 0.68) if disabled else Color.WHITE


func _get_card_stylebox(cache_key: String, fill_color: Color, border_color: Color) -> StyleBoxFlat:
	if _card_style_cache.has(cache_key):
		return _card_style_cache[cache_key]
	var style := _make_card_stylebox(fill_color, border_color)
	_card_style_cache[cache_key] = style
	return style


func _make_card_stylebox(fill_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 18
	style.corner_radius_bottom_right = 18
	return style


func _spawn_towers() -> void:
	_spawn_building({"id": "player_left_tower", "name": "Blue Left Tower", "hp": 1800.0, "range": 230.0, "damage": 58.0, "cooldown": 0.9, "radius": 34.0, "color": Color(0.3, 0.63, 1.0), "lane": LANE_LEFT}, PLAYER_TEAM, Vector2(180, 930))
	_spawn_building({"id": "player_right_tower", "name": "Blue Right Tower", "hp": 1800.0, "range": 230.0, "damage": 58.0, "cooldown": 0.9, "radius": 34.0, "color": Color(0.3, 0.63, 1.0), "lane": LANE_RIGHT}, PLAYER_TEAM, Vector2(540, 930))
	_spawn_building({"id": "player_king", "name": "Blue King Tower", "hp": 3200.0, "range": 250.0, "damage": 78.0, "cooldown": 1.0, "radius": 42.0, "color": Color(0.19, 0.47, 0.9), "is_king": true, "lane": LANE_CENTER}, PLAYER_TEAM, Vector2(360, 1070))
	_spawn_building({"id": "enemy_left_tower", "name": "Red Left Tower", "hp": 1800.0, "range": 230.0, "damage": 58.0, "cooldown": 0.9, "radius": 34.0, "color": Color(0.95, 0.35, 0.3), "lane": LANE_LEFT}, ENEMY_TEAM, Vector2(180, 270))
	_spawn_building({"id": "enemy_right_tower", "name": "Red Right Tower", "hp": 1800.0, "range": 230.0, "damage": 58.0, "cooldown": 0.9, "radius": 34.0, "color": Color(0.95, 0.35, 0.3), "lane": LANE_RIGHT}, ENEMY_TEAM, Vector2(540, 270))
	_spawn_building({"id": "enemy_king", "name": "Red King Tower", "hp": 3200.0, "range": 250.0, "damage": 78.0, "cooldown": 1.0, "radius": 42.0, "color": Color(0.84, 0.22, 0.2), "is_king": true, "lane": LANE_CENTER}, ENEMY_TEAM, Vector2(360, 130))


func _try_player_deploy(world_pos: Vector2) -> void:
	if selected_card_id == "":
		status_text = "Pick a card before dropping troops."
		return
	if not ARENA_RECT.has_point(world_pos):
		status_text = "Click inside the arena."
		return
	if world_pos.y < PLAYER_DEPLOY_Y:
		status_text = "You can only deploy on your half of the arena."
		return
	var cost := float(troop_defs[selected_card_id]["cost"])
	if player_elixir < cost:
		status_text = "Not enough elixir."
		return
	var lane := _lane_for_x(world_pos.x)
	player_elixir -= cost
	var spawn_x: float = LANE_X[lane] + randf_range(-24.0, 24.0)
	var spawn_y: float = clamp(world_pos.y, PLAYER_DEPLOY_Y + 20.0, ARENA_RECT.end.y - 24.0)
	_spawn_troop(selected_card_id, PLAYER_TEAM, lane, Vector2(spawn_x, spawn_y))
	status_text = "%s deployed on %s lane." % [troop_defs[selected_card_id]["name"], lane]
	selected_card_id = ""


func _enemy_play() -> void:
	var affordable: Array[String] = []
	for card_id in enemy_deck:
		if enemy_elixir >= float(troop_defs[card_id]["cost"]):
			affordable.append(card_id)
	if affordable.is_empty():
		ai_play_timer = 1.0
		return
	var card_id := affordable[randi() % affordable.size()]
	var lane := LANE_LEFT if randi() % 2 == 0 else LANE_RIGHT
	enemy_elixir -= float(troop_defs[card_id]["cost"])
	_spawn_troop(card_id, ENEMY_TEAM, lane, Vector2(LANE_X[lane] + randf_range(-24.0, 24.0), randf_range(ARENA_RECT.position.y + 24.0, ENEMY_DEPLOY_Y - 20.0)))
	status_text = "Enemy deployed %s on %s lane." % [troop_defs[card_id]["name"], lane]
	ai_play_timer = randf_range(1.8, 3.7)


func _spawn_troop(card_id: String, team: int, lane: String, spawn_pos: Vector2) -> void:
	var troop := BattleUnit.new()
	var unit_config: Dictionary = troop_defs[card_id].duplicate(true)
	unit_config["lane"] = lane
	troop.setup(unit_config, team, self, spawn_pos)
	add_child(troop)


func _spawn_building(config: Dictionary, team: int, spawn_pos: Vector2) -> void:
	var building := BattleBuilding.new()
	building.setup(config, team, self, spawn_pos)
	add_child(building)


func _lane_for_x(x: float) -> String:
	return LANE_LEFT if x < LANE_X[LANE_CENTER] else LANE_RIGHT


func get_lane_path_for_unit(unit: Node) -> Array[Vector2]:
	var lane: String = unit.lane
	var lane_x: float = LANE_X[lane]
	var waypoints: Array[Vector2] = []
	if unit.team == PLAYER_TEAM:
		waypoints.append(Vector2(lane_x, FRONTLINE_Y[PLAYER_TEAM]))
		waypoints.append(Vector2(lane_x, BRIDGE_Y[PLAYER_TEAM]))
		waypoints.append(Vector2(lane_x, BRIDGE_Y[ENEMY_TEAM]))
		var enemy_tower = get_lane_tower(unit.enemy_team, lane)
		if enemy_tower != null:
			waypoints.append(enemy_tower.global_position)
		var enemy_king = get_king_tower(unit.enemy_team)
		if enemy_king != null:
			waypoints.append(enemy_king.global_position)
	else:
		waypoints.append(Vector2(lane_x, FRONTLINE_Y[ENEMY_TEAM]))
		waypoints.append(Vector2(lane_x, BRIDGE_Y[ENEMY_TEAM]))
		waypoints.append(Vector2(lane_x, BRIDGE_Y[PLAYER_TEAM]))
		var player_tower = get_lane_tower(unit.enemy_team, lane)
		if player_tower != null:
			waypoints.append(player_tower.global_position)
		var player_king = get_king_tower(unit.enemy_team)
		if player_king != null:
			waypoints.append(player_king.global_position)
	return waypoints


func update_unit_target(unit: Node, current_target, force_retarget: bool) -> Node:
	var focus_target: Node = unit.get_focus_target()
	if _is_target_valid(unit, focus_target):
		return focus_target
	if not force_retarget and _is_target_valid(unit, current_target):
		return current_target
	var best_target: Node = null
	var best_score: float = INF
	var sight_radius: float = unit.get_sight_radius()
	for entity in get_tree().get_nodes_in_group("battle_entity"):
		if entity == unit:
			continue
		if entity.is_dead or entity.team == unit.team:
			continue
		if unit.targets_buildings_only and entity.entity_kind == "unit":
			continue
		var distance: float = unit.global_position.distance_to(entity.global_position)
		if entity.entity_kind == "unit" and distance > sight_radius:
			continue
		var lane_penalty := 0.0
		if entity.lane != unit.lane and entity.lane != LANE_CENTER:
			lane_penalty = 220.0
		if entity.entity_kind == "building" and entity.lane != unit.lane and entity.lane != LANE_CENTER:
			lane_penalty += 80.0
		var score: float = distance + lane_penalty
		if entity == current_target:
			score -= 55.0
		if score < best_score:
			best_score = score
			best_target = entity
	return best_target


func _is_target_valid(unit: Node, target) -> bool:
	if target == null:
		return false
	if not is_instance_valid(target):
		return false
	if target.is_dead or target.team == unit.team:
		return false
	if unit.targets_buildings_only and target.entity_kind == "unit":
		return false
	var leash_distance: float = 320.0 + unit.attack_range
	if target.entity_kind == "unit" and unit.global_position.distance_to(target.global_position) > leash_distance:
		return false
	return true


func choose_target_for_building(building: Node) -> Node:
	var best_target: Node = null
	var best_score: float = INF
	for entity in get_tree().get_nodes_in_group("battle_entity"):
		if entity == building:
			continue
		if entity.is_dead or entity.team == building.team:
			continue
		if entity.entity_kind == "building":
			continue
		var distance: float = building.global_position.distance_to(entity.global_position)
		var score: float = distance
		if building.lane != LANE_CENTER and entity.lane != building.lane:
			score += 180.0
		if score < best_score:
			best_score = score
			best_target = entity
	return best_target


func get_lane_tower(team: int, lane: String) -> Node:
	for entity in get_tree().get_nodes_in_group("battle_entity"):
		if entity.entity_kind == "building" and not entity.is_dead and entity.team == team and entity.lane == lane and not entity.is_king:
			return entity
	return null


func get_king_tower(team: int) -> Node:
	for entity in get_tree().get_nodes_in_group("battle_entity"):
		if entity.entity_kind == "building" and not entity.is_dead and entity.team == team and entity.is_king:
			return entity
	return null


func is_king_tower_awake(team: int) -> bool:
	return king_awake[team]


func wake_king_tower(team: int, reason: String = "") -> void:
	if king_awake[team]:
		return
	king_awake[team] = true
	if reason != "":
		status_text = reason


func on_damage_dealt(target: Node, attacker: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	if target.has_method("remember_attacker"):
		target.remember_attacker(attacker)
	play_hit_sfx(target, attacker)
	if target.entity_kind == "building" and target.is_king:
		wake_king_tower(target.team, "%s awakened the %s king tower." % [attacker.display_name, "enemy" if attacker.team == PLAYER_TEAM else "player"])


func play_attack_sfx(attacker: Node) -> void:
	var heavy: bool = attacker.entity_kind == "building" or attacker.radius >= 22.0 or attacker.damage >= 120.0
	var pitch: float = randf_range(0.94, 1.08)
	var volume_db: float = -7.0 if heavy else -9.5
	_play_sfx(_attack_sfx_heavy if heavy else _attack_sfx_light, pitch, volume_db)


func play_hit_sfx(target: Node, attacker: Node) -> void:
	var heavy: bool = target.entity_kind == "building" or attacker.damage >= 120.0 or attacker.radius >= 22.0
	var pitch: float = randf_range(0.92, 1.05)
	var volume_db: float = -5.5 if heavy else -8.0
	_play_sfx(_hit_sfx_heavy if heavy else _hit_sfx_light, pitch, volume_db)


func _setup_audio() -> void:
	_attack_sfx_light = _create_sfx(760.0, 420.0, 0.05, 0.22, 0.06)
	_attack_sfx_heavy = _create_sfx(420.0, 210.0, 0.08, 0.28, 0.18)
	_hit_sfx_light = _create_sfx(940.0, 180.0, 0.06, 0.24, 0.20)
	_hit_sfx_heavy = _create_sfx(280.0, 90.0, 0.10, 0.34, 0.32)
	for _i in range(8):
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_sfx_players.append(player)


func _play_sfx(stream: AudioStream, pitch: float, volume_db: float) -> void:
	if stream == null or _sfx_players.is_empty():
		return
	var player: AudioStreamPlayer = _sfx_players[_sfx_cursor % _sfx_players.size()]
	_sfx_cursor += 1
	player.stop()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = volume_db
	player.play()


func _create_sfx(freq_start: float, freq_end: float, duration: float, amplitude: float, noise_mix: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var sample_count: int = int(sample_rate * duration)
	var data: PackedByteArray = PackedByteArray()
	var phase: float = 0.0
	for i in range(sample_count):
		var t: float = float(i) / float(max(sample_count - 1, 1))
		var freq: float = lerpf(freq_start, freq_end, t)
		phase += TAU * freq / sample_rate
		var env: float = sin(t * PI)
		var tone: float = sin(phase)
		var noise: float = sin(float(i) * 0.173) * 0.65 + sin(float(i) * 0.047) * 0.35
		var sample: float = ((tone * (1.0 - noise_mix)) + (noise * noise_mix)) * env * amplitude
		var pcm: int = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.append(pcm & 0xFF)
		data.append((pcm >> 8) & 0xFF)
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream


func get_friendly_blocker(unit: Node, desired_dir: Vector2) -> Node:
	var best_blocker: Node = null
	var best_forward: float = INF
	for entity in get_tree().get_nodes_in_group("battle_entity"):
		if entity == unit:
			continue
		if entity.is_dead or entity.entity_kind != "unit" or entity.team != unit.team or entity.lane != unit.lane:
			continue
		var offset: Vector2 = entity.global_position - unit.global_position
		var forward: float = offset.dot(desired_dir)
		if forward <= 0.0:
			continue
		if abs(offset.x) > unit.radius + entity.radius + 18.0:
			continue
		var needed_gap: float = unit.radius + entity.radius + 6.0
		if offset.length() <= needed_gap + 18.0 and forward < best_forward:
			best_forward = forward
			best_blocker = entity
	return best_blocker


func get_unit_separation(unit: Node) -> Vector2:
	var push := Vector2.ZERO
	for entity in get_tree().get_nodes_in_group("battle_entity"):
		if entity == unit:
			continue
		if entity.is_dead or entity.entity_kind != "unit" or entity.lane != unit.lane:
			continue
		var offset: Vector2 = unit.global_position - entity.global_position
		var distance: float = offset.length()
		var min_distance: float = unit.radius + entity.radius + 2.0
		if distance > 0.001 and distance < min_distance:
			push += offset.normalized() * (min_distance - distance)
	return push


func can_move_to_position(unit: Node, candidate_position: Vector2) -> bool:
	if not ARENA_RECT.has_point(candidate_position):
		return false
	for entity in get_tree().get_nodes_in_group("battle_entity"):
		if entity == unit:
			continue
		if entity.is_dead or entity.entity_kind != "unit" or entity.team != unit.team or entity.lane != unit.lane:
			continue
		var min_distance: float = unit.radius + entity.radius + 2.0
		if candidate_position.distance_to(entity.global_position) < min_distance:
			return false
	return true


func on_entity_destroyed(entity: Node) -> void:
	for other in get_tree().get_nodes_in_group("battle_entity"):
		if other == entity or other.is_dead:
			continue
		if other.has_method("clear_target_reference"):
			other.clear_target_reference(entity)
	if entity.entity_kind == "building":
		if entity.is_king:
			battle_over = true
			winner_text = "Victory! Enemy King Tower destroyed." if entity.team == ENEMY_TEAM else "Defeat! Your King Tower fell."
			status_text = winner_text
		else:
			wake_king_tower(entity.team, "%s destroyed. %s king tower is now awake." % [entity.display_name, "Blue" if entity.team == PLAYER_TEAM else "Red"])


func _check_victory() -> void:
	if battle_over:
		return
	var player_king_alive := false
	var enemy_king_alive := false
	for entity in get_tree().get_nodes_in_group("battle_entity"):
		if entity.entity_kind == "building" and entity.is_king and not entity.is_dead:
			if entity.team == PLAYER_TEAM:
				player_king_alive = true
			else:
				enemy_king_alive = true
	if not enemy_king_alive:
		battle_over = true
		winner_text = "Victory! Enemy King Tower destroyed."
	elif not player_king_alive:
		battle_over = true
		winner_text = "Defeat! Your King Tower fell."


func _on_card_button_pressed(card_id: String) -> void:
	if battle_over:
		return
	selected_card_id = "" if selected_card_id == card_id else card_id
	if selected_card_id == "":
		status_text = "Selection cleared."
	else:
		status_text = "Selected %s. Click left or right lane to deploy." % troop_defs[card_id]["name"]
	_update_ui()


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()















