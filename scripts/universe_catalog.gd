class_name UniverseCatalog
extends RefCounted

enum BodyCategory {
	ALL,
	STATIONS,
	SOLAR,
	MOONS,
	STARS,
	EXOPLANETS,
	BLACK_HOLES,
	GALAXIES,
}

const AU: float = 149_597_870_700.0
const LY: float = 9_460_730_472_580_800.0
const DAY: float = 86_400.0
const G_CONST: float = 6.67430e-11
const C_LIGHT: float = 299_792_458.0

static func category_label(cat: int) -> String:
	match cat:
		BodyCategory.ALL: return "Все"
		BodyCategory.STATIONS: return "Станции"
		BodyCategory.SOLAR: return "Солнечная"
		BodyCategory.MOONS: return "Спутники"
		BodyCategory.STARS: return "Звёзды"
		BodyCategory.EXOPLANETS: return "Экзопланеты"
		BodyCategory.BLACK_HOLES: return "Чёрные дыры"
		BodyCategory.GALAXIES: return "Галактики"
		_: return "Все"

# --- 64-bit double-precision 3D vector helpers ---

static func v64(x: float = 0.0, y: float = 0.0, z: float = 0.0) -> PackedFloat64Array:
	var a := PackedFloat64Array()
	a.resize(3)
	a[0] = x
	a[1] = y
	a[2] = z
	return a

static func v64_add(a: PackedFloat64Array, b: PackedFloat64Array) -> PackedFloat64Array:
	return v64(a[0] + b[0], a[1] + b[1], a[2] + b[2])

static func v64_sub(a: PackedFloat64Array, b: PackedFloat64Array) -> PackedFloat64Array:
	return v64(a[0] - b[0], a[1] - b[1], a[2] - b[2])

static func v64_scale(a: PackedFloat64Array, s: float) -> PackedFloat64Array:
	return v64(a[0] * s, a[1] * s, a[2] * s)

static func v64_len_sq(a: PackedFloat64Array) -> float:
	return a[0] * a[0] + a[1] * a[1] + a[2] * a[2]

static func v64_len(a: PackedFloat64Array) -> float:
	return sqrt(max(0.0, a[0] * a[0] + a[1] * a[1] + a[2] * a[2]))

static func v64_dot(a: PackedFloat64Array, b: PackedFloat64Array) -> float:
	return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]

static func v64_cross(a: PackedFloat64Array, b: PackedFloat64Array) -> PackedFloat64Array:
	return v64(
		a[1] * b[2] - a[2] * b[1],
		a[2] * b[0] - a[0] * b[2],
		a[0] * b[1] - a[1] * b[0]
	)

static func v64_norm(a: PackedFloat64Array, fallback: PackedFloat64Array = PackedFloat64Array([0.0, 1.0, 0.0])) -> PackedFloat64Array:
	var l2: float = a[0] * a[0] + a[1] * a[1] + a[2] * a[2]
	if l2 > 1e-18:
		var inv: float = 1.0 / sqrt(l2)
		return v64(a[0] * inv, a[1] * inv, a[2] * inv)
	return fallback.duplicate()

static func v64_to_vec3(a: PackedFloat64Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])

static func quat_act_v64(q: Quaternion, v: PackedFloat64Array) -> PackedFloat64Array:
	var b := Basis(q)
	return v64(
		float(b.x.x) * v[0] + float(b.y.x) * v[1] + float(b.z.x) * v[2],
		float(b.x.y) * v[0] + float(b.y.y) * v[1] + float(b.z.y) * v[2],
		float(b.x.z) * v[0] + float(b.y.z) * v[1] + float(b.z.z) * v[2]
	)

static func celestial_phase_lat(ra_hours: float, dec_deg: float) -> Vector2:
	return Vector2((ra_hours / 24.0) * TAU, deg_to_rad(dec_deg))

static func _hex_color(hex: int) -> Color:
	return Color(
		float((hex >> 16) & 0xFF) / 255.0,
		float((hex >> 8) & 0xFF) / 255.0,
		float(hex & 0xFF) / 255.0,
		1.0
	)

