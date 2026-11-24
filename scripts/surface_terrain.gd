class_name SurfaceTerrain
extends RefCounted

class TerrainCollision:
	var body_id: String
	var grid_n: int
	var u_coords: PackedFloat64Array
	var v_coords: PackedFloat64Array
	var east: PackedFloat64Array
	var north: PackedFloat64Array
	var up_world: PackedFloat64Array
	var build_rot: Quaternion
	var body_radius: float
	var patch_half_extent: float
	var vertex_heights: PackedFloat64Array
	var is_habitable: bool

	func sample_height(world_pos64: PackedFloat64Array, cur_rot: Quaternion, cur_body_pos64: PackedFloat64Array) -> Variant:
		var rel := UniverseCatalog.v64_sub(world_pos64, cur_body_pos64)
		var inv_delta: Quaternion = (build_rot * cur_rot.inverse()).normalized()
		var raw_build := UniverseCatalog.quat_act_v64(inv_delta, rel)
		if UniverseCatalog.v64_len_sq(raw_build) <= 1e-12:
			return null
		var dir_build := UniverseCatalog.v64_norm(raw_build)
		var d_up: float = UniverseCatalog.v64_dot(dir_build, up_world)
		if d_up <= 0.1:
			return null

		var u_norm: float = ((UniverseCatalog.v64_dot(dir_build, east) / d_up) * body_radius) / patch_half_extent
		var v_norm: float = ((UniverseCatalog.v64_dot(dir_build, north) / d_up) * body_radius) / patch_half_extent

		if u_norm < u_coords[0] or u_norm > u_coords[grid_n - 1] or v_norm < v_coords[0] or v_norm > v_coords[grid_n - 1]:
			return null

		var ix: int = _find_cell(u_coords, u_norm, grid_n)
		var iz: int = _find_cell(v_coords, v_norm, grid_n)

		var fx: float = (u_norm - u_coords[ix]) / max(1e-12, u_coords[ix + 1] - u_coords[ix])
		var fz: float = (v_norm - v_coords[iz]) / max(1e-12, v_coords[iz + 1] - v_coords[iz])

		var h00: float = vertex_heights[iz * grid_n + ix]
		var h10: float = vertex_heights[iz * grid_n + (ix + 1)]
		var h01: float = vertex_heights[(iz + 1) * grid_n + ix]
		var h11: float = vertex_heights[(iz + 1) * grid_n + (ix + 1)]

		var h: float
		if fx >= fz:
			h = h00 + fx * (h10 - h00) + fz * (h11 - h10)
		else:
			h = h00 + fz * (h01 - h00) + fx * (h11 - h01)
		return max(0.0, h) if is_habitable else h

	func _find_cell(coords: PackedFloat64Array, val: float, count: int) -> int:
		var lo: int = 0
		var hi: int = count - 2
		while lo < hi:
			var mid: int = (lo + hi + 1) >> 1
			if coords[mid] <= val:
				lo = mid
			else:
				hi = mid - 1
		return clampi(lo, 0, count - 2)

static func _hash31(ix: int, iy: int, iz: int, seed: int = 0) -> float:
	var h: int = ((ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)) & 0x7FFFFFFF
	h = (h ^ (h >> 13)) & 0x7FFFFFFF
	h = ((h * 1274126177) ^ (h >> 16)) & 0x7FFFFFFF
	return float(h & 0xFFFFFF) / 16777216.0

static func _value_noise3d(p: Vector3) -> float:
	var fx: float = floor(p.x)
	var fy: float = floor(p.y)
	var fz: float = floor(p.z)
	var ix: int = int(fx)
	var iy: int = int(fy)
	var iz: int = int(fz)
	var dx: float = p.x - fx
	var dy: float = p.y - fy
	var dz: float = p.z - fz
	var ux: float = dx * dx * (3.0 - 2.0 * dx)
	var uy: float = dy * dy * (3.0 - 2.0 * dy)
	var uz: float = dz * dz * (3.0 - 2.0 * dz)

	var n000 := _hash31(ix, iy, iz)
	var n100 := _hash31(ix + 1, iy, iz)
	var n010 := _hash31(ix, iy + 1, iz)
	var n110 := _hash31(ix + 1, iy + 1, iz)
	var n001 := _hash31(ix, iy, iz + 1)
	var n101 := _hash31(ix + 1, iy, iz + 1)
	var n011 := _hash31(ix, iy + 1, iz + 1)
	var n111 := _hash31(ix + 1, iy + 1, iz + 1)

	var nx00: float = n000 + (n100 - n000) * ux
	var nx10: float = n010 + (n110 - n010) * ux
	var nx01: float = n001 + (n101 - n001) * ux
	var nx11: float = n011 + (n111 - n011) * ux
	var nxy0: float = nx00 + (nx10 - nx00) * uy
	var nxy1: float = nx01 + (nx11 - nx01) * uy
	return nxy0 + (nxy1 - nxy0) * uz

static func _fbm3d(p: Vector3, octaves: int) -> float:
	var q := p
	var v: float = 0.0
	var a: float = 0.5
	for _i in octaves:
		v += a * _value_noise3d(q)
		q = q * 2.07 + Vector3(13.1, 7.4, 19.7)
		a *= 0.49
	return v

static func _ridged_fbm3d(p: Vector3, octaves: int) -> float:
	var q := p
	var v: float = 0.0
	var a: float = 0.5
	var norm_s: float = 0.0
	for _i in octaves:
		var r: float = 1.0 - abs(_value_noise3d(q) * 2.0 - 1.0)
		v += a * (r * r)
		norm_s += a
		q = q * 2.13 + Vector3(7.7, 17.3, 11.9)
		a *= 0.5
	return (v / norm_s) if norm_s > 0.0 else 0.0

