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
    return config_file.get_value("Controls", "mouse_scale")
    
func get_mouse_area() :
    return config_file.get_value("Controls", "mouse_area")

func get_mouse_degrees():
    return config_file.get_value("Controls", "mouse_degrees")
    
func _ready():
    print("Autoload config")
    config_file.load(config_path)