static func _make_body(
	id: String,
	body_name: String,
	body_type: String,
	category: int,
	sma: float,
	period: float,
	phase: float,
	lat: float,
	parent_id: String,
	radius: float,
	mass: float,
	tilt: float,
	rot_period: float,
	temp_k: int,
	c1_hex: int,
	c2_hex: int,
	is_star: bool,
	has_atmo: bool,
	has_rings: bool,
	summary: String,
	is_bh: bool = false,
	is_gal: bool = false,
	clouds: float = 0.0
) -> Dictionary:
	var is_gas := id in ["jupiter", "saturn", "uranus", "neptune", "dimidium", "hd189733b"]
	var is_hab := id in ["earth", "proxima_b", "trappist1e", "kepler186f", "kepler442b"]
	var is_icy := id in ["europa", "enceladus", "pluto", "triton", "ganymede", "callisto", "eris", "trappist1f", "trappist1g"]
	var is_land := (not is_star) and (not is_bh) and (not is_gal) and (not is_gas)
	var surf_g := 0.0
	var v1 := 0.0
	var v2 := 0.0
	if radius > 0.0:
		surf_g = ((G_CONST * mass) / (radius * radius)) / 9.80665
		v1 = sqrt((G_CONST * mass) / radius)
		v2 = sqrt((2.0 * G_CONST * mass) / radius)
	var atmo_h := 0.0
	if id == "earth" or is_hab:
		atmo_h = 110_000.0
	elif id == "mars" or id == "trappist1d":
		atmo_h = 75_000.0
	elif id == "venus" or id == "titan" or id == "trappist1b":
		atmo_h = 140_000.0
	elif has_atmo and is_land:
		atmo_h = 55_000.0

	return {
		"id": id,
		"name": body_name,
		"type": body_type,
		"category": category,
		"semi_major_axis_m": sma,
		"orbital_period_s": period,
		"initial_phase_rad": phase,
		"latitude_rad": lat,
		"parent_id": parent_id,
		"radius_m": radius,
		"mass_kg": mass,
		"axial_tilt_rad": tilt,
		"rotation_period_s": rot_period,
		"mean_temp_k": temp_k,
		"mean_temp_c": temp_k - 273,
		"color": _hex_color(c1_hex),
		"secondary_color": _hex_color(c2_hex),
		"is_star": is_star,
		"is_black_hole": is_bh,
		"is_galaxy": is_gal,
		"has_atmosphere": has_atmo,
		"has_rings": has_rings,
		"cloud_coverage": clouds,
		"is_gas_giant": is_gas,
		"is_habitable": is_hab,
		"is_icy": is_icy,
		"is_landable": is_land,
		"surface_gravity_g": surf_g,
		"first_cosmic_mps": v1,
		"escape_velocity_mps": v2,
		"atmo_height_m": atmo_h,
		"summary": summary,
	}

