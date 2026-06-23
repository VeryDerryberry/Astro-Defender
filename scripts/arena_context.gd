extends Node

var _player: Node2D
var _entities: Node2D


func register(player: Node2D, entities: Node2D) -> void:
	_player = player
	_entities = entities


func clear() -> void:
	_player = null
	_entities = null


func get_player() -> Node2D:
	return _player


func get_entities() -> Node2D:
	return _entities