static func _crater_field3d(p: Vector3) -> float:
	var cx: int = int(floor(p.x))
	var cy: int = int(floor(p.y))
	var cz: int = int(floor(p.z))
	var delta: float = 0.0
	for dz in range(-1, 2):
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var ix: int = cx + dx
				var iy: int = cy + dy
				var iz: int = cz + dz
				var prob := _hash31(ix, iy, iz, 11)
				if prob < 0.44:
					continue
				var center := Vector3(
					float(ix) + 0.18 + 0.64 * _hash31(ix, iy, iz, 23),
					float(iy) + 0.18 + 0.64 * _hash31(ix, iy, iz, 37),
					float(iz) + 0.18 + 0.64 * _hash31(ix, iy, iz, 53)
				)
				var rad: float = 0.16 + 0.24 * _hash31(ix, iy, iz, 71)
				var dist: float = p.distance_to(center) / rad
				if dist < 1.35:
					var w: float = 0.45 + 0.55 * prob
					var bowl: float = (dist * dist - 1.0) * 0.85 if dist < 1.0 else 0.0
					var rt: float = (dist - 1.0) * 5.2
					var rim: float = exp(-(rt * rt)) * 0.36
					delta += (bowl + rim) * w
	return clampf(delta, -1.2, 0.8)

static func sample_terrain(local_dir: Vector3, body: Dictionary) -> Dictionary:
	var dir := local_dir.normalized() if local_dir.length_squared() > 1e-12 else Vector3.UP
	var lat: float = abs(dir.y)
	var r: float = body["radius_m"]
	var scale800: float = max(12.0, r / 800.0)
	var scale140: float = max(60.0, r / 140.0)
	var bid: String = body["id"]

	if body["is_habitable"]:
		var n := _fbm3d(dir * 3.6, 4)
		var warp := _fbm3d(dir * 2.2 + Vector3(4.1, 1.7, 8.3), 3) * 0.25
		var elev := n + warp - 0.12
		var detail := _fbm3d(dir * 18.0, 3)

		if lat + detail * 0.10 > 0.84:
			var local_h := (_fbm3d(dir * scale800, 3) - 0.45) * 90.0 + (_value_noise3d(dir * scale140) - 0.5) * 11.0
			return {"height": max(8.0, 60.0 + detail * 480.0 + local_h), "color": Color(0.84, 0.88, 0.92), "is_water": false}

		if elev < 0.475:
			var depth_n := clampf(elev / 0.475, 0.0, 1.0)
			var col := Color(0.01, 0.05, 0.16).lerp(Color(0.03, 0.22, 0.42), depth_n * depth_n)
			return {"height": (elev - 0.475) * 4_500.0, "color": col, "is_water": true}

		var land_f: float = max(0.0, (elev - 0.475) / 0.44)
		var m_mask := smoothstep(0.18, 0.72, land_f)
		var ridges := _ridged_fbm3d(dir * 28.0, 4)
		var hills := _fbm3d(dir * 140.0, 3)
		var loc_h := (_fbm3d(dir * scale800, 3) - 0.45) * 140.0
		var mic_h := (_value_noise3d(dir * scale140) - 0.5) * 13.0
		var h: float = max(2.0, land_f * 1_200.0 + ridges * m_mask * 4_400.0 + hills * 480.0 + loc_h + mic_h)

		var arid := smoothstep(0.06, 0.30, absf(lat - 0.26)) * smoothstep(0.18, 0.78, detail)
		var col := Color(0.92, 0.86, 0.72).lerp(Color(0.84, 0.92, 0.76).lerp(Color(0.72, 0.84, 0.66), detail), arid)
		if bid == "proxima_b" or bid == "kepler186f":
			col = col.lerp(Color(0.82, 0.68, 0.64), 0.35)
		col = Color(0.95, 0.90, 0.76).lerp(col, smoothstep(8.0, 55.0, h))
		col = col.lerp(Color(0.58, 0.56, 0.54), smoothstep(1_150.0, 2_200.0, h))
		col = col.lerp(Color(0.95, 0.97, 1.0), smoothstep(2_800.0, 3_900.0, h + lat * 680.0))
		return {"height": h, "color": col, "is_water": false}

	if body["is_icy"]:
		var base := _fbm3d(dir * 4.0, 4)
		var ridges := _ridged_fbm3d(dir * 20.0, 4)
		var loc_r := (_ridged_fbm3d(dir * scale800, 3) - 0.35) * 140.0
		var craters := _crater_field3d(dir * 26.0) * 900.0
		var mic := (_value_noise3d(dir * scale140) - 0.5) * 11.0
		var h: float = (base - 0.48) * 1_800.0 + ridges * 1_600.0 + craters + loc_r + mic
		var col := Color(0.68, 0.80, 0.92).lerp(Color(0.88, 0.93, 0.98), smoothstep(-700.0, 900.0, h))
		col = col.lerp(Color(0.98, 0.99, 1.0), smoothstep(1_000.0, 2_400.0, h))
		return {"height": h, "color": col, "is_water": false}

	if bid == "mars" or bid == "trappist1d":
		var base := _fbm3d(dir * 3.8, 4)
		var ridges := _ridged_fbm3d(dir * 19.0, 4)
		var mic_f := _fbm3d(dir * 110.0, 3)
		var craters := _crater_field3d(dir * 34.0)
		var loc_r := (_ridged_fbm3d(dir * scale800, 3) - 0.35) * 160.0
		var mic_b := (_value_noise3d(dir * scale140) - 0.5) * 12.0
		var h: float = (base - 0.48) * 3_800.0 + ridges * 3_200.0 + craters * 950.0 + (mic_f - 0.45) * 420.0 + loc_r + mic_b
		var col := Color(0.68, 0.56, 0.50).lerp(Color(0.92, 0.82, 0.74), smoothstep(-700.0, 1_500.0, h))
		col = col.lerp(Color(0.98, 0.88, 0.78), smoothstep(1_200.0, 4_200.0, h + ridges * 700.0))
		if lat + mic_f * 0.09 > 0.86:
			col = Color(0.96, 0.95, 0.94)
		return {"height": h, "color": col, "is_water": false}

	if bid in ["moon", "mercury", "ceres", "phobos"]:
		var maria := _fbm3d(dir * 3.2, 4)
		var rough := _fbm3d(dir * 26.0, 3)
		var c_big := _crater_field3d(dir * 16.0)
		var c_small := _crater_field3d(dir * 52.0)
		var c_loc := _crater_field3d(dir * scale800) * 110.0
		var mic_b := (_value_noise3d(dir * scale140) - 0.5) * 10.0
		var amp := 0.25 if bid == "phobos" else 1.0
		var h: float = ((maria - 0.48) * 2_400.0 + (rough - 0.45) * 850.0 + c_big * 2_200.0 + c_small * 650.0) * amp + c_loc + mic_b
		var is_merc := bid == "mercury" or bid == "phobos"
		var c_dark := Color(0.62, 0.60, 0.58) if is_merc else Color(0.58, 0.60, 0.62)
		var c_mid := Color(0.80, 0.78, 0.75) if is_merc else Color(0.82, 0.83, 0.85)
		var c_hi := Color(0.96, 0.94, 0.90) if is_merc else Color(0.96, 0.97, 0.99)
		var col := c_dark.lerp(c_mid, smoothstep(-1_200.0 * amp, 1_400.0 * amp, h))
		col = col.lerp(c_hi, smoothstep(0.05, 0.42, maxf(0.0, c_big + c_small * 0.5) + (rough - 0.45) * 0.35))
		return {"height": h, "color": col, "is_water": false}

	# Вулканические / Титан / прочие
	var p_base := _fbm3d(dir * 4.2, 4)
	var v_ridge := _ridged_fbm3d(dir * 22.0, 4)
	var loc_rv := (_ridged_fbm3d(dir * scale800, 3) - 0.35) * 155.0
	var loc_bv := (_value_noise3d(dir * scale140) - 0.5) * 12.0
	var hv: float = (p_base - 0.48) * 2_800.0 + v_ridge * 2_800.0 + loc_rv + loc_bv
	var base_c: Color = body["color"]
	var colv := base_c.darkened(0.35).lerp(base_c, smoothstep(-400.0, 2_200.0, hv))
	return {"height": hv, "color": colv, "is_water": false}

