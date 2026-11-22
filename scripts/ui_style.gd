class_name UiStyle
extends RefCounted
## Спільний стиль інтерфейсу RoomCraft: кольори, панелі, кнопки та іконки.

const TEXT_COLOR := Color(0.9, 0.92, 0.95)
const ACCENT := Color(0.95, 0.72, 0.29)
const ERROR_COLOR := Color(1.0, 0.45, 0.4)
const PANEL_BG := Color(0.07, 0.09, 0.12, 0.92)
const BUTTON_BG := Color(0.16, 0.19, 0.24)
const BUTTON_HOVER := Color(0.23, 0.27, 0.34)
const BUTTON_PRESSED := Color(0.31, 0.36, 0.45)


static func style_panel(panel: PanelContainer) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = PANEL_BG
	box.set_corner_radius_all(12)
	box.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", box)


static func style_button(button: Button, icon_name: String = "") -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _button_box(BUTTON_BG))
	button.add_theme_stylebox_override("hover", _button_box(BUTTON_HOVER))
	button.add_theme_stylebox_override("pressed", _button_box(BUTTON_PRESSED))
	button.add_theme_stylebox_override("disabled", _button_box(BUTTON_BG.darkened(0.3)))
	button.add_theme_color_override("font_color", TEXT_COLOR)
	button.add_theme_color_override("font_hover_color", ACCENT)
	button.add_theme_color_override("font_pressed_color", ACCENT)
	if icon_name != "":
		button.icon = load_icon(icon_name)
		button.add_theme_constant_override("icon_max_width", 22)


static func make_button(text: String, icon_name: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = text
	style_button(button, icon_name)
	button.pressed.connect(handler)
	return button


static func load_icon(icon_name: String) -> Texture2D:
	return load("res://assets/ui/icons/%s.svg" % icon_name) as Texture2D


static func _button_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(8)
	box.set_content_margin_all(8)
	return box
