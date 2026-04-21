extends Node2D

const BattleUnit = preload("res://scripts/battle_unit.gd")
const BattleBuilding = preload("res://scripts/battle_building.gd")
const DeckManagerClass = preload("res://scripts/DeckManager.gd")
const BattleNavigatorClass = preload("res://scripts/BattleNavigator.gd")
const SpellEffectClass = preload("res://scripts/SpellEffect.gd")
const CardDatabaseClass = preload("res://scripts/CardDatabase.gd")

const TEXTURE_ASSET_MAP := {
	"res://assets/units/knight.svg": preload("res://assets/units/knight.svg"),
	"res://assets/units/archer.svg": preload("res://assets/units/archer.svg"),
	"res://assets/units/giant.svg": preload("res://assets/units/giant.svg"),
	"res://assets/units/mini_pekka.svg": preload("res://assets/units/mini_pekka.svg"),
	"res://assets/buildings/crown_tower.svg": preload("res://assets/buildings/crown_tower.svg"),
	"res://assets/buildings/king_tower.svg": preload("res://assets/buildings/king_tower.svg"),
	"res://assets/icon.png": preload("res://assets/icon.png")
}

const PLAYER_TEAM := 0
const ENEMY_TEAM := 1
const SCREEN_SIZE := Vector2(720, 1280)
const ARENA_RECT := Rect2(40, 110, 640, 980)
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
	PLAYER_TEAM: 650.0,
	ENEMY_TEAM: 550.0
}
const FRONTLINE_Y := {
	PLAYER_TEAM: 760.0,
	ENEMY_TEAM: 440.0
}

var troop_defs: Dictionary:
	get:
		return CardDatabaseClass.troop_defs

var enemy_deck = ["knight", "archer", "giant", "wizard", "fireball", "rage", "healer", "bomber"]
var player_deck = ["knight", "archer", "giant", "mini_pekka", "wizard", "fireball", "freeze", "lightning", "rage", "healer", "bomber"]

var player_elixir := 5.0
var enemy_elixir := 5.0
var max_elixir := 10.0
var elixir_regen := 0.9
var selected_card_id := ""
var selected_hand_index := -1
var battle_over := false
var winner_text := ""
var status_text := "Select a card, then click left or right lane on your side."
var ai_play_timer := 2.0
var king_awake := {
	PLAYER_TEAM: false,
	ENEMY_TEAM: false
}

var _deck_manager: DeckManager
var _navigator: BattleNavigator
var ui_layer: CanvasLayer
var elixir_label: Label
var enemy_elixir_label: Label
var status_label: Label
var selected_label: Label
var restart_button: Button
var card_icon_textures: Dictionary = {}
var spell_icon_textures: Dictionary = {}
var hand_slot_buttons: Array[Button] = []
var next_card_preview_button: Button
var _svg_texture_cache: Dictionary = {}
var _card_style_cache: Dictionary = {}
var _battle_entities: Array[Node] = []
var _battle_units: Array[Node] = []
var _battle_buildings: Array[Node] = []


func get_battle_entities() -> Array:
	return _battle_entities


var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_cursor := 0
var _attack_sfx_light: AudioStreamWAV
var _attack_sfx_heavy: AudioStreamWAV
var _hit_sfx_light: AudioStreamWAV
var _hit_sfx_heavy: AudioStreamWAV
var _spell_cast_sfx: AudioStreamWAV


func _ready() -> void:
	randomize()
	_init_deck_manager()
	_init_navigator()
	_setup_audio()
	_load_card_icons()
	_setup_ui()
	_spawn_towers()
	queue_redraw()


func _init_deck_manager() -> void:
	_deck_manager = DeckManager.new()
	add_child(_deck_manager)
	_deck_manager.init(troop_defs)
	_deck_manager.hand_updated.connect(_on_deck_hand_updated)


func _init_navigator() -> void:
	_navigator = BattleNavigator.new()
	add_child(_navigator)
	_navigator.init(_battle_buildings)


