extends Node3D

@onready var world_env: WorldEnvironment = $WorldEnvironment
@onready var sun_light: DirectionalLight3D = $SunLight
@onready var main_camera: Camera3D = $MainCamera

var ship_node := Node3D.new()
var ship_visual := Node3D.new()
var third_person_node: Node3D
var landing_gear_node: Node3D
var exhaust_nodes: Array[MeshInstance3D] = []
var parked_ship_node := Node3D.new()
var parked_ship_visual: Node3D
var camera_boom := Node3D.new()

var orbit_lines_mesh := ImmediateMesh.new()
var orbit_lines_node := MeshInstance3D.new()

var terrain_root := Node3D.new()
var terrain_mesh_inst := MeshInstance3D.new()
var ocean_mesh_inst := MeshInstance3D.new()
var surface_props_node: Node3D = null

var dust_root := Node3D.new()
var dust_items: Array[Dictionary] = []

var body_nodes: Dictionary = {}
var planet_meshes: Dictionary = {}
var planet_mats: Dictionary = {}
var station_nodes: Dictionary = {}

# --- State exposed to HUD ---
var is_main_menu: bool = true
var speed_index: int = 0
var time_warp_index: int = 0
var is_time_paused: bool = false
var is_time_reversed: bool = false
var show_orbits: bool = true
var show_markers: bool = true
var is_free_camera: bool = false
var auto_speed: bool = false
var throttle: float = 0.0
var flight_assist: bool = true
var is_third_person: bool = true
var is_landed: bool = false
var is_near_surface: bool = false
var is_walking: bool = false
var is_over_water: bool = false
var can_auto_land: bool = false
var eva_sprinting: bool = false
var eva_jetpack_active: bool = false
var eva_jetpack_fuel: float = 1.0
var eva_scanner_open: bool = false
var eva_scan_report: Dictionary = {}
var eva_ship_dist_text: String = "7 м"
var eva_temp_text: String = "15 °C"
var surface_alt_text: String = ""
var zone_text: String = ""
var distance_text: String = ""
var speed_text: String = "0 м/с"
var auto_speed_label: String = "АВТО"
var eta_text: String = "Стоп"
var sim_date_text: String = "24.11.2026"
var target_body: Dictionary
var screen_markers: Array[Dictionary] = []

var pilot_profile: Dictionary = {}
var docked_station: Dictionary = {}
var has_docked_station: bool = false
var nearby_station: Dictionary = {}
var has_nearby_station: bool = false
var nearby_station_dist_text: String = ""
var is_fss_open: bool = false
var fss_frequency_mhz: float = 42.0
var last_fss_message: String = ""

const SPEED_STEPS := [
	{"label": "1.5 км/с", "mps": 1_500.0},
	{"label": "7.9 км/с (Орбита)", "mps": 7_900.0},
	{"label": "11.2 км/с (2-я косм.)", "mps": 11_200.0},
	{"label": "100 км/с", "mps": 100_000.0},
	{"label": "10 000 км/с", "mps": 10_000_000.0},
	{"label": "1 c", "mps": 299_792_458.0},
	{"label": "100 c", "mps": 29_979_245_800.0},
	{"label": "10 000 c", "mps": 2_997_924_580_000.0},
	{"label": "500 000 c", "mps": 149_896_229_000_000.0},
	{"label": "10 млн c", "mps": 2_997_924_580_000_000.0},
	{"label": "1 млрд c", "mps": 299_792_458_000_000_000.0},
]

const TIME_WARP_STEPS := [
	{"label": "1x", "mult": 1.0},
	{"label": "10x", "mult": 10.0},
	{"label": "100x", "mult": 100.0},
	{"label": "1 000x", "mult": 1_000.0},
	{"label": "10 000x", "mult": 10_000.0},
	{"label": "100 000x", "mult": 100_000.0},
	{"label": "1 млн x", "mult": 1_000_000.0},
]

# --- 64-bit simulation variables ---
var ship_pos64: PackedFloat64Array = UniverseCatalog.v64(-UniverseCatalog.AU + 10_200_000.0, 2_800_000.0, 11_400_000.0)
var ship_vel64: PackedFloat64Array = UniverseCatalog.v64(0.0, 0.0, 0.0)
var ship_orient: Quaternion = Quaternion(Vector3(-0.18, 1.0, 0.0).normalized(), 0.68)

var stick_input: Vector2 = Vector2.ZERO
var angular_vel_yaw: float = 0.0
var angular_vel_pitch: float = 0.0
var orbit_yaw: float = 0.0
var orbit_pitch: float = -0.16
var orbit_distance: float = 13.5
var sim_time_s: float = 0.0
var frame_counter: int = 0

var active_surface_body_id: String = ""
var last_terrain_anchor_local64: PackedFloat64Array = UniverseCatalog.v64()
var last_terrain_build_rot := Quaternion.IDENTITY
var last_terrain_alt: float = -1.0
var active_collision: SurfaceTerrain.TerrainCollision = null
var has_props_for_anchor: bool = false

var last_tracked_body_id: String = ""
var last_tracked_pos64 := UniverseCatalog.v64()
var last_tracked_rot := Quaternion.IDENTITY
var last_tracked_time_s: float = 0.0
var current_ground_h: float = 0.0

var eva_yaw: float = 0.0
var eva_pitch: float = -0.05
var eva_vertical_vel: float = 0.0
var eva_height_above_ground: float = 1.85
var eva_walk_phase: float = 0.0
var eva_ref_fwd_local := Vector3(0, 0, -1)

var parked_ship_body_id: String = ""
var parked_ship_local_pos64: PackedFloat64Array = UniverseCatalog.v64()
var parked_ship_local_orient := Quaternion.IDENTITY

var docked_station_id: String = ""
var _base_env_sky: Sky
var _disk_ring_tex_cache: Dictionary = {}
var _galaxy_tex_cache: Dictionary = {}

func step_time_warp(delta_idx: int) -> void:
	time_warp_index = clampi(time_warp_index + delta_idx, 0, TIME_WARP_STEPS.size() - 1)

func current_warp_label() -> String:
	return TIME_WARP_STEPS[time_warp_index]["label"]

func step_speed(delta_idx: int) -> void:
	speed_index = clampi(speed_index + delta_idx, 0, SPEED_STEPS.size() - 1)

func current_speed_label() -> String:
	return SPEED_STEPS[speed_index]["label"]

func stop_ship() -> void:
	throttle = 0.0
	ship_vel64 = UniverseCatalog.v64()

const SHADER_PLANET := preload("res://shaders/planet.gdshader")
const SHADER_STAR := preload("res://shaders/star.gdshader")
const SHADER_BH := preload("res://shaders/black_hole.gdshader")
const SHADER_ACCRETION := preload("res://shaders/accretion_disk.gdshader")

func _id_seed(id_str: String) -> float:
	var h: int = 2166136261
	for c in id_str.to_utf8_buffer():
		h = ((h ^ int(c)) * 16777619) & 0x7FFFFFFF
	return float(h & 0xFFFF) / 512.0

func _ready() -> void:
	target_body = UniverseCatalog.find_body("earth")
	pilot_profile = EliteSystems.load_profile()
	_base_env_sky = world_env.environment.sky

	add_child(ship_node)
	ship_node.add_child(ship_visual)
	var built_ship := ShipBuilder.build_ship_node()
	third_person_node = built_ship["root"]
	landing_gear_node = built_ship["landing_gear"]
	exhaust_nodes = built_ship["exhaust_nodes"]
	ship_visual.add_child(third_person_node)

	var parked_built := ShipBuilder.build_ship_node()
	parked_ship_visual = parked_built["root"]
	parked_ship_node.add_child(parked_ship_visual)
	parked_ship_node.visible = false
	add_child(parked_ship_node)

	ship_node.add_child(camera_boom)
	main_camera.get_parent().remove_child(main_camera)
	camera_boom.add_child(main_camera)
	update_camera_mode()

	terrain_root.visible = false
	terrain_root.add_child(terrain_mesh_inst)
	terrain_root.add_child(ocean_mesh_inst)
	add_child(terrain_root)

	orbit_lines_node.mesh = orbit_lines_mesh
	var o_mat := StandardMaterial3D.new()
	o_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	o_mat.albedo_color = Color(0.25, 0.72, 1.0, 0.45)
	o_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	orbit_lines_node.material_override = o_mat
	add_child(orbit_lines_node)

	_build_space_dust()
	_build_celestial_bodies()
	_build_stations()
	align_to_target()

func _build_space_dust() -> void:
	add_child(dust_root)
	var m := SphereMesh.new()
	m.radius = 0.055; m.height = 0.11
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.85, 0.88, 0.95, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x55AA33CC
	for _i in range(90):
		var d := MeshInstance3D.new()
		d.mesh = m
		d.material_override = mat
		var off := Vector3(rng.randf_range(-45.0, 45.0), rng.randf_range(-45.0, 45.0), rng.randf_range(-45.0, 45.0))
		d.position = off
		dust_root.add_child(d)
		dust_items.append({"node": d, "offset": off})

