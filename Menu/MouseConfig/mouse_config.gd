extends VBoxContainer

var _is_collecting_area: bool = false
var _motion_sum: float
var _area_min: float
var _area_max: float

@onready var _gui_area := $Options/Area
@onready var _gui_degrees := $Options/Degrees

func _helper_get_area() -> float:
    var result = _gui_area.text
    if result:
        return result.to_float()
    return 1000
    
func _helper_get_degrees() -> float:
    var result = _gui_degrees.text
    if result:
        return result.to_float()
    return 360
    
func _helper_calc_scale(area: float, degrees: float) -> float:
    var radians = deg_to_rad(degrees)
    
    return radians / area

func _helper_signal_change() -> void:
    var area: float = _helper_get_area()
    var degrees: float = _helper_get_degrees()
    var mscale: float = _helper_calc_scale(area, degrees)
    Config.set_mouse_scale(mscale, area, degrees)

func _helper_stop_area_input() -> void:
    Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
    _is_collecting_area = false
    _helper_signal_change()

func _helper_load_from_config():
    var marea = Config.get_mouse_area()
    var mdegrees = Config.get_mouse_degrees()
    
    if marea is float and mdegrees is float:
        _gui_area.text = str(marea)
        _gui_degrees.text = str(mdegrees)

func _input(event):
    if not _is_collecting_area:
        return
        
    if event.is_action("ui_cancel"):
        _helper_stop_area_input()
    elif  event is InputEventMouseButton and event.pressed:
        _helper_stop_area_input()
    elif event is InputEventMouseMotion and _is_collecting_area:
        if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
            _helper_stop_area_input()
        _motion_sum += event.relative.x
        if _area_min > _motion_sum:
            _area_min = _motion_sum
        
        if _area_max < _motion_sum:
            _area_max = _motion_sum
        
        _gui_area.text = str(_area_max - _area_min)

func _on_record_area_button_down() -> void:
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    _is_collecting_area = true
    _area_min = 0
    _area_max = 0
    _motion_sum = 0
    
func _on_set_mouse_scale(_scale: float, area:float, degrees: float):
    if _helper_get_area() != area:
        _gui_area.text = str(area)
    if _helper_get_degrees() != degrees:
        _gui_degrees.text = str(degrees)
    
func _on_area_text_changed(_new_text: String) -> void:
    _helper_signal_change()
    
func _on_degrees_text_changed(_new_text: String) -> void:
    _helper_signal_change()

func _on_visibility_changed() -> void:
    _helper_load_from_config()    
    
func _ready():
    _helper_load_from_config()
