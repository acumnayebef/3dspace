class_name ShipBuilder
extends RefCounted

static func get_ship_catalog() -> Array[Dictionary]:
	if Engine.has_meta(&"space3d_ship_catalog"):
		return Engine.get_meta(&"space3d_ship_catalog")
	var ships: Array[Dictionary] = [
		{
			"id": "striker",
			"name": "Striker MK-II",
			"role": "Перехватчик",
			"model_path": "res://models/Striker.glb",
			"summary": "Маневренный ударный звездолёт со сдвоенными крыльями и 3D-детализацией.",
		},
		{
			"id": "imperial",
			"name": "Imperial Corvette",
			"role": "Корвет",
			"model_path": "res://models/Imperial.glb",
			"summary": "Тяжёлый экспедиционный корвет с удлинённым корпусом для дальних перелётов.",
		},
		{
			"id": "zenith",
			"name": "Zenith Explorer",
			"role": "Крейсер",
			"model_path": "res://models/Zenith.glb",
			"summary": "Исследовательский корабль дальнего космоса для изучения звёздных систем и чёрных дыр.",
		},
		{
			"id": "vanguard",
			"name": "Vanguard Delta",
			"role": "Классика",
			"model_path": "",
			"summary": "Оригинальный клиновидный дельта-истребитель Space: Eternity.",
		},
	]
	Engine.set_meta(&"space3d_ship_catalog", ships)
	return ships

static func find_ship(ship_id: String) -> Dictionary:
	var catalog := get_ship_catalog()
	for s in catalog:
		if s["id"] == ship_id:
			return s
	return catalog[0]

static func _make_convex_facet_mesh(pts: Array, tris: Array) -> ArrayMesh:
	var center := Vector3.ZERO
	for pt in pts:
		center += pt
	if pts.size() > 0:
		center /= float(pts.size())

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	for tri in tris:
		var a: Vector3 = pts[tri[0]]
		var b: Vector3 = pts[tri[1]]
		var c: Vector3 = pts[tri[2]]
		var tri_c := (a + b + c) / 3.0
		var outward := tri_c - center
		# Godot 4 front faces use clockwise winding so (b - a).cross(c - a) points inward
		if (b - a).cross(c - a).dot(outward) > 0.0:
			var tmp := b
			b = c
			c = tmp
		var n := -(b - a).cross(c - a).normalized()
		verts.append(a); verts.append(b); verts.append(c)
		norms.append(n); norms.append(n); norms.append(n)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

static func _make_wing_mesh(side: float) -> ArrayMesh:
	var rl_t := Vector3(side * 0.68, 0.06, -0.55)
	var rl_b := Vector3(side * 0.68, -0.10, -0.55)
	var rt_t := Vector3(side * 0.68, 0.08, 1.95)
	var rt_b := Vector3(side * 0.68, -0.09, 1.95)
	var tl_t := Vector3(side * 3.75, -0.12, 1.25)
	var tl_b := Vector3(side * 3.75, -0.18, 1.25)
	var tt_t := Vector3(side * 3.75, -0.11, 2.25)
	var tt_b := Vector3(side * 3.75, -0.17, 2.25)
	var pts := [rl_t, rl_b, rt_t, rt_b, tl_t, tl_b, tt_t, tt_b]
	var tris := [
		[0, 4, 6], [0, 6, 2],
		[1, 3, 7], [1, 7, 5],
		[0, 1, 5], [0, 5, 4],
		[2, 6, 7], [2, 7, 3],
		[4, 5, 7], [4, 7, 6],
		[0, 2, 3], [0, 3, 1],
	]
	return _make_convex_facet_mesh(pts, tris)

static func _collect_mesh_aabb(node: Node, parent_xform: Transform3D, state: Dictionary) -> void:
	var cur_xform := parent_xform
	if node is Node3D:
		cur_xform = parent_xform * (node as Node3D).transform
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var aabb := mi.mesh.get_aabb()
			for corner_idx in range(8):
				var pt := cur_xform * aabb.get_endpoint(corner_idx)
				if not state["has_pts"]:
					state["min"] = pt
					state["max"] = pt
					state["has_pts"] = true
				else:
					state["min"] = (state["min"] as Vector3).min(pt)
					state["max"] = (state["max"] as Vector3).max(pt)
	for child in node.get_children():
		_collect_mesh_aabb(child, cur_xform, state)

