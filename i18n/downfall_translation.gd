class_name DownfallTranslation
extends Translation

## The English "translation" Godot's controls ask for their text: every
## message goes through I18n.translate() (see i18n.gd).

func _get_message(src_message: StringName, _context: StringName) -> StringName:
	return StringName(I18n.translate(String(src_message)))

func _get_plural_message(src_message: StringName, _src_plural_message: StringName, _n: int, _context: StringName) -> StringName:
	return StringName(I18n.translate(String(src_message)))