static func find_scenic_approach_dir(body: Dictionary, body_pos64: PackedFloat64Array, inv_rot: Quaternion) -> Vector3:
	var raw_to_sun := Vector3(-body_pos64[0], -body_pos64[1], -body_pos64[2])
	var to_sun := raw_to_sun.normalized() if raw_to_sun.length_squared() > 1e6 else Vector3(0.6, 0.25, 0.75).normalized()
	var ref_ax := Vector3(1, 0, 0) if abs(to_sun.y) > 0.9 else Vector3(0, 1, 0)
	var right := ref_ax.cross(to_sun).normalized()
	var up := to_sun.cross(right).normalized()
	var def_dir := (to_sun * 0.46 + right * 0.84 + up * 0.26).normalized()
	if not body["is_habitable"]:
		return def_dir

	var fallback_dir := def_dir
	var best_h := -1e9
	for i in range(24):
		var az := float(i) * (PI / 12.0)
		var cand := (to_sun * 0.46 + (right * cos(az) + up * sin(az)) * 0.88).normalized()
		var local_d := inv_rot * cand
		var s := sample_terrain(local_d, body)
		if not s["is_water"]:
			if abs(local_d.y) >= 0.20 and abs(local_d.y) <= 0.68 and s["height"] > 220.0 and s["height"] < 1_400.0:
				return cand
			if s["height"] > best_h:
				best_h = s["height"]
				fallback_dir = cand
	return fallback_dir

static func _theme_key(body: Dictionary) -> String:
	if body["is_habitable"]:
		return "habitable"
	var bid: String = body["id"]
	if bid == "mars" or bid == "trappist1d":
		return "mars"
	if body["is_icy"]:
		return "icy"
	if bid in ["venus", "trappist1b", "titan", "io"]:
		return "volcanic"
	return "lunar"

static func _periodic_noise2d(u: float, v: float, period: int, seed: int) -> float:
	var mask: int = period - 1
	var x: float = u * float(period)
	var y: float = v * float(period)
	var fx := floorf(x)
	var fy := floorf(y)
	var dx := x - fx
	var dy := y - fy
	var ux := dx * dx * (3.0 - 2.0 * dx)
	var uy := dy * dy * (3.0 - 2.0 * dy)
	var ix := int(fx)
	var iy := int(fy)
	var n00 := _hash31(ix & mask, iy & mask, period, seed)
	var n10 := _hash31((ix + 1) & mask, iy & mask, period, seed)
	var n01 := _hash31(ix & mask, (iy + 1) & mask, period, seed)
	var n11 := _hash31((ix + 1) & mask, (iy + 1) & mask, period, seed)
	return (n00 + (n10 - n00) * ux) + ((n01 + (n11 - n01) * ux) - (n00 + (n10 - n00) * ux)) * uy