static func _build_glb_hull(model_path: String) -> Dictionary:
	if model_path == "" or not ResourceLoader.exists(model_path):
		return {"ok": false}
	var res := load(model_path)
	if not (res is PackedScene):
		return {"ok": false}
	var inst: Node = (res as PackedScene).instantiate()
	if inst == null:
		return {"ok": false}

	var pivot := Node3D.new()
	pivot.name = "ModelPivot"
	var holder := Node3D.new()
	holder.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	holder.add_child(inst)
	pivot.add_child(holder)

	var bounds := {"has_pts": false, "min": Vector3.ZERO, "max": Vector3.ZERO}
	_collect_mesh_aabb(pivot, Transform3D.IDENTITY, bounds)
	if not bounds["has_pts"]:
		pivot.queue_free()
		return {"ok": false}

	var b_min: Vector3 = bounds["min"]
	var b_max: Vector3 = bounds["max"]
	var b_size: Vector3 = b_max - b_min
	var max_dim: float = maxf(b_size.x, maxf(b_size.y, b_size.z))
	if max_dim < 0.001:
		pivot.queue_free()
		return {"ok": false}

	var s: float = 7.4 / max_dim
	var center: Vector3 = (b_min + b_max) * 0.5
	holder.scale = Vector3(s, s, s)
	holder.position = -center * s
	return {
		"ok": true,
		"node": pivot,
		"half_extents": (b_size * s) * 0.5,
	}

