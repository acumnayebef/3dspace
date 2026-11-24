extends CanvasLayer

@onready var main_ctrl: Node3D = get_parent()

# --- UI Roots ---
var main_menu_root := Control.new()
var menu_sub_panel := PanelContainer.new()
var menu_sub_title := Label.new()
var menu_sub_body := Label.new()
var menu_tg_btn := Button.new()
var menu_btns: Array[Button] = []
var selected_menu_idx: int = 0
var menu_sub_tab: String = ""

var markers_layer := Control.new()
var marker_pool: Array[Button] = []

var ship_hud := Control.new()
var catalog_btn := Button.new()
var speed_eta_lbl := Label.new()
var credits_lbl := Label.new()
var fss_btn := Button.new()
var orbits_btn := Button.new()
var markers_btn := Button.new()
var cam_mode_btn := Button.new()
var fpv_btn := Button.new()

var prox_bar := PanelContainer.new()
var zone_lbl := Label.new()
var alt_lbl := Label.new()
var exit_ship_btn := Button.new()
var takeoff_btn := Button.new()
var land_btn := Button.new()
var horizon_btn := Button.new()

var station_prox_bar := PanelContainer.new()
var station_prox_lbl := Label.new()
var dock_btn := Button.new()

var throttle_lbl := Label.new()
var throttle_slider := HSlider.new()
var fa_btn := Button.new()
var time_date_lbl := Label.new()
var time_warp_lbl := Label.new()
var time_rev_btn := Button.new()
var time_pause_btn := Button.new()
var auto_speed_btn := Button.new()
var speed_down_btn := Button.new()
var speed_up_btn := Button.new()
var speed_val_lbl := Label.new()

var eva_hud := Control.new()
var eva_ship_lbl := Label.new()
var eva_scan_card := PanelContainer.new()
var eva_scan_text := Label.new()
var eva_sprint_btn := Button.new()
var eva_jetpack_btn := Button.new()
var eva_fuel_bar := ProgressBar.new()
var eva_stick_lbl := Label.new()

var catalog_panel := PanelContainer.new()
var catalog_title := Label.new()
var catalog_list := VBoxContainer.new()
var selected_cat: int = UniverseCatalog.BodyCategory.ALL

var info_panel := PanelContainer.new()
var info_title := Label.new()
var info_body := Label.new()
var info_land_btn := Button.new()

var station_panel := PanelContainer.new()
var st_header_lbl := Label.new()
var st_credits_lbl := Label.new()
var st_list := VBoxContainer.new()
var active_st_tab: int = 0 # 0=market, 1=carto, 2=shipyard

var fss_panel := PanelContainer.new()
var fss_target_lbl := Label.new()
var fss_freq_lbl := Label.new()
var fss_status_lbl := Label.new()
var fss_slider := HSlider.new()
var fss_bars: Array[ColorRect] = []
var fss_scan_btn := Button.new()
var fss_msg_lbl := Label.new()

var _updating_sliders := false

func _ready() -> void:
	_build_markers_layer()
	_build_main_menu()
	_build_ship_hud()
	_build_eva_hud()
	_build_catalog_panel()
	_build_info_panel()
	_build_station_panel()
	_build_fss_panel()

