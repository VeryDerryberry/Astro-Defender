extends Node

signal options_changed

const DEFAULT_FIRE_RATE := 0.18
const DEFAULT_LIVES := 3
const DEFAULT_ENEMIES := 4
const DEFAULT_ENEMY_SPEED := 1.0
const DEFAULT_PLAYER_SPEED := 1.0
const DEFAULT_SPAWN_INTERVAL := 1.2

var fire_rate: float = DEFAULT_FIRE_RATE
var starting_lives: int = DEFAULT_LIVES
var enemies_per_wave: int = DEFAULT_ENEMIES
var enemy_speed_multiplier: float = DEFAULT_ENEMY_SPEED
var player_speed_multiplier: float = DEFAULT_PLAYER_SPEED
var spawn_interval: float = DEFAULT_SPAWN_INTERVAL


func reset_defaults() -> void:
	fire_rate = DEFAULT_FIRE_RATE
	starting_lives = DEFAULT_LIVES
	enemies_per_wave = DEFAULT_ENEMIES
	enemy_speed_multiplier = DEFAULT_ENEMY_SPEED
	player_speed_multiplier = DEFAULT_PLAYER_SPEED
	spawn_interval = DEFAULT_SPAWN_INTERVAL
	options_changed.emit()


func summary() -> String:
	return (
		"fire_rate=%.2f,lives=%d,enemies=%d,enemy_spd=%.1f,player_spd=%.1f,spawn=%.1f"
		% [
			fire_rate,
			starting_lives,
			enemies_per_wave,
			enemy_speed_multiplier,
			player_speed_multiplier,
			spawn_interval,
		]
	)


func adjust_fire_rate(delta: float) -> void:
	fire_rate = clampf(fire_rate + delta, 0.05, 0.6)
	options_changed.emit()


func adjust_lives(delta: int) -> void:
	starting_lives = clampi(starting_lives + delta, 1, 10)
	options_changed.emit()


func adjust_enemies(delta: int) -> void:
	enemies_per_wave = clampi(enemies_per_wave + delta, 1, 16)
	options_changed.emit()


func adjust_enemy_speed(delta: float) -> void:
	enemy_speed_multiplier = clampf(enemy_speed_multiplier + delta, 0.5, 3.0)
	options_changed.emit()


func adjust_player_speed(delta: float) -> void:
	player_speed_multiplier = clampf(player_speed_multiplier + delta, 0.5, 2.5)
	options_changed.emit()


func adjust_spawn_interval(delta: float) -> void:
	spawn_interval = clampf(spawn_interval + delta, 0.3, 3.0)
	options_changed.emit()