static func surface_pbr_textures(body: Dictionary) -> Dictionary:
	var cache: Dictionary = Engine.get_meta(&"space3d_pbr_cache") if Engine.has_meta(&"space3d_pbr_cache") else {}
	var key := _theme_key(body)
	if cache.has(key):
		return cache[key]

	var diff_path := "res://textures/surface/rock_ground_02_diff_1k.jpg"
	var norm_path := "res://textures/surface/rock_ground_02_nor_gl_1k.jpg"
	match key:
		"habitable":
			diff_path = "res://textures/surface/aerial_grass_rock_diff_1k.jpg"
			norm_path = "res://textures/surface/aerial_grass_rock_nor_gl_1k.jpg"
		"mars":
			diff_path = "res://textures/surface/red_sand_diff_1k.jpg"
			norm_path = "res://textures/surface/red_sand_nor_gl_1k.jpg"
		"icy":
			diff_path = "res://textures/surface/snow_02_diff_1k.jpg"
			norm_path = "res://textures/surface/snow_02_nor_gl_1k.jpg"

	var res := {
		"diffuse": load(diff_path),
		"normal": load(norm_path),
	}
	cache[key] = res
	Engine.set_meta(&"space3d_pbr_cache", cache)
	return res

static func _project_km_uv(local_dir: Vector3, dom_axis: int, radius_km: float) -> Vector2:
	match dom_axis:
		1: return Vector2(local_dir.x * radius_km, local_dir.z * radius_km)
		0: return Vector2(local_dir.z * radius_km, local_dir.y * radius_km)
		_: return Vector2(local_dir.x * radius_km, local_dir.y * radius_km)

static func _append_outward_tri(i0: int, i1: int, i2: int, pos_arr: PackedVector3Array, up_f: Vector3, indices: PackedInt32Array) -> void:
	var v0 := pos_arr[i0]
	var v1 := pos_arr[i1]
	var v2 := pos_arr[i2]
	var cross_v := (v1 - v0).cross(v2 - v0)
	if cross_v.dot(up_f) <= 0.0:
		indices.append(i0); indices.append(i1); indices.append(i2)
	else:
		indices.append(i0); indices.append(i2); indices.append(i1)