static func get_bodies() -> Array[Dictionary]:
	if Engine.has_meta(&"space3d_bodies"):
		return Engine.get_meta(&"space3d_bodies")

	var p_proxima := celestial_phase_lat(14.495, -62.68)
	var p_alpha := celestial_phase_lat(14.660, -60.83)
	var p_sirius := celestial_phase_lat(6.752, -16.72)
	var p_tau := celestial_phase_lat(1.735, -15.94)
	var p_vega := celestial_phase_lat(18.616, 38.78)
	var p_arcturus := celestial_phase_lat(14.261, 19.18)
	var p_trappist := celestial_phase_lat(23.108, -5.04)
	var p_51peg := celestial_phase_lat(22.958, 20.77)
	var p_hd189 := celestial_phase_lat(20.012, 22.71)
	var p_aldebaran := celestial_phase_lat(4.599, 16.51)
	var p_polaris := celestial_phase_lat(2.530, 89.26)
	var p_betel := celestial_phase_lat(5.919, 7.41)
	var p_k186 := celestial_phase_lat(19.910, 43.95)
	var p_rigel := celestial_phase_lat(5.242, -8.20)
	var p_k442 := celestial_phase_lat(19.131, 39.28)
	var p_crab := celestial_phase_lat(5.575, 22.01)
	var p_uy := celestial_phase_lat(18.460, -12.46)
	var p_steph := celestial_phase_lat(18.651, -6.03)

	var p_sgr := celestial_phase_lat(17.761, -29.01)
	var p_cyg := celestial_phase_lat(19.973, 35.20)
	var p_m87 := celestial_phase_lat(12.514, 12.39)
	var p_ton := celestial_phase_lat(12.473, 31.48)

	var p_lmc := celestial_phase_lat(5.393, -69.76)
	var p_m31 := celestial_phase_lat(0.712, 41.27)
	var p_m33 := celestial_phase_lat(1.564, 30.66)
	var p_m51 := celestial_phase_lat(13.498, 47.20)
	var p_m104 := celestial_phase_lat(12.667, -11.62)
	var p_ic1101 := celestial_phase_lat(15.183, 5.74)

	var list: Array[Dictionary] = [
		# Солнечная система (12)
		_make_body("sun", "Солнце", "Звезда G2V", BodyCategory.SOLAR, 0.0, 0.0, 0.0, 0.0, "", 696_340_000.0, 1.9885e30, 0.126, 25.38 * DAY, 5778, 0xFFCC44, 0xFF6600, true, false, false, "Жёлтый карлик главной последовательности (99.86% массы Солнечной системы)."),
		_make_body("mercury", "Меркурий", "Планета земной группы", BodyCategory.SOLAR, 0.387098 * AU, 87.969 * DAY, 0.4, 0.05, "sun", 2_439_700.0, 3.3011e23, 0.0005, 58.646 * DAY, 440, 0x948F88, 0x524E48, false, false, false, "Ближайшая к Солнцу и самая маленькая планета системы."),
		_make_body("venus", "Венера", "Планета земной группы", BodyCategory.SOLAR, 0.723332 * AU, 224.701 * DAY, 2.1, -0.02, "sun", 6_051_800.0, 4.8675e24, 3.095, -243.025 * DAY, 737, 0xE6B87D, 0xB87A38, false, true, false, "Плотная атмосфера из CO2 с давлением 92 атм.", false, false, 0.96),
		_make_body("earth", "Земля", "Обитаемая планета", BodyCategory.SOLAR, 1.0 * AU, 365.256 * DAY, PI, 0.0, "sun", 6_371_000.0, 5.97237e24, 0.4091, 86_164.1, 288, 0x164E9C, 0x3B8C4E, false, true, false, "Голубая планета с океанами жидкой воды и развитой биосферой.", false, false, 0.72),
		_make_body("mars", "Марс", "Планета земной группы", BodyCategory.SOLAR, 1.523679 * AU, 686.980 * DAY, 1.3, 0.02, "sun", 3_389_500.0, 6.4171e23, 0.4396, 88_642.6, 210, 0xC8522E, 0x692311, false, true, false, "Красная планета с каньонами, полярными шапками и вулканом Олимп.", false, false, 0.22),
		_make_body("ceres", "Церера", "Карликовая планета", BodyCategory.SOLAR, 2.7675 * AU, 1681.63 * DAY, 3.1, 0.185, "sun", 469_730.0, 9.3835e20, 0.07, 32_666.0, 168, 0x7A7875, 0x454340, false, false, false, "Крупнейший объект Главного пояса астероидов."),
		_make_body("jupiter", "Юпитер", "Газовый гигант", BodyCategory.SOLAR, 5.2044 * AU, 4332.59 * DAY, 5.2, -0.01, "sun", 69_911_000.0, 1.8982e27, 0.0546, 35_730.0, 165, 0xD8B088, 0x8F5230, false, true, false, "Крупнейшая планета Солнечной системы с ураганами и мощным магнитным полем.", false, false, 0.85),
		_make_body("saturn", "Сатурн", "Газовый гигант", BodyCategory.SOLAR, 9.5826 * AU, 10759.22 * DAY, 3.7, 0.03, "sun", 58_232_000.0, 5.6834e26, 0.4665, 38_362.0, 134, 0xE8D49E, 0xB39252, false, true, true, "Гигант с величественной системой ледяных колец.", false, false, 0.80),
		_make_body("uranus", "Уран", "Ледяной гигант", BodyCategory.SOLAR, 19.2184 * AU, 30688.5 * DAY, 4.5, -0.01, "sun", 25_362_000.0, 8.6810e25, 1.706, -62_064.0, 76, 0x84E6F5, 0x4CB3C9, false, true, true, "Ледяной гигант с наклоном оси 97.7°.", false, false, 0.75),
		_make_body("neptune", "Нептун", "Ледяной гигант", BodyCategory.SOLAR, 30.11 * AU, 60195.0 * DAY, 0.2, 0.02, "sun", 24_622_000.0, 1.02413e26, 0.494, 57_996.0, 72, 0x3666FF, 0x1A3494, false, true, false, "Далёкая планета со сверхзвуковыми ветрами.", false, false, 0.78),
		_make_body("pluto", "Плутон", "Карликовая планета", BodyCategory.SOLAR, 39.482 * AU, 90560.0 * DAY, 5.05, 0.299, "sun", 1_188_300.0, 1.303e22, 2.138, -6.387 * DAY, 44, 0xD4B99B, 0x6E4836, false, false, false, "Ледяной карлик пояса Койпера с азотными ледниками."),
		_make_body("eris", "Эрида", "Карликовая планета", BodyCategory.SOLAR, 67.864 * AU, 204199.0 * DAY, 0.65, 0.769, "sun", 1_163_000.0, 1.6466e22, 0.78, 93_240.0, 42, 0xE6EAEF, 0x9AA6B5, false, false, false, "Массивная карликовая планета рассеянного диска."),

		# Спутники (10)
		_make_body("moon", "Луна", "Спутник Земли", BodyCategory.MOONS, 384_400_000.0, 27.32166 * DAY, 0.85, 0.089, "earth", 1_737_400.0, 7.342e22, 0.116, 27.32166 * DAY, 220, 0xC4C4C4, 0x6A6A6A, false, false, false, "Естественный спутник Земли."),
		_make_body("phobos", "Фобос", "Спутник Марса", BodyCategory.MOONS, 9_376_000.0, 0.3189 * DAY, 1.1, 0.019, "mars", 11_267.0, 1.0659e16, 0.0, 0.3189 * DAY, 233, 0x7A6C64, 0x423833, false, false, false, "Крошечный спутник Марса с кратером Стикни."),
		_make_body("io", "Ио", "Спутник Юпитера", BodyCategory.MOONS, 421_700_000.0, 1.7691 * DAY, 0.5, 0.001, "jupiter", 1_821_600.0, 8.9319e22, 0.0, 1.7691 * DAY, 110, 0xE6C43E, 0x9C4018, false, false, false, "Вулканический спутник Юпитера."),
		_make_body("europa", "Европа", "Ледяной спутник Юпитера", BodyCategory.MOONS, 671_034_000.0, 3.5512 * DAY, 2.2, 0.008, "jupiter", 1_560_800.0, 4.7998e22, 0.002, 3.5512 * DAY, 102, 0xD2E4F0, 0x8A6D54, false, false, false, "Ледяной спутник с глобальным подлёдным океаном."),
		_make_body("ganymede", "Ганимед", "Спутник Юпитера", BodyCategory.MOONS, 1_070_412_000.0, 7.1546 * DAY, 3.9, 0.003, "jupiter", 2_634_100.0, 1.4819e23, 0.003, 7.1546 * DAY, 110, 0xA49C94, 0x5E5852, false, false, false, "Крупнейший спутник Солнечной системы."),
		_make_body("callisto", "Каллисто", "Спутник Юпитера", BodyCategory.MOONS, 1_882_709_000.0, 16.689 * DAY, 5.1, 0.003, "jupiter", 2_410_300.0, 1.0759e23, 0.0, 16.689 * DAY, 134, 0x7E7872, 0x3D3A37, false, false, false, "Древняя кратерированная ледово-каменная луна."),
		_make_body("titan", "Титан", "Спутник Сатурна", BodyCategory.MOONS, 1_221_870_000.0, 15.945 * DAY, 1.8, 0.006, "saturn", 2_574_730.0, 1.3452e23, 0.005, 15.945 * DAY, 94, 0xD9963A, 0x8F5618, false, true, false, "Спутник с плотной атмосферой и углеводородными морями.", false, false, 0.96),
		_make_body("enceladus", "Энцелад", "Ледяной спутник Сатурна", BodyCategory.MOONS, 237_948_000.0, 1.3702 * DAY, 4.4, 0.0003, "saturn", 252_100.0, 1.0802e20, 0.0, 1.3702 * DAY, 75, 0xF0F6FC, 0x7EAED4, false, false, false, "Ослепительно белый спутник с водяными гейзерами."),
		_make_body("triton", "Тритон", "Спутник Нептуна", BodyCategory.MOONS, 354_759_000.0, 5.8769 * DAY, 2.9, 0.40, "neptune", 1_353_400.0, 2.139e22, 0.0, 5.8769 * DAY, 38, 0xD8CCD2, 0x8A7880, false, false, false, "Криовулканический спутник Нептуна."),
		_make_body("charon", "Харон", "Спутник Плутона", BodyCategory.MOONS, 19_591_000.0, 6.3872 * DAY, 1.5, 0.01, "pluto", 606_000.0, 1.586e21, 0.0, 6.3872 * DAY, 53, 0x9B9794, 0x5E4742, false, false, false, "Крупнейший спутник Плутона."),

		# Звёзды (18)
		_make_body("proxima", "Проксима Центавра", "Звезда M5.5Ve", BodyCategory.STARS, 4.2465 * LY, 0.0, p_proxima.x, p_proxima.y, "", 107_280_000.0, 2.428e29, 0.0, 83.5 * DAY, 3042, 0xFF5A36, 0xB8250A, true, false, false, "Ближайшая к Солнцу звезда с экзопланетой Proxima b."),
		_make_body("alpha_cen_a", "Альфа Центавра A", "Звезда G2V", BodyCategory.STARS, 4.344 * LY, 0.0, p_alpha.x, p_alpha.y, "", 851_000_000.0, 2.14e30, 0.0, 22.0 * DAY, 5790, 0xFFD970, 0xFF8811, true, false, false, "Ближайшая солнцеподобная звезда."),
		_make_body("sirius", "Сириус A", "Звезда A1V", BodyCategory.STARS, 8.60 * LY, 0.0, p_sirius.x, p_sirius.y, "", 1_190_000_000.0, 4.018e30, 0.0, 5.5 * DAY, 9940, 0xD6EAFF, 0x88B8FF, true, false, false, "Ярчайшая звезда ночного неба."),
		_make_body("tau_ceti", "Тау Кита", "Звезда G8V", BodyCategory.STARS, 11.91 * LY, 0.0, p_tau.x, p_tau.y, "", 552_000_000.0, 1.557e30, 0.0, 34.0 * DAY, 5344, 0xFFC56E, 0xD96B18, true, false, false, "Близкий жёлтый карлик в созвездии Кита."),
		_make_body("vega", "Вега", "Звезда A0Va", BodyCategory.STARS, 25.04 * LY, 0.0, p_vega.x, p_vega.y, "", 1_643_000_000.0, 4.24e30, 0.0, 0.52 * DAY, 9602, 0xCBE5FF, 0x6AA8FF, true, false, false, "Голубая звезда-эталон созвездия Лиры."),
		_make_body("arcturus", "Арктур", "Красный гигант K1.5III", BodyCategory.STARS, 36.7 * LY, 0.0, p_arcturus.x, p_arcturus.y, "", 17_687_000_000.0, 2.15e30, 0.0, 730.0 * DAY, 4286, 0xFF9442, 0xCC3300, true, false, false, "Оранжевый гигант северного неба."),
		_make_body("trappist1", "TRAPPIST-1", "Звезда M8V (7 планет)", BodyCategory.STARS, 40.66 * LY, 0.0, p_trappist.x, p_trappist.y, "", 84_180_000.0, 1.787e29, 0.0, 3.3 * DAY, 2566, 0xFF4522, 0x991A00, true, false, false, "Красный карлик с 7 землеподобными планетами."),
		_make_body("pegasi51", "51 Пегаса", "Звезда G2IV", BodyCategory.STARS, 50.9 * LY, 0.0, p_51peg.x, p_51peg.y, "", 861_000_000.0, 2.21e30, 0.0, 37.0 * DAY, 5793, 0xFFE080, 0xFF8C1A, true, false, false, "Звезда, у которой открыли первый горячий юпитер."),
		_make_body("hd189733", "HD 189733", "Звезда K2V", BodyCategory.STARS, 64.5 * LY, 0.0, p_hd189.x, p_hd189.y, "", 557_000_000.0, 1.59e30, 0.0, 11.9 * DAY, 5050, 0xFFB058, 0xC84B12, true, false, false, "Оранжевый карлик с синим газовым гигантом."),
		_make_body("aldebaran", "Альдебаран", "Красный гигант K5III", BodyCategory.STARS, 65.3 * LY, 0.0, p_aldebaran.x, p_aldebaran.y, "", 30_640_000_000.0, 2.31e30, 0.0, 643.0 * DAY, 3910, 0xFF7B38, 0xB82800, true, false, false, "Оранжевый гигант «Глаз Тельца»."),
		_make_body("polaris", "Полярная звезда", "Цефеида F7Ib", BodyCategory.STARS, 433.0 * LY, 0.0, p_polaris.x, p_polaris.y, "", 26_110_000_000.0, 1.07e31, 0.0, 119.0 * DAY, 6015, 0xFFF2B8, 0xE6A845, true, false, false, "Сверхгигант над северным полюсом Земли."),
		_make_body("betelgeuse", "Бетельгейзе", "Красный сверхгигант M1Ia", BodyCategory.STARS, 548.0 * LY, 0.0, p_betel.x, p_betel.y, "", 532_000_000_000.0, 3.30e31, 0.0, 13140.0 * DAY, 3600, 0xFF5020, 0x8F1500, true, false, false, "Огромный красный сверхгигант Ориона."),
		_make_body("kepler186", "Kepler-186", "Звезда M1V", BodyCategory.STARS, 582.0 * LY, 0.0, p_k186.x, p_k186.y, "", 364_000_000.0, 1.08e30, 0.0, 33.7 * DAY, 3755, 0xFF6A38, 0xA82208, true, false, false, "Красный карлик в Лебеде с планетой в зоне обитаемости."),
		_make_body("rigel", "Ригель", "Голубой сверхгигант B8Ia", BodyCategory.STARS, 863.0 * LY, 0.0, p_rigel.x, p_rigel.y, "", 54_940_000_000.0, 4.18e31, 0.0, 60.0 * DAY, 12100, 0xB8DAFF, 0x4A90FF, true, false, false, "Голубой сверхгигант Ориона."),
		_make_body("kepler442", "Kepler-442", "Звезда K-типа", BodyCategory.STARS, 1206.0 * LY, 0.0, p_k442.x, p_k442.y, "", 416_000_000.0, 1.21e30, 0.0, 28.0 * DAY, 4402, 0xFF9848, 0xC44A10, true, false, false, "Звезда с одной из лучших суперземель для жизни."),
		_make_body("crab_pulsar", "Пульсар Крабовидной", "Нейтронная звезда", BodyCategory.STARS, 6500.0 * LY, 0.0, p_crab.x, p_crab.y, "", 10_500.0, 2.78e30, 0.45, 0.033, 1_600_000, 0x99EEFF, 0x3377FF, true, false, false, "Пульсар радиусом 10.5 км, вращающийся 30 раз/с."),
		_make_body("uy_scuti", "UY Щита", "Красный гипергигант", BodyCategory.STARS, 5100.0 * LY, 0.0, p_uy.x, p_uy.y, "", 1_189_000_000_000.0, 1.6e31, 0.0, 18250.0 * DAY, 3365, 0xFF4418, 0x7A0E00, true, false, false, "Один из крупнейших известных гипергигантов."),
		_make_body("stephenson2_18", "Stephenson 2-18", "Красный гипергигант", BodyCategory.STARS, 18900.0 * LY, 0.0, p_steph.x, p_steph.y, "", 1_497_000_000_000.0, 2.0e31, 0.0, 21900.0 * DAY, 3200, 0xFF3612, 0x6A0800, true, false, false, "Крупнейший известный красный гипергигант Вселенной."),

		# Экзопланеты (10)
		_make_body("proxima_b", "Proxima b", "Экзопланета (зона обитаемости)", BodyCategory.EXOPLANETS, 0.04856 * AU, 11.186 * DAY, 0.9, 0.02, "proxima", 6_817_000.0, 6.39e24, 0.05, 11.186 * DAY, 268, 0x22689C, 0x4A8C4E, false, true, false, "Ближайшая землеподобная экзопланета.", false, false, 0.70),
		_make_body("trappist1b", "TRAPPIST-1b", "Горячая суперземля", BodyCategory.EXOPLANETS, 0.01154 * AU, 1.5109 * DAY, 0.4, 0.01, "trappist1", 7_110_000.0, 8.20e24, 0.0, 1.5109 * DAY, 400, 0xC86B38, 0x5E2812, false, true, false, "Горячая внутренняя планета TRAPPIST-1.", false, false, 0.90),
		_make_body("trappist1d", "TRAPPIST-1d", "Каменистая экзопланета", BodyCategory.EXOPLANETS, 0.02227 * AU, 4.0492 * DAY, 1.9, -0.01, "trappist1", 4_995_000.0, 2.32e24, 0.02, 4.0492 * DAY, 288, 0xB86442, 0x6E321D, false, true, false, "Каменистая экзопланета у края зоны обитаемости.", false, false, 0.25),
		_make_body("trappist1e", "TRAPPIST-1e", "Обитаемый океанический мир", BodyCategory.EXOPLANETS, 0.02925 * AU, 6.1010 * DAY, 3.4, 0.01, "trappist1", 5_861_000.0, 4.13e24, 0.02, 6.1010 * DAY, 275, 0x1B5EA8, 0x3D8A52, false, true, false, "Кандидат №1 на жидкие океаны в системе TRAPPIST-1.", false, false, 0.72),
		_make_body("trappist1f", "TRAPPIST-1f", "Холодная экзопланета", BodyCategory.EXOPLANETS, 0.03849 * AU, 9.2075 * DAY, 4.9, -0.01, "trappist1", 6_658_000.0, 6.21e24, 0.02, 9.2075 * DAY, 219, 0x8CA8BE, 0x4E6478, false, true, false, "Богатая водой и льдами экзопланета.", false, false, 0.45),
		_make_body("trappist1g", "TRAPPIST-1g", "Суперземля", BodyCategory.EXOPLANETS, 0.04683 * AU, 12.3529 * DAY, 5.7, 0.01, "trappist1", 7_193_000.0, 7.89e24, 0.02, 12.3529 * DAY, 199, 0x7A8FA4, 0x445264, false, true, false, "Крупнейшая планета системы TRAPPIST-1.", false, false, 0.35),
		_make_body("dimidium", "51 Пегаса b (Димидий)", "Горячий юпитер", BodyCategory.EXOPLANETS, 0.0527 * AU, 4.2308 * DAY, 1.2, 0.03, "pegasi51", 132_800_000.0, 8.73e26, 0.02, 4.2308 * DAY, 1284, 0xE8965A, 0x7A2E14, false, true, false, "Исторически первая экзопланета у солнцеподобной звезды.", false, false, 0.85),
		_make_body("hd189733b", "HD 189733 b", "Кобальтовый газовый гигант", BodyCategory.EXOPLANETS, 0.0314 * AU, 2.2186 * DAY, 2.6, 0.02, "hd189733", 79_560_000.0, 2.17e27, 0.02, 2.2186 * DAY, 1200, 0x2255EE, 0x10288A, false, true, false, "Синий горячий юпитер со стеклянными дождями.", false, false, 0.88),
		_make_body("kepler186f", "Kepler-186f", "Экзопланета земного типа", BodyCategory.EXOPLANETS, 0.432 * AU, 129.94 * DAY, 4.0, 0.01, "kepler186", 7_454_000.0, 8.60e24, 0.04, 42.0 * 3600.0, 245, 0x3D6A8A, 0x784E3A, false, true, false, "Первая землеразмерная экзопланета в обитаемой зоне.", false, false, 0.65),
		_make_body("kepler442b", "Kepler-442b", "Обитаемая суперземля", BodyCategory.EXOPLANETS, 0.409 * AU, 112.31 * DAY, 0.7, -0.02, "kepler442", 8_537_000.0, 1.41e25, 0.15, 32.0 * 3600.0, 282, 0x1C6A9E, 0x3E8A44, false, true, false, "Суперземля с индексом ESI 0.84.", false, false, 0.72),

		# Чёрные дыры (4)
		_make_body("sgr_a", "Стрелец A*", "Сверхмассивная ЧД", BodyCategory.BLACK_HOLES, 26_673.0 * LY, 0.0, p_sgr.x, p_sgr.y, "", 12_000_000_000.0, 8.26e36, 0.4, 600.0, 0, 0x000000, 0xFF8811, false, false, true, "Чёрная дыра в центре Млечного Пути (~4.15 млн масс Солнца).", true, false, 0.0),
		_make_body("cygnus_x1", "Лебедь X-1", "ЧД звёздной массы", BodyCategory.BLACK_HOLES, 7_200.0 * LY, 0.0, p_cyg.x, p_cyg.y, "", 62_600.0, 4.215e31, 0.52, 120.0, 0, 0x000000, 0x55AAFF, false, false, true, "Рентгеновская чёрная дыра (~21.2 массы Солнца).", true, false, 0.0),
		_make_body("m87_star", "M87* (Повехи)", "Сверхмассивная ЧД", BodyCategory.BLACK_HOLES, 53_500_000.0 * LY, 0.0, p_m87.x, p_m87.y, "", 19_200_000_000_000.0, 1.29e40, 0.30, 86_400.0, 0, 0x000000, 0xFF6600, false, false, true, "Чёрная дыра галактики M87 (~6.5 млрд масс Солнца).", true, false, 0.0),
		_make_body("ton618", "TON 618", "Ультрамассивная ЧД", BodyCategory.BLACK_HOLES, 10_370_000_000.0 * LY, 0.0, p_ton.x, p_ton.y, "", 120_000_000_000_000.0, 8.09e40, 0.42, 172_800.0, 0, 0x000000, 0xFFAA33, false, false, true, "Одна из крупнейших известных чёрных дыр (~40.7 млрд масс Солнца).", true, false, 0.0),

		# Галактики (7)
		_make_body("milky_way", "Млечный Путь", "Спиральная галактика SBbc", BodyCategory.GALAXIES, 26_673.0 * LY, 0.0, p_sgr.x, p_sgr.y, "", 52_850.0 * LY, 2.3e42, 0.48, 0.0, 0, 0xFFE6B8, 0x6AA8FF, false, false, false, "Наша спиральная галактика (~105 700 св. лет).", false, true, 0.0),
		_make_body("lmc", "Большое Магелланово Облако", "Карликовая галактика", BodyCategory.GALAXIES, 163_000.0 * LY, 0.0, p_lmc.x, p_lmc.y, "", 16_100.0 * LY, 2.7e41, 0.62, 0.0, 0, 0xDDEEFF, 0xFF88AA, false, false, false, "Крупнейший спутник Млечного Пути.", false, true, 0.0),
		_make_body("m31", "Туманность Андромеды (M31)", "Спиральная галактика SA(s)b", BodyCategory.GALAXIES, 2_537_000.0 * LY, 0.0, p_m31.x, p_m31.y, "", 110_000.0 * LY, 3.0e42, 0.85, 0.0, 0, 0xFFE8C4, 0x7AB4FF, false, false, false, "Крупнейшая галактика Местной группы (~1 трлн звёзд).", false, true, 0.0),
		_make_body("m33", "Галактика Треугольника (M33)", "Спиральная галактика SA(s)cd", BodyCategory.GALAXIES, 2_730_000.0 * LY, 0.0, p_m33.x, p_m33.y, "", 30_000.0 * LY, 1.0e41, 0.55, 0.0, 0, 0xD8ECFF, 0x629EFF, false, false, false, "Третья галактика Местной группы.", false, true, 0.0),
		_make_body("m51", "Галактика Водоворот (M51)", "Спиральная галактика SA(s)bc", BodyCategory.GALAXIES, 31_000_000.0 * LY, 0.0, p_m51.x, p_m51.y, "", 38_000.0 * LY, 3.2e41, 0.35, 0.0, 0, 0xFFF0D4, 0x68ACFF, false, false, false, "Эталонная спиральная галактика в Гончих Псах.", false, true, 0.0),
		_make_body("m104", "Галактика Сомбреро (M104)", "Линзовидная SA(s)a", BodyCategory.GALAXIES, 31_100_000.0 * LY, 0.0, p_m104.x, p_m104.y, "", 25_000.0 * LY, 1.6e42, 1.38, 0.0, 0, 0xFFE2A8, 0xD48844, false, false, false, "Галактика с массивным балджем и пылевой полосой.", false, true, 0.0),
		_make_body("ic1101", "IC 1101", "Сверхгигантская эллиптическая", BodyCategory.GALAXIES, 1_045_000_000.0 * LY, 0.0, p_ic1101.x, p_ic1101.y, "", 2_000_000.0 * LY, 2.0e44, 0.30, 0.0, 0, 0xFFD998, 0xD89050, false, false, false, "Гигантская галактика диаметром ~4 млн св. лет.", false, true, 0.0),
	]
	Engine.set_meta(&"space3d_bodies", list)
	return list

