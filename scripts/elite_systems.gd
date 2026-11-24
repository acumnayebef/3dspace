class_name EliteSystems
extends RefCounted

const PROFILE_PATH: String = "user://pilot_profile.json"

const CARGO_CAPACITIES := [20, 40, 80, 160]
const CARGO_COSTS := [15_000, 45_000, 120_000]
const FSS_MULTIPLIERS := [1.0, 1.5, 2.0, 3.0]
const FSS_COSTS := [12_000, 36_000, 90_000]
const JETPACK_DRAINS := [0.28, 0.18, 0.12]
const JETPACK_COSTS := [10_000, 32_000]

static func get_stations() -> Array[Dictionary]:
	if Engine.has_meta(&"space3d_stations"):
		return Engine.get_meta(&"space3d_stations")
	var list: Array[Dictionary] = [
		{
			"id": "station_earth_gateway",
			"name": "Врата Земли",
			"parent_body_id": "earth",
			"economy": "Высокие технологии",
			"orbit_alt_m": 1_200_000.0,
			"orbital_period_s": 6_550.0,
			"initial_phase_rad": 0.45,
			"inclination_rad": 0.12,
			"radius_m": 280.0,
			"accent_color": Color(0.0, 0.90, 1.0),
			"summary": "Главный орбитальный хаб человечества на низкой орбите Земли.",
		},
		{
			"id": "station_lunar_port",
			"name": "Лунный Порт Артемида",
			"parent_body_id": "moon",
			"economy": "Добыча",
			"orbit_alt_m": 350_000.0,
			"orbital_period_s": 8_400.0,
			"initial_phase_rad": 1.65,
			"inclination_rad": 0.08,
			"radius_m": 260.0,
			"accent_color": Color(1.0, 0.67, 0.20),
			"summary": "Орбитальный терминал добычи гелия-3 и титановой руды.",
		},
		{
			"id": "station_mars_olympus",
			"name": "Олимп-Орбиталь",
			"parent_body_id": "mars",
			"economy": "Индустриальная",
			"orbit_alt_m": 650_000.0,
			"orbital_period_s": 7_200.0,
			"initial_phase_rad": 2.85,
			"inclination_rad": 0.15,
			"radius_m": 290.0,
			"accent_color": Color(1.0, 0.35, 0.16),
			"summary": "Машиностроительный комплекс и верфь Красной планеты.",
		},
		{
			"id": "station_europa_lab",
			"name": "Крио-Станция Европа",
			"parent_body_id": "europa",
			"economy": "Научная",
			"orbit_alt_m": 420_000.0,
			"orbital_period_s": 9_100.0,
			"initial_phase_rad": 4.10,
			"inclination_rad": 0.06,
			"radius_m": 250.0,
			"accent_color": Color(0.47, 0.87, 1.0),
			"summary": "Исследовательская станция подлёдного океана Европы.",
		},
		{
			"id": "station_titan_refinery",
			"name": "Титан-Синтез",
			"parent_body_id": "titan",
			"economy": "Топливная",
			"orbit_alt_m": 580_000.0,
			"orbital_period_s": 10_800.0,
			"initial_phase_rad": 5.20,
			"inclination_rad": 0.10,
			"radius_m": 270.0,
			"accent_color": Color(1.0, 0.80, 0.27),
			"summary": "Топливный хаб Сатурна по синтезу дейтерия.",
		},
		{
			"id": "station_proxima_outpost",
			"name": "Аванпост Проксима",
			"parent_body_id": "proxima_b",
			"economy": "Фронтир",
			"orbit_alt_m": 900_000.0,
			"orbital_period_s": 6_900.0,
			"initial_phase_rad": 0.95,
			"inclination_rad": 0.18,
			"radius_m": 300.0,
			"accent_color": Color(0.67, 0.40, 1.0),
			"summary": "Дальний межзвёздный форпост на орбите Proxima b.",
		},
	]
	Engine.set_meta(&"space3d_stations", list)
	return list

static func get_commodities() -> Array[Dictionary]:
	if Engine.has_meta(&"space3d_commodities"):
		return Engine.get_meta(&"space3d_commodities")
	var list: Array[Dictionary] = [
		{"id": "water_ice", "name": "Водяной лёд", "base_price": 140},
		{"id": "titanium", "name": "Титановая руда", "base_price": 480},
		{"id": "deuterium", "name": "Дейтерий-топливо", "base_price": 820},
		{"id": "superconductors", "name": "Сверхпроводники", "base_price": 1_950},
		{"id": "med_tech", "name": "Колониальное медоборудование", "base_price": 2_600},
		{"id": "exocrystals", "name": "Экзо-кристаллы", "base_price": 5_400},
	]
	Engine.set_meta(&"space3d_commodities", list)
	return list

