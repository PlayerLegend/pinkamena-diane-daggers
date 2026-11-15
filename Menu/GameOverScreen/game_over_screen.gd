class_name GameOverScreen
extends Control

signal did_press_retry()

@export var retry_button: Button

@onready var new_stats: GameOverStatsDisplay = $HBoxContainer/Center/NewStats
@onready var best_stats: GameOverStatsDisplay = $HBoxContainer/Center/BestStats
@onready var total_stats: GameOverStatsDisplay = $HBoxContainer/Center/TotalStats

func _on_retry():
    did_press_retry.emit()

func _ready() -> void:
    assert(retry_button)
    retry_button.pressed.connect(_on_retry)
    
func set_stats(stats: GameOverStats):
    new_stats.set_stats(stats)
    Config.add_game_over_event(stats)
    best_stats.set_stats(Config.get_best_stats())
    total_stats.set_stats(Config.get_total_stats())