static func find_body(id: String) -> Dictionary:
	for b in get_bodies():
		if b["id"] == id:
			return b
	return get_bodies()[0]

static func get_body_pos(body: Dictionary, sim_time: float, cache: Dictionary = {}) -> PackedFloat64Array:
	var bid: String = body["id"]
	if cache.has(bid):
		return cache[bid]
	var pid: String = body["parent_id"]
	var parent_pos := v64(0.0, 0.0, 0.0)
	if pid != "":
		if cache.has(pid):
			parent_pos = cache[pid]
		else:
			var parent := find_body(pid)
			parent_pos = get_body_pos(parent, sim_time, cache)
	var sma: float = body["semi_major_axis_m"]
	if sma <= 0.0:
		cache[bid] = parent_pos
		return parent_pos
	var period: float = body["orbital_period_s"]
	var angle: float = body["initial_phase_rad"]
	if period > 0.0:
		angle += (TAU / period) * sim_time
	var lat: float = body["latitude_rad"]
	var cos_lat: float = cos(lat)
	var res := v64(
		parent_pos[0] + cos(angle) * cos_lat * sma,
		parent_pos[1] + sin(lat) * sma,
		parent_pos[2] - sin(angle) * cos_lat * sma
	)
	cache[bid] = res
	return res

static func orbit_point(body: Dictionary, angle: float, parent_pos: PackedFloat64Array) -> PackedFloat64Array:
	var sma: float = body["semi_major_axis_m"]
	var lat: float = body["latitude_rad"]
	var cos_lat: float = cos(lat)
	return v64(
		parent_pos[0] + cos(angle) * cos_lat * sma,
		parent_pos[1] + sin(lat) * sma,
		parent_pos[2] - sin(angle) * cos_lat * sma
	)