static func commodity_price(item_id: String, base_price: int, economy: String) -> int:
	var mult: float = 1.0
	match item_id:
		"water_ice":
			match economy:
				"Научная": mult = 0.55
				"Топливная": mult = 0.65
				"Добыча", "Индустриальная": mult = 1.65
				"Фронтир": mult = 1.45
				_: mult = 1.05
		"titanium":
			match economy:
				"Добыча": mult = 0.60
				"Индустриальная", "Высокие технологии": mult = 1.55
				"Фронтир": mult = 1.30
				_: mult = 1.00
		"deuterium":
			match economy:
				"Топливная": mult = 0.55
				"Высокие технологии", "Фронтир": mult = 1.50
				"Научная": mult = 1.25
				_: mult = 1.15
		"superconductors":
			match economy:
				"Индустриальная": mult = 0.65
				"Высокие технологии", "Научная": mult = 1.50
				"Фронтир": mult = 1.35
				_: mult = 1.05
		"med_tech":
			match economy:
				"Высокие технологии": mult = 0.65
				"Фронтир", "Добыча": mult = 1.55
				"Индустриальная": mult = 1.20
				_: mult = 1.05
		"exocrystals":
			match economy:
				"Фронтир": mult = 0.50
				"Высокие технологии": mult = 1.65
				"Научная": mult = 1.50
				"Индустриальная": mult = 1.25
				_: mult = 1.10
	return max(10, int(round(float(base_price) * mult)))

static func commodity_demand_tag(item_id: String, base_price: int, economy: String) -> String:
	var p: int = commodity_price(item_id, base_price, economy)
	if float(p) <= float(base_price) * 0.72:
		return "ЭКСПОРТ ↓"
	if float(p) >= float(base_price) * 1.40:
		return "СПРОС ↑"
	return "БАЛАНС"

static func get_station_pos(station: Dictionary, sim_time: float, body_cache: Dictionary) -> PackedFloat64Array:
	var parent_id: String = station["parent_body_id"]
	var parent := UniverseCatalog.find_body(parent_id)
	var p_pos := UniverseCatalog.get_body_pos(parent, sim_time, body_cache)
	var orbit_r: float = parent["radius_m"] + station["orbit_alt_m"]
	var period: float = station["orbital_period_s"]
	var angle: float = station["initial_phase_rad"]
	if period > 0.0:
		angle += (TAU / period) * sim_time
	var inc: float = station["inclination_rad"]
	var cos_lat: float = cos(inc)
	return UniverseCatalog.v64(
		p_pos[0] + cos(angle) * cos_lat * orbit_r,
		p_pos[1] + sin(inc) * orbit_r,
		p_pos[2] - sin(angle) * cos_lat * orbit_r
	)

static func fss_frequency_mhz(body: Dictionary) -> float:
	var min_f: float = 15.0
	var span: float = 13.0
	match body["category"]:
		UniverseCatalog.BodyCategory.SOLAR, UniverseCatalog.BodyCategory.ALL:
			min_f = 15.0; span = 13.0
		UniverseCatalog.BodyCategory.MOONS, UniverseCatalog.BodyCategory.STATIONS:
			min_f = 29.0; span = 13.0
		UniverseCatalog.BodyCategory.STARS:
			min_f = 43.0; span = 15.0
		UniverseCatalog.BodyCategory.EXOPLANETS:
			min_f = 59.0; span = 15.0
		UniverseCatalog.BodyCategory.BLACK_HOLES:
			min_f = 75.0; span = 11.0
		UniverseCatalog.BodyCategory.GALAXIES:
			min_f = 87.0; span = 11.0
	var h: int = 2166136261
	var bid: String = body["id"]
	for b in bid.to_utf8_buffer():
		h = (h ^ int(b)) * 16777619
	var unit: float = float(h & 0xFFFF) / 65535.0
	return round((min_f + unit * span) * 10.0) / 10.0

static func fss_base_payout(body: Dictionary) -> int:
	match body["category"]:
		UniverseCatalog.BodyCategory.MOONS: return 1_500
		UniverseCatalog.BodyCategory.SOLAR: return 3_000
		UniverseCatalog.BodyCategory.STARS: return 6_000
		UniverseCatalog.BodyCategory.EXOPLANETS: return 12_000
		UniverseCatalog.BodyCategory.BLACK_HOLES: return 20_000
		UniverseCatalog.BodyCategory.GALAXIES: return 25_000
		_: return 3_000

static func load_profile() -> Dictionary:
	var defaults := {
		"credits": 10_000,
		"cargo": {},
		"scans": [],
		"cargo_level": 0,
		"fss_level": 0,
		"jetpack_level": 0,
	}
	if not FileAccess.file_exists(PROFILE_PATH):
		return defaults
	var txt := FileAccess.get_file_as_string(PROFILE_PATH)
	var parsed = JSON.parse_string(txt)
	if typeof(parsed) != TYPE_DICTIONARY:
		return defaults
	for k in defaults:
		if not parsed.has(k):
			parsed[k] = defaults[k]
	return parsed

static func save_profile(profile: Dictionary) -> void:
	var f := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(profile))

static func cargo_capacity_tons(profile: Dictionary) -> int:
	var lvl: int = clampi(int(profile.get("cargo_level", 0)), 0, CARGO_CAPACITIES.size() - 1)
	return CARGO_CAPACITIES[lvl]

static func used_cargo_tons(profile: Dictionary) -> int:
	var total: int = 0
	var cargo: Dictionary = profile.get("cargo", {})
	for v in cargo.values():
		total += int(v)
	return total

