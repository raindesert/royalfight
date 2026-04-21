class_name CardDatabase

static var troop_defs := {
	"knight": {
		"id": "knight",
		"name": "Knight",
		"ui_name": "Knight",
		"cost": 3,
		"hp": 620.0,
		"speed": 92.0,
		"range": 20.0,
		"damage": 78.0,
		"cooldown": 1.05,
		"radius": 18.0,
		"color": Color(0.24, 0.61, 0.98),
		"card_type": "troop"
	},
	"archer": {
		"id": "archer",
		"name": "Archer",
		"ui_name": "Archer",
		"cost": 3,
		"hp": 260.0,
		"speed": 82.0,
		"range": 165.0,
		"damage": 52.0,
		"cooldown": 0.9,
		"radius": 15.0,
		"color": Color(0.39, 0.83, 0.56),
		"card_type": "troop"
	},
	"giant": {
		"id": "giant",
		"name": "Giant",
		"ui_name": "Giant",
		"cost": 5,
		"hp": 1650.0,
		"speed": 58.0,
		"range": 24.0,
		"damage": 155.0,
		"cooldown": 1.35,
		"radius": 25.0,
		"color": Color(0.93, 0.66, 0.24),
		"targets_buildings_only": true,
		"card_type": "troop"
	},
	"mini_pekka": {
		"id": "mini_pekka",
		"name": "Mini P.E.K.K.A",
		"ui_name": "Mini PEKKA",
		"cost": 4,
		"hp": 720.0,
		"speed": 98.0,
		"range": 20.0,
		"damage": 185.0,
		"cooldown": 1.2,
		"radius": 18.0,
		"color": Color(0.77, 0.42, 0.99),
		"card_type": "troop"
	},
	"wizard": {
		"id": "wizard",
		"name": "Wizard",
		"ui_name": "Wizard",
		"cost": 5,
		"hp": 340.0,
		"speed": 72.0,
		"range": 145.0,
		"damage": 130.0,
		"splash_damage": 90.0,
		"splash_radius": 65.0,
		"cooldown": 1.1,
		"radius": 16.0,
		"color": Color(0.25, 0.58, 0.95),
		"card_type": "troop"
	},
	"healer": {
		"id": "healer",
		"name": "Healer",
		"ui_name": "Healer",
		"cost": 4,
		"hp": 280.0,
		"speed": 88.0,
		"range": 130.0,
		"damage": 0.0,
		"heal_amount": 45.0,
		"heal_cooldown": 1.0,
		"cooldown": 1.0,
		"radius": 16.0,
		"color": Color(1.0, 0.75, 0.85),
		"card_type": "troop"
	},
	"bomber": {
		"id": "bomber",
		"name": "Bomber",
		"ui_name": "Bomber",
		"cost": 3,
		"hp": 220.0,
		"speed": 68.0,
		"range": 110.0,
		"damage": 0.0,
		"splash_damage": 160.0,
		"splash_radius": 55.0,
		"cooldown": 1.4,
		"radius": 15.0,
		"color": Color(0.2, 0.75, 0.35),
		"card_type": "troop"
	},
	"fireball": {
		"id": "fireball",
		"name": "Fireball",
		"ui_name": "Fireball",
		"cost": 4,
		"hp": 0.0,
		"speed": 0.0,
		"range": 0.0,
		"damage": 0.0,
		"cooldown": 0.0,
		"radius": 0.0,
		"color": Color(1.0, 0.4, 0.1),
		"card_type": "spell",
		"spell_effect": "damage",
		"spell_damage": 320.0,
		"spell_radius": 75.0
	},
	"freeze": {
		"id": "freeze",
		"name": "Freeze",
		"ui_name": "Freeze",
		"cost": 4,
		"hp": 0.0,
		"speed": 0.0,
		"range": 0.0,
		"damage": 0.0,
		"cooldown": 0.0,
		"radius": 0.0,
		"color": Color(0.4, 0.7, 1.0),
		"card_type": "spell",
		"spell_effect": "freeze",
		"spell_freeze_duration": 2.5,
		"spell_radius": 90.0
	},
	"lightning": {
		"id": "lightning",
		"name": "Lightning",
		"ui_name": "Lightning",
		"cost": 3,
		"hp": 0.0,
		"speed": 0.0,
		"range": 0.0,
		"damage": 0.0,
		"cooldown": 0.0,
		"radius": 0.0,
		"color": Color(1.0, 0.95, 0.3),
		"card_type": "spell",
		"spell_effect": "lightning",
		"spell_lightning_count": 3,
		"spell_lightning_damage": 200.0,
		"spell_radius": 120.0
	},
	"rage": {
		"id": "rage",
		"name": "Rage",
		"ui_name": "Rage",
		"cost": 3,
		"hp": 0.0,
		"speed": 0.0,
		"range": 0.0,
		"damage": 0.0,
		"cooldown": 0.0,
		"radius": 0.0,
		"color": Color(1.0, 0.2, 0.4),
		"card_type": "spell",
		"spell_effect": "rage",
		"spell_rage_duration": 3.0,
		"spell_rage_speed_mult": 1.35,
		"spell_rage_damage_mult": 1.25,
		"spell_radius": 85.0
	}
}

static func is_spell_card(card_id: String) -> bool:
	return troop_defs.has(card_id) and troop_defs[card_id].get("card_type", "troop") == "spell"

static func get_card_cost(card_id: String) -> int:
	if not troop_defs.has(card_id):
		return 99
	return int(troop_defs[card_id].get("cost", 99))

static func get_card_name(card_id: String) -> String:
	if not troop_defs.has(card_id):
		return card_id
	return str(troop_defs[card_id].get("name", card_id))

static func get_card_ui_name(card_id: String) -> String:
	if not troop_defs.has(card_id):
		return card_id
	return str(troop_defs[card_id].get("ui_name", troop_defs[card_id].get("name", card_id)))

static func get_card_color(card_id: String) -> Color:
	if not troop_defs.has(card_id):
		return Color.WHITE
	return troop_defs[card_id].get("color", Color.WHITE)

static func get_card_config(card_id: String) -> Dictionary:
	if not troop_defs.has(card_id):
		return {}
	return troop_defs[card_id].duplicate(true)
