extends Node

var config_file = ConfigFile.new()
var config_path = "user://settings.ini"
signal signal_set_mouse_scale(scale: float, area: float, degrees: float)

func set_mouse_scale(scale: float, area: float, degrees: float):
    config_file.set_value("Controls", "mouse_scale", scale)
    config_file.set_value("Controls", "mouse_area", area)
    config_file.set_value("Controls", "mouse_degrees", degrees)
    signal_set_mouse_scale.emit(scale, area, degrees)
    
func save():
    print("Saved config")
    config_file.save(config_path)
    
func get_mouse_scale():
    return config_file.get_value("Controls", "mouse_scale", 0)
    
func get_mouse_area() :
    return config_file.get_value("Controls", "mouse_area", 0)

func get_mouse_degrees():
    return config_file.get_value("Controls", "mouse_degrees", 0)
    
func _ready():
    print("Autoload config")
    config_file.load(config_path)

# === Game over stats ===

const STATS_SECTION := "Stats"

# Records a finished run, updates totals and bests, and saves to disk.
func add_game_over_event(stats: GameOverStats) -> void:
    # Totals
    _add_to_stat("total_games", 1)
    _add_to_stat("total_time", stats.time)
    _add_to_stat("total_kills", stats.kills)
    _add_to_stat("total_power", stats.power)
    _add_to_stat("total_accuracy_sum", stats.accuracy)

    # Bests
    _max_stat("best_time", stats.time)
    _max_stat("best_kills", stats.kills)
    _max_stat("best_accuracy", stats.accuracy)
    _max_stat("best_power", stats.power)

    save()

# Returns a GameOverStats holding the best value of each stat across all runs.
func get_best_stats() -> GameOverStats:
    var result := GameOverStats.new()
    result.time = config_file.get_value(STATS_SECTION, "best_time", 0.0)
    result.kills = config_file.get_value(STATS_SECTION, "best_kills", 0)
    result.accuracy = config_file.get_value(STATS_SECTION, "best_accuracy", 0.0)
    result.power = config_file.get_value(STATS_SECTION, "best_power", 0)
    result.death_type = ""
    return result

# Returns a GameOverStats holding totals across all runs.
# Accuracy is the average accuracy per game, since summing accuracy is meaningless.
func get_total_stats() -> GameOverStats:
    var result := GameOverStats.new()
    var games: int = get_games_played()
    result.time = config_file.get_value(STATS_SECTION, "total_time", 0.0)
    result.kills = config_file.get_value(STATS_SECTION, "total_kills", 0)
    result.power = config_file.get_value(STATS_SECTION, "total_power", 0)
    var accuracy_sum: float = config_file.get_value(STATS_SECTION, "total_accuracy_sum", 0.0)
    result.accuracy = accuracy_sum / games if games > 0 else 0.0
    result.death_type = ""
    return result

func get_games_played() -> int:
    return config_file.get_value(STATS_SECTION, "total_games", 0)

# --- helpers ---

func _add_to_stat(key: String, amount) -> void:
    var current = config_file.get_value(STATS_SECTION, key, 0 * amount) # keeps int/float type
    config_file.set_value(STATS_SECTION, key, current + amount)

func _max_stat(key: String, value) -> void:
    var current = config_file.get_value(STATS_SECTION, key, 0 * value)
    if value > current:
        config_file.set_value(STATS_SECTION, key, value)