static func build_terrain_mesh(
	body: Dictionary,
	body_pos64: PackedFloat64Array,
	anchor_pos64: PackedFloat64Array,
	planet_rot: Quaternion,
	inv_rot: Quaternion,
	altitude_m: float,
	compress_fn: Callable
) -> Dictionary:
	var raw_up := UniverseCatalog.v64_sub(anchor_pos64, body_pos64)
	var up64 := UniverseCatalog.v64_norm(raw_up)
	var up_f := UniverseCatalog.v64_to_vec3(up64).normalized()
	var ref_ax := Vector3(1, 0, 0) if abs(up_f.y) > 0.95 else Vector3(0, 1, 0)
	var north_f := up_f.cross(ref_ax).normalized()
	var east_f := north_f.cross(up_f).normalized()
	var east64 := UniverseCatalog.v64(east_f.x, east_f.y, east_f.z)
	var north64 := UniverseCatalog.v64(north_f.x, north_f.y, north_f.z)

	var local_up := inv_rot * up_f
	var ax := absf(local_up.x)
	var ay := absf(local_up.y)
	var az := absf(local_up.z)
	var dom_axis: int = 1 if (ay >= ax and ay >= az) else (0 if (ax >= ay and ax >= az) else 2)
	var r_m: float = body["radius_m"]
	var r_km: float = r_m / 1_000.0
	var anchor_uv := _project_km_uv(local_up, dom_axis, r_km)
	var uv_ox: float = floor(anchor_uv.x)
	var uv_oy: float = floor(anchor_uv.y)

	var is_low := altitude_m < 1_500.0
	var grid_n: int = 65 if is_low else 49
	var v_count: int = grid_n * grid_n
	var horizon: float = sqrt(maxf(1.0, 2.0 * r_m * maxf(50.0, altitude_m)))
	var patch_half: float = minf(r_m * 0.30, maxf(12_000.0, horizon * 1.15)) if is_low else minf(r_m * 0.36, maxf(22_000.0, horizon * 1.05))

	var u_coords := PackedFloat64Array()
	var v_coords := PackedFloat64Array()
	u_coords.resize(grid_n)
	v_coords.resize(grid_n)
	for i in range(grid_n):
		var t: float = (float(i) / float(grid_n - 1)) * 2.0 - 1.0
		var sgn: float = 1.0 if t >= 0.0 else -1.0
		var c: float = sgn * (0.015 * absf(t) + 0.985 * absf(t * t * t)) if is_low else sgn * (0.12 * absf(t) + 0.88 * t * t)
		u_coords[i] = c
		v_coords[i] = c

	var pos_arr := PackedVector3Array()
	pos_arr.resize(v_count)
	var norm_arr := PackedVector3Array()
	norm_arr.resize(v_count)
	var uv_arr := PackedVector2Array()
	uv_arr.resize(v_count)
	var col_arr := PackedColorArray()
	col_arr.resize(v_count)
	var v_heights := PackedFloat64Array()
	v_heights.resize(v_count)

	for iz in range(grid_n):
		var v := v_coords[iz]
		for ix in range(grid_n):
			var u := u_coords[ix]
			var off := UniverseCatalog.v64_add(UniverseCatalog.v64_scale(east64, u * patch_half), UniverseCatalog.v64_scale(north64, v * patch_half))
			var dir64 := UniverseCatalog.v64_norm(UniverseCatalog.v64_add(UniverseCatalog.v64_scale(up64, r_m), off))
			var dir_f := UniverseCatalog.v64_to_vec3(dir64)
			var local_dir := inv_rot * dir_f
			var samp := sample_terrain(local_dir, body)
			var raw_h: float = (samp["height"] - 28.0) if samp["is_water"] else samp["height"]
			var vh: float = max(-120.0, raw_h) if body["is_habitable"] else samp["height"]
			var pt64 := UniverseCatalog.v64_add(body_pos64, UniverseCatalog.v64_scale(dir64, r_m + vh))
			var comp: Dictionary = compress_fn.call(UniverseCatalog.v64_sub(pt64, anchor_pos64))

			var idx := iz * grid_n + ix
			pos_arr[idx] = comp["pos"]
			v_heights[idx] = vh
			var r_uv := _project_km_uv(local_dir, dom_axis, r_km)
			uv_arr[idx] = Vector2(r_uv.x - uv_ox, r_uv.y - uv_oy)
			col_arr[idx] = samp["color"]

	for iz in range(grid_n):
		for ix in range(grid_n):
			var idx := iz * grid_n + ix
			var pL := pos_arr[iz * grid_n + maxi(0, ix - 1)]
			var pR := pos_arr[iz * grid_n + mini(grid_n - 1, ix + 1)]
			var pD := pos_arr[maxi(0, iz - 1) * grid_n + ix]
			var pU := pos_arr[mini(grid_n - 1, iz + 1) * grid_n + ix]
			var n := (pR - pL).cross(pU - pD)
			if n.length_squared() < 1e-12:
				n = up_f
			else:
				n = n.normalized()
				if n.dot(up_f) < 0.0:
					n = -n
			norm_arr[idx] = n

	var indices := PackedInt32Array()
	for iz in range(grid_n - 1):
		for ix in range(grid_n - 1):
			var i00 := iz * grid_n + ix
			var i10 := iz * grid_n + (ix + 1)
			var i01 := (iz + 1) * grid_n + ix
			var i11 := (iz + 1) * grid_n + (ix + 1)
			_append_outward_tri(i00, i10, i11, pos_arr, up_f, indices)
			_append_outward_tri(i00, i11, i01, pos_arr, up_f, indices)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos_arr
	arrays[Mesh.ARRAY_NORMAL] = norm_arr
	arrays[Mesh.ARRAY_TEX_UV] = uv_arr
	arrays[Mesh.ARRAY_COLOR] = col_arr
	arrays[Mesh.ARRAY_INDEX] = indices
	var terrain_mesh := ArrayMesh.new()
	terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var tex := surface_pbr_textures(body)
	var t_mat := StandardMaterial3D.new()
	t_mat.vertex_color_use_as_albedo = true
	t_mat.albedo_texture = tex["diffuse"]
	t_mat.normal_enabled = true
	t_mat.normal_texture = tex["normal"]
	t_mat.normal_scale = 1.15
	t_mat.uv1_scale = Vector3(110.0, 110.0, 1.0)
	t_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	t_mat.roughness = 0.45 if body["is_icy"] else 0.88
	t_mat.metallic = 0.02

	var ocean_mesh: ArrayMesh = null
	var ocean_mat: Material = null
	if body["is_habitable"]:
		var ocean_res := _build_ocean_mesh(body, body_pos64, anchor_pos64, inv_rot, up64, east64, north64, up_f, patch_half, compress_fn, dom_axis, r_km, uv_ox, uv_oy)
		ocean_mesh = ocean_res["mesh"]
		ocean_mat = ocean_res["mat"]

	var cloud_mesh: ArrayMesh = null
	var cloud_mat: StandardMaterial3D = null
	if float(body["cloud_coverage"]) > 0.20:
		var cl_res := _build_cloud_deck_mesh(body, body_pos64, anchor_pos64, up64, east64, north64, up_f, patch_half, compress_fn)
		cloud_mesh = cl_res["mesh"]
		cloud_mat = cl_res["mat"]

	var collision := TerrainCollision.new()
	collision.body_id = body["id"]
	collision.grid_n = grid_n
	collision.u_coords = u_coords
	collision.v_coords = v_coords
	collision.east = east64
	collision.north = north64
	collision.up_world = up64
	collision.build_rot = planet_rot
	collision.body_radius = r_m
	collision.patch_half_extent = patch_half
	collision.vertex_heights = v_heights
	collision.is_habitable = body["is_habitable"]

	return {
		"terrain_mesh": terrain_mesh,
		"terrain_mat": t_mat,
		"ocean_mesh": ocean_mesh,
		"ocean_mat": ocean_mat,
		"cloud_mesh": cloud_mesh,
		"cloud_mat": cloud_mat,
		"collision": collision,
	}