func _build_celestial_bodies() -> void:
	var sphere_hi := SphereMesh.new(); sphere_hi.radius = 1.0; sphere_hi.height = 2.0; sphere_hi.radial_segments = 64; sphere_hi.rings = 32
	var sphere_lo := SphereMesh.new(); sphere_lo.radius = 1.0; sphere_lo.height = 2.0; sphere_lo.radial_segments = 32; sphere_lo.rings = 16

	for body in UniverseCatalog.get_bodies():
		var bid: String = body["id"]
		var root := Node3D.new()
		root.rotation = Vector3(0, 0, body["axial_tilt_rad"])

		var mesh_inst := MeshInstance3D.new()
		mesh_inst.mesh = sphere_hi if (body["category"] == UniverseCatalog.BodyCategory.SOLAR or bid == "moon") else sphere_lo

		if body["is_black_hole"]:
			var sm := ShaderMaterial.new()
			sm.shader = SHADER_BH
			var rcol := Color(1.0, 0.68, 0.28)
			var inner_c := Color(1.0, 0.94, 0.78)
			var outer_c := Color(0.92, 0.34, 0.05)
			var sharp := 9.0
			var asym := 0.35
			var halo := 0.28
			var d_scale := 6.4
			var spin_spd := 1.4
			if bid == "cygnus_x1":
				rcol = Color(0.50, 0.85, 1.0)
				inner_c = Color(0.88, 0.97, 1.0)
				outer_c = Color(0.18, 0.52, 1.0)
				sharp = 12.0; asym = 0.50; halo = 0.40; d_scale = 5.6; spin_spd = 3.2
				_add_polar_jets(root, Color(0.45, 0.88, 1.0), 6.2, 0.22, true, 0.0)
			elif bid == "m87_star":
				rcol = Color(1.0, 0.60, 0.14)
				inner_c = Color(1.0, 0.82, 0.42)
				outer_c = Color(0.85, 0.24, 0.04)
				sharp = 7.5; asym = 0.65; halo = 0.32; d_scale = 7.4; spin_spd = 0.9
				_add_polar_jets(root, Color(0.55, 0.78, 1.0), 11.5, 0.34, false, 8.0)
			elif bid == "ton618":
				rcol = Color(1.0, 0.88, 0.55)
				inner_c = Color(1.0, 0.96, 0.88)
				outer_c = Color(0.75, 0.35, 1.0)
				sharp = 6.2; asym = 0.42; halo = 0.62; d_scale = 9.2; spin_spd = 2.0
				_add_polar_jets(root, Color(0.82, 0.58, 1.0), 14.0, 0.48, true, 0.0)
			sm.set_shader_parameter("ring_color", Vector3(rcol.r, rcol.g, rcol.b))
			sm.set_shader_parameter("ring_sharpness", sharp)
			sm.set_shader_parameter("ring_intensity", 3.4)
			sm.set_shader_parameter("asymmetry", asym)
			sm.set_shader_parameter("lensed_halo", halo)
			mesh_inst.material_override = sm
			_add_bh_accretion_disk(root, inner_c, outer_c, d_scale, spin_spd, _id_seed(bid))
		elif body["is_galaxy"]:
			mesh_inst.visible = false
			_add_galaxy_disc(root, body)
		elif body["is_star"]:
			var sm := ShaderMaterial.new()
			sm.shader = SHADER_STAR
			var c1: Color = body["color"]
			var c2: Color = body["secondary_color"]
			var temp_k: int = int(body["mean_temp_k"])
			var g_scale := 9.0
			var spots := 0.32
			var flares := 0.25
			var spd := 1.0
			if bid == "crab_pulsar":
				g_scale = 16.0; spots = 0.08; flares = 0.95; spd = 6.5
				_add_polar_jets(mesh_inst, Color(0.45, 0.85, 1.0), 12.0, 0.40, true, 32.0)
			elif temp_k >= 8500:
				g_scale = 15.0; spots = 0.08; flares = 0.22; spd = 1.8
			elif float(body["radius_m"]) > 100_000_000_000.0:
				# Красные сверх/гипергиганты с гигантскими конвективными ячейками
				g_scale = 2.6; spots = 0.52; flares = 0.55; spd = 0.55
			elif temp_k <= 3800:
				# Вспыхивающие красные карлики
				g_scale = 6.5; spots = 0.62; flares = 0.65; spd = 1.6
			elif float(body["radius_m"]) > 10_000_000_000.0:
				g_scale = 4.2; spots = 0.42; flares = 0.35; spd = 0.75
			sm.set_shader_parameter("hot_color", Vector3(c1.r, c1.g, c1.b))
			sm.set_shader_parameter("cool_color", Vector3(c2.r, c2.g, c2.b))
			sm.set_shader_parameter("star_seed", _id_seed(bid))
			sm.set_shader_parameter("granule_scale", g_scale)
			sm.set_shader_parameter("spot_amount", spots)
			sm.set_shader_parameter("flare_intensity", flares)
			sm.set_shader_parameter("anim_speed", spd)
			mesh_inst.material_override = sm
			_add_star_corona(root, c1, c2, 1.24 if bid == "crab_pulsar" else (1.18 if temp_k >= 8500 else 1.12))
		else:
			var sm := ShaderMaterial.new()
			sm.shader = SHADER_PLANET
			var mode := 4
			var atmo_str := 0.0
			var atmo_c := Color(0.32, 0.62, 1.0)
			var bump := 0.65
			if body["is_habitable"]:
				mode = 1; atmo_str = 1.0; bump = 0.45
				atmo_c = Color(0.30, 0.62, 1.0) if bid != "kepler186f" else Color(0.55, 0.70, 0.92)
			elif bid in ["venus", "titan", "trappist1b"]:
				mode = 6; atmo_str = 1.15; bump = 0.14
				atmo_c = Color(0.96, 0.78, 0.44) if bid == "venus" else (Color(0.90, 0.58, 0.22) if bid == "titan" else Color(0.92, 0.45, 0.22))
			elif bid == "mars" or bid == "trappist1d":
				mode = 2; atmo_str = 0.55; atmo_c = Color(0.88, 0.48, 0.26); bump = 0.62
			elif body["is_gas_giant"]:
				mode = 3; atmo_str = 0.72; atmo_c = body["color"]; bump = 0.16
			elif body["is_icy"]:
				mode = 5; atmo_str = 0.18 if body["has_atmosphere"] else 0.0; bump = 0.52
			var c1: Color = body["color"]
			var c2: Color = body["secondary_color"]
			sm.set_shader_parameter("planet_mode", mode)
			sm.set_shader_parameter("color_primary", Vector3(c1.r, c1.g, c1.b))
			sm.set_shader_parameter("color_secondary", Vector3(c2.r, c2.g, c2.b))
			sm.set_shader_parameter("atmo_color", Vector3(atmo_c.r, atmo_c.g, atmo_c.b))
			sm.set_shader_parameter("has_cities", 1 if bid == "earth" else 0)
			sm.set_shader_parameter("planet_seed", _id_seed(bid))
			sm.set_shader_parameter("has_red_spot", 1.0 if bid == "jupiter" else 0.0)
			sm.set_shader_parameter("atmo_strength", atmo_str)
			sm.set_shader_parameter("cloud_amount", float(body["cloud_coverage"]))
			sm.set_shader_parameter("bump_strength", bump)
			mesh_inst.material_override = sm
			planet_mats[bid] = sm

		if body["has_rings"] and not body["is_black_hole"]:
			_add_disk_ring(root, false, bid == "uranus", body["secondary_color"])

		root.add_child(mesh_inst)
		add_child(root)
		body_nodes[bid] = root
		planet_meshes[bid] = mesh_inst

func _add_bh_accretion_disk(root: Node3D, inner_c: Color, outer_c: Color, d_scale: float, spin_spd: float, d_seed: float) -> void:
	var sm := ShaderMaterial.new()
	sm.shader = SHADER_ACCRETION
	sm.set_shader_parameter("inner_color", Vector3(inner_c.r, inner_c.g, inner_c.b))
	sm.set_shader_parameter("outer_color", Vector3(outer_c.r, outer_c.g, outer_c.b))
	sm.set_shader_parameter("spin_speed", spin_spd)
	sm.set_shader_parameter("turbulence", 1.15)
	sm.set_shader_parameter("doppler_strength", 0.55)
	sm.set_shader_parameter("inner_radius", 0.25)
	sm.set_shader_parameter("disk_seed", d_seed)
	var plane := QuadMesh.new()
	plane.size = Vector2(d_scale, d_scale)
	var inst := MeshInstance3D.new()
	inst.mesh = plane
	inst.material_override = sm
	inst.rotation_degrees = Vector3(-90, 0, 0)
	root.add_child(inst)

func _add_polar_jets(parent_node: Node3D, col: Color, length_s: float, radius_s: float, both_sides: bool, tilt_deg: float) -> void:
	var jet_root := Node3D.new()
	jet_root.rotation_degrees = Vector3(0, 0, tilt_deg)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(col.r, col.g, col.b, 0.34)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cone := CylinderMesh.new()
	cone.top_radius = radius_s
	cone.bottom_radius = radius_s * 0.14
	cone.height = length_s
	cone.radial_segments = 14
	var dirs := [1.0, -1.0] if both_sides else [1.0]
	for d in dirs:
		var sd := float(d)
		var j := MeshInstance3D.new()
		j.mesh = cone
		j.material_override = mat
		j.position = Vector3(0, sd * (0.9 + length_s * 0.5), 0)
		if sd < 0.0:
			j.rotation_degrees = Vector3(180, 0, 0)
		jet_root.add_child(j)
	parent_node.add_child(jet_root)

func _add_star_corona(root: Node3D, c1: Color, c2: Color, scale_s: float) -> void:
	var tex: ImageTexture
	if _galaxy_tex_cache.has("_corona_halo"):
		tex = _galaxy_tex_cache["_corona_halo"]
	else:
		var size := 96
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var half := float(size) * 0.5
		for y in range(size):
			for x in range(size):
				var dx := (float(x) - half) / half
				var dy := (float(y) - half) / half
				var r := sqrt(dx * dx + dy * dy)
				var a := exp(-r * r * 5.2) * (1.0 - smoothstep(0.55, 0.98, r))
				img.set_pixel(x, y, Color(1.0, 1.0, 1.0, clampf(a * 0.65, 0.0, 1.0)))
		tex = ImageTexture.create_from_image(img)
		_galaxy_tex_cache["_corona_halo"] = tex
	var glow_c := c1.lerp(c2, 0.35)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(glow_c.r, glow_c.g, glow_c.b, 0.72)
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.no_depth_test = false
	var q := QuadMesh.new()
	var s := scale_s * 2.8
	q.size = Vector2(s, s)
	var corona := MeshInstance3D.new()
	corona.mesh = q
	corona.material_override = mat
	root.add_child(corona)

