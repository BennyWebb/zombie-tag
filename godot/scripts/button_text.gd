class_name ButtonText
## Words with pictures of the joypad's buttons in them, so the same help works whatever letters a
## joypad has on its buttons. In the text, "{go}" shows the four face buttons with the one that says
## yes lit, and "{leave}" the one that goes back (see Controls.go_button). On a
## computer, the key goes in front ("Space or ...", "Backspace or ..."), unless there's a * in
## front ("{*go}"), for when the words say which key already.

const KEYS := { go = "Space or ", leave = "Backspace or " }


## A new label with the text in it.
static func make(text: String, font_size: int, colour: Color, centred := true) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centred else HORIZONTAL_ALIGNMENT_LEFT
	l.add_theme_font_size_override("normal_font_size", font_size)
	l.add_theme_color_override("default_color", colour)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	fill(l, text)
	return l


## Puts the text into a label (in place of what was there).
static func fill(l: RichTextLabel, text: String) -> void:
	l.clear()
	var size: int = l.get_theme_font_size("normal_font_size")
	var bits := text.split("{")
	l.append_text(bits[0])
	for bit in bits.slice(1):
		var token := bit.get_slice("}", 0)
		var kind := token.trim_prefix("*")
		if not OS.has_feature("android") and not token.begins_with("*"):
			l.append_text(KEYS.get(kind, ""))
		l.add_image(Controls.glyph(kind), roundi(size * 1.6), roundi(size * 1.6))
		l.append_text(bit.substr(token.length() + 1))