static func _build_vanguard_hull(root: Node3D) -> Vector3:
	var hull_titanium := StandardMaterial3D.new()
	hull_titanium.albedo_color = Color(0.84, 0.87, 0.92)
	hull_titanium.metallic = 0.60
	hull_titanium.roughness = 0.24

	var dark_armor := StandardMaterial3D.new()
	dark_armor.albedo_color = Color(0.11, 0.13, 0.17)
	dark_armor.metallic = 0.85
	dark_armor.roughness = 0.30

	var orange_trim := StandardMaterial3D.new()
	orange_trim.albedo_color = Color(0.95, 0.42, 0.08)
	orange_trim.metallic = 0.18
	orange_trim.roughness = 0.32

	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.albedo_color = Color(0.04, 0.20, 0.38, 0.95)
	canopy_mat.metallic = 0.96
	canopy_mat.roughness = 0.05

	var nav_red := StandardMaterial3D.new()
	nav_red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nav_red.albedo_color = Color(1.0, 0.22, 0.16)

	var nav_green := StandardMaterial3D.new()
	nav_green.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	nav_green.albedo_color = Color(0.16, 1.0, 0.42)

	var hull_pts := [
		Vector3(0.0, 0.03, -3.90),
		Vector3(0.0, -0.14, -3.72),
		Vector3(-0.74, 0.20, -1.10),
		Vector3(0.74, 0.20, -1.10),
		Vector3(-0.88, -0.30, -0.85),
		Vector3(0.88, -0.30, -0.85),
		Vector3(-1.05, 0.24, 1.95),
		Vector3(1.05, 0.24, 1.95),
		Vector3(-1.12, -0.34, 2.05),
		Vector3(1.12, -0.34, 2.05),
	]
	var hull_tris := [
		[0, 2, 3], [2, 6, 7], [2, 7, 3],
		[1, 5, 4], [4, 5, 9], [4, 9, 8],
		[0, 1, 4], [0, 4, 2], [2, 4, 8], [2, 8, 6],
		[0, 3, 5], [0, 5, 1], [3, 7, 9], [3, 9, 5],
		[6, 8, 9], [6, 9, 7],
	]
	var hull_inst := MeshInstance3D.new()
	hull_inst.mesh = _make_convex_facet_mesh(hull_pts, hull_tris)
	hull_inst.material_override = hull_titanium
	root.add_child(hull_inst)

	var spine_pts := [
		Vector3(0.0, 0.14, -2.55),
		Vector3(-0.34, 0.24, 0.15),
		Vector3(0.34, 0.24, 0.15),
		Vector3(0.0, 0.44, 0.25),
		Vector3(-0.42, 0.24, 2.00),
		Vector3(0.42, 0.24, 2.00),
		Vector3(0.0, 0.48, 1.92),
	]
	var spine_tris := [
		[0, 1, 3], [0, 3, 2], [0, 2, 1],
		[1, 4, 6], [1, 6, 3],
		[3, 6, 5], [3, 5, 2],
		[4, 5, 6],
		[1, 2, 5], [1, 5, 4],
	]
	var spine_inst := MeshInstance3D.new()
	spine_inst.mesh = _make_convex_facet_mesh(spine_pts, spine_tris)
	spine_inst.material_override = dark_armor
	root.add_child(spine_inst)

	var probe_m := CylinderMesh.new()
	probe_m.top_radius = 0.012; probe_m.bottom_radius = 0.055; probe_m.height = 0.72; probe_m.radial_segments = 8
	var probe := MeshInstance3D.new()
	probe.mesh = probe_m; probe.material_override = dark_armor
	probe.rotation_degrees = Vector3(-90, 0, 0)
	probe.position = Vector3(0.0, -0.04, -4.18)
	root.add_child(probe)

	var can_pts := [
		Vector3(0.0, 0.22, -2.45),
		Vector3(-0.40, 0.18, -1.25),
		Vector3(0.40, 0.18, -1.25),
		Vector3(0.0, 0.56, -1.05),
		Vector3(-0.38, 0.20, -0.05),
		Vector3(0.38, 0.20, -0.05),
		Vector3(0.0, 0.52, -0.08),
	]
	var can_tris := [
		[0, 1, 3], [0, 3, 2], [0, 2, 1],
		[1, 4, 6], [1, 6, 3],
		[3, 6, 5], [3, 5, 2],
		[4, 5, 6],
		[1, 2, 5], [1, 5, 4],
	]
	var canopy := MeshInstance3D.new()
	canopy.mesh = _make_convex_facet_mesh(can_pts, can_tris)
	canopy.material_override = canopy_mat
	root.add_child(canopy)

	var intake_m := BoxMesh.new(); intake_m.size = Vector3(0.28, 0.28, 1.85)
	var trim_m := BoxMesh.new(); trim_m.size = Vector3(0.14, 0.05, 1.05)
	var winglet_m := BoxMesh.new(); winglet_m.size = Vector3(0.07, 0.52, 0.92)
	var fin_m := BoxMesh.new(); fin_m.size = Vector3(0.08, 0.92, 0.98)
	var nav_m := SphereMesh.new(); nav_m.radius = 0.055; nav_m.height = 0.11

	for side in [-1.0, 1.0]:
		var sx := float(side)
		var wing := MeshInstance3D.new()
		wing.mesh = _make_wing_mesh(sx)
		wing.material_override = dark_armor
		root.add_child(wing)

		var intake := MeshInstance3D.new()
		intake.mesh = intake_m; intake.material_override = dark_armor
		intake.position = Vector3(sx * 0.95, 0.02, 0.72)
		root.add_child(intake)

		var winglet := MeshInstance3D.new()
		winglet.mesh = winglet_m; winglet.material_override = hull_titanium
		winglet.position = Vector3(sx * 3.84, 0.08, 1.75)
		winglet.rotation_degrees = Vector3(16.0, 0.0, -sx * 26.0)
		root.add_child(winglet)

		var stripe := MeshInstance3D.new()
		stripe.mesh = trim_m; stripe.material_override = orange_trim
		stripe.position = Vector3(sx * 3.55, -0.09, 1.72)
		root.add_child(stripe)

		var nav := MeshInstance3D.new()
		nav.mesh = nav_m
		nav.material_override = nav_red if sx < 0.0 else nav_green
		nav.position = Vector3(sx * 3.92, 0.28, 1.88)
		root.add_child(nav)

		var fin := MeshInstance3D.new()
		fin.mesh = fin_m; fin.material_override = orange_trim
		fin.position = Vector3(sx * 0.96, 0.48, 1.68)
		fin.rotation_degrees = Vector3(14.0, 0.0, -sx * 24.0)
		root.add_child(fin)

	var dark_eng_m := CylinderMesh.new()
	dark_eng_m.top_radius = 0.30; dark_eng_m.bottom_radius = 0.36; dark_eng_m.height = 1.15; dark_eng_m.radial_segments = 12
	for side in [-1.0, 1.0]:
		var sx := float(side)
		var eng := MeshInstance3D.new()
		eng.mesh = dark_eng_m; eng.material_override = dark_armor
		eng.rotation_degrees = Vector3(90, 0, 0)
		eng.position = Vector3(sx * 0.56, -0.04, 1.68)
		root.add_child(eng)

	return Vector3(3.9, 0.55, 2.25)