func _style_box(bg: Color, border: Color = Color(0.2, 0.7, 0.9, 0.4), radius: int = 12, bw: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(8)
	return s

func _build_markers_layer() -> void:
	markers_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	markers_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(markers_layer)
	for i in range(18):
		var b := Button.new()
		b.visible = false
		b.add_theme_font_size_override("font_size", 11)
		b.add_theme_stylebox_override("normal", _style_box(Color(0, 0, 0, 0.5), Color(0, 0.8, 1, 0.4), 6, 1))
		var idx := i
		b.pressed.connect(func():
			if idx < main_ctrl.screen_markers.size():
				var bid: String = main_ctrl.screen_markers[idx]["id"]
				main_ctrl.target_body = UniverseCatalog.find_body(bid)
		)
		markers_layer.add_child(b)
		marker_pool.append(b)

func _build_main_menu() -> void:
	main_menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_menu_root)

	# Тёмная виньетка слева (в духе S.T.A.L.K.E.R. 2)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05, 0.72)
	bg.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	bg.offset_right = 400
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_menu_root.add_child(bg)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 36)
	main_menu_root.add_child(hbox)

	var left_pad := MarginContainer.new()
	left_pad.add_theme_constant_override("margin_left", 44)
	left_pad.add_theme_constant_override("margin_top", 44)
	left_pad.add_theme_constant_override("margin_bottom", 24)
	hbox.add_child(left_pad)

	var left_col := VBoxContainer.new()
	left_col.custom_minimum_size.x = 280
	left_col.add_theme_constant_override("separation", 10)
	left_pad.add_child(left_col)

	var title := Label.new()
	title.text = "S.P.A.C.E. 3D"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98))
	left_col.add_child(title)

	var line := ColorRect.new()
	line.color = Color(0.75, 0.88, 0.95, 0.55)
	line.custom_minimum_size = Vector2(240, 2)
	left_col.add_child(line)

	var sub := Label.new()
	sub.text = "СИМУЛЯТОР ВСЕЛЕННОЙ 1:1"
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color(0.75, 0.82, 0.88, 0.85))
	left_col.add_child(sub)

	var sp1 := Control.new(); sp1.custom_minimum_size = Vector2(0, 20); left_col.add_child(sp1)

	var items := ["ИГРАТЬ", "НАСТРОЙКИ", "АВТОРЫ"]
	for i in range(items.size()):
		var btn := Button.new()
		btn.text = "  " + items[i]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(230, 40)
		btn.add_theme_font_size_override("font_size", 16)
		var idx := i
		btn.pressed.connect(func(): _on_menu_click(idx))
		left_col.add_child(btn)
		menu_btns.append(btn)

	var sp2 := Control.new(); sp2.size_flags_vertical = Control.SIZE_EXPAND_FILL; left_col.add_child(sp2)
	var footer := Label.new()
	footer.text = "SPACE 1:1 • GODOT 4 • @xantapers"
	footer.add_theme_font_size_override("font_size", 10)
	footer.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8, 0.6))
	left_col.add_child(footer)

	# Полноэкранный раздел Настройки / Авторы
	menu_sub_panel.visible = false
	menu_sub_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_sub_panel.add_theme_stylebox_override("panel", _style_box(Color(0.03, 0.04, 0.06, 0.96), Color(0, 0, 0, 0), 0, 0))
	main_menu_root.add_child(menu_sub_panel)

	var sub_margin := MarginContainer.new()
	sub_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	sub_margin.add_theme_constant_override("margin_left", 56)
	sub_margin.add_theme_constant_override("margin_right", 56)
	sub_margin.add_theme_constant_override("margin_top", 40)
	sub_margin.add_theme_constant_override("margin_bottom", 40)
	menu_sub_panel.add_child(sub_margin)

	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 18)
	sub_margin.add_child(mv)

	var mh := HBoxContainer.new()
	mv.add_child(mh)
	menu_sub_title.add_theme_font_size_override("font_size", 28)
	menu_sub_title.add_theme_color_override("font_color", Color(0.93, 0.95, 0.98))
	mh.add_child(menu_sub_title)
	var m_sp := Control.new(); m_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; mh.add_child(m_sp)
	var m_back := Button.new()
	m_back.text = "← НАЗАД"
	m_back.custom_minimum_size = Vector2(140, 42)
	m_back.add_theme_font_size_override("font_size", 15)
	m_back.pressed.connect(func():
		menu_sub_tab = ""
		selected_menu_idx = 0
		_refresh_menu_styles()
	)
	mh.add_child(m_back)

	var divider := ColorRect.new()
	divider.color = Color(0.75, 0.88, 0.95, 0.35)
	divider.custom_minimum_size = Vector2(0, 2)
	mv.add_child(divider)

	menu_sub_body.autowrap_mode = TextServer.AUTOWRAP_WORD
	menu_sub_body.add_theme_font_size_override("font_size", 16)
	menu_sub_body.add_theme_color_override("font_color", Color(0.84, 0.88, 0.92))
	mv.add_child(menu_sub_body)

	menu_tg_btn.text = "Перейти в Telegram: @xantapers"
	menu_tg_btn.custom_minimum_size = Vector2(340, 46)
	menu_tg_btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	menu_tg_btn.add_theme_font_size_override("font_size", 15)
	var tg_norm := _style_box(Color(0.91, 0.90, 0.85), Color(0, 0, 0, 0), 4, 0)
	var tg_hov := _style_box(Color(1.0, 0.98, 0.92), Color(0, 0, 0, 0), 4, 0)
	menu_tg_btn.add_theme_stylebox_override("normal", tg_norm)
	menu_tg_btn.add_theme_stylebox_override("hover", tg_hov)
	menu_tg_btn.add_theme_stylebox_override("pressed", tg_norm)
	menu_tg_btn.add_theme_stylebox_override("focus", tg_norm)
	menu_tg_btn.add_theme_color_override("font_color", Color(0.06, 0.08, 0.10))
	menu_tg_btn.add_theme_color_override("font_hover_color", Color(0.06, 0.08, 0.10))
	menu_tg_btn.add_theme_color_override("font_pressed_color", Color(0.06, 0.08, 0.10))
	menu_tg_btn.add_theme_color_override("font_focus_color", Color(0.06, 0.08, 0.10))
	menu_tg_btn.pressed.connect(func(): OS.shell_open("https://t.me/xantapers"))
	mv.add_child(menu_tg_btn)
	_refresh_menu_styles()

func _on_menu_click(idx: int) -> void:
	selected_menu_idx = idx
	if idx == 0:
		menu_sub_tab = ""
		main_ctrl.is_main_menu = false
	elif idx == 1:
		menu_sub_tab = "" if menu_sub_tab == "settings" else "settings"
	else:
		menu_sub_tab = "" if menu_sub_tab == "authors" else "authors"
	_refresh_menu_styles()

func _refresh_menu_styles() -> void:
	var sel_sb := _style_box(Color(0.91, 0.90, 0.85), Color(0, 0, 0, 0), 2, 0)
	var norm_sb := _style_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 2, 0)
	var hov_sb := _style_box(Color(1.0, 1.0, 1.0, 0.10), Color(0.75, 0.88, 0.95, 0.35), 2, 1)
	var dark_txt := Color(0.06, 0.08, 0.10)
	var light_txt := Color(0.92, 0.94, 0.96)
	for i in range(menu_btns.size()):
		var b := menu_btns[i]
		if i == selected_menu_idx:
			b.add_theme_stylebox_override("normal", sel_sb)
			b.add_theme_stylebox_override("hover", sel_sb)
			b.add_theme_stylebox_override("pressed", sel_sb)
			b.add_theme_stylebox_override("focus", sel_sb)
			b.add_theme_color_override("font_color", dark_txt)
			b.add_theme_color_override("font_hover_color", dark_txt)
			b.add_theme_color_override("font_pressed_color", dark_txt)
			b.add_theme_color_override("font_focus_color", dark_txt)
		else:
			b.add_theme_stylebox_override("normal", norm_sb)
			b.add_theme_stylebox_override("hover", hov_sb)
			b.add_theme_stylebox_override("pressed", hov_sb)
			b.add_theme_stylebox_override("focus", norm_sb)
			b.add_theme_color_override("font_color", light_txt)
			b.add_theme_color_override("font_hover_color", Color.WHITE)
			b.add_theme_color_override("font_pressed_color", Color.WHITE)
			b.add_theme_color_override("font_focus_color", light_txt)
	menu_sub_panel.visible = menu_sub_tab != ""
	if menu_sub_tab == "settings":
		menu_sub_title.text = "НАСТРОЙКИ"
		menu_sub_body.text = "Раздел настроек пока пуст."
		menu_tg_btn.visible = false
	elif menu_sub_tab == "authors":
		menu_sub_title.text = "АВТОРЫ"
		menu_sub_body.text = "Space 3D — Симулятор Вселенной 1:1\n\nНовости, обновления и комьюнити проекта в Telegram-канале автора: @xantapers"
		menu_tg_btn.visible = true

