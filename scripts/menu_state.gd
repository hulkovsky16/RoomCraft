class_name MenuState
extends RefCounted
## Stan przekazywany między menu głównym a pokojem (zmienne statyczne, bez autoloadu).
## Projekty są zapisywane w user://projects; nazwa projektu to nazwa pliku.

const PROJECTS_DIR := "user://projects"
const RECENT_PROJECTS_FILE := "user://recent_projects.cfg"
const MAX_RECENT_PROJECTS := 12
const MAX_NAME_LENGTH := 40
const FORBIDDEN_CHARS := ["/", "\\", ":", "*", "?", "\"", "<", ">", "|", "."]

## Plik projektu do wczytania przy wejściu do pokoju.
static var pending_project_path := ""

## Nazwa nowego projektu do utworzenia przy wejściu do pokoju.
static var pending_new_name := ""

## Plik, do którego przycisk „Zapisz zmiany” zapisuje bieżący projekt.
static var current_project_path := ""

## Czy pokazywać podpowiedzi sterowania w pokoju.
static var show_hints := true


static func ensure_projects_dir() -> void:
	DirAccess.make_dir_recursive_absolute(PROJECTS_DIR)


static func project_path_for(project_name: String) -> String:
	return "%s/%s.json" % [PROJECTS_DIR, project_name.strip_edges()]


static func list_projects() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(PROJECTS_DIR)
	if dir != null:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.get_extension().to_lower() == "json":
				result.append("%s/%s" % [PROJECTS_DIR, file_name])
			file_name = dir.get_next()
	result.sort()
	for path in _recent_projects():
		if FileAccess.file_exists(path):
			result.append(path)
	return result


static func remember_project(path: String) -> void:
	var absolute := ProjectSettings.globalize_path(path).replace("\\", "/").simplify_path()
	var projects_dir := ProjectSettings.globalize_path(PROJECTS_DIR).replace("\\", "/").simplify_path()
	if absolute.get_base_dir().nocasecmp_to(projects_dir) == 0:
		return
	var recent := _recent_projects()
	recent.erase(absolute)
	recent.insert(0, absolute)
	if recent.size() > MAX_RECENT_PROJECTS:
		recent.resize(MAX_RECENT_PROJECTS)
	var config := ConfigFile.new()
	config.set_value("projects", "recent", recent)
	var error := config.save(RECENT_PROJECTS_FILE)
	if error != OK:
		push_warning("Nie udało się zapisać listy ostatnich projektów: " + error_string(error))


static func _recent_projects() -> PackedStringArray:
	var config := ConfigFile.new()
	if config.load(RECENT_PROJECTS_FILE) == OK:
		var paths: Variant = config.get_value("projects", "recent", PackedStringArray())
		if paths is PackedStringArray:
			return paths
	return PackedStringArray()


## Zwraca pusty tekst, gdy nazwa jest poprawna, w przeciwnym razie komunikat dla gracza.
static func check_project_name(project_name: String) -> String:
	var clean := project_name.strip_edges()
	if clean == "":
		return "Podaj nazwę projektu."
	if clean.length() > MAX_NAME_LENGTH:
		return "Nazwa może mieć najwyżej %d znaków." % MAX_NAME_LENGTH
	for ch in FORBIDDEN_CHARS:
		if clean.contains(ch):
			return "Nazwa nie może zawierać znaków: / \\ : * ? \" < > | ."
	if FileAccess.file_exists(project_path_for(clean)):
		return "Projekt o tej nazwie już istnieje."
	return ""