func _add_disk_ring(root: Node3D, is_bh: bool, is_uranus: bool, tint: Color) -> void:
	var cache_key := "%s_%s_%s" % [str(is_bh), str(is_uranus), tint.to_html(false)]
	var tex: ImageTexture
	if _disk_ring_tex_cache.has(cache_key):
		tex = _disk_ring_tex_cache[cache_key]
	else:
		var size := 128
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var half := float(size) * 0.5
		for y in range(size):
			for x in range(size):
				var dx := (float(x) - half) / half
				var dy := (float(y) - half) / half
				var r := sqrt(dx * dx + dy * dy)
				var col := Color(0, 0, 0, 0)
				if is_uranus and r > 0.62 and r < 0.94:
					var ring := 0.5 + 0.5 * sin(r * 95.0)
					col = Color(0.72, 0.88, 0.96, ring * 0.35)
				elif not is_uranus and r > 0.46 and r < 0.96:
					if not (r > 0.74 and r < 0.78):
						var band := 0.55 + 0.45 * sin(r * 140.0)
						col = Color(0.78, 0.70, 0.54, band * 0.78)
				img.set_pixel(x, y, col)
		tex = ImageTexture.create_from_image(img)
		_disk_ring_tex_cache[cache_key] = tex
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var plane := QuadMesh.new()
	var d_scale := 4.1 if is_uranus else 4.6
	plane.size = Vector2(d_scale, d_scale)
	var inst := MeshInstance3D.new()
	inst.mesh = plane
	inst.material_override = mat
	inst.rotation_degrees = Vector3(-90, 0, 0)
	root.add_child(inst)

func _add_galaxy_disc(root: Node3D, body: Dictionary) -> void:
	var bid: String = body["id"]
	var c1: Color = body["color"]
	var c2: Color = body["secondary_color"]
	var tex: ImageTexture
	if _galaxy_tex_cache.has(bid):
		tex = _galaxy_tex_cache[bid]
	else:
		var size := 128
		var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
		var half := float(size) * 0.5
		for y in range(size):
			for x in range(size):
				var dx := (float(x) - half) / half
				var dy := (float(y) - half) / half
				if bid == "m104":
					dy *= 2.8
				var r := sqrt(dx * dx + dy * dy)
				if r >= 0.98 and bid != "m51":
					img.set_pixel(x, y, Color(0, 0, 0, 0))
					continue
				var ang := atan2(dy, dx)
				var core := exp(-r * r * (5.5 if bid == "ic1101" else (10.0 if bid == "m104" else 14.0)))
				var arm := 0.0
				var alpha := 0.0
				var col := c1.lerp(c2, clampf(r * 1.1, 0.0, 1.0))
				match bid:
					"ic1101":
						alpha = clampf(exp(-r * r * 3.8) * 0.95, 0.0, 1.0)
					"m104":
						var dust_cut := exp(-absf(dy) * 18.0) * 0.72 if absf(dx) < 0.85 else 0.0
						alpha = clampf((core + exp(-r * 2.8) * 0.45) * (1.0 - dust_cut), 0.0, 1.0)
					"lmc":
						var bar := exp(-pow(dx * 0.6 + dy * 0.8, 2.0) * 12.0 - r * r * 3.0)
						var clumps := 0.5 + 0.5 * sin(dx * 16.0 + sin(dy * 11.0)) * cos(dy * 14.0)
						alpha = clampf((bar * 0.65 + (1.0 - r) * clumps * 0.55) * smoothstep(0.95, 0.35, r), 0.0, 1.0)
						if clumps > 0.78 and r < 0.65:
							col = col.lerp(Color(1.0, 0.38, 0.65), 0.55)
					"m33":
						arm = pow(0.5 + 0.5 * cos(3.0 * (ang - r * 3.4)), 1.8)
						var knots := 0.5 + 0.5 * sin(r * 22.0 + ang * 7.0)
						alpha = clampf(core * 0.7 + (1.0 - r) * (0.25 + arm * 0.75) * 0.62, 0.0, 1.0)
						if arm > 0.72 and knots > 0.75:
							col = col.lerp(Color(1.0, 0.45, 0.72), 0.45)
					"m51":
						arm = pow(0.5 + 0.5 * cos(2.0 * (ang - r * 5.2)), 2.8)
						var rc := sqrt(pow(dx - 0.56, 2.0) + pow(dy - 0.24, 2.0))
						var comp := exp(-rc * rc * 24.0) * 0.85
						alpha = clampf((core + (1.0 - minf(1.0, r)) * arm * 0.75) * smoothstep(0.98, 0.45, r) + comp, 0.0, 1.0)
						if comp > 0.15:
							col = col.lerp(Color(1.0, 0.88, 0.68), clampf(comp, 0.0, 1.0))
					"milky_way":
						var bar_mw := exp(-pow(dy * cos(0.5) - dx * sin(0.5), 2.0) * 28.0 - r * r * 4.5) * 0.6
						arm = pow(0.5 + 0.5 * cos(4.0 * (ang - r * 4.4)), 2.2)
						alpha = clampf(core + bar_mw + (1.0 - r) * arm * 0.58, 0.0, 1.0)
					_:
						arm = pow(0.5 + 0.5 * cos(2.0 * (ang - r * 6.2)) * 0.7 + 0.3 * cos(3.0 * ang), 2.0)
						alpha = clampf(core * 1.15 + (1.0 - r) * (0.18 + arm * 0.65) * 0.65, 0.0, 1.0)
				img.set_pixel(x, y, Color(col.r, col.g, col.b, alpha))
		tex = ImageTexture.create_from_image(img)
		_galaxy_tex_cache[bid] = tex
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q := QuadMesh.new()
	var gs := 2.5 if bid in ["ic1101", "m51"] else 2.0
	q.size = Vector2(gs, gs)
	var inst := MeshInstance3D.new()
	inst.mesh = q
	inst.material_override = mat
	inst.rotation_degrees = Vector3(-90, 0, 0)
	root.add_child(inst)

func _build_stations() -> void:
	for st in EliteSystems.get_stations():
		var st_node := EliteSystems.build_station_node(st)
		add_child(st_node)
		station_nodes[st["id"]] = st_node

func compress_to_scene(rel64: PackedFloat64Array) -> Dictionary:
	var dist := UniverseCatalog.v64_len(rel64)
	var max_d := 420_000.0
	if dist <= max_d or dist < 1e-6:
		return {"pos": UniverseCatalog.v64_to_vec3(rel64), "scale": 1.0}
	var comp_d := max_d * (1.0 + 0.045 * log(dist / max_d) / log(10.0))
	var sf := comp_d / dist
	return {"pos": UniverseCatalog.v64_to_vec3(UniverseCatalog.v64_scale(rel64, sf)), "scale": sf}

func update_camera_mode() -> void:
	if is_walking:
		main_camera.position = Vector3.ZERO
		camera_boom.rotation = Vector3.ZERO
		ship_visual.visible = false
	elif is_free_camera:
		main_camera.position = Vector3.ZERO
		camera_boom.rotation = Vector3.ZERO
		ship_visual.visible = false
	elif is_third_person:
		main_camera.position = Vector3(0, 1.35, orbit_distance)
		ship_visual.visible = true
	else:
		main_camera.position = Vector3(0, 0.55, -1.1)
		camera_boom.rotation = Vector3.ZERO
		ship_visual.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if is_main_menu or has_docked_station:
		return
	if event is InputEventScreenDrag:
		_handle_look_drag(event.relative.x, event.relative.y)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_handle_look_drag(event.relative.x, event.relative.y)
	elif event is InputEventMouseButton and is_third_person and not is_free_camera and not is_walking:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			orbit_distance = clampf(orbit_distance * 0.9, 6.5, 45.0)
			update_camera_mode()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			orbit_distance = clampf(orbit_distance * 1.1, 6.5, 45.0)
			update_camera_mode()

func _handle_look_drag(dx: float, dy: float) -> void:
	if is_walking:
		eva_yaw -= dx * 0.0055
		eva_pitch = clampf(eva_pitch - dy * 0.0055, -1.25, 1.30)
	elif is_free_camera:
		var qy := Quaternion(Vector3.UP, -dx * 0.0045)
		var qp := Quaternion(Vector3.RIGHT, -dy * 0.0045)
		ship_orient = (ship_orient * qy * qp).normalized()
	elif is_third_person:
		orbit_yaw -= dx * 0.006
		orbit_pitch = clampf(orbit_pitch - dy * 0.006, -1.35, 1.35)
		update_camera_mode()

func _orientation_from_fwd_up(fwd: Vector3, up: Vector3) -> Quaternion:
	var f := fwd.normalized() if fwd.length_squared() > 1e-12 else Vector3.FORWARD
	var u := up.normalized() if up.length_squared() > 1e-12 else Vector3.UP
	var r := f.cross(u)
	if r.length_squared() < 1e-10:
		var ref := Vector3.UP if absf(u.y) < 0.9 else Vector3.RIGHT
		r = ref.cross(u).normalized()
	else:
		r = r.normalized()
	u = r.cross(f).normalized()
	var b := Basis(r, u, -f)
	return b.get_rotation_quaternion().normalized()