static func planet_quat(body: Dictionary, sim_time: float) -> Quaternion:
	var period: float = body["rotation_period_s"]
	var wrapped: float = 0.0
	if period != 0.0:
		wrapped = fmod((TAU / period) * sim_time, TAU)
	var q_tilt := Quaternion(Vector3(0, 0, 1), body["axial_tilt_rad"])
	var q_spin := Quaternion(Vector3(0, 1, 0), wrapped)
	return (q_tilt * q_spin).normalized()

static func rotate_body_local_to_world64(body: Dictionary, sim_time: float, v64: PackedFloat64Array) -> PackedFloat64Array:
	var period: float = body["rotation_period_s"]
	var spin_ang: float = fmod((TAU / period) * sim_time, TAU) if period != 0.0 else 0.0
	var tilt: float = body["axial_tilt_rad"]
	var cs: float = cos(spin_ang)
	var sn: float = sin(spin_ang)
	var x1: float = v64[0] * cs + v64[2] * sn
	var y1: float = v64[1]
	var z1: float = -v64[0] * sn + v64[2] * cs
	var ct: float = cos(tilt)
	var st: float = sin(tilt)
	return v64(x1 * ct - y1 * st, x1 * st + y1 * ct, z1)

static func rotate_body_world_to_local64(body: Dictionary, sim_time: float, v64: PackedFloat64Array) -> PackedFloat64Array:
	var period: float = body["rotation_period_s"]
	var spin_ang: float = fmod((TAU / period) * sim_time, TAU) if period != 0.0 else 0.0
	var tilt: float = body["axial_tilt_rad"]
	var ct: float = cos(-tilt)
	var st: float = sin(-tilt)
	var x1: float = v64[0] * ct - v64[1] * st
	var y1: float = v64[0] * st + v64[1] * ct
	var z1: float = v64[2]
	var cs: float = cos(-spin_ang)
	var sn: float = sin(-spin_ang)
	return v64(x1 * cs + z1 * sn, y1, -x1 * sn + z1 * cs)

