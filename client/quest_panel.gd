class_name QuestPanel
extends PanelContainer
## Quest board UI: daily and weekly quests with progress and rewards, plus
## how many Relics can still be earned this week.

var _list: VBoxContainer
var _cap: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", ShopPanel.dark_panel_style())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	var title := Label.new()
	title.text = "Quests"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	box.add_child(title)
	_list = VBoxContainer.new()
	box.add_child(_list)
	_cap = Label.new()
	_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cap.add_theme_font_size_override("font_size", 22)
	box.add_child(_cap)
	Profile.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	for child in _list.get_children():
		child.free()
	for period in [Quests.Period.DAILY, Quests.Period.WEEKLY]:
		var header := Label.new()
		header.text = "Daily" if period == Quests.Period.DAILY else "Weekly"
		header.add_theme_font_size_override("font_size", 28)
		header.add_theme_color_override("font_color", Color(0.85, 0.3, 0.25))
		_list.add_child(header)
		for quest in Quests.ALL:
			if quest.period != period:
				continue
			var state := Profile.quest_state(quest)
			var row := Label.new()
			var mark := "✓" if state.done else "%d/%d" % [state.progress, quest.target]
			row.text = "%s   %s   (+%d Teeth, +%d Relics)" % [mark, quest.title, quest.teeth, quest.relics]
			row.add_theme_font_size_override("font_size", 22)
			if state.done:
				row.modulate = Color(0.6, 0.6, 0.6)
			_list.add_child(row)
	_cap.text = "Relics you can still earn this week: %d / %d" % [Profile.relics_left_this_week(), Economy.RELICS_WEEKLY_CAP]