func align_to_target() -> void:
	var t_pos := UniverseCatalog.get_body_pos(target_body, sim_time_s)
	var d := UniverseCatalog.v64_norm(UniverseCatalog.v64_sub(t_pos, ship_pos64), UniverseCatalog.v64(0, 0, -1))
	var dir_v := UniverseCatalog.v64_to_vec3(d).normalized()
	ship_orient = _orientation_from_fwd_up(dir_v, Vector3.UP)
	orbit_yaw = 0.0
	orbit_pitch = -0.16
	angular_vel_yaw = 0.0
	angular_vel_pitch = 0.0
	update_camera_mode()

func align_to_station(st: Dictionary) -> void:
	var st_pos := EliteSystems.get_station_pos(st, sim_time_s, {})
	var d := UniverseCatalog.v64_norm(UniverseCatalog.v64_sub(st_pos, ship_pos64), UniverseCatalog.v64(0, 0, -1))
	ship_orient = _orientation_from_fwd_up(UniverseCatalog.v64_to_vec3(d), Vector3.UP)
	orbit_yaw = 0.0
	orbit_pitch = -0.14
	angular_vel_yaw = 0.0
	angular_vel_pitch = 0.0
	update_camera_mode()

func warp_to_body(body: Dictionary) -> void:
	if is_walking:
		board_ship()
	docked_station = {}; has_docked_station = false; docked_station_id = ""; is_fss_open = false
	target_body = body
	throttle = 0.0
	ship_vel64 = UniverseCatalog.v64()
	is_landed = false
	last_terrain_alt = -1.0
	active_surface_body_id = ""
	active_collision = null
	last_tracked_body_id = ""
	has_props_for_anchor = false
	eva_scanner_open = false
	terrain_root.visible = false

	var b_pos := UniverseCatalog.get_body_pos(body, sim_time_s)
	var orbit_d: float = body["radius_m"] * 2.9
	if body["is_black_hole"]: orbit_d = max(body["radius_m"] * 8.5, 50_000_000.0)
	elif body["is_galaxy"]: orbit_d = body["radius_m"] * 2.4
	elif body["radius_m"] < 100_000.0: orbit_d = max(body["radius_m"] * 4.5, 120_000.0)

	var off := Vector3(0.6, 0.25, 0.75).normalized()
	if body["is_galaxy"] or body["is_black_hole"]:
		off = Vector3(0.45, 0.62, 0.64).normalized()
	elif not body["is_star"] and UniverseCatalog.v64_len(b_pos) > 1_000.0:
		var to_sun := UniverseCatalog.v64_to_vec3(UniverseCatalog.v64_norm(UniverseCatalog.v64_scale(b_pos, -1.0)))
		var right := Vector3.UP.cross(to_sun).normalized()
		off = (to_sun * 0.74 + right * 0.62 + Vector3(0, 0.20, 0)).normalized()

	ship_pos64 = UniverseCatalog.v64_add(b_pos, UniverseCatalog.v64_scale(UniverseCatalog.v64(off.x, off.y, off.z), orbit_d))
	align_to_target()

func warp_to_surface_approach(body: Dictionary) -> void:
	if not body["is_landable"]:
		return
	if is_walking:
		board_ship()
	docked_station = {}; has_docked_station = false; docked_station_id = ""; is_fss_open = false
	target_body = body
	throttle = 0.0
	ship_vel64 = UniverseCatalog.v64()
	is_landed = false
	auto_speed = true
	last_terrain_alt = -1.0
	active_surface_body_id = ""
	active_collision = null
	last_tracked_body_id = ""
	has_props_for_anchor = false
	eva_scanner_open = false

	var b_pos := UniverseCatalog.get_body_pos(body, sim_time_s)
	var rot := UniverseCatalog.planet_quat(body, sim_time_s)
	var inv_rot := rot.inverse()
	var off := SurfaceTerrain.find_scenic_approach_dir(body, b_pos, inv_rot)
	var samp := SurfaceTerrain.sample_terrain(inv_rot * off, body)
	var g_h: float = max(0.0, samp["height"]) if body["is_habitable"] else samp["height"]

	ship_pos64 = UniverseCatalog.v64_add(b_pos, UniverseCatalog.v64_scale(UniverseCatalog.v64(off.x, off.y, off.z), body["radius_m"] + g_h + 4_500.0))
	var to_sun := Vector3(-b_pos[0], -b_pos[1], -b_pos[2]).normalized() if UniverseCatalog.v64_len_sq(b_pos) > 1e6 else Vector3(0.6, 0.25, 0.75).normalized()
	var sun_h := (to_sun - off * to_sun.dot(off)).normalized()
	var side := off.cross(sun_h).normalized()
	var h_fwd := (sun_h * 0.55 + side * 0.83).normalized()
	var look_fwd := (h_fwd * cos(0.28) - off * sin(0.28)).normalized()
	ship_orient = _orientation_from_fwd_up(look_fwd, off)
	orbit_yaw = 0.0; orbit_pitch = -0.16
	update_camera_mode()

func warp_to_station(st: Dictionary) -> void:
	if is_walking:
		board_ship()
	docked_station = {}; has_docked_station = false; docked_station_id = ""; is_fss_open = false
	throttle = 0.0
	ship_vel64 = UniverseCatalog.v64()
	is_landed = false
	last_terrain_alt = -1.0
	active_surface_body_id = ""
	active_collision = null
	last_tracked_body_id = ""
	terrain_root.visible = false
	target_body = UniverseCatalog.find_body(st["parent_body_id"])
	var st_pos := EliteSystems.get_station_pos(st, sim_time_s, {})
	var off := Vector3(0.40, 0.25, 0.88).normalized()
	ship_pos64 = UniverseCatalog.v64_add(st_pos, UniverseCatalog.v64_scale(UniverseCatalog.v64(off.x, off.y, off.z), 1_400.0))
	align_to_station(st)

func toggle_free_camera() -> void:
	if is_walking:
		return
	is_free_camera = not is_free_camera
	ship_vel64 = UniverseCatalog.v64()
	update_camera_mode()

func level_to_horizon() -> void:
	var near := _find_nearest_landable()
	var b_pos: PackedFloat64Array = near["pos"]
	var up_v := UniverseCatalog.v64_to_vec3(UniverseCatalog.v64_norm(UniverseCatalog.v64_sub(ship_pos64, b_pos))).normalized()
	var fwd := ship_orient * Vector3.FORWARD
	var horiz := (fwd - up_v * fwd.dot(up_v)).normalized()
	ship_orient = _orientation_from_fwd_up(horiz, up_v)
	angular_vel_yaw = 0.0; angular_vel_pitch = 0.0; orbit_yaw = 0.0; orbit_pitch = -0.16
	update_camera_mode()

func land_at_current_spot() -> void:
	if is_walking or is_free_camera:
		return
	var near := _find_nearest_landable()
	var body: Dictionary = near["body"]
	var b_pos: PackedFloat64Array = near["pos"]
	var dist_s: float = near["surf_dist"]
	var rot := UniverseCatalog.planet_quat(body, sim_time_s)
	var up64 := UniverseCatalog.v64_norm(UniverseCatalog.v64_sub(ship_pos64, b_pos))
	var g := _ground_sample_at(ship_pos64, body, b_pos, rot, rot.inverse())
	var radar: float = maxf(0.0, dist_s - float(g["height"]))
	if g["is_water"] or radar >= 1_800.0:
		return
	ship_pos64 = UniverseCatalog.v64_add(b_pos, UniverseCatalog.v64_scale(up64, body["radius_m"] + g["height"] + 1.35))
	level_to_horizon()
	throttle = 0.0
	ship_vel64 = UniverseCatalog.v64()
	has_props_for_anchor = false
	is_landed = true
	landing_gear_node.visible = true
	target_body = body

func enter_walking_mode() -> void:
	if not is_landed or is_walking:
		return
	var near := _find_nearest_landable()
	var body: Dictionary = near["body"]
	var b_pos: PackedFloat64Array = near["pos"]
	var rot := UniverseCatalog.planet_quat(body, sim_time_s)
	var inv_rot := rot.inverse()
	parked_ship_body_id = body["id"]
	parked_ship_local_pos64 = UniverseCatalog.rotate_body_world_to_local64(body, sim_time_s, UniverseCatalog.v64_sub(ship_pos64, b_pos))
	parked_ship_local_orient = (inv_rot * ship_orient).normalized()
	parked_ship_node.visible = true

	var up_v := UniverseCatalog.v64_to_vec3(UniverseCatalog.v64_norm(UniverseCatalog.v64_sub(ship_pos64, b_pos))).normalized()
	var s_right := ship_orient * Vector3.RIGHT
	var s_fwd := ship_orient * Vector3.FORWARD
	var tan_r := (s_right - up_v * s_right.dot(up_v)).normalized()
	var p_spot := UniverseCatalog.v64_add(ship_pos64, UniverseCatalog.v64(tan_r.x * 7.0, tan_r.y * 7.0, tan_r.z * 7.0))
	var p_up64 := UniverseCatalog.v64_norm(UniverseCatalog.v64_sub(p_spot, b_pos))
	var g := _ground_sample_at(p_spot, body, b_pos, rot, inv_rot)
	ship_pos64 = UniverseCatalog.v64_add(b_pos, UniverseCatalog.v64_scale(p_up64, body["radius_m"] + g["height"] + 1.85))

	eva_ref_fwd_local = inv_rot * ((s_fwd * 0.35 - tan_r * 0.90).normalized())
	eva_yaw = 0.0; eva_pitch = -0.05; eva_vertical_vel = 0.0; eva_height_above_ground = 1.85; eva_walk_phase = 0.0
	is_walking = true; is_free_camera = false; eva_sprinting = false; eva_jetpack_active = false
	eva_scanner_open = false; eva_scan_report = {}
	eva_jetpack_fuel = 1.0; eva_ship_dist_text = "7 м"; eva_temp_text = "%d °C" % body["mean_temp_c"]
	has_props_for_anchor = false
	throttle = 0.0; ship_vel64 = UniverseCatalog.v64(); target_body = body
	update_camera_mode()