func _build_ship_hud() -> void:
	ship_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	ship_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ship_hud)

	var root_v := VBoxContainer.new()
	root_v.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 12); pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 10); pad.add_theme_constant_override("margin_bottom", 10)
	ship_hud.add_child(pad)
	pad.add_child(root_v)

	# Top Row
	var top_h := HBoxContainer.new()
	top_h.add_theme_constant_override("separation", 6)
	root_v.add_child(top_h)

	var menu_btn := Button.new(); menu_btn.text = "☰"
	menu_btn.pressed.connect(func():
		catalog_panel.visible = false
		info_panel.visible = false
		main_ctrl.is_main_menu = true
	)
	top_h.add_child(menu_btn)

	catalog_btn.pressed.connect(func():
		catalog_panel.visible = not catalog_panel.visible
		info_panel.visible = false
		if catalog_panel.visible:
			_rebuild_catalog()
	)
	top_h.add_child(catalog_btn)

	var inf_btn := Button.new(); inf_btn.text = "ⓘ"
	inf_btn.pressed.connect(func():
		info_panel.visible = not info_panel.visible
		catalog_panel.visible = false
		if info_panel.visible:
			_refresh_info_panel()
	)
	top_h.add_child(inf_btn)

	speed_eta_lbl.add_theme_font_size_override("font_size", 11)
	speed_eta_lbl.add_theme_color_override("font_color", Color.CYAN)
	top_h.add_child(speed_eta_lbl)

	credits_lbl.add_theme_font_size_override("font_size", 11)
	credits_lbl.add_theme_color_override("font_color", Color.YELLOW)
	top_h.add_child(credits_lbl)

	var sp_top := Control.new(); sp_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sp_top.mouse_filter = Control.MOUSE_FILTER_IGNORE; top_h.add_child(sp_top)

	fss_btn.text = "FSS"
	fss_btn.pressed.connect(func():
		catalog_panel.visible = false
		info_panel.visible = false
		main_ctrl.is_fss_open = not main_ctrl.is_fss_open
		if main_ctrl.is_fss_open:
			_refresh_fss_panel()
	)
	top_h.add_child(fss_btn)

	orbits_btn.text = "Орбиты"; orbits_btn.pressed.connect(func(): main_ctrl.show_orbits = not main_ctrl.show_orbits)
	top_h.add_child(orbits_btn)

	markers_btn.text = "Метки"; markers_btn.pressed.connect(func(): main_ctrl.show_markers = not main_ctrl.show_markers)
	top_h.add_child(markers_btn)

	var aim_btn := Button.new(); aim_btn.text = "На цель"; aim_btn.pressed.connect(func(): main_ctrl.align_to_target())
	top_h.add_child(aim_btn)

	cam_mode_btn.pressed.connect(func(): main_ctrl.toggle_free_camera())
	top_h.add_child(cam_mode_btn)

	fpv_btn.pressed.connect(func():
		main_ctrl.is_third_person = not main_ctrl.is_third_person
		main_ctrl.update_camera_mode()
	)
	top_h.add_child(fpv_btn)

	# Proximity Planet Bar
	prox_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	prox_bar.add_theme_stylebox_override("panel", _style_box(Color(0, 0, 0, 0.72), Color(0, 0.85, 1, 0.45), 16, 1))
	root_v.add_child(prox_bar)
	var ph := HBoxContainer.new(); ph.add_theme_constant_override("separation", 8); prox_bar.add_child(ph)
	ph.add_child(zone_lbl); ph.add_child(alt_lbl)
	exit_ship_btn.text = "ВЫЙТИ"; exit_ship_btn.pressed.connect(func(): main_ctrl.enter_walking_mode()); ph.add_child(exit_ship_btn)
	takeoff_btn.text = "ВЗЛЁТ"; takeoff_btn.pressed.connect(func(): main_ctrl.takeoff_from_surface()); ph.add_child(takeoff_btn)
	land_btn.text = "ПОСАДИТЬ"; land_btn.pressed.connect(func(): main_ctrl.land_at_current_spot()); ph.add_child(land_btn)
	horizon_btn.text = "ГОРИЗОНТ"; horizon_btn.pressed.connect(func(): main_ctrl.level_to_horizon()); ph.add_child(horizon_btn)

	# Station Proximity Bar
	station_prox_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	station_prox_bar.add_theme_stylebox_override("panel", _style_box(Color(0, 0, 0, 0.78), Color(1, 0.6, 0.1, 0.55), 16, 1))
	root_v.add_child(station_prox_bar)
	var sph := HBoxContainer.new(); sph.add_theme_constant_override("separation", 8); station_prox_bar.add_child(sph)
	sph.add_child(station_prox_lbl)
	dock_btn.text = "СТЫКОВКА"
	dock_btn.pressed.connect(func():
		catalog_panel.visible = false
		info_panel.visible = false
		main_ctrl.dock_at_nearby_station()
	)
	sph.add_child(dock_btn)

	var sp_mid := Control.new(); sp_mid.size_flags_vertical = Control.SIZE_EXPAND_FILL; sp_mid.mouse_filter = Control.MOUSE_FILTER_IGNORE; root_v.add_child(sp_mid)

	# Bottom Ship Controls
	var bot_h := HBoxContainer.new(); bot_h.add_theme_constant_override("separation", 10); bot_h.mouse_filter = Control.MOUSE_FILTER_IGNORE; root_v.add_child(bot_h)
	bot_h.add_child(_create_joystick(func(pt): main_ctrl.stick_input = pt, Label.new(), "РУЛЬ / WASD"))

	var th_panel := PanelContainer.new(); th_panel.add_theme_stylebox_override("panel", _style_box(Color(0, 0, 0, 0.72), Color(1, 1, 1, 0.2), 14, 1))
	th_panel.size_flags_vertical = Control.SIZE_SHRINK_END; bot_h.add_child(th_panel)
	var th_v := VBoxContainer.new(); th_panel.add_child(th_v)
	var th_top := HBoxContainer.new(); th_v.add_child(th_top)
	th_top.add_child(throttle_lbl)
	var th_sp := Control.new(); th_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; th_top.add_child(th_sp)
	fa_btn.pressed.connect(func(): main_ctrl.flight_assist = not main_ctrl.flight_assist); th_top.add_child(fa_btn)
	throttle_slider.custom_minimum_size = Vector2(150, 24); throttle_slider.min_value = 0.0; throttle_slider.max_value = 1.0; throttle_slider.step = 0.01
	throttle_slider.value_changed.connect(func(v: float):
		if not _updating_sliders:
			main_ctrl.throttle = v
	)
	th_v.add_child(throttle_slider)

	var sp_bot := Control.new(); sp_bot.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sp_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE; bot_h.add_child(sp_bot)

	var right_v := VBoxContainer.new(); right_v.add_theme_constant_override("separation", 6); bot_h.add_child(right_v)
	var tw_p := PanelContainer.new(); tw_p.add_theme_stylebox_override("panel", _style_box(Color(0, 0, 0, 0.72), Color(1, 1, 1, 0.2), 14, 1)); right_v.add_child(tw_p)
	var tw_h := HBoxContainer.new(); tw_h.add_theme_constant_override("separation", 6); tw_p.add_child(tw_h)
	tw_h.add_child(time_date_lbl)
	time_rev_btn.text = "◀◀"; time_rev_btn.pressed.connect(func(): main_ctrl.is_time_reversed = not main_ctrl.is_time_reversed); tw_h.add_child(time_rev_btn)
	time_pause_btn.text = "❚❚"; time_pause_btn.pressed.connect(func(): main_ctrl.is_time_paused = not main_ctrl.is_time_paused); tw_h.add_child(time_pause_btn)
	var tw_m := Button.new(); tw_m.text = "−"; tw_m.pressed.connect(func(): main_ctrl.step_time_warp(-1)); tw_h.add_child(tw_m)
	tw_h.add_child(time_warp_lbl)
	var tw_p_btn := Button.new(); tw_p_btn.text = "+"; tw_p_btn.pressed.connect(func(): main_ctrl.step_time_warp(1)); tw_h.add_child(tw_p_btn)

	var sp_p := PanelContainer.new(); sp_p.add_theme_stylebox_override("panel", _style_box(Color(0, 0, 0, 0.72), Color(1, 1, 1, 0.2), 14, 1)); right_v.add_child(sp_p)
	var sp_h := HBoxContainer.new(); sp_h.add_theme_constant_override("separation", 6); sp_p.add_child(sp_h)
	auto_speed_btn.text = "АВТО"; auto_speed_btn.pressed.connect(func(): main_ctrl.auto_speed = not main_ctrl.auto_speed); sp_h.add_child(auto_speed_btn)
	speed_down_btn.text = "−"; speed_down_btn.pressed.connect(func(): main_ctrl.step_speed(-1)); sp_h.add_child(speed_down_btn)
	speed_val_lbl.custom_minimum_size = Vector2(96, 0); speed_val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; sp_h.add_child(speed_val_lbl)
	speed_up_btn.text = "+"; speed_up_btn.pressed.connect(func(): main_ctrl.step_speed(1)); sp_h.add_child(speed_up_btn)
	var stop_btn := Button.new(); stop_btn.text = "СТОП"; stop_btn.pressed.connect(func(): main_ctrl.stop_ship()); sp_h.add_child(stop_btn)

