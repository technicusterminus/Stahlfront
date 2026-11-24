extends Node3D
## Echte Kettenglieder für alle Kettenfahrzeuge ohne eigenes Gliedermodell (der Falke hat tracked_visual.gd).
## Ablauf:
##  1. Kettenoberfläche im Modell finden: GLB-Material "Rubber…", sonst Dreiecke der dunklen Rumpfoberfläche im untersten
##     Bereich und in den äußeren Bändern (abgetrennt), bei Code-Modellen die mit meta "track" markierten Kästen.
##  2. Daraus je Seite die Schleife bestimmen (Breite, Höhe = Raddurchmesser, Länge) und die starre Kette ausblenden.
##  3. Glieder (Platte mit Greifsteg und Führungszähnen) als MultiMesh entlang Oberlauf, vorderem Bogen, Unterlauf und
##     hinterem Bogen setzen; innen ein dunkler Kern. Die Glieder wandern mit der gefahrenen Strecke, in Kurven gegenläufig.

const PITCH := 0.2        # Gliedlänge in Metern (Modellmaßstab)

static var _link_mesh: ArrayMesh
static var _link_mat: StandardMaterial3D
static var _core_mat: StandardMaterial3D

var _sides: Array = []    # je Seite: {mm, n, L, R, zr, zf, yc, loop}
var _phase := [0.0, 0.0]
var half_w := 1.2
var belt_w := 0.5
var _last_yaw := 0.0
var _yaw_init := false
var _tick := 0.0

func setup(root: Node3D) -> bool:
	var pts: Array = []   # Eckpunkte der Kettenoberfläche im Raum des Modells
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var hits: Array = []
		if mi.has_meta("track"):
			for si in mi.mesh.get_surface_count():
				hits.append(si)
		else:
			for si in mi.mesh.get_surface_count():
				var m: Material = mi.mesh.surface_get_material(si)
				if m != null and String(m.resource_name).to_lower().begins_with("rubber"):
					hits.append(si)
			if hits.is_empty():
				var split := _split_dark(mi)
				if split >= 0:
					hits.append(split)
		if hits.is_empty():
			continue
		var xf := _to_root(mi, root)
		var drop: Array = hits.duplicate()
		for si in hits:
			var arr := mi.mesh.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx = arr[Mesh.ARRAY_INDEX]
			if idx != null and (idx as PackedInt32Array).size() > 0:
				for i in idx:
					pts.append(xf * verts[i])
			else:
				for v in verts:
					pts.append(xf * v)
		# alte, starre Kette entfernen: Code-Kasten ausblenden, bei GLB die Oberflächen aus dem Netz nehmen
		if mi.has_meta("track"):
			mi.visible = false
		else:
			_drop_surfaces(mi, drop)

	if pts.size() < 12:
		return false
	var xmin := INF
	var xmax := -INF
	for p in pts:
		xmin = min(xmin, p.x)
		xmax = max(xmax, p.x)
	var xc := (xmin + xmax) * 0.5
	for side in 2:
		var b_min := Vector3(INF, INF, INF)
		var b_max := Vector3(-INF, -INF, -INF)
		for p in pts:
			if (p.x < xc) == (side == 0):
				b_min = b_min.min(p)
				b_max = b_max.max(p)
		if b_max.x - b_min.x < 0.1 or b_max.z - b_min.z < 1.0:
			return false
		_build_side(b_min, b_max)
	half_w = max(0.6, (xmax - xmin) * 0.5 - belt_w * 0.5)
	_extract_wheels(root)
	return true

func _to_root(n: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf

func _drop_surfaces(mi: MeshInstance3D, drop: Array) -> void:
	var src: Mesh = mi.mesh
	var out := ArrayMesh.new()
	for si in src.get_surface_count():
		if si in drop:
			continue
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(si))
		out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(si))
	mi.mesh = out