func board_ship() -> void:
	if not is_walking:
		return
	parked_ship_node.visible = false
	if parked_ship_body_id != "":
		var b := UniverseCatalog.find_body(parked_ship_body_id)
		var b_pos := UniverseCatalog.get_body_pos(b, sim_time_s)
		var rot := UniverseCatalog.planet_quat(b, sim_time_s)
		var w_off64 := UniverseCatalog.rotate_body_local_to_world64(b, sim_time_s, parked_ship_local_pos64)
		ship_pos64 = UniverseCatalog.v64_add(b_pos, w_off64)
		ship_orient = (rot * parked_ship_local_orient).normalized()
		target_body = b
	is_walking = false; eva_sprinting = false; eva_jetpack_active = false
	eva_scanner_open = false; eva_scan_report = {}
	eva_jetpack_fuel = 1.0; has_props_for_anchor = false
	is_landed = true; throttle = 0.0; ship_vel64 = UniverseCatalog.v64()
	update_camera_mode()

func eva_jump() -> void:
	if is_walking and eva_height_above_ground <= 2.05:
		eva_vertical_vel = 5.2

func takeoff_from_surface() -> void:
	if is_walking:
		board_ship()
	var near := _find_nearest_landable()
	var up_v := UniverseCatalog.v64_to_vec3(UniverseCatalog.v64_norm(UniverseCatalog.v64_sub(ship_pos64, near["pos"]))).normalized()
	is_landed = false; throttle = 0.45; auto_speed = true
	ship_vel64 = UniverseCatalog.v64(up_v.x * 65.0, up_v.y * 65.0, up_v.z * 65.0)
	ship_pos64 = UniverseCatalog.v64_add(ship_pos64, UniverseCatalog.v64(up_v.x * 5.0, up_v.y * 5.0, up_v.z * 5.0))
	var fwd := ship_orient * Vector3.FORWARD
	var horiz := (fwd - up_v * fwd.dot(up_v)).normalized()
	ship_orient = _orientation_from_fwd_up((horiz * cos(0.26) + up_v * sin(0.26)).normalized(), up_v)

func toggle_surface_scanner() -> void:
	eva_scanner_open = not eva_scanner_open
	if not eva_scanner_open:
		eva_scan_report = {}
		return
	var near := _find_nearest_landable()
	var body: Dictionary = near["body"]
	var rot := UniverseCatalog.planet_quat(body, sim_time_s)
	var inv_rot := rot.inverse()
	var up_v := UniverseCatalog.v64_to_vec3(UniverseCatalog.v64_norm(UniverseCatalog.v64_sub(ship_pos64, near["pos"]))).normalized()
	var g := _ground_sample_at(ship_pos64, body, near["pos"], rot, inv_rot)
	eva_scan_report = SurfaceTerrain.surface_scan_report(body, inv_rot * up_v, g["height"])

	var rec_id: String = "eva_%s" % body["id"]
	var scans: Array = pilot_profile["scans"]
	var found := false
	for r in scans:
		if r["id"] == rec_id:
			found = true; break
	if not found:
		var payout := int(round(3_000.0 * EliteSystems.fss_multiplier(pilot_profile)))
		scans.append({"id": rec_id, "body_id": body["id"], "body_name": body["name"], "scan_type": "Поверхностная геология (EVA)", "payout_credits": payout, "sold": false})
		EliteSystems.save_profile(pilot_profile)

func dock_at_nearby_station() -> void:
	if is_walking or is_landed or not has_nearby_station:
		return
	docked_station = nearby_station
	has_docked_station = true
	docked_station_id = nearby_station["id"]
	is_fss_open = false
	throttle = 0.0
	ship_vel64 = UniverseCatalog.v64()
	align_to_station(docked_station)

func undock_from_station() -> void:
	if has_docked_station:
		var st_pos := EliteSystems.get_station_pos(docked_station, sim_time_s, {})
		var out := UniverseCatalog.v64_norm(UniverseCatalog.v64_sub(ship_pos64, st_pos), UniverseCatalog.v64(0, 0, 1))
		ship_pos64 = UniverseCatalog.v64_add(st_pos, UniverseCatalog.v64_scale(out, 900.0))
		ship_vel64 = UniverseCatalog.v64_scale(out, 40.0)
	docked_station = {}; has_docked_station = false; docked_station_id = ""; throttle = 0.0

func buy_commodity(item: Dictionary, qty: int) -> void:
	if not has_docked_station or qty <= 0:
		return
	var price := EliteSystems.commodity_price(item["id"], item["base_price"], docked_station["economy"])
	var free_space := EliteSystems.cargo_capacity_tons(pilot_profile) - EliteSystems.used_cargo_tons(pilot_profile)
	var max_aff: int = int(pilot_profile["credits"]) / maxi(1, price)
	var count := mini(qty, mini(free_space, max_aff))
	if count <= 0:
		return
	pilot_profile["credits"] = int(pilot_profile["credits"]) - count * price
	var cargo: Dictionary = pilot_profile["cargo"]
	cargo[item["id"]] = int(cargo.get(item["id"], 0)) + count
	EliteSystems.save_profile(pilot_profile)

func sell_commodity(item: Dictionary, qty: int) -> void:
	if not has_docked_station or qty <= 0:
		return
	var cargo: Dictionary = pilot_profile["cargo"]
	var held := int(cargo.get(item["id"], 0))
	var count := mini(qty, held)
	if count <= 0:
		return
	var price := EliteSystems.commodity_price(item["id"], item["base_price"], docked_station["economy"])
	pilot_profile["credits"] = int(pilot_profile["credits"]) + count * price
	if held - count > 0:
		cargo[item["id"]] = held - count
	else:
		cargo.erase(item["id"])
	EliteSystems.save_profile(pilot_profile)

func sell_all_cartographics() -> void:
	var total := 0
	for r in pilot_profile["scans"]:
		if not r["sold"]:
			total += int(r["payout_credits"])
			r["sold"] = true
	if total > 0:
		pilot_profile["credits"] = int(pilot_profile["credits"]) + total
		EliteSystems.save_profile(pilot_profile)

func upgrade_cargo() -> void:
	var lvl := int(pilot_profile["cargo_level"])
	if lvl >= EliteSystems.CARGO_COSTS.size(): return
	var cost: int = EliteSystems.CARGO_COSTS[lvl]
	if int(pilot_profile["credits"]) < cost: return
	pilot_profile["credits"] = int(pilot_profile["credits"]) - cost
	pilot_profile["cargo_level"] = lvl + 1
	EliteSystems.save_profile(pilot_profile)

func upgrade_fss() -> void:
	var lvl := int(pilot_profile["fss_level"])
	if lvl >= EliteSystems.FSS_COSTS.size(): return
	var cost: int = EliteSystems.FSS_COSTS[lvl]
	if int(pilot_profile["credits"]) < cost: return
	pilot_profile["credits"] = int(pilot_profile["credits"]) - cost
	pilot_profile["fss_level"] = lvl + 1
	EliteSystems.save_profile(pilot_profile)

func upgrade_jetpack() -> void:
	var lvl := int(pilot_profile["jetpack_level"])
	if lvl >= EliteSystems.JETPACK_COSTS.size(): return
	var cost: int = EliteSystems.JETPACK_COSTS[lvl]
	if int(pilot_profile["credits"]) < cost: return
	pilot_profile["credits"] = int(pilot_profile["credits"]) - cost
	pilot_profile["jetpack_level"] = lvl + 1
	EliteSystems.save_profile(pilot_profile)

func auto_tune_fss() -> void:
	fss_frequency_mhz = EliteSystems.fss_frequency_mhz(target_body)
	last_fss_message = "Настройка на %s: %.1f МГц" % [target_body["name"], fss_frequency_mhz]

func perform_fss_scan() -> void:
	var tf := EliteSystems.fss_frequency_mhz(target_body)
	if absf(fss_frequency_mhz - tf) > 4.0:
		last_fss_message = "Настройте частоту на сигнал цели (±4 МГц)"
		return
	var rec_id: String = "fss_%s" % target_body["id"]
	for r in pilot_profile["scans"]:
		if r["id"] == rec_id:
			last_fss_message = "%s: данные уже записаны" % target_body["name"]
			return
	var payout := int(round(float(EliteSystems.fss_base_payout(target_body)) * EliteSystems.fss_multiplier(pilot_profile)))
	pilot_profile["scans"].append({"id": rec_id, "body_id": target_body["id"], "body_name": target_body["name"], "scan_type": "FSS-спектроскопия (%s)" % target_body["type"], "payout_credits": payout, "sold": false})
	EliteSystems.save_profile(pilot_profile)
	last_fss_message = "Сканирование завершено: +%d CR (сдайте на станции)" % payout

func _find_nearest_landable() -> Dictionary:
	var best_b := target_body
	var best_pos := UniverseCatalog.v64()
	var best_d := 1e30
	for b in UniverseCatalog.get_bodies():
		if not b["is_landable"]:
			continue
		var pos := UniverseCatalog.get_body_pos(b, sim_time_s)
		var d := UniverseCatalog.v64_len(UniverseCatalog.v64_sub(ship_pos64, pos)) - float(b["radius_m"])
		if d < best_d:
			best_d = d; best_b = b; best_pos = pos
	return {"body": best_b, "pos": best_pos, "surf_dist": best_d}