static func _build_cloud_deck_mesh(
	body: Dictionary,
	body_pos64: PackedFloat64Array,
	anchor_pos64: PackedFloat64Array,
	up64: PackedFloat64Array,
	east64: PackedFloat64Array,
	north64: PackedFloat64Array,
	up_f: Vector3,
	patch_half: float,
	compress_fn: Callable
) -> Dictionary:
	var n_c := 25
	var r_m: float = float(body["radius_m"]) + 7_500.0
	var pos_arr := PackedVector3Array(); pos_arr.resize(n_c * n_c)
	var norm_arr := PackedVector3Array(); norm_arr.resize(n_c * n_c)
	var uv_arr := PackedVector2Array(); uv_arr.resize(n_c * n_c)

	for iz in range(n_c):
		var tz := (float(iz) / float(n_c - 1)) * 2.0 - 1.0
		for ix in range(n_c):
			var tx := (float(ix) / float(n_c - 1)) * 2.0 - 1.0
			var off := UniverseCatalog.v64_add(UniverseCatalog.v64_scale(east64, tx * patch_half * 1.4), UniverseCatalog.v64_scale(north64, tz * patch_half * 1.4))
			var dir64 := UniverseCatalog.v64_norm(UniverseCatalog.v64_add(UniverseCatalog.v64_scale(up64, r_m), off))
			var pt64 := UniverseCatalog.v64_add(body_pos64, UniverseCatalog.v64_scale(dir64, r_m))
			var comp: Dictionary = compress_fn.call(UniverseCatalog.v64_sub(pt64, anchor_pos64))
			var idx := iz * n_c + ix
			pos_arr[idx] = comp["pos"]
			norm_arr[idx] = UniverseCatalog.v64_to_vec3(dir64)
			uv_arr[idx] = Vector2(tx * 2.5, tz * 2.5)

	var indices := PackedInt32Array()
	for iz in range(n_c - 1):
		for ix in range(n_c - 1):
			var i00 := iz * n_c + ix
			var i10 := iz * n_c + (ix + 1)
			var i01 := (iz + 1) * n_c + ix
			var i11 := (iz + 1) * n_c + (ix + 1)
			_append_outward_tri(i00, i10, i11, pos_arr, up_f, indices)
			_append_outward_tri(i00, i11, i01, pos_arr, up_f, indices)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos_arr
	arrays[Mesh.ARRAY_NORMAL] = norm_arr
	arrays[Mesh.ARRAY_TEX_UV] = uv_arr
	arrays[Mesh.ARRAY_INDEX] = indices
	var c_mesh := ArrayMesh.new()
	c_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var cache: Dictionary = Engine.get_meta(&"space3d_pbr_cache") if Engine.has_meta(&"space3d_pbr_cache") else {}
	var ctex: ImageTexture
	if cache.has("_surface_clouds"):
		ctex = cache["_surface_clouds"]
	else:
		var sz := 128
		var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
		for py in range(sz):
			var v := float(py) / float(sz)
			for px in range(sz):
				var u := float(px) / float(sz)
				var n := _periodic_noise2d(u, v, 4, 911) * 0.6 + _periodic_noise2d(u, v, 8, 947) * 0.28 + _periodic_noise2d(u, v, 16, 977) * 0.12
				var a := smoothstep(0.42, 0.78, n) * 0.78
				img.set_pixel(px, py, Color(1.0, 1.0, 1.0, a))
		img.generate_mipmaps()
		ctex = ImageTexture.create_from_image(img)
		cache["_surface_clouds"] = ctex
		Engine.set_meta(&"space3d_pbr_cache", cache)

	var c_mat := StandardMaterial3D.new()
	c_mat.albedo_texture = ctex
	c_mat.albedo_color = Color(0.96, 0.96, 0.98) if body["is_habitable"] else (body["color"] as Color).lightened(0.35)
	c_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	c_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	c_mat.roughness = 0.95
	return {"mesh": c_mesh, "mat": c_mat}

static func _build_ocean_mesh(
	body: Dictionary,
	body_pos64: PackedFloat64Array,
	anchor_pos64: PackedFloat64Array,
	inv_rot: Quaternion,
	up64: PackedFloat64Array,
	east64: PackedFloat64Array,
	north64: PackedFloat64Array,
	up_f: Vector3,
	patch_half: float,
	compress_fn: Callable,
	dom_axis: int = 1,
	r_km: float = 6_371.0,
	uv_ox: float = 0.0,
	uv_oy: float = 0.0
) -> Dictionary:
	var n_o := 29
	var r_m: float = body["radius_m"]
	var pos_arr := PackedVector3Array()
	pos_arr.resize(n_o * n_o)
	var norm_arr := PackedVector3Array()
	norm_arr.resize(n_o * n_o)
	var uv_arr := PackedVector2Array()
	uv_arr.resize(n_o * n_o)

	for iz in range(n_o):
		var tz := (float(iz) / float(n_o - 1)) * 2.0 - 1.0
		var v := (1.0 if tz >= 0.0 else -1.0) * (0.12 * absf(tz) + 0.88 * tz * tz)
		for ix in range(n_o):
			var tx := (float(ix) / float(n_o - 1)) * 2.0 - 1.0
			var u := (1.0 if tx >= 0.0 else -1.0) * (0.12 * absf(tx) + 0.88 * tx * tx)
			var off := UniverseCatalog.v64_add(UniverseCatalog.v64_scale(east64, u * patch_half), UniverseCatalog.v64_scale(north64, v * patch_half))
			var dir64 := UniverseCatalog.v64_norm(UniverseCatalog.v64_add(UniverseCatalog.v64_scale(up64, r_m), off))
			var pt64 := UniverseCatalog.v64_add(body_pos64, UniverseCatalog.v64_scale(dir64, r_m))
			var comp: Dictionary = compress_fn.call(UniverseCatalog.v64_sub(pt64, anchor_pos64))
			var idx := iz * n_o + ix
			pos_arr[idx] = comp["pos"]
			var dir_f := UniverseCatalog.v64_to_vec3(dir64)
			norm_arr[idx] = dir_f
			var r_uv := _project_km_uv(inv_rot * dir_f, dom_axis, r_km)
			uv_arr[idx] = Vector2(r_uv.x - uv_ox, r_uv.y - uv_oy)

	var indices := PackedInt32Array()
	for iz in range(n_o - 1):
		for ix in range(n_o - 1):
			var i00 := iz * n_o + ix
			var i10 := iz * n_o + (ix + 1)
			var i01 := (iz + 1) * n_o + ix
			var i11 := (iz + 1) * n_o + (ix + 1)
			_append_outward_tri(i00, i10, i11, pos_arr, up_f, indices)
			_append_outward_tri(i00, i11, i01, pos_arr, up_f, indices)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = pos_arr
	arrays[Mesh.ARRAY_NORMAL] = norm_arr
	arrays[Mesh.ARRAY_TEX_UV] = uv_arr
	arrays[Mesh.ARRAY_INDEX] = indices
	var o_mesh := ArrayMesh.new()
	o_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var st := SurfaceTool.new()
	st.create_from(o_mesh, 0)
	st.generate_tangents()
	o_mesh = st.commit()

	var o_mat := ShaderMaterial.new()
	o_mat.shader = preload("res://shaders/ocean_water.gdshader")
	return {"mesh": o_mesh, "mat": o_mat}