## Ein Glied: Platte quer zur Fahrtrichtung, Greifsteg außen, zwei Führungszähne innen. Breite 1 (wird skaliert).
static func _link() -> ArrayMesh:
	if _link_mesh != null:
		return _link_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var plate := BoxMesh.new()
	plate.size = Vector3(1.0, 0.045, PITCH * 0.86)
	st.append_from(plate, 0, Transform3D(Basis(), Vector3(0, 0.0, 0)))
	var grouser := BoxMesh.new()
	grouser.size = Vector3(0.96, 0.04, 0.045)
	st.append_from(grouser, 0, Transform3D(Basis(), Vector3(0, 0.04, -PITCH * 0.18)))
	var tooth := BoxMesh.new()
	tooth.size = Vector3(0.08, 0.06, PITCH * 0.4)
	st.append_from(tooth, 0, Transform3D(Basis(), Vector3(-0.18, -0.05, 0)))
	st.append_from(tooth, 0, Transform3D(Basis(), Vector3(0.18, -0.05, 0)))
	_link_mesh = st.commit()
	_link_mat = StandardMaterial3D.new()
	_link_mat.albedo_color = Color(0.2, 0.19, 0.18)
	_link_mat.metallic = 0.65
	_link_mat.roughness = 0.55
	_core_mat = StandardMaterial3D.new()
	_core_mat.albedo_color = Color(0.06, 0.06, 0.06)
	_core_mat.roughness = 0.9
	return _link_mesh

func _build_side(b_min: Vector3, b_max: Vector3) -> void:
	var w := b_max.x - b_min.x
	belt_w = w
	var R := clampf((b_max.y - b_min.y) * 0.5, 0.18, 0.7)
	var yc := b_min.y + R
	var zr := b_min.z + R
	var zf := b_max.z - R
	var L := maxf(zf - zr, 0.2)
	var loop := 2.0 * L + 2.0 * PI * R
	var n := int(round(loop / PITCH))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _link()
	mm.instance_count = n
	var view := MultiMeshInstance3D.new()
	view.multimesh = mm
	view.material_override = _link_mat
	view.position = Vector3((b_min.x + b_max.x) * 0.5, 0, 0)
	view.scale = Vector3(w, 1, 1)
	add_child(view)
	# dunkler Kern innerhalb der Schleife, schmaler als die Kette (Laufrollen bleiben sichtbar)
	var core := MeshInstance3D.new()
	var cb := BoxMesh.new()
	cb.size = Vector3(w * 0.55, 2.0 * R * 0.82, L + R * 1.2)
	core.mesh = cb
	core.material_override = _core_mat
	core.position = Vector3((b_min.x + b_max.x) * 0.5, yc, (zr + zf) * 0.5)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	_sides.append({"mm": mm, "n": n, "L": L, "R": R, "zr": zr, "zf": zf, "yc": yc, "loop": loop, "x0": b_min.x, "x1": b_max.x})
	_place(_sides.size() - 1)

## Lage eines Punktes auf der Schleife: Oberlauf hinten→vorn, vorderer Bogen abwärts, Unterlauf vorn→hinten, hinterer Bogen.
func _at(sd: Dictionary, s: float) -> Transform3D:
	var L: float = sd["L"]
	var R: float = sd["R"]
	var yc: float = sd["yc"]
	var zr: float = sd["zr"]
	var zf: float = sd["zf"]
	s = fposmod(s, sd["loop"])
	var pos: Vector3
	var up: Vector3
	var tg: Vector3
	if s < L:
		pos = Vector3(0, yc + R, zr + s)
		up = Vector3.UP
		tg = Vector3(0, 0, 1)
	elif s < L + PI * R:
		var a := (s - L) / R
		pos = Vector3(0, yc + R * cos(a), zf + R * sin(a))
		up = Vector3(0, cos(a), sin(a))
		tg = Vector3(0, -sin(a), cos(a))
	elif s < 2.0 * L + PI * R:
		var t := s - L - PI * R
		pos = Vector3(0, yc - R, zf - t)
		up = Vector3.DOWN
		tg = Vector3(0, 0, -1)
	else:
		var a2 := (s - 2.0 * L - PI * R) / R
		pos = Vector3(0, yc - R * cos(a2), zr - R * sin(a2))
		up = Vector3(0, -cos(a2), -sin(a2))
		tg = Vector3(0, sin(a2), -cos(a2))
	return Transform3D(Basis(up.cross(tg), up, tg), pos)

func _place(i: int) -> void:
	var sd: Dictionary = _sides[i]
	var mm: MultiMesh = sd["mm"]
	var step: float = float(sd["loop"]) / float(sd["n"])
	for k in sd["n"]:
		mm.set_instance_transform(k, _at(sd, _phase[i] + k * step))