func _on_deck_hand_updated() -> void:
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
	draw_rect(Rect2(ARENA_RECT.position.x, RIVER_Y - RIVER_HALF_HEIGHT, ARENA_RECT.size.x, RIVER_HALF_HEIGHT * 2.0), Color(0.2, 0.58, 0.9))
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
	for lane in [LANE_LEFT, LANE_RIGHT]:
		var bridge_rect := _navigator.get_bridge_rect(lane)
		draw_rect(bridge_rect, Color(0.61, 0.48, 0.32))
		draw_rect(bridge_rect, Color(0.32, 0.22, 0.1, 0.85), false, 3.0)
		for plank in range(5):
			var plank_y := bridge_rect.position.y + 8.0 + plank * 18.0
			draw_line(Vector2(bridge_rect.position.x, plank_y), Vector2(bridge_rect.end.x, plank_y), Color(0.42, 0.28, 0.14), 3.0)


func _unhandled_input(event: InputEvent) -> void:
	if battle_over:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if selected_hand_index >= 0:
			_try_player_deploy(event.position, selected_hand_index)
	elif event is InputEventScreenTouch and event.pressed:
		if selected_hand_index >= 0:
			_try_player_deploy(event.position, selected_hand_index)


func _load_card_icons() -> void:
	var troop_cards := ["knight", "archer", "giant", "mini_pekka", "wizard", "healer", "bomber"]
	for card_id in troop_cards:
		card_icon_textures[card_id] = load_svg_texture("res://assets/units/%s.svg" % card_id, 1.35)
	var spell_cards := ["fireball", "freeze", "lightning", "rage"]
	for card_id in spell_cards:
		var spell_path := "res://assets/spells/%s.svg" % card_id
		if ResourceLoader.exists(spell_path):
			spell_icon_textures[card_id] = ResourceLoader.load(spell_path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE)


