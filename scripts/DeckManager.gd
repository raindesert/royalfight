class_name DeckManager
extends Node

const PLAYER_DECK_TEMPLATE := ["knight", "archer", "giant", "mini_pekka", "wizard", "archer", "giant", "mini_pekka"]

var deck: Array = []
var hand: Array = []
var next_card_preview: String = ""

var troop_defs: Dictionary

signal hand_updated
signal deck_reshuffled


func init(defs: Dictionary) -> void:
	troop_defs = defs
	reset_deck()


func reset_deck() -> void:
	deck = PLAYER_DECK_TEMPLATE.duplicate()
	hand.clear()
	next_card_preview = ""
	shuffle_deck()
	draw_initial_hand()


func shuffle_deck() -> void:
	deck.shuffle()


func draw_initial_hand() -> void:
	for i in range(4):
		if deck.is_empty():
			break
		var card_id = deck.pop_front()
		if card_id != null:
			hand.append(card_id)
	_refresh_preview()


func draw_one_card() -> void:
	if deck.is_empty():
		deck = PLAYER_DECK_TEMPLATE.duplicate()
		deck.shuffle()
		deck_reshuffled.emit()
	if not deck.is_empty():
		var card_id = deck.pop_front()
		if card_id != null:
			hand.append(card_id)
	_refresh_preview()


func _refresh_preview() -> void:
	if deck.is_empty():
		next_card_preview = hand[0] if not hand.is_empty() else ""
	else:
		next_card_preview = deck[0]
	hand_updated.emit()


func get_card_cost(card_id: String) -> int:
	return int(troop_defs.get(card_id, {}).get("cost", 0))


func get_card_info(card_id: String) -> Dictionary:
	return troop_defs.get(card_id, {})


func get_hand_size() -> int:
	return hand.size()


func get_hand_card(hand_index: int) -> String:
	if hand_index < 0 or hand_index >= hand.size():
		return ""
	return hand[hand_index]


func remove_card_from_hand(hand_index: int) -> String:
	if hand_index < 0 or hand_index >= hand.size():
		return ""
	var card_id: String = hand[hand_index]
	hand.remove_at(hand_index)
	draw_one_card()
	return card_id