static func _attach_ship_systems(root: Node3D, half_ext: Vector3) -> Dictionary:
	var glow_cyan := StandardMaterial3D.new()
	glow_cyan.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_cyan.albedo_color = Color(0.18, 0.88, 1.0)

	var flame_mat := StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	flame_mat.albedo_color = Color(0.28, 0.84, 1.0, 0.82)

	var exhaust_nodes: Array[MeshInstance3D] = []
	var glow_ring_m := CylinderMesh.new()
	glow_ring_m.top_radius = 0.22; glow_ring_m.bottom_radius = 0.22; glow_ring_m.height = 0.06; glow_ring_m.radial_segments = 12
	var flame_m := CylinderMesh.new()
	flame_m.top_radius = 0.20; flame_m.bottom_radius = 0.02; flame_m.height = 2.05; flame_m.radial_segments = 12

	var ex_x: float = clampf(half_ext.x * 0.22, 0.38, 0.68)
	var ex_z: float = maxf(2.15, half_ext.z * 0.94)
	for side in [-1.0, 1.0]:
		var sx := float(side)
		var ring := MeshInstance3D.new()
		ring.mesh = glow_ring_m; ring.material_override = glow_cyan
		ring.rotation_degrees = Vector3(90, 0, 0)
		ring.position = Vector3(sx * ex_x, -0.02, ex_z)
		root.add_child(ring)

		var fl := MeshInstance3D.new()
		fl.mesh = flame_m; fl.material_override = flame_mat
		fl.rotation_degrees = Vector3(90, 0, 0)
		fl.position = Vector3(sx * ex_x, -0.02, ex_z + 1.04)
		fl.visible = false
		root.add_child(fl)
		exhaust_nodes.append(fl)

	var dark_armor := StandardMaterial3D.new()
	dark_armor.albedo_color = Color(0.11, 0.13, 0.17)
	dark_armor.metallic = 0.85; dark_armor.roughness = 0.30
	var silver_strut := StandardMaterial3D.new()
	silver_strut.albedo_color = Color(0.62, 0.66, 0.72)
	silver_strut.metallic = 0.88; silver_strut.roughness = 0.22

	var gear_root := Node3D.new()
	gear_root.name = "LandingGear"
	gear_root.visible = false
	var upper_strut_m := CylinderMesh.new()
	upper_strut_m.top_radius = 0.065; upper_strut_m.bottom_radius = 0.055; upper_strut_m.height = 0.45
	var piston_m := CylinderMesh.new()
	piston_m.top_radius = 0.040; piston_m.bottom_radius = 0.038; piston_m.height = 0.45
	var pad_m := BoxMesh.new()
	pad_m.size = Vector3(0.42, 0.08, 0.62)

	var gear_y: float = -clampf(half_ext.y + 0.46, 0.82, 1.38)
	var gear_pts := [
		Vector3(0.0, gear_y, -clampf(half_ext.z * 0.55, 1.5, 2.5)),
		Vector3(-clampf(half_ext.x * 0.45, 0.9, 1.6), gear_y, clampf(half_ext.z * 0.42, 0.9, 1.9)),
		Vector3(clampf(half_ext.x * 0.45, 0.9, 1.6), gear_y, clampf(half_ext.z * 0.42, 0.9, 1.9)),
	]
	for gp in gear_pts:
		var up := MeshInstance3D.new()
		up.mesh = upper_strut_m; up.material_override = dark_armor
		up.position = gp + Vector3(0, 0.52, 0)
		gear_root.add_child(up)

		var pist := MeshInstance3D.new()
		pist.mesh = piston_m; pist.material_override = silver_strut
		pist.position = gp + Vector3(0, 0.22, 0)
		gear_root.add_child(pist)

		var pad := MeshInstance3D.new()
		pad.mesh = pad_m; pad.material_override = dark_armor
		pad.position = gp
		gear_root.add_child(pad)
	root.add_child(gear_root)

	var reentry_sm := ShaderMaterial.new()
	reentry_sm.shader = preload("res://shaders/reentry_plasma.gdshader")
	reentry_sm.set_shader_parameter("intensity", 0.0)
	var reentry_m := CylinderMesh.new()
	reentry_m.top_radius = 0.05
	reentry_m.bottom_radius = maxf(2.65, half_ext.x * 0.88)
	reentry_m.height = maxf(7.4, half_ext.z * 2.2)
	reentry_m.radial_segments = 24
	var reentry_node := MeshInstance3D.new()
	reentry_node.mesh = reentry_m
	reentry_node.material_override = reentry_sm
	reentry_node.rotation_degrees = Vector3(-90, 0, 0)
	reentry_node.position = Vector3(0.0, 0.0, -0.55)
	reentry_node.visible = false
	root.add_child(reentry_node)

	return {
		"root": root,
		"exhaust_nodes": exhaust_nodes,
		"landing_gear": gear_root,
		"reentry_node": reentry_node,
		"reentry_mat": reentry_sm,
	}

static func build_ship_node(ship_id: String = "striker") -> Dictionary:
	var spec := find_ship(ship_id)
	var root := Node3D.new()
	root.name = "StarshipVisual"

	var half_ext := Vector3(3.9, 0.55, 2.25)
	var glb := _build_glb_hull(spec["model_path"])
	if glb["ok"]:
		root.add_child(glb["node"])
		half_ext = glb["half_extents"]
	else:
		half_ext = _build_vanguard_hull(root)

	return _attach_ship_systems(root, half_ext)