func load_svg_texture(asset_path: String, raster_scale: float = 1.0) -> Texture2D:
	var cache_key := "%s@%.2f" % [asset_path, raster_scale]
	if _svg_texture_cache.has(cache_key):
		return _svg_texture_cache[cache_key]
	var texture_path := asset_path
	if not TEXTURE_ASSET_MAP.has(texture_path):
		var basename := asset_path.get_file().get_basename()
		for known_path in TEXTURE_ASSET_MAP.keys():
			if known_path.get_file().get_basename() == basename:
				texture_path = known_path
				break
	var texture: Texture2D = TEXTURE_ASSET_MAP.get(texture_path, null)
	if texture == null and ResourceLoader.exists(asset_path):
		texture = ResourceLoader.load(asset_path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
	if texture != null:
		_svg_texture_cache[cache_key] = texture
	return texture


func _get_card_icon(card_id: String) -> Texture2D:
	if card_icon_textures.has(card_id):
		return card_icon_textures[card_id]
	if spell_icon_textures.has(card_id):
		return spell_icon_textures[card_id]
	return null


func _is_spell_card(card_id: String) -> bool:
	return troop_defs.has(card_id) and troop_defs[card_id].get("card_type", "troop") == "spell"



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
	var preview_label := Label.new()
	preview_label.text = "NEXT"
	preview_label.position = Vector2(590, 1068)
	preview_label.size = Vector2(90, 20)
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.add_theme_font_size_override("font_size", 14)
	ui_layer.add_child(preview_label)
	next_card_preview_button = Button.new()
	next_card_preview_button.position = Vector2(590, 1095)
	next_card_preview_button.size = Vector2(90, 60)
	next_card_preview_button.disabled = true
	next_card_preview_button.add_theme_font_size_override("font_size", 11)
	next_card_preview_button.add_theme_stylebox_override("disabled", _get_card_stylebox("preview:disabled", Color(0.2, 0.2, 0.24), Color(1.0, 1.0, 1.0, 0.1)))
	next_card_preview_button.self_modulate = Color(1.0, 1.0, 1.0, 0.7)
	ui_layer.add_child(next_card_preview_button)
	var x := 48.0
	for i in range(4):
		var button := Button.new()
		button.position = Vector2(x, 1130)
		button.size = Vector2(145, 100)
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(_on_hand_slot_pressed.bind(i))
		ui_layer.add_child(button)
		hand_slot_buttons.append(button)
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
	_update_hand_slots()
	_update_next_preview()


func _update_hand_slots() -> void:
	var hand: Array = _deck_manager.hand
	for i in range(4):
		var button: Button = hand_slot_buttons[i]
		if i < hand.size():
			var card_id: String = hand[i]
			var cost: int = int(troop_defs[card_id]["cost"])
			var disabled := battle_over or player_elixir < float(cost)
			var selected := i == selected_hand_index
			var style_key := "%s:%s:%s" % [card_id, selected, disabled]
			button.icon = _get_card_icon(card_id)
			button.text = "%s\nCost %d" % [str(troop_defs[card_id].get("ui_name", troop_defs[card_id]["name"])), cost]
			button.disabled = disabled
			button.modulate = Color.WHITE
			var current_style_key := str(button.get_meta("style_key")) if button.has_meta("style_key") else ""
			if current_style_key != style_key:
				_apply_card_styles(button, card_id, selected, disabled)
				button.set_meta("style_key", style_key)
		else:
			button.icon = null
			button.text = ""
			button.disabled = true
			button.self_modulate = Color(1.0, 1.0, 1.0, 0.3)
			if button.has_meta("style_key"):
				button.remove_meta("style_key")


func _update_next_preview() -> void:
	var preview: String = _deck_manager.next_card_preview
	if preview != "":
		next_card_preview_button.icon = _get_card_icon(preview)
		next_card_preview_button.text = str(troop_defs[preview].get("ui_name", troop_defs[preview]["name"]))
		var style := _get_card_stylebox("preview:disabled", Color(0.2, 0.2, 0.24), Color(1.0, 1.0, 1.0, 0.1))
		next_card_preview_button.add_theme_stylebox_override("disabled", style)
	else:
		next_card_preview_button.icon = null
		next_card_preview_button.text = ""


func _apply_card_styles(button: Button, card_id: String, selected: bool, disabled: bool) -> void:
	var accent: Color = troop_defs[card_id]["color"]
	var border := Color(1.0, 0.93, 0.58) if selected else Color(1.0, 1.0, 1.0, 0.18)
	var is_spell: bool = _is_spell_card(card_id)
	if is_spell:
		border = Color(1.0, 0.6, 0.2) if selected else Color(1.0, 0.7, 0.3, 0.4)
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


func _register_entity(entity: Node) -> void:
	_battle_entities.append(entity)
	if entity.entity_kind == "unit":
		_battle_units.append(entity)
	else:
		_battle_buildings.append(entity)
		_navigator.init(_battle_buildings)


func _unregister_entity(entity: Node) -> void:
	_battle_entities.erase(entity)
	if entity.entity_kind == "unit":
		_battle_units.erase(entity)
	else:
		_battle_buildings.erase(entity)
		_navigator.init(_battle_buildings)


func _spawn_towers() -> void:
	_spawn_building({"id": "player_left_tower", "name": "Blue Left Tower", "hp": 1800.0, "range": 230.0, "damage": 58.0, "cooldown": 0.9, "radius": 34.0, "color": Color(0.3, 0.63, 1.0), "lane": LANE_LEFT}, PLAYER_TEAM, Vector2(180, 930))
	_spawn_building({"id": "player_right_tower", "name": "Blue Right Tower", "hp": 1800.0, "range": 230.0, "damage": 58.0, "cooldown": 0.9, "radius": 34.0, "color": Color(0.3, 0.63, 1.0), "lane": LANE_RIGHT}, PLAYER_TEAM, Vector2(540, 930))
	_spawn_building({"id": "player_king", "name": "Blue King Tower", "hp": 3200.0, "range": 250.0, "damage": 78.0, "cooldown": 1.0, "radius": 42.0, "color": Color(0.19, 0.47, 0.9), "is_king": true, "lane": LANE_CENTER}, PLAYER_TEAM, Vector2(360, 1070))
	_spawn_building({"id": "enemy_left_tower", "name": "Red Left Tower", "hp": 1800.0, "range": 230.0, "damage": 58.0, "cooldown": 0.9, "radius": 34.0, "color": Color(0.95, 0.35, 0.3), "lane": LANE_LEFT}, ENEMY_TEAM, Vector2(180, 270))
	_spawn_building({"id": "enemy_right_tower", "name": "Red Right Tower", "hp": 1800.0, "range": 230.0, "damage": 58.0, "cooldown": 0.9, "radius": 34.0, "color": Color(0.95, 0.35, 0.3), "lane": LANE_RIGHT}, ENEMY_TEAM, Vector2(540, 270))
	_spawn_building({"id": "enemy_king", "name": "Red King Tower", "hp": 3200.0, "range": 250.0, "damage": 78.0, "cooldown": 1.0, "radius": 42.0, "color": Color(0.84, 0.22, 0.2), "is_king": true, "lane": LANE_CENTER}, ENEMY_TEAM, Vector2(360, 130))


func _try_player_deploy(world_pos: Vector2, hand_index: int) -> void:
	var hand: Array = _deck_manager.hand
	if hand_index < 0 or hand_index >= hand.size():
		status_text = "Invalid card slot."
		return
	var card_id: String = hand[hand_index]
	var cost := float(troop_defs[card_id]["cost"])
	if player_elixir < cost:
		status_text = "Not enough elixir."
		return
	if not ARENA_RECT.has_point(world_pos):
		status_text = "Click inside the arena."
		return

	if _is_spell_card(card_id):
		player_elixir -= cost
		_cast_spell(card_id, PLAYER_TEAM, world_pos)
		status_text = "%s cast at (%.0f, %.0f)." % [troop_defs[card_id]["name"], world_pos.x, world_pos.y]
		_deck_manager.remove_card_from_hand(hand_index)
		selected_card_id = ""
		selected_hand_index = -1
		return

	if world_pos.y < PLAYER_DEPLOY_Y:
		status_text = "You can only deploy on your half of the arena."
		return
	var lane := _lane_for_x(world_pos.x)
	var spawn_pos := _navigator._get_player_deploy_position(world_pos, lane)
	player_elixir -= cost
	_spawn_troop(card_id, PLAYER_TEAM, lane, spawn_pos)
	status_text = "%s deployed on %s lane." % [troop_defs[card_id]["name"], lane]
	_deck_manager.remove_card_from_hand(hand_index)
	selected_card_id = ""
	selected_hand_index = -1


func _cast_spell(card_id: String, team: int, target_pos: Vector2) -> void:
	var config: Dictionary = troop_defs[card_id].duplicate(true)
	var spell: Node = SpellEffectClass.new()
	spell.setup(config, team, self, target_pos)
	add_child(spell)
	_play_sfx(_spell_cast_sfx, randf_range(0.9, 1.1), -8.0)


func _enemy_play() -> void:
	var affordable: Array[String] = []
	for card_id in enemy_deck:
		if enemy_elixir >= float(troop_defs[card_id]["cost"]):
			affordable.append(card_id)
	if affordable.is_empty():
		ai_play_timer = 1.0
		return

	var card_id := _choose_best_ai_card(affordable)

	if _is_spell_card(card_id):
		enemy_elixir -= float(troop_defs[card_id]["cost"])
		var spell_radius: float = float(troop_defs[card_id].get("spell_radius", 75.0))
		var target_pos: Vector2 = _find_best_spell_target(card_id, ENEMY_TEAM, spell_radius)
		_cast_spell(card_id, ENEMY_TEAM, target_pos)
		status_text = "Enemy cast %s!" % troop_defs[card_id]["name"]
		ai_play_timer = randf_range(1.8, 3.7)
		return

	var lane := _choose_best_ai_lane(card_id)
	enemy_elixir -= float(troop_defs[card_id]["cost"])
	_spawn_troop(card_id, ENEMY_TEAM, lane, _navigator._get_enemy_deploy_position(lane))
	status_text = "Enemy deployed %s on %s lane." % [troop_defs[card_id]["name"], lane]
	ai_play_timer = randf_range(1.8, 3.7)


func _choose_best_ai_card(affordable: Array[String]) -> String:
	var player_push_strength: float = _calculate_lane_strength(PLAYER_TEAM)
	var enemy_push_strength: float = _calculate_lane_strength(ENEMY_TEAM)
	var needs_defense: bool = player_push_strength > enemy_push_strength + 200.0

	var best_card: String = affordable[0]
	var best_score: float = -INF

	for card_id in affordable:
		var card_info: Dictionary = troop_defs[card_id]
		var score: float = 0.0
		var card_type: String = card_info.get("card_type", "troop")

		if card_type == "spell":
			var spell_effect: String = card_info.get("spell_effect", "damage")
			if spell_effect == "damage" or spell_effect == "lightning":
				var spell_damage: float = float(card_info.get("spell_damage", 0.0)) + float(card_info.get("spell_lightning_damage", 0.0)) * float(card_info.get("spell_lightning_count", 1.0))
				var target_value: float = _estimate_spell_target_value(card_id, ENEMY_TEAM)
				score = target_value * spell_damage * 0.01
			elif spell_effect == "freeze":
				score = 80.0 if needs_defense else 30.0
			elif spell_effect == "rage":
				score = 70.0 if enemy_push_strength > 150.0 else 20.0
		else:
			var hp: float = float(card_info.get("hp", 0.0))
			var dmg: float = float(card_info.get("damage", 0.0)) + float(card_info.get("splash_damage", 0.0))
			var cost: float = float(card_info.get("cost", 1.0))
			var value: float = (hp * 0.3 + dmg * 2.0) / cost

			if card_info.get("heal_amount", 0.0) > 0.0:
				score = 60.0 if enemy_push_strength > 100.0 else value
			elif needs_defense and hp > 400.0:
				score = value * 1.5
			elif not needs_defense and dmg > 100.0:
				score = value * 1.3
			else:
				score = value

		if score > best_score:
			best_score = score
			best_card = card_id

	return best_card


func _calculate_lane_strength(team_id: int) -> float:
	var strength: float = 0.0
	for entity in _battle_entities:
		if entity.get("team") == null or entity.team != team_id:
			continue
		if entity.get("entity_kind") == null or entity.entity_kind != "unit":
			continue
		var entity_is_dead: bool = false
		if entity.has_method("get_is_dead"):
			entity_is_dead = entity.get_is_dead()
		elif entity.get("is_dead") != null:
			entity_is_dead = entity.is_dead
		if entity_is_dead:
			continue
		var hp: float = float(entity.hp) if entity.get("hp") != null else 0.0
		var dmg: float = float(entity.damage) if entity.get("damage") != null else 0.0
		strength += hp * 0.2 + dmg * 1.5
	return strength


func _estimate_spell_target_value(card_id: String, team: int) -> float:
	var enemy_team: int = PLAYER_TEAM if team == ENEMY_TEAM else ENEMY_TEAM
	var count: int = 0
	for entity in _battle_entities:
		if entity.get("team") == null or entity.team != enemy_team:
			continue
		var entity_is_dead: bool = false
		if entity.has_method("get_is_dead"):
			entity_is_dead = entity.get_is_dead()
		elif entity.get("is_dead") != null:
			entity_is_dead = entity.is_dead
		if entity_is_dead:
			continue
		count += 1
	return float(count) * 15.0 + 20.0


func _choose_best_ai_lane(card_id: String) -> String:
	var left_strength: float = 0.0
	var right_strength: float = 0.0
	for entity in _battle_entities:
		if entity.get("team") == null or entity.team != PLAYER_TEAM:
			continue
		if entity.get("entity_kind") == null or entity.entity_kind != "unit":
			continue
		var entity_is_dead: bool = false
		if entity.has_method("get_is_dead"):
			entity_is_dead = entity.get_is_dead()
		elif entity.get("is_dead") != null:
			entity_is_dead = entity.is_dead
		if entity_is_dead:
			continue
		if entity.get("lane") == null:
			continue
		if entity.lane == LANE_LEFT:
			left_strength += float(entity.hp) * 0.3 + float(entity.damage) * 1.5
		elif entity.lane == LANE_RIGHT:
			right_strength += float(entity.hp) * 0.3 + float(entity.damage) * 1.5

	var card_info: Dictionary = troop_defs[card_id]
	var is_defensive: bool = float(card_info.get("hp", 0.0)) > 500.0 or card_info.get("heal_amount", 0.0) > 0.0

	if is_defensive:
		return LANE_LEFT if left_strength > right_strength else LANE_RIGHT
	else:
		return LANE_LEFT if left_strength < right_strength else LANE_RIGHT


func _find_best_spell_target(card_id: String, team: int, radius: float) -> Vector2:
	var enemy_team: int = PLAYER_TEAM if team == ENEMY_TEAM else ENEMY_TEAM
	var best_pos: Vector2 = Vector2(360, 600)
	var best_score: float = -INF
	for entity in _battle_entities:
		var entity_is_dead: bool = false
		if entity.has_method("get_is_dead"):
			entity_is_dead = entity.get_is_dead()
		elif entity.get("is_dead") != null:
			entity_is_dead = entity.is_dead
		if entity_is_dead or entity.team != enemy_team:
			continue
		var count: int = 0
		var total_hp: float = 0.0
		for other in _battle_entities:
			var other_is_dead: bool = false
			if other.has_method("get_is_dead"):
				other_is_dead = other.get_is_dead()
			elif other.get("is_dead") != null:
				other_is_dead = other.is_dead
			if other_is_dead or other.team != enemy_team:
				continue
			if entity.global_position.distance_to(other.global_position) <= radius:
				count += 1
				total_hp += other.hp
		var score: float = float(count) * 100.0 + total_hp * 0.1
		if entity.entity_kind == "building":
			score += 50.0
		if score > best_score:
			best_score = score
			best_pos = entity.global_position
	return best_pos

func _spawn_troop(card_id: String, team: int, lane: String, spawn_pos: Vector2) -> void:
	var troop: Node = BattleUnit.new()
	var unit_config: Dictionary = troop_defs[card_id].duplicate(true)
	unit_config["lane"] = lane
	troop.setup(unit_config, team, self, spawn_pos)
	_register_entity(troop)
	add_child(troop)


func _spawn_building(config: Dictionary, team: int, spawn_pos: Vector2) -> void:
	var building: Node = BattleBuilding.new()
	building.setup(config, team, self, spawn_pos)
	_register_entity(building)
	add_child(building)


func _lane_for_x(x: float) -> String:
	var left_distance: float = absf(x - float(LANE_X[LANE_LEFT]))
	var right_distance: float = absf(x - float(LANE_X[LANE_RIGHT]))
	return LANE_LEFT if left_distance <= right_distance else LANE_RIGHT


func update_unit_target(unit: Node, current_target, force_retarget: bool) -> Node:
	var focus_target: Node = unit.get_focus_target()
	if _is_target_valid(unit, focus_target):
		return focus_target
	if not force_retarget and _is_target_valid(unit, current_target):
		return current_target
	var best_target: Node = null
	var best_score: float = INF
	var sight_radius: float = unit.get_sight_radius()
	for entity in _battle_entities:
		if entity == unit:
			continue
		var entity_is_dead: bool = false
		if entity.has_method("get_is_dead"):
			entity_is_dead = entity.get_is_dead()
		elif entity.get("is_dead") != null:
			entity_is_dead = entity.is_dead
		if entity_is_dead or entity.team == unit.team:
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
	var target_is_dead: bool = false
	if target.has_method("get_is_dead"):
		target_is_dead = target.get_is_dead()
	elif target.get("is_dead") != null:
		target_is_dead = target.is_dead
	if target_is_dead or target.team == unit.team:
		return false
	if target.get("entity_kind") == null or (unit.targets_buildings_only and target.entity_kind == "unit"):
		return false
	var leash_distance: float = 320.0 + unit.attack_range
	if target.entity_kind == "unit" and unit.global_position.distance_to(target.global_position) > leash_distance:
		return false
	return true


func choose_target_for_building(building: Node) -> Node:
	var best_target: Node = null
	var best_score: float = INF
	for entity in _battle_units:
		var entity_is_dead: bool = false
		if entity.has_method("get_is_dead"):
			entity_is_dead = entity.get_is_dead()
		elif entity.get("is_dead") != null:
			entity_is_dead = entity.is_dead
		if entity_is_dead or entity.team == building.team:
			continue
		var distance: float = building.global_position.distance_to(entity.global_position)
		var score: float = distance
		if building.lane != LANE_CENTER and entity.lane != building.lane:
			score += 180.0
		if score < best_score:
			best_score = score
			best_target = entity
	return best_target


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
	_spell_cast_sfx = _create_sfx(520.0, 180.0, 0.18, 0.18, 0.12)
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
	for entity in _battle_units:
		if entity == unit:
			continue
		var entity_is_dead: bool = false
		if entity.has_method("get_is_dead"):
			entity_is_dead = entity.get_is_dead()
		elif entity.get("is_dead") != null:
			entity_is_dead = entity.is_dead
		if entity_is_dead or entity.entity_kind != "unit" or entity.team != unit.team or entity.lane != unit.lane:
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
	for entity in _battle_units:
		if entity == unit:
			continue
		var entity_is_dead: bool = false
		if entity.has_method("get_is_dead"):
			entity_is_dead = entity.get_is_dead()
		elif entity.get("is_dead") != null:
			entity_is_dead = entity.is_dead
		if entity_is_dead or entity.entity_kind != "unit" or entity.lane != unit.lane:
			continue
		var offset: Vector2 = unit.global_position - entity.global_position
		var distance: float = offset.length()
		var min_distance: float = unit.radius + entity.radius + 2.0
		if distance > 0.001 and distance < min_distance:
			push += offset.normalized() * (min_distance - distance)
	return push


func on_entity_destroyed(entity: Node) -> void:
	_unregister_entity(entity)
	for other in _battle_entities.duplicate():
		var other_is_dead: bool = false
		if other.has_method("get_is_dead"):
			other_is_dead = other.get_is_dead()
		elif other.get("is_dead") != null:
			other_is_dead = other.is_dead
		if other == entity or other_is_dead:
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
	for entity in _battle_buildings:
		if entity.entity_kind == "building" and entity.is_king:
			var entity_is_dead: bool = false
			if entity.has_method("get_is_dead"):
				entity_is_dead = entity.get_is_dead()
			elif entity.get("is_dead") != null:
				entity_is_dead = entity.is_dead
			if not entity_is_dead:
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


func constrain_unit_position(unit: Node, candidate_position: Vector2) -> Vector2:
	return _navigator.constrain_unit_position(unit, candidate_position)


func can_move_to_position(unit: Node, candidate_position: Vector2) -> bool:
	return _navigator.can_move_to_position(unit, candidate_position, _battle_units)


func get_navigation_target_for_unit(unit: Node, desired_target: Vector2) -> Vector2:
	return _navigator.get_navigation_target_for_unit(unit, desired_target)


func get_lane_path_for_unit(unit: Node) -> Array[Vector2]:
	return _navigator.get_lane_path_for_unit(unit)


func _on_hand_slot_pressed(slot_index: int) -> void:
	if battle_over:
		return
	var hand: Array = _deck_manager.hand
	if slot_index < 0 or slot_index >= hand.size():
		return
	var card_id: String = hand[slot_index]
	var cost: float = troop_defs[card_id]["cost"]
	if player_elixir < cost:
		status_text = "Not enough elixir."
		return
	if selected_hand_index == slot_index:
		selected_card_id = ""
		selected_hand_index = -1
		status_text = "Selection cleared."
	else:
		selected_card_id = card_id
		selected_hand_index = slot_index
	if _is_spell_card(card_id):
		status_text = "Selected %s. Click anywhere on the arena to cast." % troop_defs[card_id]["name"]
	else:
		status_text = "Selected %s. Click left or right lane to deploy." % troop_defs[card_id]["name"]


func _on_restart_pressed() -> void:
	get_tree().reload_current_scene()