static func build_surface_props(
	body: Dictionary,
	body_pos64: PackedFloat64Array,
	anchor_pos64: PackedFloat64Array,
	planet_rot: Quaternion,
	inv_rot: Quaternion,
	clear_center64: PackedFloat64Array,
	has_clear_center: bool,
	collision: TerrainCollision
) -> Node3D:
	var container := Node3D.new()
	var up64 := UniverseCatalog.v64_norm(UniverseCatalog.v64_sub(anchor_pos64, body_pos64))
	var r_m: float = body["radius_m"]
	var local_anchor := (inv_rot * UniverseCatalog.v64_to_vec3(up64)) * r_m

	var ax := absf(local_anchor.x)
	var ay := absf(local_anchor.y)
	var az := absf(local_anchor.z)
	var dom: int = 1 if (ay >= ax and ay >= az) else (0 if (ax >= ay and ax >= az) else 2)
	var u0: float = local_anchor.x if dom != 0 else local_anchor.z
	var v0: float = local_anchor.z if dom == 1 else local_anchor.y
	var d_sign: float = (1.0 if local_anchor.y >= 0.0 else -1.0) if dom == 1 else ((1.0 if local_anchor.x >= 0.0 else -1.0) if dom == 0 else (1.0 if local_anchor.z >= 0.0 else -1.0))

	var trunk_mat := StandardMaterial3D.new(); trunk_mat.albedo_color = Color(0.24, 0.16, 0.09); trunk_mat.roughness = 0.94
	var pine_mat := StandardMaterial3D.new(); pine_mat.albedo_color = Color(0.07, 0.24, 0.08) if body["id"] == "earth" else Color(0.14, 0.26, 0.16); pine_mat.roughness = 0.88
	var rock_mat := StandardMaterial3D.new(); rock_mat.albedo_color = (body["color"] as Color).darkened(0.25); rock_mat.roughness = 0.94
	var ice_mat := StandardMaterial3D.new(); ice_mat.albedo_color = Color(0.64, 0.82, 0.94, 0.92); ice_mat.roughness = 0.25; ice_mat.metallic = 0.1

	var trunk_m := CylinderMesh.new(); trunk_m.top_radius = 0.22; trunk_m.bottom_radius = 0.28; trunk_m.height = 2.2
	var cone_m := CylinderMesh.new(); cone_m.top_radius = 0.12; cone_m.bottom_radius = 1.65; cone_m.height = 3.2; cone_m.radial_segments = 8
	var cone_top_m := CylinderMesh.new(); cone_top_m.top_radius = 0.04; cone_top_m.bottom_radius = 1.15; cone_top_m.height = 2.6; cone_top_m.radial_segments = 8
	var boulder_m := SphereMesh.new(); boulder_m.radius = 0.82; boulder_m.height = 1.05; boulder_m.radial_segments = 6; boulder_m.rings = 3
	var spire_m := CylinderMesh.new(); spire_m.top_radius = 0.04; spire_m.bottom_radius = 0.75; spire_m.height = 3.2; spire_m.radial_segments = 5

	var cell_size := 35.0
	var cx0 := int(floor(u0 / cell_size))
	var cz0 := int(floor(v0 / cell_size))
	var r2: float = r_m * r_m
	var thr := 0.72 if body["is_habitable"] else 0.78

	for dz in range(-10, 11):
		for dx in range(-10, 11):
			var cx := cx0 + dx
			var cz := cz0 + dz
			if _hash31(cx, cz, dom, 404) < thr:
				continue
			var h1 := _hash31(cx, cz, dom, 509)
			var h2 := _hash31(cx, cz, dom, 613)
			var h3 := _hash31(cx, cz, dom, 719)
			var h4 := _hash31(cx, cz, dom, 823)

			var u := (float(cx) + 0.15 + 0.70 * h1) * cell_size
			var v := (float(cz) + 0.15 + 0.70 * h2) * cell_size
			var comp2 := r2 - u * u - v * v
			if comp2 <= 100.0:
				continue
			var w := d_sign * sqrt(comp2)
			var local_d: Vector3
			match dom:
				1: local_d = Vector3(u, w, v).normalized()
				0: local_d = Vector3(w, v, u).normalized()
				_: local_d = Vector3(u, v, w).normalized()

			var samp := sample_terrain(local_d, body)
			if samp["is_water"]:
				continue
			var dir_w := (planet_rot * local_d).normalized()
			var dir64 := UniverseCatalog.v64(dir_w.x, dir_w.y, dir_w.z)
			var rough_p64 := UniverseCatalog.v64_add(body_pos64, UniverseCatalog.v64_scale(dir64, r_m + samp["height"]))
			var col_h: Variant = collision.sample_height(rough_p64, planet_rot, body_pos64) if collision != null else null
			var raw_sh: float = float(samp["height"])
			var prop_h: float = float(col_h) if col_h != null else (maxf(0.0, raw_sh) if body["is_habitable"] else raw_sh)
			var prop_w64 := UniverseCatalog.v64_add(body_pos64, UniverseCatalog.v64_scale(dir64, r_m + prop_h))

			var dist_a := UniverseCatalog.v64_len(UniverseCatalog.v64_sub(prop_w64, anchor_pos64))
			if dist_a < 14.0 or dist_a > 400.0:
				continue
			if has_clear_center and UniverseCatalog.v64_len(UniverseCatalog.v64_sub(prop_w64, clear_center64)) < 14.0:
				continue

			var prop_node := Node3D.new()
			prop_node.position = UniverseCatalog.v64_to_vec3(UniverseCatalog.v64_sub(prop_w64, anchor_pos64))
			var align_q := Quaternion(Vector3.UP, dir_w)
			var yaw_q := Quaternion(Vector3.UP, h3 * TAU)
			prop_node.quaternion = (align_q * yaw_q).normalized()

			if body["is_habitable"] and prop_h > 15.0 and prop_h < 1_800.0:
				if h4 < 0.60:
					var s := 0.85 + h3 * 0.85
					var tr := MeshInstance3D.new(); tr.mesh = trunk_m; tr.material_override = trunk_mat; tr.position = Vector3(0, 1.0, 0); prop_node.add_child(tr)
					var cn := MeshInstance3D.new(); cn.mesh = cone_m; cn.material_override = pine_mat; cn.position = Vector3(0, 2.9, 0); prop_node.add_child(cn)
					var cnt := MeshInstance3D.new(); cnt.mesh = cone_top_m; cnt.material_override = pine_mat; cnt.position = Vector3(0, 4.5, 0); prop_node.add_child(cnt)
					prop_node.scale = Vector3(s, s, s)
				else:
					var rk := MeshInstance3D.new(); rk.mesh = boulder_m; rk.material_override = rock_mat; rk.position = Vector3(0, 0.28, 0); prop_node.add_child(rk)
					var sr := 0.8 + h3 * 1.6
					prop_node.scale = Vector3(sr, sr * 0.78, sr)
			elif body["is_icy"]:
				var sp := MeshInstance3D.new(); sp.mesh = spire_m; sp.material_override = ice_mat; sp.position = Vector3(0, 1.4, 0); prop_node.add_child(sp)
				var si := 0.75 + h3 * 1.3
				prop_node.scale = Vector3(si * 0.9, si * 1.2, si * 0.9)
			else:
				var rk2 := MeshInstance3D.new(); rk2.mesh = boulder_m; rk2.material_override = rock_mat; rk2.position = Vector3(0, 0.28, 0); prop_node.add_child(rk2)
				var s2 := 0.65 + h3 * 2.0
				prop_node.scale = Vector3(s2, s2 * (0.65 + h1 * 0.45), s2)

			container.add_child(prop_node)
	return container

