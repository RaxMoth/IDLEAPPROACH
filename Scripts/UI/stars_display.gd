## Row of star glyphs (★ earned / ☆ missing).
##
## Dependencies: none
class_name StarsDisplay
extends HBoxContainer

@export var max_stars: int = 3
@export var star_font_size: int = 40
@export var earned_color: Color = Color(1.0, 0.82, 0.25)
@export var missing_color: Color = Color(1, 1, 1, 0.25)

var _star_labels: Array[Label] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	for star_index: int in max_stars:
		var star_label: Label = Label.new()
		star_label.text = "★"
		star_label.add_theme_font_size_override("font_size", star_font_size)
		star_label.add_theme_color_override("font_color", missing_color)
		add_child(star_label)
		_star_labels.append(star_label)


func set_stars(earned_stars: int, animate: bool = false) -> void:
	for star_index: int in _star_labels.size():
		var star_label: Label = _star_labels[star_index]
		var is_earned: bool = star_index < earned_stars
		star_label.add_theme_color_override("font_color", earned_color if is_earned else missing_color)
		if animate and is_earned:
			star_label.scale = Vector2.ZERO
			star_label.pivot_offset = star_label.size * 0.5
			var tween: Tween = star_label.create_tween()
			tween.tween_interval(0.15 + star_index * 0.2)
			tween.tween_property(star_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