func _build_eva_hud() -> void:
	eva_hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	eva_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(eva_hud)

	var pad := MarginContainer.new(); pad.set_anchors_preset(Control.PRESET_FULL_RECT); pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override("margin_left", 12); pad.add_theme_constant_override("margin_right", 12)
	pad.add_theme_constant_override("margin_top", 10); pad.add_theme_constant_override("margin_bottom", 10)
	eva_hud.add_child(pad)

	var v := VBoxContainer.new(); v.mouse_filter = Control.MOUSE_FILTER_IGNORE; pad.add_child(v)
	var top := HBoxContainer.new(); v.add_child(top)

	var ship_pill := PanelContainer.new(); ship_pill.add_theme_stylebox_override("panel", _style_box(Color(0, 0, 0, 0.78), Color(0, 0.85, 1, 0.45), 16, 1)); top.add_child(ship_pill)
	ship_pill.add_child(eva_ship_lbl)

	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sp.mouse_filter = Control.MOUSE_FILTER_IGNORE; top.add_child(sp)
	var scan_btn := Button.new(); scan_btn.text = "СКАНЕР"; scan_btn.pressed.connect(func(): main_ctrl.toggle_surface_scanner())
	top.add_child(scan_btn)

	eva_scan_card.visible = false
	eva_scan_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	eva_scan_card.add_theme_stylebox_override("panel", _style_box(Color(0, 0, 0, 0.86), Color(0, 0.85, 1, 0.5), 12, 1))
	v.add_child(eva_scan_card)
	var sc_v := VBoxContainer.new(); eva_scan_card.add_child(sc_v)
	var sc_close := Button.new(); sc_close.text = "Закрыть сканер"; sc_close.pressed.connect(func(): main_ctrl.toggle_surface_scanner())
	sc_v.add_child(eva_scan_text); sc_v.add_child(sc_close)

	var sp_mid := Control.new(); sp_mid.size_flags_vertical = Control.SIZE_EXPAND_FILL; sp_mid.mouse_filter = Control.MOUSE_FILTER_IGNORE; v.add_child(sp_mid)

	var bot := HBoxContainer.new(); bot.mouse_filter = Control.MOUSE_FILTER_IGNORE; v.add_child(bot)
	bot.add_child(_create_joystick(func(pt): main_ctrl.stick_input = pt, eva_stick_lbl, "ХОДЬБА"))
	var sp_b := Control.new(); sp_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sp_b.mouse_filter = Control.MOUSE_FILTER_IGNORE; bot.add_child(sp_b)

	var ctrl_p := PanelContainer.new(); ctrl_p.size_flags_vertical = Control.SIZE_SHRINK_END; ctrl_p.add_theme_stylebox_override("panel", _style_box(Color(0, 0, 0, 0.78), Color(0, 0.85, 1, 0.4), 16, 1)); bot.add_child(ctrl_p)
	var ctrl_h := HBoxContainer.new(); ctrl_h.add_theme_constant_override("separation", 6); ctrl_p.add_child(ctrl_h)
	eva_sprint_btn.text = "СПРИНТ"; eva_sprint_btn.pressed.connect(func(): main_ctrl.eva_sprinting = not main_ctrl.eva_sprinting); ctrl_h.add_child(eva_sprint_btn)
	eva_jetpack_btn.text = "РАНЕЦ 100%"
	eva_jetpack_btn.pressed.connect(func():
		if main_ctrl.eva_jetpack_fuel > 0.02 or main_ctrl.eva_jetpack_active:
			main_ctrl.eva_jetpack_active = not main_ctrl.eva_jetpack_active
	)
	ctrl_h.add_child(eva_jetpack_btn)
	eva_fuel_bar.custom_minimum_size = Vector2(46, 12); eva_fuel_bar.max_value = 100.0; eva_fuel_bar.show_percentage = false; ctrl_h.add_child(eva_fuel_bar)
	var j_btn := Button.new(); j_btn.text = "ПРЫЖОК"; j_btn.pressed.connect(func(): main_ctrl.eva_jump()); ctrl_h.add_child(j_btn)
	var b_btn := Button.new(); b_btn.text = "В КОРАБЛЬ"; b_btn.pressed.connect(func(): main_ctrl.board_ship()); ctrl_h.add_child(b_btn)