static func surface_scan_report(body: Dictionary, local_dir: Vector3, elevation_m: float) -> Dictionary:
	var bid: String = body["id"]
	var lat := absf(local_dir.y)
	var biome: String = "Реголит и ударные кратеры"
	if body["is_habitable"]:
		if elevation_m <= 1.0: biome = "Прибрежная полоса океана"
		elif lat > 0.80: biome = "Полярная ледяная шапка"
		elif elevation_m > 2_500.0: biome = "Высокогорные хребты"
		elif elevation_m > 1_100.0: biome = "Скалистое нагорье"
		else: biome = "Умеренные холмы и леса"
	elif bid == "mars" or bid == "trappist1d":
		biome = "Полярная ледяная шапка" if lat > 0.84 else ("Каньоны и хребты" if elevation_m > 1_600.0 else "Оксидные дюны и пустыня")
	elif body["is_icy"]:
		biome = "Ледяная кора и криоразломы"
	elif bid in ["venus", "trappist1b", "io"]:
		biome = "Серные вулканические поля" if bid == "io" else "Базальтовые лавовые плато"
	elif bid == "titan":
		biome = "Дюны толинов и замёрзший метан"

	var atmo := "Отсутствует (вакуум)"
	if bid == "earth": atmo = "1.0 атм (N2 78%, O2 21%)"
	elif bid in ["mars", "trappist1d"]: atmo = "0.006 атм (CO2 95%)"
	elif bid in ["venus", "trappist1b"]: atmo = "92 атм (CO2 96%)"
	elif bid == "titan": atmo = "1.45 атм (N2 95%, CH4 5%)"
	elif body["is_habitable"]: atmo = "Кислородно-азотная плотная"
	elif body["has_atmosphere"]: atmo = "Разрежённая газовая оболочка"

	var comp := "Кремнезём (SiO2), силикаты"
	if body["is_habitable"]: comp = "Силикаты (SiO2), полевой шпат, органика"
	elif bid in ["mars", "trappist1d"]: comp = "Оксид железа (Fe2O3), базальт, перхлораты"
	elif bid in ["moon", "mercury", "ceres", "phobos"]: comp = "Анортизит, базальт, ильменит (FeTiO3)"
	elif body["is_icy"]: comp = "Водяной лёд (H2O), твёрдый азот"
	elif bid == "io": comp = "Сера (S), диоксид серы, лава"

	var g_val: float = body["surface_gravity_g"]
	return {
		"planet_name": body["name"],
		"biome_name": biome,
		"elevation_m": int(round(elevation_m)),
		"gravity_g": g_val,
		"gravity_mps2": g_val * 9.80665,
		"temp_c": body["mean_temp_c"],
		"atmosphere_text": atmo,
		"composition_text": comp,
	}

static func atmosphere_fog_color(body: Dictionary) -> Color:
	var bid: String = body["id"]
	if body["is_habitable"]:
		return Color(0.45, 0.72, 0.98)
	if bid == "mars" or bid == "trappist1d":
		return Color(0.86, 0.56, 0.36)
	if bid == "venus" or bid == "titan" or bid == "trappist1b":
		return Color(0.92, 0.66, 0.32)
	return Color(0.55, 0.72, 0.90)