func _ground_sample_at(w_pos64: PackedFloat64Array, body: Dictionary, b_pos64: PackedFloat64Array, rot: Quaternion, inv_rot: Quaternion) -> Dictionary:
	var up_v := UniverseCatalog.v64_to_vec3(UniverseCatalog.v64_norm(UniverseCatalog.v64_sub(w_pos64, b_pos64)))
	var samp := SurfaceTerrain.sample_terrain(inv_rot * up_v, body)
	if active_surface_body_id == body["id"] and active_collision != null:
		var ch: Variant = active_collision.sample_height(w_pos64, rot, b_pos64)
		if ch != null:
			return {"height": float(ch), "is_water": samp["is_water"]}
	var h: float = max(0.0, samp["height"]) if body["is_habitable"] else samp["height"]
	return {"height": h, "is_water": samp["is_water"]}

func _combined_stick() -> Vector2:
	var v := stick_input
	var kx := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var ky := Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	if absf(kx) > 0.05 or absf(ky) > 0.05:
		v = Vector2(kx, ky).limit_length(1.0)
	return v

func _process(delta: float) -> void:
	var real_dt := minf(0.05, delta)
	frame_counter += 1

	if is_main_menu:
		ship_vel64 = UniverseCatalog.v64()
		orbit_yaw += real_dt * 0.07
		if is_third_person and not is_free_camera and not is_walking:
			camera_boom.rotation = Vector3(orbit_pitch, orbit_yaw, 0.0)

	var warp: float = 0.0 if is_time_paused else (TIME_WARP_STEPS[time_warp_index]["mult"] * (-1.0 if is_time_reversed else 1.0))
	sim_time_s += real_dt * warp

	var pos_cache: Dictionary = {}
	var bodies := UniverseCatalog.get_bodies()
	var near_b := bodies[3]
	var near_pos := UniverseCatalog.v64()
	var near_dist_c := 1e30
	var near_surf_dist := 1e30

	for b in bodies:
		var bp := UniverseCatalog.get_body_pos(b, sim_time_s, pos_cache)
		var dc := UniverseCatalog.v64_len(UniverseCatalog.v64_sub(bp, ship_pos64))
		if b["is_galaxy"] and dc < b["radius_m"] * 1.15:
			continue
		var sd := maxf(0.0, dc - b["radius_m"])
		if sd < near_surf_dist:
			near_surf_dist = sd; near_dist_c = dc; near_b = b; near_pos = bp

	var near_rot := UniverseCatalog.planet_quat(near_b, sim_time_s)
	var inv_near_rot := near_rot.inverse()
	if not near_b["is_star"] and near_surf_dist < 240_000.0 and not has_docked_station:
		if last_tracked_body_id == near_b["id"]:
			var lw := 1.0 if (is_landed or is_walking or near_surf_dist < 120_000.0) else clampf((240_000.0 - near_surf_dist) / 120_000.0, 0.0, 1.0)
			var orb_d := UniverseCatalog.v64_scale(UniverseCatalog.v64_sub(near_pos, last_tracked_pos64), lw)
			ship_pos64 = UniverseCatalog.v64_add(ship_pos64, orb_d)
			var spin_q := (near_rot * last_tracked_rot.inverse()).normalized()
			if lw > 0.99:
				var rel_s := UniverseCatalog.v64_sub(ship_pos64, near_pos)
				var rel_loc64 := UniverseCatalog.rotate_body_world_to_local64(near_b, last_tracked_time_s, rel_s)
				ship_pos64 = UniverseCatalog.v64_add(near_pos, UniverseCatalog.rotate_body_local_to_world64(near_b, sim_time_s, rel_loc64))
				if not is_walking:
					ship_orient = (spin_q * ship_orient).normalized()
		last_tracked_body_id = near_b["id"]
		last_tracked_pos64 = near_pos
		last_tracked_rot = near_rot
		last_tracked_time_s = sim_time_s
	else:
		last_tracked_body_id = ""

	var last_is_water := false
	var up_w64 := UniverseCatalog.v64_norm(UniverseCatalog.v64_sub(ship_pos64, near_pos))
	if near_b["is_landable"] and near_surf_dist < 350_000.0:
		var g := _ground_sample_at(ship_pos64, near_b, near_pos, near_rot, inv_near_rot)
		last_is_water = g["is_water"]
		current_ground_h = g["height"]
	else:
		current_ground_h = 0.0

	var pre_radar := maxf(0.0, near_surf_dist - current_ground_h)
	var auto_max_mps: float = maxf(8.0, pre_radar * 0.40) if (near_b["is_landable"] and pre_radar < 2_000.0) else maxf(50.0, maxf(10.0, near_surf_dist) * 0.45)
	var eff_max_speed: float = auto_max_mps if auto_speed else SPEED_STEPS[speed_index]["mps"]

	var ctrl_stick := _combined_stick()
	if is_walking:
		if Input.is_action_just_pressed("jump"):
			eva_jump()
		var sprinting_now := eva_sprinting or Input.is_action_pressed("sprint")
		var up_v := UniverseCatalog.v64_to_vec3(up_w64).normalized()
		var ref_w := (near_rot * eva_ref_fwd_local)
		var ref_proj := (ref_w - up_v * ref_w.dot(up_v)).normalized()
		var w_fwd := (Quaternion(up_v, eva_yaw) * ref_proj).normalized()
		var w_right := w_fwd.cross(up_v).normalized()
		var move_v := (w_fwd * (-ctrl_stick.y) + w_right * ctrl_stick.x) * (14.0 if sprinting_now else 5.8)
		ship_pos64 = UniverseCatalog.v64_add(ship_pos64, UniverseCatalog.v64(move_v.x * real_dt, move_v.y * real_dt, move_v.z * real_dt))

		var g_surf: float = maxf(0.25, near_b["surface_gravity_g"] * 9.80665)
		var drain_rate := EliteSystems.jetpack_drain_per_sec(pilot_profile)
		if eva_jetpack_active and eva_jetpack_fuel > 0.01:
			eva_vertical_vel = minf(22.0, eva_vertical_vel + (g_surf + 9.5) * real_dt)
			eva_jetpack_fuel = maxf(0.0, eva_jetpack_fuel - real_dt * drain_rate)
			if eva_jetpack_fuel <= 0.01:
				eva_jetpack_active = false
		else:
			eva_vertical_vel -= g_surf * real_dt
			if eva_height_above_ground <= 1.86:
				eva_jetpack_fuel = minf(1.0, eva_jetpack_fuel + real_dt * 0.35)

		eva_height_above_ground = clampf(eva_height_above_ground + eva_vertical_vel * real_dt, 1.85, 450.0)
		if eva_height_above_ground <= 1.85:
			eva_vertical_vel = 0.0

		up_w64 = UniverseCatalog.v64_norm(UniverseCatalog.v64_sub(ship_pos64, near_pos))
		var gs := _ground_sample_at(ship_pos64, near_b, near_pos, near_rot, inv_near_rot)
		last_is_water = gs["is_water"]
		current_ground_h = gs["height"]
		var h_spd := move_v.length()
		eva_walk_phase = (eva_walk_phase + real_dt * (14.0 if sprinting_now else 9.5)) if (h_spd > 0.3 and eva_height_above_ground <= 1.86) else 0.0
		var bob := sin(eva_walk_phase) * (0.11 if sprinting_now else 0.07) if eva_walk_phase > 0.0 else 0.0
		ship_pos64 = UniverseCatalog.v64_add(near_pos, UniverseCatalog.v64_scale(up_w64, near_b["radius_m"] + current_ground_h + eva_height_above_ground + bob))
		ship_vel64 = UniverseCatalog.v64(move_v.x, move_v.y, move_v.z)

		var q_p := Quaternion(w_right, eva_pitch)
		ship_orient = _orientation_from_fwd_up((q_p * w_fwd).normalized(), (q_p * up_v).normalized())
		ship_visual.rotation = Vector3.ZERO
	elif is_landed:
		if throttle > 0.15 or (is_free_camera and ctrl_stick.length() > 0.1):
			is_landed = false
			var up_l := UniverseCatalog.v64_scale(up_w64, 25.0 if is_free_camera else 55.0)
			ship_vel64 = up_l
			ship_pos64 = UniverseCatalog.v64_add(ship_pos64, UniverseCatalog.v64_scale(up_w64, 4.0))
		else:
			ship_vel64 = UniverseCatalog.v64()
			var y_rate := -ctrl_stick.x * 0.9
			if absf(y_rate) > 0.01:
				ship_orient = (Quaternion(UniverseCatalog.v64_to_vec3(up_w64), y_rate * real_dt) * ship_orient).normalized()
			if is_third_person:
				camera_boom.rotation = Vector3(orbit_pitch, orbit_yaw, 0.0)
	elif not has_docked_station and not is_main_menu:
		var fwd_v := ship_orient * Vector3.FORWARD
		var right_v := ship_orient * Vector3.RIGHT
		if is_free_camera:
			var m_f := -ctrl_stick.y + throttle
			var d_vel := (fwd_v * m_f + right_v * ctrl_stick.x) * eff_max_speed
			var d64 := UniverseCatalog.v64(d_vel.x, d_vel.y, d_vel.z)
			ship_vel64 = UniverseCatalog.v64_add(ship_vel64, UniverseCatalog.v64_scale(UniverseCatalog.v64_sub(d64, ship_vel64), minf(1.0, real_dt * 6.0)))
			ship_visual.rotation = Vector3.ZERO
		else:
			angular_vel_yaw = lerpf(angular_vel_yaw, -ctrl_stick.x * 1.45, minf(1.0, real_dt * 6.5))
			angular_vel_pitch = lerpf(angular_vel_pitch, -ctrl_stick.y * 1.15, minf(1.0, real_dt * 6.5))
			if absf(angular_vel_yaw) > 0.0001 or absf(angular_vel_pitch) > 0.0001:
				var qy := Quaternion(Vector3.UP, angular_vel_yaw * real_dt)
				var qp := Quaternion(Vector3.RIGHT, angular_vel_pitch * real_dt)
				ship_orient = (ship_orient * qy * qp).normalized()
			ship_visual.rotation.z = lerpf(ship_visual.rotation.z, angular_vel_yaw * 0.32, minf(1.0, real_dt * 8.0))
			ship_visual.rotation.x = lerpf(ship_visual.rotation.x, angular_vel_pitch * 0.18, minf(1.0, real_dt * 8.0))
			if is_third_person:
				camera_boom.rotation = Vector3(orbit_pitch - angular_vel_pitch * 0.10, orbit_yaw - angular_vel_yaw * 0.14, 0.0)

			var des_v := fwd_v * (eff_max_speed * throttle)
			var des64 := UniverseCatalog.v64(des_v.x, des_v.y, des_v.z)
			if flight_assist:
				ship_vel64 = UniverseCatalog.v64_add(ship_vel64, UniverseCatalog.v64_scale(UniverseCatalog.v64_sub(des64, ship_vel64), minf(1.0, real_dt * 3.5)))
			else:
				if throttle > 0.001:
					ship_vel64 = UniverseCatalog.v64_add(ship_vel64, UniverseCatalog.v64_scale(des64, 0.25 * real_dt))
				if not near_b["is_star"] and near_surf_dist < 120_000.0:
					var g_acc: float = (UniverseCatalog.G_CONST * float(near_b["mass_kg"])) / maxf(1.0, near_dist_c * near_dist_c)
					ship_vel64 = UniverseCatalog.v64_sub(ship_vel64, UniverseCatalog.v64_scale(up_w64, g_acc * real_dt))

		var flight_dt := real_dt if (is_time_paused or is_free_camera) else (real_dt * maxf(1.0, absf(warp)))
		ship_pos64 = UniverseCatalog.v64_add(ship_pos64, UniverseCatalog.v64_scale(ship_vel64, flight_dt))

	if not is_walking and near_b["is_landable"] and near_surf_dist < 350_000.0 and not has_docked_station:
		up_w64 = UniverseCatalog.v64_norm(UniverseCatalog.v64_sub(ship_pos64, near_pos))
		var gc := _ground_sample_at(ship_pos64, near_b, near_pos, near_rot, inv_near_rot)
		last_is_water = gc["is_water"]
		current_ground_h = gc["height"]
		var clearance := 2.0 if is_free_camera else 1.35
		var min_d: float = near_b["radius_m"] + current_ground_h + clearance
		var cur_d := UniverseCatalog.v64_len(UniverseCatalog.v64_sub(ship_pos64, near_pos))
		if cur_d <= min_d:
			ship_pos64 = UniverseCatalog.v64_add(near_pos, UniverseCatalog.v64_scale(up_w64, min_d))
			var v_rad := UniverseCatalog.v64_dot(ship_vel64, up_w64)
			if v_rad < 0.0:
				ship_vel64 = UniverseCatalog.v64_sub(ship_vel64, UniverseCatalog.v64_scale(up_w64, v_rad))
			if not is_free_camera and throttle < 0.15 and not gc["is_water"]:
				is_landed = true; ship_vel64 = UniverseCatalog.v64()

	var eva_ship_dist := 0.0
	if is_walking and parked_ship_body_id != "":
		var pb := UniverseCatalog.find_body(parked_ship_body_id)
		var pb_pos: PackedFloat64Array = pos_cache[parked_ship_body_id] if pos_cache.has(parked_ship_body_id) else UniverseCatalog.get_body_pos(pb, sim_time_s, pos_cache)
		var p_rot := UniverseCatalog.planet_quat(pb, sim_time_s)
		var off_w64 := UniverseCatalog.rotate_body_local_to_world64(pb, sim_time_s, parked_ship_local_pos64)
		var sw_pos := UniverseCatalog.v64_add(pb_pos, off_w64)
		var rel_p := UniverseCatalog.v64_sub(sw_pos, ship_pos64)
		eva_ship_dist = UniverseCatalog.v64_len(rel_p)
		parked_ship_node.position = UniverseCatalog.v64_to_vec3(rel_p)
		parked_ship_node.quaternion = (p_rot * parked_ship_local_orient).normalized()

	ship_node.quaternion = ship_orient
	var actual_spd := UniverseCatalog.v64_len(ship_vel64)
	var upd_surf_dist: float = maxf(0.0, UniverseCatalog.v64_len(UniverseCatalog.v64_sub(ship_pos64, near_pos)) - float(near_b["radius_m"]))
	var radar_alt: float = maxf(0.0, upd_surf_dist - current_ground_h)
	landing_gear_node.visible = near_b["is_landable"] and (radar_alt < 180.0 or is_landed or is_walking)

	for fl in exhaust_nodes:
		fl.visible = throttle > 0.01 and not is_free_camera and not is_landed and not is_walking and not has_docked_station
		if fl.visible:
			fl.scale = Vector3(1.0, maxf(0.1, throttle * (1.0 + float(speed_index) * 0.2)), 1.0)

	var sun_dir := UniverseCatalog.v64_to_vec3(UniverseCatalog.v64_norm(UniverseCatalog.v64_scale(ship_pos64, -1.0), UniverseCatalog.v64(1, 0, 0))).normalized()
	if sun_dir.length_squared() > 1e-6:
		var l_up := Vector3.UP if absf(sun_dir.y) < 0.99 else Vector3.RIGHT
		sun_light.look_at(-sun_dir, l_up)

	var terrain_vis: bool = near_b["is_landable"] and upd_surf_dist < 240_000.0
	if terrain_vis:
		var anc_off64 := UniverseCatalog.rotate_body_local_to_world64(near_b, sim_time_s, last_terrain_anchor_local64)
		var anc_w64 := UniverseCatalog.v64_add(near_pos, anc_off64)
		var moved := UniverseCatalog.v64_len(UniverseCatalog.v64_sub(ship_pos64, anc_w64)) if last_terrain_alt >= 0.0 else 1e30
		var want_props := upd_surf_dist < 2_500.0
		var move_lim: float = 70.0 if is_walking else (220.0 if want_props else maxf(1_200.0, upd_surf_dist * 0.25))
		var rebuild: bool = active_surface_body_id != near_b["id"] or last_terrain_alt < 0.0 or abs(upd_surf_dist - last_terrain_alt) > max(400.0, last_terrain_alt * 0.25) or moved > move_lim or (want_props and not has_props_for_anchor)
		if rebuild:
			var built := SurfaceTerrain.build_terrain_mesh(near_b, near_pos, ship_pos64, near_rot, inv_near_rot, max(50.0, upd_surf_dist), Callable(self, "compress_to_scene"))
			terrain_mesh_inst.mesh = built["terrain_mesh"]
			terrain_mesh_inst.material_override = built["terrain_mat"]
			ocean_mesh_inst.visible = built["ocean_mesh"] != null
			if built["ocean_mesh"] != null:
				ocean_mesh_inst.mesh = built["ocean_mesh"]
				ocean_mesh_inst.material_override = built["ocean_mat"]
			active_collision = built["collision"]
			active_surface_body_id = near_b["id"]
			last_terrain_anchor_local64 = UniverseCatalog.rotate_body_world_to_local64(near_b, sim_time_s, UniverseCatalog.v64_sub(ship_pos64, near_pos))
			last_terrain_build_rot = near_rot
			last_terrain_alt = upd_surf_dist
			if surface_props_node != null:
				if surface_props_node.get_parent() != null:
					surface_props_node.get_parent().remove_child(surface_props_node)
				surface_props_node.queue_free()
				surface_props_node = null
			if want_props:
				var cl_center := UniverseCatalog.v64()
				var has_cl := false
				if is_walking and parked_ship_body_id == near_b["id"]:
					var pw64 := UniverseCatalog.rotate_body_local_to_world64(near_b, sim_time_s, parked_ship_local_pos64)
					cl_center = UniverseCatalog.v64_add(near_pos, pw64)
					has_cl = true
				elif is_landed:
					cl_center = ship_pos64
					has_cl = true
				surface_props_node = SurfaceTerrain.build_surface_props(near_b, near_pos, ship_pos64, near_rot, inv_near_rot, cl_center, has_cl, active_collision)
				terrain_root.add_child(surface_props_node)
				has_props_for_anchor = true
			else:
				has_props_for_anchor = false
		elif surface_props_node != null:
			surface_props_node.visible = want_props
		var anc_now_off64 := UniverseCatalog.rotate_body_local_to_world64(near_b, sim_time_s, last_terrain_anchor_local64)
		var anc_now64 := UniverseCatalog.v64_add(near_pos, anc_now_off64)
		terrain_root.visible = true
		terrain_root.position = UniverseCatalog.v64_to_vec3(UniverseCatalog.v64_sub(anc_now64, ship_pos64))
		terrain_root.quaternion = (near_rot * last_terrain_build_rot.inverse()).normalized()
	else:
		terrain_root.visible = false
		active_collision = null
		active_surface_body_id = ""
		last_terrain_alt = -1.0
		has_props_for_anchor = false

	# Атмосферное небо / туман (Compatibility-дружелюбно)
	var atmo_h: float = near_b["atmo_height_m"]
	var atmo_d := 0.0
	if atmo_h > 0.0 and upd_surf_dist < atmo_h:
		var hn := clampf(upd_surf_dist / atmo_h, 0.0, 1.0)
		atmo_d = exp(-hn * 3.8) * (1.0 - hn)
	if atmo_d > 0.02:
		var to_sun_b := UniverseCatalog.v64_to_vec3(UniverseCatalog.v64_norm(UniverseCatalog.v64_scale(near_pos, -1.0))).normalized()
		var day_f := clampf((to_sun_b.dot(UniverseCatalog.v64_to_vec3(up_w64)) + 0.22) / 0.40, 0.0, 1.0)
		var sky_c: Color = SurfaceTerrain.atmosphere_fog_color(near_b) * (0.12 + 0.88 * day_f)
		world_env.environment.background_mode = Environment.BG_COLOR
		world_env.environment.background_color = sky_c
		world_env.environment.ambient_light_energy = 0.28 + atmo_d * day_f * 0.32
		world_env.environment.fog_enabled = true
		world_env.environment.fog_light_color = sky_c * 0.80
		world_env.environment.fog_light_energy = 0.65
		world_env.environment.fog_density = 0.000010 * atmo_d
	else:
		world_env.environment.background_mode = Environment.BG_SKY
		world_env.environment.sky = _base_env_sky
		world_env.environment.ambient_light_energy = 0.48 if (near_b["is_landable"] and upd_surf_dist < 240_000.0) else 0.35
		world_env.environment.fog_enabled = false

	# Обновление всех 61 небесных тел и меток
	var prio_m: Array[Dictionary] = []
	var other_m: Array[Dictionary] = []
	var vp_size := get_viewport().get_visible_rect().size
	for b in bodies:
		var bid: String = b["id"]
		var node: Node3D = body_nodes.get(bid)
		if node == null:
			continue
		var bp: PackedFloat64Array = pos_cache[bid] if pos_cache.has(bid) else UniverseCatalog.get_body_pos(b, sim_time_s, pos_cache)
		var rel := UniverseCatalog.v64_sub(bp, ship_pos64)
		var dist_rel := UniverseCatalog.v64_len(rel)
		if b["is_galaxy"] and dist_rel < b["radius_m"] * 1.05:
			node.visible = false
			continue
		node.visible = true
		var c_res := compress_to_scene(rel)
		var r_scale := maxf(0.35, b["radius_m"] * c_res["scale"])
		node.position = c_res["pos"]
		node.scale = Vector3(r_scale, r_scale, r_scale)

		var mesh: MeshInstance3D = planet_meshes[bid]
		var spin_ang := 0.0
		if b["rotation_period_s"] != 0.0:
			spin_ang = fmod((TAU / b["rotation_period_s"]) * sim_time_s, TAU)
			mesh.rotation.y = spin_ang

		if terrain_vis and bid == near_b["id"] and upd_surf_dist <= 100_000.0:
			mesh.visible = false
		else:
			mesh.visible = not b["is_galaxy"]

		if planet_mats.has(bid):
			var to_sun_v := UniverseCatalog.v64_to_vec3(UniverseCatalog.v64_norm(UniverseCatalog.v64_scale(bp, -1.0))).normalized()
			var inv_spin := (Quaternion(Vector3.UP, -spin_ang) * Quaternion(Vector3(0, 0, 1), -b["axial_tilt_rad"])).normalized()
			(planet_mats[bid] as ShaderMaterial).set_shader_parameter("sun_dir_local", inv_spin * to_sun_v)

		var hide_m: bool = terrain_vis and bid == near_b["id"] and upd_surf_dist < 100_000.0
		if show_markers and not is_walking and not is_main_menu and not has_docked_station and not hide_m:
			if not main_camera.is_position_behind(node.position):
				var sp := main_camera.unproject_position(node.position)
				if sp.x >= 16.0 and sp.x <= vp_size.x - 16.0 and sp.y >= 46.0 and sp.y <= vp_size.y - 64.0:
					var col := Color.CYAN if bid == target_body["id"] else (Color.MEDIUM_PURPLE if b["is_black_hole"] else (Color.ORANGE if b["is_galaxy"] else (Color.YELLOW if b["is_star"] else Color.WHITE)))
					var mk := {"id": bid, "name": b["name"], "pos": sp, "color": col, "is_target": bid == target_body["id"]}
					if bid == target_body["id"] or bid == "sun":
						prio_m.append(mk)
					else:
						mk["dist"] = dist_rel
						other_m.append(mk)

	other_m.sort_custom(func(a, b): return a["dist"] < b["dist"])
	var rem := maxi(0, 18 - prio_m.size())
	var merged: Array[Dictionary] = []
	merged.append_array(prio_m)
	for i in range(mini(rem, other_m.size())):
		merged.append(other_m[i])
	screen_markers = merged

	# Орбитальные станции
	var near_st: Dictionary = {}
	var near_st_d := 1e30
	var docked_st_pos := UniverseCatalog.v64()
	for st in EliteSystems.get_stations():
		var st_pos := EliteSystems.get_station_pos(st, sim_time_s, pos_cache)
		if has_docked_station and st["id"] == docked_station_id:
			docked_st_pos = st_pos
		var rel_st := UniverseCatalog.v64_sub(st_pos, ship_pos64)
		var d_st := UniverseCatalog.v64_len(rel_st)
		if d_st < near_st_d:
			near_st_d = d_st; near_st = st
		var st_n: Node3D = station_nodes.get(st["id"])
		if st_n != null:
			var sc := compress_to_scene(rel_st)
			var sr: float = st["radius_m"] * sc["scale"]
			st_n.visible = sr >= 0.02 and d_st <= 50_000_000.0
			if st_n.visible:
				st_n.position = sc["pos"]
				st_n.scale = Vector3(sr, sr, sr)
				st_n.rotation.z += real_dt * 0.22

	if has_docked_station:
		ship_pos64 = UniverseCatalog.v64_add(docked_st_pos, UniverseCatalog.v64(0, 0, 500.0))
		ship_vel64 = UniverseCatalog.v64()
		var st_n2: Node3D = station_nodes.get(docked_station_id)
		if st_n2 != null:
			var r_d := UniverseCatalog.v64_sub(docked_st_pos, ship_pos64)
			var sc_d := compress_to_scene(r_d)
			st_n2.visible = true
			st_n2.position = sc_d["pos"]
			var sr2: float = docked_station["radius_m"] * sc_d["scale"]
			st_n2.scale = Vector3(sr2, sr2, sr2)

	has_nearby_station = (not is_walking) and (not is_landed) and (not has_docked_station) and (not is_main_menu) and near_st_d < 20_000.0
	nearby_station = near_st if has_nearby_station else {}
	nearby_station_dist_text = UniverseCatalog.format_distance(near_st_d) if has_nearby_station else ""

	if is_main_menu or not show_orbits:
		orbit_lines_node.visible = false
	elif frame_counter % 3 == 0:
		_update_orbit_lines(pos_cache)

	# Телеметрия HUD
	var t_bid: String = target_body["id"]
	var t_pos: PackedFloat64Array = pos_cache[t_bid] if pos_cache.has(t_bid) else UniverseCatalog.get_body_pos(target_body, sim_time_s, pos_cache)
	var s_dist: float = max(0.0, UniverseCatalog.v64_len(UniverseCatalog.v64_sub(t_pos, ship_pos64)) - target_body["radius_m"])
	distance_text = UniverseCatalog.format_distance(s_dist)
	speed_text = UniverseCatalog.format_speed(actual_spd)
	auto_speed_label = UniverseCatalog.format_speed(auto_max_mps)
	eta_text = UniverseCatalog.format_time(s_dist / actual_spd) if actual_spd > 1.0 else "Стоп"
	eva_ship_dist_text = UniverseCatalog.format_distance(eva_ship_dist)
	eva_temp_text = "%d °C" % near_b["mean_temp_c"]
	is_over_water = last_is_water
	is_near_surface = (near_b["is_landable"] and upd_surf_dist < 240_000.0) or atmo_d > 0.002
	can_auto_land = (not is_landed) and (not is_walking) and (not is_free_camera) and near_b["is_landable"] and radar_alt < 1_800.0 and (not last_is_water)
	zone_text = "ПРОГУЛКА" if is_walking else ("ПОСАДКА" if is_landed else ("АТМОСФЕРА" if atmo_d > 0.002 else ("СНИЖЕНИЕ" if (near_b["is_landable"] and upd_surf_dist < 240_000.0) else "")))
	surface_alt_text = ("ГРАВ: %.2f g" % near_b["surface_gravity_g"]) if is_walking else ("НА ПОВЕРХНОСТИ" if is_landed else (("ВЫС: %.0f м" % radar_alt) if radar_alt < 1_000.0 else ("ВЫС: %.1f км" % (radar_alt / 1_000.0))))
	var days := int(floor(sim_time_s / 86_400.0))
	sim_date_text = "Д+%d" % days if days != 0 else "24.11.2026"