func _create_joystick(on_change: Callable, lbl_ref: Label, default_text: String) -> Control:
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(104, 104)
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel", _style_box(Color(0, 0, 0, 0.48), Color(0, 0.85, 1, 0.55), 52, 2))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(panel)

	lbl_ref.text = default_text
	lbl_ref.add_theme_font_size_override("font_size", 9)
	lbl_ref.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_ref.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lbl_ref.position.y = 8
	lbl_ref.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(lbl_ref)

	var knob := Panel.new()
	knob.custom_minimum_size = Vector2(36, 36)
	knob.size = Vector2(36, 36)
	knob.position = Vector2(34, 34)
	knob.add_theme_stylebox_override("panel", _style_box(Color(0.1, 0.85, 1.0, 0.85), Color(0, 0, 0, 0), 18, 0))
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(knob)

	var active := [false]
	pad.gui_input.connect(func(ev):
		var max_r := 38.0
		var center := Vector2(52, 52)
		if ev is InputEventMouseButton:
			if ev.button_index == MOUSE_BUTTON_LEFT:
				active[0] = ev.pressed
				if not ev.pressed:
					knob.position = Vector2(34, 34)
					on_change.call(Vector2.ZERO)
				else:
					var diff: Vector2 = (ev.position - center).limit_length(max_r)
					knob.position = center + diff - Vector2(18, 18)
					on_change.call(diff / max_r)
		elif ev is InputEventMouseMotion and active[0]:
			var diff: Vector2 = (ev.position - center).limit_length(max_r)
			knob.position = center + diff - Vector2(18, 18)
			on_change.call(diff / max_r)
	)
	return pad

func _build_catalog_panel() -> void:
	catalog_panel.visible = false
	catalog_panel.set_anchors_preset(Control.PRESET_CENTER)
	catalog_panel.offset_left = -260; catalog_panel.offset_right = 260; catalog_panel.offset_top = -170; catalog_panel.offset_bottom = 170
	catalog_panel.add_theme_stylebox_override("panel", _style_box(Color(0.04, 0.05, 0.08, 0.94), Color(0, 0.85, 1, 0.45), 14, 1))
	add_child(catalog_panel)

	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); catalog_panel.add_child(v)
	var h := HBoxContainer.new(); v.add_child(h)
	h.add_child(catalog_title)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(sp)
	var cb := Button.new(); cb.text = "Закрыть"; cb.pressed.connect(func(): catalog_panel.visible = false); h.add_child(cb)

	var tabs := ScrollContainer.new(); tabs.custom_minimum_size = Vector2(0, 38); tabs.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; v.add_child(tabs)
	var th := HBoxContainer.new(); th.add_theme_constant_override("separation", 6); tabs.add_child(th)
	for cat in [
		UniverseCatalog.BodyCategory.ALL, UniverseCatalog.BodyCategory.STATIONS,
		UniverseCatalog.BodyCategory.SOLAR, UniverseCatalog.BodyCategory.MOONS,
		UniverseCatalog.BodyCategory.STARS, UniverseCatalog.BodyCategory.EXOPLANETS,
		UniverseCatalog.BodyCategory.BLACK_HOLES, UniverseCatalog.BodyCategory.GALAXIES
	]:
		var b := Button.new(); b.text = UniverseCatalog.category_label(cat)
		var c_id: int = cat
		b.pressed.connect(func():
			selected_cat = c_id
			_rebuild_catalog()
		)
		th.add_child(b)

	var scr := ScrollContainer.new(); scr.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(scr)
	scr.add_child(catalog_list)
	catalog_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _rebuild_catalog() -> void:
	for ch in catalog_list.get_children():
		ch.queue_free()
	var stations: Array = EliteSystems.get_stations() if (selected_cat == UniverseCatalog.BodyCategory.ALL or selected_cat == UniverseCatalog.BodyCategory.STATIONS) else []
	var bodies: Array[Dictionary] = []
	if selected_cat != UniverseCatalog.BodyCategory.STATIONS:
		for b in UniverseCatalog.get_bodies():
			if selected_cat == UniverseCatalog.BodyCategory.ALL or b["category"] == selected_cat:
				bodies.append(b)
	catalog_title.text = "Астрономический каталог 1:1 (%d)" % (stations.size() + bodies.size())

	for st in stations:
		var st_ref: Dictionary = st
		var row := HBoxContainer.new()
		var lbl := Label.new(); lbl.text = "%s\nСтанция • %s" % [st_ref["name"], st_ref["economy"]]; lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var b1 := Button.new(); b1.text = "Курс"
		b1.pressed.connect(func():
			main_ctrl.align_to_station(st_ref)
			catalog_panel.visible = false
		)
		row.add_child(b1)
		var b2 := Button.new(); b2.text = "Перелёт"
		b2.pressed.connect(func():
			main_ctrl.warp_to_station(st_ref)
			catalog_panel.visible = false
		)
		row.add_child(b2)
		catalog_list.add_child(row)

	for b in bodies:
		var b_ref: Dictionary = b
		var row := HBoxContainer.new()
		var lbl := Label.new(); lbl.text = "%s\n%s" % [b_ref["name"], b_ref["type"]]; lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(lbl)
		var b1 := Button.new(); b1.text = "Курс"
		b1.pressed.connect(func():
			main_ctrl.target_body = b_ref
			main_ctrl.align_to_target()
			catalog_panel.visible = false
		)
		row.add_child(b1)
		var b2 := Button.new(); b2.text = "Перелёт"
		b2.pressed.connect(func():
			main_ctrl.warp_to_body(b_ref)
			catalog_panel.visible = false
		)
		row.add_child(b2)
		if b_ref["is_landable"]:
			var b3 := Button.new(); b3.text = "Посадка"
			b3.pressed.connect(func():
				main_ctrl.warp_to_surface_approach(b_ref)
				catalog_panel.visible = false
			)
			row.add_child(b3)
		catalog_list.add_child(row)

