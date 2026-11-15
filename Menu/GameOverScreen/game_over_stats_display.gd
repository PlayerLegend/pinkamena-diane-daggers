class_name GameOverStatsDisplay
extends VBoxContainer
@onready var label_time: RichTextLabel = $HBoxContainer/Time
@onready var label_death_type: RichTextLabel = $HBoxContainer/DeathType
@onready var label_power: RichTextLabel = $HBoxContainer2/Power
@onready var label_kills: RichTextLabel = $HBoxContainer2/Kills
@onready var label_accuracy: RichTextLabel = $HBoxContainer2/Accuracy

func set_stats(stats: GameOverStats):
    label_time.text = "Time: " + String.num(stats.time, 2)
    label_death_type.text = "Death: " + stats.death_type
    label_power.text = "Power: " + str(stats.power)
    label_kills.text = "Kills(todo): " + str(stats.kills)
    label_accuracy.text = "Accuracy(todo): " + String.num(stats.accuracy, 2)
    