## Zerlegt die dunkle Rumpfoberfläche eines GLB: Dreiecke im untersten Bereich und in den äußeren Bändern bilden eine
## eigene Oberfläche (die Kette). Gibt deren Index zurück oder -1.
func _split_dark(mi: MeshInstance3D) -> int:
	var src: Mesh = mi.mesh
	var dark := -1
	for si in src.get_surface_count():
		var m: Material = src.surface_get_material(si)
		if m != null:
			var nm := String(m.resource_name).to_lower()
			if nm.begins_with("dark") and nm.ends_with("_hull"):
				dark = si
				break
	if dark < 0:
		return -1
	var arr: Array = src.surface_get_arrays(dark)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx := PackedInt32Array()
	if arr[Mesh.ARRAY_INDEX] != null:
		idx = arr[Mesh.ARRAY_INDEX]
	if idx.is_empty():
		for i in verts.size():
			idx.append(i)
	var all_min := Vector3(INF, INF, INF)
	var all_max := Vector3(-INF, -INF, -INF)
	for si in src.get_surface_count():
		for v in src.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]:
			all_min = all_min.min(v)
			all_max = all_max.max(v)
	var xc := (all_min.x + all_max.x) * 0.5
	var hw := (all_max.x - all_min.x) * 0.5
	var band := clampf(hw * 0.38, 0.3, 0.8)
	var ylim := all_min.y + clampf((all_max.y - all_min.y) * 0.42, 0.5, 1.05)
	var keep := PackedInt32Array()
	var track := PackedInt32Array()
	for t in range(0, idx.size() - 2, 3):
		var c: Vector3 = (verts[idx[t]] + verts[idx[t + 1]] + verts[idx[t + 2]]) / 3.0
		if c.y < ylim and abs(c.x - xc) > hw - band:
			track.append_array([idx[t], idx[t + 1], idx[t + 2]])
		else:
			keep.append_array([idx[t], idx[t + 1], idx[t + 2]])
	if track.size() < 36:
		return -1
	var out := ArrayMesh.new()
	for si in src.get_surface_count():
		var a: Array = src.surface_get_arrays(si)
		if si == dark:
			a = a.duplicate()
			a[Mesh.ARRAY_INDEX] = keep
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(si))
	var a2: Array = src.surface_get_arrays(dark).duplicate()
	a2[Mesh.ARRAY_INDEX] = track
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
	var ti := out.get_surface_count() - 1
	out.surface_set_material(ti, src.surface_get_material(dark))
	mi.mesh = out
	return ti

## metres: Weg dieses Bildes im Modellmaßstab, yaw: Fahrtrichtung. Glieder nur nahe der Kamera neu setzen.
func advance(metres: float, yaw: float, delta := 0.016, near_camera := true) -> void:
	if not _yaw_init:
		_last_yaw = yaw
		_yaw_init = true
	var dyaw := wrapf(yaw - _last_yaw, -PI, PI)
	_last_yaw = yaw
	var turn := dyaw * half_w
	_phase[0] += metres + turn
	_phase[1] += metres - turn
	_tick += delta
	if near_camera and _tick >= 1.0 / 30.0 and (absf(metres) > 0.0001 or absf(turn) > 0.0001):
		_tick = 0.0
		for i in _sides.size():
			_place(i)
		_spin_wheels()

# ---------------------------------------------------------------- Laufrollen

var _wheels: Array = []   # [Node3D, Seite, Radius]