func _build_info_panel() -> void:
	info_panel.visible = false
	info_panel.set_anchors_preset(Control.PRESET_CENTER)
	info_panel.offset_left = -210; info_panel.offset_right = 210; info_panel.offset_top = -145; info_panel.offset_bottom = 145
	info_panel.add_theme_stylebox_override("panel", _style_box(Color(0.04, 0.05, 0.08, 0.94), Color(0, 0.85, 1, 0.5), 14, 1))
	add_child(info_panel)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); info_panel.add_child(v)
	var h := HBoxContainer.new(); v.add_child(h); h.add_child(info_title)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(sp)
	var cb := Button.new(); cb.text = "Закрыть"; cb.pressed.connect(func(): info_panel.visible = false); h.add_child(cb)
	info_body.autowrap_mode = TextServer.AUTOWRAP_WORD; info_body.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(info_body)
	var bh := HBoxContainer.new(); v.add_child(bh)
	var b1 := Button.new(); b1.text = "Курс"; b1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b1.pressed.connect(func():
		main_ctrl.align_to_target()
		info_panel.visible = false
	)
	bh.add_child(b1)
	var b2 := Button.new(); b2.text = "На орбиту"; b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b2.pressed.connect(func():
		main_ctrl.warp_to_body(main_ctrl.target_body)
		info_panel.visible = false
	)
	bh.add_child(b2)
	info_land_btn.text = "Посадка"; info_land_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_land_btn.pressed.connect(func():
		main_ctrl.warp_to_surface_approach(main_ctrl.target_body)
		info_panel.visible = false
	)
	bh.add_child(info_land_btn)

func _refresh_info_panel() -> void:
	var b: Dictionary = main_ctrl.target_body
	info_title.text = "%s (%s)" % [b["name"], b["type"]]
	var rad_str: String = UniverseCatalog.format_distance(b["radius_m"]) if b["radius_m"] >= 0.01 * UniverseCatalog.LY else ("%.0f км" % (b["radius_m"] / 1_000.0))
	var temp_str: String = ("%d °C (%d K)" % [b["mean_temp_c"], b["mean_temp_k"]]) if b["mean_temp_k"] > 0 else "Горизонт событий"
	info_body.text = "%s\n\nРадиус: %s\nГравитация: %.2f g\n1-я / 2-я косм.: %.1f / %.1f км/с\nТемпература: %s" % [b["summary"], rad_str, b["surface_gravity_g"], b["first_cosmic_mps"] / 1_000.0, b["escape_velocity_mps"] / 1_000.0, temp_str]
	info_land_btn.visible = b["is_landable"]

func _build_station_panel() -> void:
	station_panel.visible = false
	station_panel.set_anchors_preset(Control.PRESET_CENTER)
	station_panel.offset_left = -330; station_panel.offset_right = 330; station_panel.offset_top = -170; station_panel.offset_bottom = 170
	station_panel.add_theme_stylebox_override("panel", _style_box(Color(0.03, 0.04, 0.06, 0.94), Color(1, 0.6, 0.1, 0.7), 14, 2))
	add_child(station_panel)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); station_panel.add_child(v)
	var h := HBoxContainer.new(); v.add_child(h)
	h.add_child(st_header_lbl)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(sp)
	h.add_child(st_credits_lbl)
	var ub := Button.new(); ub.text = "ОТСТЫКОВКА"; ub.pressed.connect(func(): main_ctrl.undock_from_station()); h.add_child(ub)

	var tabs := HBoxContainer.new(); tabs.add_theme_constant_override("separation", 8); v.add_child(tabs)
	for pair in [[0, "РЫНОК"], [1, "КАРТОГРАФИЯ"], [2, "ВЕРФЬ"]]:
		var tb := Button.new(); tb.text = pair[1]
		var idx: int = pair[0]
		tb.pressed.connect(func():
			active_st_tab = idx
			_rebuild_station_list()
		)
		tabs.add_child(tb)

	var scr := ScrollContainer.new(); scr.size_flags_vertical = Control.SIZE_EXPAND_FILL; v.add_child(scr)
	st_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL; scr.add_child(st_list)