func _update_orbit_lines(pos_cache: Dictionary) -> void:
	orbit_lines_node.visible = true
	orbit_lines_mesh.clear_surfaces()
	var verts := PackedVector3Array()
	var max_d := 250.0 * UniverseCatalog.AU
	for b in UniverseCatalog.get_bodies():
		if b["semi_major_axis_m"] <= 0.0 or b["orbital_period_s"] <= 0.0:
			continue
		var pid: String = b["parent_id"]
		var p_pos := UniverseCatalog.v64()
		if pid != "":
			p_pos = pos_cache[pid] if pos_cache.has(pid) else UniverseCatalog.get_body_pos(UniverseCatalog.find_body(pid), sim_time_s, pos_cache)
		if UniverseCatalog.v64_len(UniverseCatalog.v64_sub(p_pos, ship_pos64)) > max_d:
			continue
		var segs := 48
		for s in range(segs):
			var a1 := (float(s) / float(segs)) * TAU
			var a2 := (float((s + 1) % segs) / float(segs)) * TAU
			var pt1 := compress_to_scene(UniverseCatalog.v64_sub(UniverseCatalog.orbit_point(b, a1, p_pos), ship_pos64))
			var pt2 := compress_to_scene(UniverseCatalog.v64_sub(UniverseCatalog.orbit_point(b, a2, p_pos), ship_pos64))
			verts.append(pt1["pos"])
			verts.append(pt2["pos"])
	if verts.is_empty():
		orbit_lines_node.visible = false
		return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	orbit_lines_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