## Rollen im Kettenbereich aus dem Rumpf lösen: zusammenhängende, runde Teile (Breite ≈ Höhe in der Seitenansicht)
## werden zu eigenen Knoten mit Drehpunkt in ihrer Mitte und drehen sich dann mit der Kette.
func _extract_wheels(root: Node3D) -> void:
	if _sides.size() < 2:
		return
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.visible or mi.get_parent() == self or self.is_ancestor_of(mi):
			continue
		var xf := _to_root(mi, root)
		var src: Mesh = mi.mesh
		var changed := false
		var out := ArrayMesh.new()
		for si in src.get_surface_count():
			var arr: Array = src.surface_get_arrays(si)
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var idx := PackedInt32Array()
			if arr[Mesh.ARRAY_INDEX] != null:
				idx = arr[Mesh.ARRAY_INDEX]
			if idx.is_empty():
				for i in verts.size():
					idx.append(i)
			# Dreiecke im Kettenbereich einer Seite
			var cand: Array = []
			for t in range(0, idx.size() - 2, 3):
				var c: Vector3 = xf * ((verts[idx[t]] + verts[idx[t + 1]] + verts[idx[t + 2]]) / 3.0)
				for sd in _sides:
					if c.x >= sd["x0"] - 0.12 and c.x <= sd["x1"] + 0.12 and c.y < sd["yc"] + sd["R"] * 1.05 and c.z > sd["zr"] - sd["R"] * 1.1 and c.z < sd["zf"] + sd["R"] * 1.1:
						cand.append(t)
						break
			if cand.is_empty():
				out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
				out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(si))
				continue
			# zusammenhängende Teile über gemeinsame Eckpunkte (gerundete Lage)
			var parent := {}
			var key_of := func(v: Vector3) -> String:
				return "%d_%d_%d" % [roundi(v.x * 200.0), roundi(v.y * 200.0), roundi(v.z * 200.0)]
			var find := func(k: String) -> String:
				var r: String = k
				while parent.get(r, r) != r:
					r = parent[r]
				return r
			for t in cand:
				var k0: String = key_of.call(verts[idx[t]])
				var k1: String = key_of.call(verts[idx[t + 1]])
				var k2: String = key_of.call(verts[idx[t + 2]])
				for k in [k0, k1, k2]:
					if not parent.has(k):
						parent[k] = k
				var r0: String = find.call(k0)
				parent[find.call(k1)] = r0
				parent[find.call(k2)] = r0
			var groups := {}
			for t in cand:
				var g: String = find.call(key_of.call(verts[idx[t]]))
				if not groups.has(g):
					groups[g] = []
				groups[g].append(t)
			var taken := {}
			for g in groups:
				var tris: Array = groups[g]
				var bmin := Vector3(INF, INF, INF)
				var bmax := Vector3(-INF, -INF, -INF)
				for t in tris:
					for j in 3:
						var p: Vector3 = xf * verts[idx[t + j]]
						bmin = bmin.min(p)
						bmax = bmax.max(p)
				var sz := bmax - bmin
				var dia: float = max(sz.y, sz.z)
				if tris.size() < 8 or dia < 0.2 or dia > 1.6 or abs(sz.y - sz.z) > dia * 0.3 or sz.x > dia * 1.2:
					continue
				# eigene Rolle: Eckpunkte relativ zur Mitte
				var ctr := (bmin + bmax) * 0.5
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				var nrm = arr[Mesh.ARRAY_NORMAL]
				for t in tris:
					for j in 3:
						var vi: int = idx[t + j]
						if nrm != null and (nrm as PackedVector3Array).size() > vi:
							st.set_normal((xf.basis * (nrm as PackedVector3Array)[vi]).normalized())
						st.add_vertex(xf * verts[vi] - ctr)
					taken[t] = true
				var wm := st.commit()
				wm.surface_set_material(0, src.surface_get_material(si))
				var pivot := Node3D.new()
				pivot.position = ctr
				add_child(pivot)
				var wmi := MeshInstance3D.new()
				wmi.mesh = wm
				pivot.add_child(wmi)
				_wheels.append([pivot, 0 if ctr.x < (_sides[0]["x1"] + _sides[1]["x0"]) * 0.5 else 1, max(dia * 0.5, 0.1)])
			if taken.is_empty():
				out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
				out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(si))
				continue
			changed = true
			var keep := PackedInt32Array()
			for t in range(0, idx.size() - 2, 3):
				if not taken.has(t):
					keep.append_array([idx[t], idx[t + 1], idx[t + 2]])
			if keep.size() > 0:
				var a2 := arr.duplicate()
				a2[Mesh.ARRAY_INDEX] = keep
				out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
				out.surface_set_material(out.get_surface_count() - 1, src.surface_get_material(si))
		if changed:
			mi.mesh = out

func _spin_wheels() -> void:
	for w in _wheels:
		var pv: Node3D = w[0]
		if is_instance_valid(pv):
			pv.rotation.x = _phase[w[1]] / float(w[2])