func _rebuild_station_list() -> void:
	for ch in st_list.get_children():
		ch.queue_free()
	if not main_ctrl.has_docked_station:
		return
	var st: Dictionary = main_ctrl.docked_station
	var p: Dictionary = main_ctrl.pilot_profile
	st_header_lbl.text = "%s\nЭкономика: %s" % [st["name"], st["economy"]]
	st_credits_lbl.text = "%d CR | Трюм: %d / %d т" % [int(p["credits"]), EliteSystems.used_cargo_tons(p), EliteSystems.cargo_capacity_tons(p)]

	if active_st_tab == 0:
		for item in EliteSystems.get_commodities():
			var item_ref: Dictionary = item
			var price := EliteSystems.commodity_price(item_ref["id"], item_ref["base_price"], st["economy"])
			var tag := EliteSystems.commodity_demand_tag(item_ref["id"], item_ref["base_price"], st["economy"])
			var held := int(p["cargo"].get(item_ref["id"], 0))
			var row := HBoxContainer.new()
			var lbl := Label.new(); lbl.text = "%s (%d CR/т | %s | Трюм: %d т)" % [item_ref["name"], price, tag, held]; lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(lbl)
			var bs := Button.new(); bs.text = "−1"
			bs.pressed.connect(func():
				main_ctrl.sell_commodity(item_ref, 1)
				_rebuild_station_list()
			)
			row.add_child(bs)
			var b1 := Button.new(); b1.text = "+1"
			b1.pressed.connect(func():
				main_ctrl.buy_commodity(item_ref, 1)
				_rebuild_station_list()
			)
			row.add_child(b1)
			var b5 := Button.new(); b5.text = "+5"
			b5.pressed.connect(func():
				main_ctrl.buy_commodity(item_ref, 5)
				_rebuild_station_list()
			)
			row.add_child(b5)
			st_list.add_child(row)
	elif active_st_tab == 1:
		var unsold := 0
		for r in p["scans"]:
			if not r["sold"]: unsold += int(r["payout_credits"])
		if unsold > 0:
			var sb := Button.new(); sb.text = "ПРОДАТЬ ВСЕ ДАННЫЕ (+%d CR)" % unsold
			sb.pressed.connect(func():
				main_ctrl.sell_all_cartographics()
				_rebuild_station_list()
			)
			st_list.add_child(sb)
		for r in p["scans"]:
			var lbl := Label.new(); lbl.text = "%s (%s) — %s" % [r["body_name"], r["scan_type"], ("ПРОДАНО" if r["sold"] else "+%d CR" % int(r["payout_credits"]))]
			st_list.add_child(lbl)
	else:
		var upg := [
			["Грузовой отсек (Трюм: %d т)" % EliteSystems.cargo_capacity_tons(p), p["cargo_level"], EliteSystems.CARGO_COSTS, Callable(main_ctrl, "upgrade_cargo")],
			["Усилитель FSS (×%.1f)" % EliteSystems.fss_multiplier(p), p["fss_level"], EliteSystems.FSS_COSTS, Callable(main_ctrl, "upgrade_fss")],
			["Ранец EVA (Расход: %.2f/с)" % EliteSystems.jetpack_drain_per_sec(p), p["jetpack_level"], EliteSystems.JETPACK_COSTS, Callable(main_ctrl, "upgrade_jetpack")],
		]
		for u in upg:
			var row := HBoxContainer.new()
			var lbl := Label.new(); lbl.text = u[0]; lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(lbl)
			var lvl: int = u[1]
			var costs: Array = u[2]
			var cb: Callable = u[3]
			var b := Button.new()
			if lvl < costs.size():
				b.text = "Улучшить • %d CR" % costs[lvl]
				b.pressed.connect(func():
					cb.call()
					_rebuild_station_list()
				)
			else:
				b.text = "МАКС."
				b.disabled = true
			row.add_child(b)
			st_list.add_child(row)

func _build_fss_panel() -> void:
	fss_panel.visible = false
	fss_panel.set_anchors_preset(Control.PRESET_CENTER)
	fss_panel.offset_left = -240; fss_panel.offset_right = 240; fss_panel.offset_top = -125; fss_panel.offset_bottom = 125
	fss_panel.add_theme_stylebox_override("panel", _style_box(Color(0.03, 0.04, 0.07, 0.92), Color(0, 0.85, 1, 0.55), 14, 1))
	add_child(fss_panel)
	var v := VBoxContainer.new(); v.add_theme_constant_override("separation", 8); fss_panel.add_child(v)
	var h := HBoxContainer.new(); v.add_child(h)
	var t := Label.new(); t.text = "FSS-СКАНЕР ПОЛНОГО СПЕКТРА"; h.add_child(t)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(sp)
	var cb := Button.new(); cb.text = "ЗАКРЫТЬ"; cb.pressed.connect(func(): main_ctrl.is_fss_open = false); h.add_child(cb)

	var h2 := HBoxContainer.new(); v.add_child(h2); h2.add_child(fss_target_lbl); h2.add_child(fss_freq_lbl)
	var sp2 := Control.new(); sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h2.add_child(sp2); h2.add_child(fss_status_lbl)

	var spec_h := HBoxContainer.new(); spec_h.custom_minimum_size = Vector2(0, 46); spec_h.add_theme_constant_override("separation", 3); v.add_child(spec_h)
	for _i in range(36):
		var bar := ColorRect.new(); bar.custom_minimum_size = Vector2(9, 10); bar.size_flags_vertical = Control.SIZE_SHRINK_END
		spec_h.add_child(bar); fss_bars.append(bar)

	fss_slider.min_value = 10.0; fss_slider.max_value = 100.0; fss_slider.step = 0.1
	fss_slider.value_changed.connect(func(val: float):
		if not _updating_sliders:
			main_ctrl.fss_frequency_mhz = val
	)
	v.add_child(fss_slider)

	var h3 := HBoxContainer.new(); v.add_child(h3)
	var ab := Button.new(); ab.text = "АВТОНАСТРОЙКА НА ЦЕЛЬ"; ab.pressed.connect(func(): main_ctrl.auto_tune_fss()); h3.add_child(ab)
	var sp3 := Control.new(); sp3.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h3.add_child(sp3)
	fss_scan_btn.pressed.connect(func(): main_ctrl.perform_fss_scan()); h3.add_child(fss_scan_btn)
	v.add_child(fss_msg_lbl)