static func format_distance(meters: float) -> String:
	if meters < 1_000.0:
		return "%.0f м" % meters
	var km: float = meters / 1_000.0
	if km < 1_000.0:
		return "%.1f км" % km
	if km < 1_000_000.0:
		return "%.1f тыс. км" % (km / 1_000.0)
	var au_val: float = meters / AU
	if au_val < 10_000.0:
		return "%.3f а.е." % au_val
	var ly_val: float = meters / LY
	if ly_val < 1_000.0:
		return "%.2f св. лет" % ly_val
	if ly_val < 1_000_000.0:
		return "%.1f тыс. св.л" % (ly_val / 1_000.0)
	if ly_val < 1_000_000_000.0:
		return "%.2f млн св.л" % (ly_val / 1_000_000.0)
	return "%.2f млрд св.л" % (ly_val / 1_000_000_000.0)

static func format_speed(mps: float) -> String:
	if mps < 1_000.0:
		return "%.0f м/с" % mps
	var kms: float = mps / 1_000.0
	if kms < 100_000.0:
		return "%.1f км/с" % kms
	var c_val: float = mps / C_LIGHT
	if c_val < 10_000.0:
		return "%.2f c" % c_val
	var lys: float = mps / LY
	if lys >= 1_000_000.0:
		return "%.2f млн св.л/с" % (lys / 1_000_000.0)
	if lys >= 1_000.0:
		return "%.1f тыс. св.л/с" % (lys / 1_000.0)
	if lys >= 0.01:
		return "%.2f св.л/с" % lys
	return "%.0f тыс. c" % (c_val / 1_000.0)

static func format_time(sec: float) -> String:
	if sec < 60.0:
		return "%.0f сек" % sec
	if sec < 3600.0:
		return "%.1f мин" % (sec / 60.0)
	if sec < 86400.0:
		return "%.1f ч" % (sec / 3600.0)
	return "%.1f дн." % (sec / 86400.0)