static func fss_multiplier(profile: Dictionary) -> float:
	var lvl: int = clampi(int(profile.get("fss_level", 0)), 0, FSS_MULTIPLIERS.size() - 1)
	return FSS_MULTIPLIERS[lvl]

static func jetpack_drain_per_sec(profile: Dictionary) -> float:
	var lvl: int = clampi(int(profile.get("jetpack_level", 0)), 0, JETPACK_DRAINS.size() - 1)
	return JETPACK_DRAINS[lvl]

static func build_station_node(station: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = station["id"]

	var hull_dark := StandardMaterial3D.new()
	hull_dark.albedo_color = Color(0.16, 0.19, 0.24)
	hull_dark.metallic = 0.85
	hull_dark.roughness = 0.34

	var hull_light := StandardMaterial3D.new()
	hull_light.albedo_color = Color(0.78, 0.82, 0.88)
	hull_light.metallic = 0.65
	hull_light.roughness = 0.26

	var solar_mat := StandardMaterial3D.new()
	solar_mat.albedo_color = Color(0.06, 0.16, 0.36)
	solar_mat.metallic = 0.90
	solar_mat.roughness = 0.14

	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = station["accent_color"]

	var slot_mat := StandardMaterial3D.new()
	slot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	slot_mat.albedo_color = Color(1.0, 0.72, 0.24)

	var win_mat := StandardMaterial3D.new()
	win_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	win_mat.albedo_color = Color(0.85, 0.94, 1.0)

	# Бронированная центральная ось вдоль Z
	var hub := MeshInstance3D.new()
	var hub_m := CylinderMesh.new()
	hub_m.top_radius = 0.22
	hub_m.bottom_radius = 0.22
	hub_m.height = 1.48
	hub_m.radial_segments = 24
	hub.mesh = hub_m
	hub.material_override = hull_dark
	hub.rotation_degrees = Vector3(90, 0, 0)
	root.add_child(hub)

	# Док-модули со светящимся стыковочным шлюзом
	for z_sign in [1.0, -1.0]:
		var cap := MeshInstance3D.new()
		var cap_m := BoxMesh.new()
		cap_m.size = Vector3(0.32, 0.24, 0.12)
		cap.mesh = cap_m
		cap.material_override = hull_light
		cap.position = Vector3(0, 0, float(z_sign) * 0.74)
		root.add_child(cap)

		var slot := MeshInstance3D.new()
		var slot_m := BoxMesh.new()
		slot_m.size = Vector3(0.20, 0.08, 0.04)
		slot.mesh = slot_m
		slot.material_override = slot_mat
		slot.position = Vector3(0, 0, float(z_sign) * 0.80)
		root.add_child(slot)

	# Жилой вращающийся тор
	var torus := MeshInstance3D.new()
	var torus_m := TorusMesh.new()
	torus_m.inner_radius = 0.70
	torus_m.outer_radius = 0.90
	torus_m.rings = 36
	torus_m.ring_segments = 16
	torus.mesh = torus_m
	torus.material_override = hull_light
	torus.rotation_degrees = Vector3(90, 0, 0)
	torus.position = Vector3(0, 0, 0.14)
	root.add_child(torus)

	var trim := MeshInstance3D.new()
	var trim_m := TorusMesh.new()
	trim_m.inner_radius = 0.87
	trim_m.outer_radius = 0.91
	trim_m.rings = 36
	trim_m.ring_segments = 8
	trim.mesh = trim_m
	trim.material_override = win_mat
	trim.rotation_degrees = Vector3(90, 0, 0)
	trim.position = Vector3(0, 0, 0.14)
	root.add_child(trim)

	# 4 радиальные спицы
	var spoke_m := BoxMesh.new()
	spoke_m.size = Vector3(0.06, 1.56, 0.07)
	for angle_deg in [0.0, 90.0]:
		var spoke := MeshInstance3D.new()
		spoke.mesh = spoke_m
		spoke.material_override = hull_dark
		spoke.position = Vector3(0, 0, 0.14)
		spoke.rotation_degrees = Vector3(0, 0, float(angle_deg))
		root.add_child(spoke)

	# Солнечные крылья
	var wing_m := BoxMesh.new()
	wing_m.size = Vector3(0.26, 0.72, 0.018)
	for y_sign in [1.0, -1.0]:
		var wing := MeshInstance3D.new()
		wing.mesh = wing_m
		wing.material_override = solar_mat
		wing.position = Vector3(0, float(y_sign) * 0.58, -0.45)
		root.add_child(wing)

	# Навигационные маяки
	var b_m := SphereMesh.new()
	b_m.radius = 0.032
	b_m.height = 0.064
	var offsets := [
		Vector3(0.82, 0, 0.22),
		Vector3(-0.82, 0, 0.22),
		Vector3(0, 0.94, -0.45),
		Vector3(0, -0.94, -0.45),
	]
	for p in offsets:
		var b := MeshInstance3D.new()
		b.mesh = b_m
		b.material_override = glow_mat
		b.position = p
		root.add_child(b)

	return root