func _refresh_fss_panel() -> void:
	var tf := EliteSystems.fss_frequency_mhz(main_ctrl.target_body)
	var locked := absf(main_ctrl.fss_frequency_mhz - tf) <= 4.0
	var payout := int(round(float(EliteSystems.fss_base_payout(main_ctrl.target_body)) * EliteSystems.fss_multiplier(main_ctrl.pilot_profile)))
	fss_target_lbl.text = "Цель: %s  " % main_ctrl.target_body["name"]
	fss_freq_lbl.text = "%.1f МГц" % main_ctrl.fss_frequency_mhz
	fss_status_lbl.text = "ЗАХВАТ СИГНАЛА" if locked else "ПОИСК"
	_updating_sliders = true; fss_slider.value = main_ctrl.fss_frequency_mhz; _updating_sliders = false
	fss_scan_btn.text = "СКАНИРОВАТЬ (+%d CR)" % payout
	fss_scan_btn.disabled = not locked
	fss_msg_lbl.text = main_ctrl.last_fss_message
	for i in range(fss_bars.size()):
		var bf := 10.0 + (float(i) / 35.0) * 90.0
		var dt := (bf - tf) / 4.2
		var h := minf(44.0, 6.0 + exp(-(dt * dt)) * 38.0)
		fss_bars[i].custom_minimum_size.y = h
		fss_bars[i].color = (Color.GREEN if locked else Color.ORANGE) if absf(bf - main_ctrl.fss_frequency_mhz) < 2.8 else Color(0, 0.85, 1, 0.55)

func _process(_delta: float) -> void:
	main_menu_root.visible = main_ctrl.is_main_menu
	var show_ship: bool = (not main_ctrl.is_main_menu) and (not main_ctrl.has_docked_station) and (not main_ctrl.is_walking)
	var show_eva: bool = (not main_ctrl.is_main_menu) and (not main_ctrl.has_docked_station) and main_ctrl.is_walking
	ship_hud.visible = show_ship
	eva_hud.visible = show_eva

	var was_st := station_panel.visible
	station_panel.visible = main_ctrl.has_docked_station and (not main_ctrl.is_main_menu)
	if station_panel.visible and not was_st:
		_rebuild_station_list()

	fss_panel.visible = main_ctrl.is_fss_open and show_ship
	if fss_panel.visible:
		_refresh_fss_panel()

	markers_layer.visible = show_ship and main_ctrl.show_markers
	if markers_layer.visible:
		for i in range(marker_pool.size()):
			var b := marker_pool[i]
			if i < main_ctrl.screen_markers.size():
				var m: Dictionary = main_ctrl.screen_markers[i]
				b.visible = true
				b.text = m["name"]
				b.position = m["pos"] - Vector2(b.size.x * 0.5, 14.0)
				b.add_theme_color_override("font_color", m["color"])
			else:
				b.visible = false

	if show_ship:
		catalog_btn.text = "%s • %s" % [main_ctrl.target_body["name"], main_ctrl.distance_text]
		speed_eta_lbl.text = "%s • %s" % [main_ctrl.speed_text, main_ctrl.eta_text]
		credits_lbl.text = "%d CR" % int(main_ctrl.pilot_profile["credits"])
		cam_mode_btn.text = "Корабль" if main_ctrl.is_free_camera else "Камера"
		fpv_btn.visible = not main_ctrl.is_free_camera
		fpv_btn.text = "1-е лицо" if main_ctrl.is_third_person else "3-е лицо"

		prox_bar.visible = main_ctrl.is_near_surface
		zone_lbl.text = main_ctrl.zone_text
		alt_lbl.text = main_ctrl.surface_alt_text
		exit_ship_btn.visible = main_ctrl.is_landed
		takeoff_btn.visible = main_ctrl.is_landed
		land_btn.visible = main_ctrl.can_auto_land and (not main_ctrl.is_landed)
		horizon_btn.visible = (not main_ctrl.is_landed) and (not main_ctrl.is_free_camera)

		station_prox_bar.visible = main_ctrl.has_nearby_station
		if main_ctrl.has_nearby_station:
			station_prox_lbl.text = "СТАНЦИЯ: %s • %s" % [main_ctrl.nearby_station["name"], main_ctrl.nearby_station_dist_text]

		throttle_lbl.text = ("%s: %d%%" % ["КРУИЗ" if main_ctrl.is_free_camera else "ТЯГА", int(main_ctrl.throttle * 100.0)])
		_updating_sliders = true; throttle_slider.value = main_ctrl.throttle; _updating_sliders = false
		fa_btn.visible = not main_ctrl.is_free_camera
		fa_btn.text = "FA: ON" if main_ctrl.flight_assist else "ИНЕРЦИЯ"
		time_date_lbl.text = main_ctrl.sim_date_text
		time_warp_lbl.text = "ПАУЗА" if main_ctrl.is_time_paused else ("%s%s" % ["−" if main_ctrl.is_time_reversed else "", main_ctrl.current_warp_label()])
		speed_down_btn.visible = not main_ctrl.auto_speed
		speed_up_btn.visible = not main_ctrl.auto_speed
		speed_val_lbl.text = main_ctrl.auto_speed_label if main_ctrl.auto_speed else main_ctrl.current_speed_label()

	if show_eva:
		eva_ship_lbl.text = "  ✈ КОРАБЛЬ • %s • ПОСАЖЕН  " % main_ctrl.eva_ship_dist_text
		eva_stick_lbl.text = "СПРИНТ" if main_ctrl.eva_sprinting else "ХОДЬБА"
		eva_jetpack_btn.text = "РАНЕЦ %d%%" % int(main_ctrl.eva_jetpack_fuel * 100.0)
		eva_fuel_bar.value = main_ctrl.eva_jetpack_fuel * 100.0
		eva_scan_card.visible = main_ctrl.eva_scanner_open and (not main_ctrl.eva_scan_report.is_empty())
		if eva_scan_card.visible:
			var r: Dictionary = main_ctrl.eva_scan_report
			eva_scan_text.text = "СКАНЕР ПОВЕРХНОСТИ • %s\nБиом: %s\nВысота: %d м | Гравитация: %.2f g (%.1f м/с²)\nТемпература: %d °C | Атмосфера: %s\nСостав: %s" % [r["planet_name"], r["biome_name"], r["elevation_m"], r["gravity_g"], r["gravity_mps2"], r["temp_c"], r["atmosphere_text"], r["composition_text"]]
