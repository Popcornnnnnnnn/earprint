"""Build original, trademark-safe Beats-family 3D USDZ assets + over-ear 2D card renders in Blender 5.2+.

Generates:
  1. Earprint/Resources/Models/BeatsBuds.usdz      (stemless wingtip sport earbuds pair)
  2. Earprint/Resources/Models/BeatsEarhook.usdz   (over-ear sport earhook pair)
  3. Earprint/Resources/Models/BeatsOverEar.usdz   (closed-back studio over-ear headphones)
  4. Earprint/Assets.xcassets/CardRenderBeatsOverEar{Black,Sandstone,Navy,CloudPink}.imageset/*.png

Every USDZ is normalized to largest bounding dimension = 1.0, centered at origin,
Y-up with front facing +Z, cleanly separated into named Zone_* meshes/materials for
reliable RealityKit per-zone recoloring, and validated with `usdzip -c`.

Usage:
  /Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup -P tools/assets/build_beats_models.py
"""

import json
import math
import os
import subprocess
import sys

import bmesh
import bpy
import mathutils
from mathutils import Euler, Matrix, Vector

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODELS_DIR = os.path.join(REPO_ROOT, "Earprint", "Resources", "Models")
ASSETS_DIR = os.path.join(REPO_ROOT, "Earprint", "Assets.xcassets")
PREVIEWS_DIR = os.path.join(REPO_ROOT, "docs", "assets-previews")

OVER_EAR_FINISHES = [
    {
        "asset": "CardRenderBeatsOverEarBlack",
        "shell": (0.11, 0.11, 0.13),
        "accent": (0.20, 0.20, 0.23),
        "cushion": (0.09, 0.09, 0.11),
        "metal": (0.38, 0.39, 0.42),
        "metallic": 0.35,
        "roughness": 0.42,
    },
    {
        "asset": "CardRenderBeatsOverEarSandstone",
        "shell": (0.80, 0.76, 0.70),
        "accent": (0.86, 0.82, 0.76),
        "cushion": (0.72, 0.68, 0.62),
        "metal": (0.84, 0.80, 0.74),
        "metallic": 0.25,
        "roughness": 0.44,
    },
    {
        "asset": "CardRenderBeatsOverEarNavy",
        "shell": (0.18, 0.28, 0.44),
        "accent": (0.26, 0.37, 0.54),
        "cushion": (0.14, 0.22, 0.36),
        "metal": (0.45, 0.52, 0.64),
        "metallic": 0.30,
        "roughness": 0.42,
    },
    {
        "asset": "CardRenderBeatsOverEarCloudPink",
        "shell": (0.86, 0.62, 0.66),
        "accent": (0.91, 0.70, 0.74),
        "cushion": (0.74, 0.52, 0.56),
        "metal": (0.88, 0.76, 0.78),
        "metallic": 0.25,
        "roughness": 0.42,
    },
]


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def srgb_to_linear(c):
    if c <= 0.04045:
        return c / 12.92
    return ((c + 0.055) / 1.055) ** 2.4


def make_pbr_material(name, rgb, metallic=0.15, roughness=0.45, coat=0.0):
    mat = bpy.data.materials.new(name=name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (
        srgb_to_linear(rgb[0]),
        srgb_to_linear(rgb[1]),
        srgb_to_linear(rgb[2]),
        1.0,
    )
    bsdf.inputs["Metallic"].default_value = float(metallic)
    bsdf.inputs["Roughness"].default_value = float(roughness)
    if "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = float(coat)
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.55
    return mat


def link_object(bm, name, material, subsurf_levels=2, bevel_width=0.0):
    mesh = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = True
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    obj.data.materials.append(material)

    if bevel_width > 0.0:
        bev = obj.modifiers.new("Bevel", "BEVEL")
        bev.width = bevel_width
        bev.segments = 2
        bev.limit_method = "ANGLE"
        bev.angle_limit = math.radians(32)
    if subsurf_levels > 0:
        sub = obj.modifiers.new("Subsurf", "SUBSURF")
        sub.levels = subsurf_levels
        sub.render_levels = subsurf_levels

    # Apply modifiers cleanly.
    with bpy.context.temp_override(object=obj, active_object=obj, selected_objects=[obj]):
        for mod in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=mod.name)

    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def frame_on_curve(pts, index):
    """Parallel-transport-free stable local frame (tangent, normal, binormal) along polyline."""
    n = len(pts)
    if index == 0:
        t = (pts[1] - pts[0]).normalized()
    elif index == n - 1:
        t = (pts[-1] - pts[-2]).normalized()
    else:
        t = (pts[index + 1] - pts[index - 1]).normalized()
    ref = Vector((0, 0, 1)) if abs(t.z) < 0.92 else Vector((1, 0, 0))
    u = t.cross(ref).normalized()
    v = t.cross(u).normalized()
    return t, u, v


def add_swept_tube(bm, points, radii_uv, sides=24, cap_start=True, cap_end=True, twist=0.0):
    """Sweep an elliptical cross-section with smoothly rounded end caps into `bm`."""
    rings = []
    # Use parallel transport so cross-sections never flip abruptly.
    t0 = (points[1] - points[0]).normalized()
    ref = Vector((0, 1, 0)) if abs(t0.y) < 0.9 else Vector((1, 0, 0))
    u = t0.cross(ref).normalized()
    v = t0.cross(u).normalized()

    n_pts = len(points)
    for i, pt in enumerate(points):
        if i == 0:
            t = (points[1] - points[0]).normalized()
        elif i == n_pts - 1:
            t = (points[-1] - points[-2]).normalized()
        else:
            t = (points[i + 1] - points[i - 1]).normalized()
            rot = t_prev.rotation_difference(t)
            u = (rot @ u).normalized()
            v = t.cross(u).normalized()
        t_prev = t

        ru, rv = radii_uv[i]
        ang_off = twist * (i / max(1, n_pts - 1))
        ring = []
        for s in range(sides):
            a = 2.0 * math.pi * s / sides + ang_off
            p = pt + u * (ru * math.cos(a)) + v * (rv * math.sin(a))
            ring.append(bm.verts.new(p))
        rings.append(ring)

    for i in range(len(rings) - 1):
        r0, r1 = rings[i], rings[i + 1]
        for s in range(sides):
            sn = (s + 1) % sides
            bm.faces.new((r0[s], r0[sn], r1[sn], r1[s]))

    if cap_start:
        t_s = (points[1] - points[0]).normalized()
        r_avg = 0.5 * (radii_uv[0][0] + radii_uv[0][1])
        c_s = bm.verts.new(points[0] - t_s * (r_avg * 0.55))
        r0 = rings[0]
        for s in range(sides):
            sn = (s + 1) % sides
            bm.faces.new((r0[sn], r0[s], c_s))

    if cap_end:
        t_e = (points[-1] - points[-2]).normalized()
        r_avg = 0.5 * (radii_uv[-1][0] + radii_uv[-1][1])
        c_e = bm.verts.new(points[-1] + t_e * (r_avg * 0.55))
        r1 = rings[-1]
        for s in range(sides):
            sn = (s + 1) % sides
            bm.faces.new((r1[s], r1[sn], c_e))


def add_lathe(bm, profile_rz, segments=36, origin=Vector((0, 0, 0)), axis_mat=Matrix.Identity(4)):
    """Revolve a 2D (radius, z) profile around local Z and transform by `axis_mat`."""
    rings = []
    pole_verts = []
    for r, z in profile_rz:
        if r <= 1e-6:
            v = bm.verts.new(axis_mat @ (origin + Vector((0, 0, z))))
            rings.append(None)
            pole_verts.append(v)
        else:
            ring = []
            for s in range(segments):
                a = 2.0 * math.pi * s / segments
                local = origin + Vector((r * math.cos(a), r * math.sin(a), z))
                ring.append(bm.verts.new(axis_mat @ local))
            rings.append(ring)
            pole_verts.append(None)

    for i in range(len(profile_rz) - 1):
        r0, p0 = rings[i], pole_verts[i]
        r1, p1 = rings[i + 1], pole_verts[i + 1]
        if r0 is None and r1 is not None:
            for s in range(segments):
                sn = (s + 1) % segments
                bm.faces.new((p0, r1[sn], r1[s]))
        elif r0 is not None and r1 is None:
            for s in range(segments):
                sn = (s + 1) % segments
                bm.faces.new((r0[s], r0[sn], p1))
        elif r0 is not None and r1 is not None:
            for s in range(segments):
                sn = (s + 1) % segments
                bm.faces.new((r0[s], r0[sn], r1[sn], r1[s]))


def cubic_bezier(p0, p1, p2, p3, n):
    pts = []
    for i in range(n):
        t = i / (n - 1)
        mt = 1.0 - t
        p = (mt ** 3) * p0 + 3 * (mt ** 2) * t * p1 + 3 * mt * (t ** 2) * p2 + (t ** 3) * p3
        pts.append(p)
    return pts


def smoothstep(edge0, edge1, x):
    t = max(0.0, min(1.0, (x - edge0) / max(1e-6, edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def make_zone_materials(finish):
    return {
        "shell": make_pbr_material("Mat_Shell", finish["shell"], metallic=finish["metallic"], roughness=finish["roughness"], coat=0.18),
        "inner": make_pbr_material("Mat_Inner", finish["cushion"], metallic=0.08, roughness=min(0.62, finish["roughness"] + 0.14)),
        "accent": make_pbr_material("Mat_Accent", finish["accent"], metallic=0.72, roughness=0.26, coat=0.2),
        "wing": make_pbr_material("Mat_Wing", finish["cushion"], metallic=0.0, roughness=0.62),
        "cushion": make_pbr_material("Mat_Cushion", finish["cushion"], metallic=0.0, roughness=0.58),
        "metal": make_pbr_material("Mat_Metal", finish["metal"], metallic=0.88, roughness=0.22),
        "grille": make_pbr_material("Mat_Grille", (0.045, 0.048, 0.055), metallic=0.35, roughness=0.55),
    }


def join_and_bake(objects, final_name, mat):
    """Join a list of objects into one mesh object with transform baked, named cleanly."""
    if not objects:
        return None
    for o in objects:
        mw = o.matrix_world.copy()
        o.data.transform(mw)
        o.matrix_world = Matrix.Identity(4)
        if mw.determinant() < 0:
            o.data.flip_normals()
        o.data.materials.clear()
        o.data.materials.append(mat)
    if len(objects) > 1:
        with bpy.context.temp_override(
            object=objects[0],
            active_object=objects[0],
            selected_objects=objects,
            selected_editable_objects=objects,
        ):
            bpy.ops.object.join()
    obj = objects[0]
    obj.name = final_name
    obj.data.name = final_name
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def normalize_and_export(zone_groups, mats, usdz_path):
    """Join objects per zone, assign UVMap, normalize bbox to 1.0, export & validate USDZ."""
    zone_objs = []
    for zone_name, objs in zone_groups.items():
        if not objs:
            continue
        mat_key = zone_name.replace("Zone_", "").lower()
        joined = join_and_bake(objs, zone_name, mats[mat_key])
        if joined is not None:
            if not joined.data.uv_layers:
                joined.data.uv_layers.new(name="UVMap")
            zone_objs.append(joined)

    # Ensure normals point cleanly outward and normalize whole assembly to max side = 1.0 at origin.
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in zone_objs:
        for v in o.data.vertices:
            for i in range(3):
                lo[i] = min(lo[i], v.co[i])
                hi[i] = max(hi[i], v.co[i])
    size = hi - lo
    center = (hi + lo) / 2.0
    s = 1.0 / max(size)
    norm_mat = Matrix.Scale(s, 4) @ Matrix.Translation(-center)
    for o in zone_objs:
        o.data.transform(norm_mat)
        o.data.update()

    os.makedirs(os.path.dirname(usdz_path), exist_ok=True)
    bpy.ops.wm.usd_export(
        filepath=usdz_path,
        export_animation=False,
        export_materials=True,
        generate_preview_surface=True,
        export_textures_mode="NEW",
        overwrite_textures=True,
        convert_orientation=True,
        export_global_forward_selection="NEGATIVE_Z",
        export_global_up_selection="Y",
        triangulate_meshes=True,
        export_lights=False,
        export_cameras=False,
        root_prim_path="/root",
        meters_per_unit=1.0,
    )
    checker = "/usr/bin/usdchecker"
    if os.path.exists(checker):
        subprocess.run([checker, usdz_path], check=True)
    else:
        subprocess.run(["/usr/bin/usdzip", "-l", usdz_path], check=True, stdout=subprocess.DEVNULL)
    tris = sum(len(p.vertices) - 2 for o in zone_objs for p in o.data.polygons)
    print(f"EXPORTED {usdz_path}: {len(zone_objs)} zones, {tris} tris, size={tuple(round(x * s, 3) for x in size)}")


def finalize_bm(bm, xf, name, material, subsurf_levels=1):
    """Ensure positive outward winding in local space, transform by `xf` (flipping if mirrored), then subdivide."""
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.transform(bm, matrix=xf, verts=bm.verts)
    if xf.determinant() < 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
    bm.normal_update()
    return link_object(bm, name, material, subsurf_levels=subsurf_levels)


# ==============================================================================
# MODEL 1: BEATS BUDS (Wingtip Sport Earbuds — sculpted pill capsule + wingtip)
# ==============================================================================

def _pill_bud_parts(side: int, mats, world_mat: Matrix, groups: dict):
    """Build one sculpted wingtip sport earbud (+X side = +1 for Right, -1 for Left)."""
    mirror = Matrix.Scale(-1.0, 4, Vector((1, 0, 0))) if side < 0 else Matrix.Identity(4)
    xf = world_mat @ mirror

    # 1) Zone_Shell: Sculpted rounded-teardrop pill housing with subtle concave outer thumb facet.
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=4, radius=1.0)
    for v in bm.verts:
        p = v.co
        taper = 1.0 - 0.19 * max(0.0, -p.z) + 0.06 * max(0.0, p.z)
        x = p.x * 0.145 * taper
        z = p.z * 0.225
        y_scale = 0.072 if p.y < 0 else 0.105
        y = p.y * y_scale
        if y < 0:
            dx = x / 0.112
            dz = (z + 0.008) / 0.172
            r2 = dx * dx + dz * dz
            dish = (1.0 - smoothstep(0.12, 0.78, r2)) * 0.009
            y += dish
        y += 0.012 * p.z
        v.co = Vector((x, y, z))
    groups["Zone_Shell"].append(finalize_bm(bm, xf, f"BudShell_{side}", mats["shell"], subsurf_levels=1))

    # 2) Zone_Accent: Flush chamfered metallic split-line bezel framing outer shell edge.
    bm = bmesh.new()
    n_rim = 48
    rim_rings = []
    for i in range(n_rim):
        a = 2.0 * math.pi * i / n_rim
        pz = math.sin(a)
        px = math.cos(a)
        taper = 1.0 - 0.19 * max(0.0, -pz) + 0.06 * max(0.0, pz)
        center_l = Vector((px * 0.142 * taper, -0.006 + 0.012 * pz, pz * 0.222))
        out_dir = Vector((px * 0.95, 0.0, pz * 0.62)).normalized()
        y_dir = Vector((0, 1, 0))
        ring = []
        for s in range(14):
            b = 2.0 * math.pi * s / 14
            off = out_dir * (0.0085 * math.cos(b)) + y_dir * (0.0115 * math.sin(b))
            ring.append(bm.verts.new(center_l + off))
        rim_rings.append(ring)
    for i in range(n_rim):
        r0 = rim_rings[i]
        r1 = rim_rings[(i + 1) % n_rim]
        for s in range(14):
            sn = (s + 1) % 14
            bm.faces.new((r0[s], r0[sn], r1[sn], r1[s]))
    groups["Zone_Accent"].append(finalize_bm(bm, xf, f"BudBezel_{side}", mats["accent"], subsurf_levels=1))

    # 3) Zone_Inner: Contoured inner ear-bowl + angled acoustic nozzle (separate clean bmeshes).
    bm_bowl = bmesh.new()
    bmesh.ops.create_icosphere(bm_bowl, subdivisions=3, radius=1.0)
    for v in bm_bowl.verts:
        p = v.co
        r_y = 0.115 if p.y > 0 else 0.055
        v.co = Vector((p.x * 0.122 - 0.018, p.y * r_y + 0.048, p.z * 0.145 + 0.028))
    groups["Zone_Inner"].append(finalize_bm(bm_bowl, xf, f"BudInnerBowl_{side}", mats["inner"], subsurf_levels=1))

    bm_noz = bmesh.new()
    nozzle_pts = [
        Vector((-0.025, 0.095, 0.015)),
        Vector((-0.045, 0.145, 0.002)),
        Vector((-0.068, 0.195, -0.012)),
    ]
    add_swept_tube(bm_noz, nozzle_pts, [(0.056, 0.056), (0.049, 0.049), (0.046, 0.046)], sides=20)
    groups["Zone_Inner"].append(finalize_bm(bm_noz, xf, f"BudNozzle_{side}", mats["inner"], subsurf_levels=1))

    # 4) Zone_Wing: Sleek organic flexible silicone wingtip rising gracefully from upper body & curving inward.
    bm_wing = bmesh.new()
    w_pts = cubic_bezier(
        Vector((-0.008, 0.048, 0.085)),
        Vector((-0.010, 0.085, 0.215)),
        Vector((-0.068, 0.140, 0.328)),
        Vector((-0.175, 0.135, 0.355)),
        26,
    )
    w_radii = []
    for i in range(len(w_pts)):
        t = i / (len(w_pts) - 1)
        w_base = (1.0 - t) ** 1.15
        ru = 0.022 + 0.068 * w_base
        rv = 0.017 + 0.040 * w_base
        w_radii.append((ru, rv))
    add_swept_tube(bm_wing, w_pts, w_radii, sides=22, cap_start=True, cap_end=True, twist=0.22)
    groups["Zone_Wing"].append(finalize_bm(bm_wing, xf, f"BudWing_{side}", mats["wing"], subsurf_levels=1))

    bm_collar = bmesh.new()
    bmesh.ops.create_icosphere(bm_collar, subdivisions=3, radius=1.0)
    for v in bm_collar.verts:
        p = v.co
        v.co = Vector((p.x * 0.114 - 0.015, p.y * 0.084 + 0.070, p.z * 0.128 + 0.052))
    groups["Zone_Wing"].append(finalize_bm(bm_collar, xf, f"BudWingCollar_{side}", mats["wing"], subsurf_levels=1))

    # 5) Zone_Cushion: Watertight contoured silicone eartip seated on nozzle end.
    tip_origin = Vector((-0.068, 0.195, -0.012))
    nozzle_dir = Vector((-0.043, 0.100, -0.027)).normalized()
    tip_rot = Vector((0, 0, 1)).rotation_difference(nozzle_dir).to_matrix().to_4x4()
    tip_local = Matrix.Translation(tip_origin) @ tip_rot
    profile = [
        (0.0, -0.032),
        (0.036, -0.032),
        (0.048, -0.025),
        (0.088, -0.002),
        (0.108, 0.038),
        (0.100, 0.075),
        (0.076, 0.098),
        (0.046, 0.106),
        (0.030, 0.096),
        (0.026, 0.060),
        (0.0, 0.060),
    ]
    bm_tip = bmesh.new()
    add_lathe(bm_tip, profile, segments=32, axis_mat=tip_local)
    groups["Zone_Cushion"].append(finalize_bm(bm_tip, xf, f"BudTip_{side}", mats["cushion"], subsurf_levels=1))

    # 6) Zone_Grille: Recessed lower pill acoustic port, tiny mic pinholes, and inner nozzle screen.
    bm_screen = bmesh.new()
    add_lathe(bm_screen, [(0.0, 0.082), (0.027, 0.082), (0.027, 0.075), (0.0, 0.075)], segments=20, axis_mat=tip_local)
    groups["Zone_Grille"].append(finalize_bm(bm_screen, xf, f"BudScreen_{side}", mats["grille"], subsurf_levels=1))

    bm_port = bmesh.new()
    add_lathe(
        bm_port,
        [(0.0, 0.003), (0.028, 0.003), (0.030, -0.006), (0.0, -0.006)],
        segments=24,
        axis_mat=Matrix.Translation(Vector((0.0, -0.062, -0.140))) @ Euler((math.radians(82), 0, 0)).to_matrix().to_4x4(),
    )
    groups["Zone_Grille"].append(finalize_bm(bm_port, xf, f"BudPort_{side}", mats["grille"], subsurf_levels=1))

    for idx, (pz, py) in enumerate([(0.168, -0.042), (-0.095, -0.060)]):
        bm_mic = bmesh.new()
        add_lathe(
            bm_mic,
            [(0.0, 0.002), (0.006, 0.002), (0.006, -0.004), (0.0, -0.004)],
            segments=12,
            axis_mat=Matrix.Translation(Vector((0.0, py, pz))) @ Euler((math.radians(90), 0, 0)).to_matrix().to_4x4(),
        )
        groups["Zone_Grille"].append(finalize_bm(bm_mic, xf, f"BudMic_{side}_{idx}", mats["grille"], subsurf_levels=1))

    bm_vent = bmesh.new()
    add_swept_tube(bm_vent, [Vector((0.122, -0.006, 0.015)), Vector((0.118, -0.004, 0.075))], [(0.013, 0.011), (0.013, 0.011)], sides=14)
    groups["Zone_Grille"].append(finalize_bm(bm_vent, xf, f"BudVent_{side}", mats["grille"], subsurf_levels=1))

    # 7) Zone_Metal: Three flush micro charging pogo contacts on lower inner back.
    for idx, dx in enumerate((-0.028, 0.0, 0.028)):
        bm_pin = bmesh.new()
        p_local = Matrix.Translation(Vector((dx, 0.072, -0.125))) @ Euler((math.radians(-78), 0, 0)).to_matrix().to_4x4()
        add_lathe(bm_pin, [(0.0, 0.003), (0.0085, 0.003), (0.0085, -0.003), (0.0, -0.003)], segments=14, axis_mat=p_local)
        groups["Zone_Metal"].append(finalize_bm(bm_pin, xf, f"BudPin_{side}_{idx}", mats["metal"], subsurf_levels=0))


def build_beats_buds(usdz_path):
    reset_scene()
    mats = make_zone_materials(OVER_EAR_FINISHES[0])
    groups = {k: [] for k in ["Zone_Shell", "Zone_Inner", "Zone_Accent", "Zone_Wing", "Zone_Cushion", "Zone_Grille", "Zone_Metal"]}

    # Balanced stereo pair matching CardRenderBeatsFit*:
    # Left bud (+36° yaw) shows inner contour + nozzle + wingtip; Right bud (-24° yaw) shows outer teardrop + bezel + wingtip.
    left_xf = (
        Matrix.Translation(Vector((-0.215, 0.015, 0.0)))
        @ Euler((math.radians(8), math.radians(-8), math.radians(36)), "XYZ").to_matrix().to_4x4()
    )
    right_xf = (
        Matrix.Translation(Vector((0.215, -0.015, 0.0)))
        @ Euler((math.radians(6), math.radians(8), math.radians(-24)), "XYZ").to_matrix().to_4x4()
    )
    _pill_bud_parts(-1, mats, left_xf, groups)
    _pill_bud_parts(+1, mats, right_xf, groups)
    normalize_and_export(groups, mats, usdz_path)


# ==============================================================================
# MODEL 2: BEATS EARHOOK (Powerbeats Pro / Pro 2 — sport body + sweeping earhook)
# ==============================================================================

def _earhook_bud_parts(side: int, mats, world_mat: Matrix, groups: dict):
    mirror = Matrix.Scale(-1.0, 4, Vector((1, 0, 0))) if side < 0 else Matrix.Identity(4)
    xf = world_mat @ mirror

    # 1) Zone_Shell: Sleek faceted/rounded sport acoustic pod tapering downward.
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=4, radius=1.0)
    for v in bm.verts:
        p = v.co
        z = p.z * 0.275
        taper = 0.72 + 0.34 * smoothstep(-1.0, 0.75, p.z)
        x = p.x * 0.132 * taper
        y_scale = 0.068 if p.y < 0 else 0.098
        y = p.y * y_scale * (0.85 + 0.15 * smoothstep(-1.0, 0.6, p.z))
        if p.y < 0:
            dx = x / 0.105
            dz = (z - 0.04) / 0.155
            r2 = dx * dx + dz * dz
            y += (1.0 - smoothstep(0.12, 0.76, r2)) * 0.008
        v.co = Vector((x, y, z))
    groups["Zone_Shell"].append(finalize_bm(bm, xf, f"HookShell_{side}", mats["shell"], subsurf_levels=1))

    # 2) Zone_Accent: Flush chamfered outer perimeter metallic trim ring.
    bm = bmesh.new()
    n_rim = 48
    rings = []
    for i in range(n_rim):
        a = 2.0 * math.pi * i / n_rim
        pz = math.sin(a)
        px = math.cos(a)
        taper = 0.72 + 0.34 * smoothstep(-1.0, 0.75, pz)
        center_l = Vector((px * 0.129 * taper, -0.007, pz * 0.271))
        out_dir = Vector((px * 0.95, 0.0, pz * 0.52)).normalized()
        y_dir = Vector((0, 1, 0))
        ring = []
        for s in range(14):
            b = 2.0 * math.pi * s / 14
            off = out_dir * (0.008 * math.cos(b)) + y_dir * (0.0105 * math.sin(b))
            ring.append(bm.verts.new(center_l + off))
        rings.append(ring)
    for i in range(n_rim):
        r0 = rings[i]
        r1 = rings[(i + 1) % n_rim]
        for s in range(14):
            sn = (s + 1) % 14
            bm.faces.new((r0[s], r0[sn], r1[sn], r1[s]))
    groups["Zone_Accent"].append(finalize_bm(bm, xf, f"HookBezel_{side}", mats["accent"], subsurf_levels=1))

    # 3) Zone_Inner: Contoured inner ear-bowl + angled nozzle.
    bm_bowl = bmesh.new()
    bmesh.ops.create_icosphere(bm_bowl, subdivisions=3, radius=1.0)
    for v in bm_bowl.verts:
        p = v.co
        v.co = Vector((p.x * 0.115 - 0.020, p.y * 0.088 + 0.055, p.z * 0.125 + 0.065))
    groups["Zone_Inner"].append(finalize_bm(bm_bowl, xf, f"HookInner_{side}", mats["inner"], subsurf_levels=1))

    bm_noz = bmesh.new()
    nozzle_pts = [
        Vector((-0.028, 0.098, 0.055)),
        Vector((-0.050, 0.150, 0.040)),
        Vector((-0.074, 0.200, 0.026)),
    ]
    add_swept_tube(bm_noz, nozzle_pts, [(0.052, 0.052), (0.046, 0.046), (0.043, 0.043)], sides=20)
    groups["Zone_Inner"].append(finalize_bm(bm_noz, xf, f"HookNozzle_{side}", mats["inner"], subsurf_levels=1))

    # 4) Zone_Wing: Graceful sweeping over-ear curved sport earhook.
    bm_hook = bmesh.new()
    hook_pts = cubic_bezier(
        Vector((0.0, 0.005, 0.195)),
        Vector((-0.042, 0.145, 0.455)),
        Vector((-0.055, 0.425, 0.415)),
        Vector((0.028, 0.460, 0.115)),
        30,
    ) + cubic_bezier(
        Vector((0.028, 0.460, 0.115)),
        Vector((0.068, 0.468, -0.025)),
        Vector((0.095, 0.420, -0.140)),
        Vector((0.090, 0.340, -0.185)),
        14,
    )[1:]
    hook_radii = []
    n_h = len(hook_pts)
    for i in range(n_h):
        t = i / (n_h - 1)
        scale = 1.0 - 0.42 * (t ** 0.9)
        hook_radii.append((0.028 * scale, 0.036 * scale))
    add_swept_tube(bm_hook, hook_pts, hook_radii, sides=20, cap_start=True, cap_end=True)
    groups["Zone_Wing"].append(finalize_bm(bm_hook, xf, f"HookLoop_{side}", mats["wing"], subsurf_levels=1))

    # 5) Zone_Cushion: Watertight contoured silicone eartip.
    tip_origin = Vector((-0.074, 0.200, 0.026))
    nozzle_dir = Vector((-0.046, 0.102, -0.029)).normalized()
    tip_rot = Vector((0, 0, 1)).rotation_difference(nozzle_dir).to_matrix().to_4x4()
    tip_local = Matrix.Translation(tip_origin) @ tip_rot
    profile = [
        (0.0, -0.030),
        (0.034, -0.030),
        (0.046, -0.022),
        (0.084, 0.0),
        (0.102, 0.036),
        (0.094, 0.070),
        (0.072, 0.092),
        (0.042, 0.099),
        (0.028, 0.090),
        (0.024, 0.056),
        (0.0, 0.056),
    ]
    bm_tip = bmesh.new()
    add_lathe(bm_tip, profile, segments=30, axis_mat=tip_local)
    groups["Zone_Cushion"].append(finalize_bm(bm_tip, xf, f"HookTip_{side}", mats["cushion"], subsurf_levels=1))

    # 6) Zone_Metal: Metallic strain-relief collar at hook base + charging pins.
    bm_collar = bmesh.new()
    collar_pts = [Vector((-0.002, 0.015, 0.205)), Vector((-0.015, 0.058, 0.285))]
    add_swept_tube(bm_collar, collar_pts, [(0.034, 0.042), (0.031, 0.039)], sides=18)
    groups["Zone_Metal"].append(finalize_bm(bm_collar, xf, f"HookCollar_{side}", mats["metal"], subsurf_levels=1))

    for idx, dz in enumerate((-0.115, -0.155)):
        bm_pin = bmesh.new()
        p_local = Matrix.Translation(Vector((0.0, 0.072, dz))) @ Euler((math.radians(-84), 0, 0)).to_matrix().to_4x4()
        add_lathe(bm_pin, [(0.0, 0.003), (0.010, 0.003), (0.010, -0.003), (0.0, -0.003)], segments=14, axis_mat=p_local)
        groups["Zone_Metal"].append(finalize_bm(bm_pin, xf, f"HookPin_{side}_{idx}", mats["metal"], subsurf_levels=0))

    # 7) Zone_Grille: Acoustic ports + nozzle screen.
    bm_screen = bmesh.new()
    add_lathe(bm_screen, [(0.0, 0.080), (0.025, 0.080), (0.025, 0.072), (0.0, 0.072)], segments=18, axis_mat=tip_local)
    groups["Zone_Grille"].append(finalize_bm(bm_screen, xf, f"HookScreen_{side}", mats["grille"], subsurf_levels=1))

    bm_port = bmesh.new()
    add_lathe(
        bm_port,
        [(0.0, 0.002), (0.022, 0.002), (0.022, -0.005), (0.0, -0.005)],
        segments=18,
        axis_mat=Matrix.Translation(Vector((0.0, -0.058, -0.175))) @ Euler((math.radians(84), 0, 0)).to_matrix().to_4x4(),
    )
    groups["Zone_Grille"].append(finalize_bm(bm_port, xf, f"HookPort_{side}", mats["grille"], subsurf_levels=1))


def build_beats_earhook(usdz_path):
    reset_scene()
    mats = make_zone_materials(OVER_EAR_FINISHES[0])
    groups = {k: [] for k in ["Zone_Shell", "Zone_Inner", "Zone_Accent", "Zone_Wing", "Zone_Cushion", "Zone_Grille", "Zone_Metal"]}

    # Balanced compact hero pair showing both Left (inner + sweeping hook) and Right (faceplate + sweeping hook)
    left_xf = (
        Matrix.Translation(Vector((-0.225, -0.01, -0.01)))
        @ Euler((math.radians(8), math.radians(-10), math.radians(52)), "XYZ").to_matrix().to_4x4()
    )
    right_xf = (
        Matrix.Translation(Vector((0.225, -0.01, -0.01)))
        @ Euler((math.radians(6), math.radians(10), math.radians(-28)), "XYZ").to_matrix().to_4x4()
    )
    _earhook_bud_parts(-1, mats, left_xf, groups)
    _earhook_bud_parts(+1, mats, right_xf, groups)
    normalize_and_export(groups, mats, usdz_path)


# ==============================================================================
# MODEL 3: BEATS OVER-EAR (Modern closed-back wireless studio over-ear headphones)
# ==============================================================================

def _add_rounded_oval_cup_shell(bm, xf, rx=0.148, rz=0.185, depth_out=0.072):
    """Build a crisp, smoothly double-curved closed-back oval earcup shell (+X = outer, -X = inner)."""
    # Revolve in local coordinates where local +Z is outward earcup normal, local X/Y are oval radii!
    # Profile from flat inner mount rim -> chamfer -> curved outer dome -> top center pole
    profile = [
        (0.92, -0.006),
        (0.985, 0.0),
        (1.00, 0.014),
        (0.99, 0.032),
        (0.92, 0.050),
        (0.76, 0.064),
        (0.50, 0.071),
        (0.22, 0.0735),
        (0.0, 0.074),
    ]
    segs = 48
    rings = []
    poles = []
    for rad_n, z_val in profile:
        if rad_n <= 1e-6:
            poles.append(bm.verts.new(xf @ Vector((0, 0, z_val * (depth_out / 0.074)))))
            rings.append(None)
        else:
            ring = []
            for s in range(segs):
                a = 2.0 * math.pi * s / segs
                # Local X = front/back depth of cup (rx), local Y = cup height (rz)
                lx = rad_n * rx * math.cos(a)
                ly = rad_n * rz * math.sin(a)
                lz = z_val * (depth_out / 0.074)
                ring.append(bm.verts.new(xf @ Vector((lx, ly, lz))))
            rings.append(ring)
            poles.append(None)

    for i in range(len(profile) - 1):
        r0, p0 = rings[i], poles[i]
        r1, p1 = rings[i + 1], poles[i + 1]
        if r0 is not None and r1 is None:
            for s in range(segs):
                sn = (s + 1) % segs
                bm.faces.new((r0[s], r0[sn], p1))
        elif r0 is not None and r1 is not None:
            for s in range(segs):
                sn = (s + 1) % segs
                bm.faces.new((r0[s], r0[sn], r1[sn], r1[s]))

    # Cap inner plate cleanly so the cup is watertight behind cushion
    inner_pole = bm.verts.new(xf @ Vector((0, 0, -0.008)))
    for s in range(segs):
        sn = (s + 1) % segs
        bm.faces.new((rings[0][sn], rings[0][s], inner_pole))


def _add_plush_oval_cushion(bm, xf, rx=0.146, rz=0.184):
    """Build a plush contoured oval memory-foam earpad extending in local -Z (inward toward head)."""
    # Closed cross-section ring swept around an oval loop in XY (with slight ergonomic squish on inner side)
    segs_u = 48
    segs_v = 24
    # Cross section parameters: outer radius width w ≈ 0.050, thickness t ≈ 0.068
    grid = []
    for iu in range(segs_u):
        au = 2.0 * math.pi * iu / segs_u
        cu, su = math.cos(au), math.sin(au)
        # Centerline of foam tube lies on an oval ~72% of outer edge
        mid_x = 0.72 * rx * cu
        mid_y = 0.72 * rz * su
        out_vec = Vector((cu * 0.28 * rx, su * 0.28 * rz, 0.0))
        out_len = out_vec.length
        out_dir = out_vec.normalized()
        row = []
        for iv in range(segs_v):
            av = 2.0 * math.pi * iv / segs_v
            # Soft squircle-like cushion cross-section: flat mount against cup (z=0), plush curved ear face (z=-0.068)
            cv, sv = math.cos(av), math.sin(av)
            rad_off = out_len * cv
            z_off = -0.036 + 0.036 * sv
            # Slight inward bevel near ear wall so inside reads tailored
            if cv < 0:
                rad_off *= 0.72
            p = Vector((mid_x, mid_y, 0.0)) + out_dir * rad_off + Vector((0, 0, z_off))
            row.append(bm.verts.new(xf @ p))
        grid.append(row)
    for iu in range(segs_u):
        r0 = grid[iu]
        r1 = grid[(iu + 1) % segs_u]
        for iv in range(segs_v):
            ivn = (iv + 1) % segs_v
            bm.faces.new((r0[iv], r1[iv], r1[ivn], r0[ivn]))


def build_beats_over_ear(usdz_path, finish=None):
    reset_scene()
    if finish is None:
        finish = OVER_EAR_FINISHES[0]
    mats = make_zone_materials(finish)
    groups = {k: [] for k in ["Zone_Shell", "Zone_Accent", "Zone_Cushion", "Zone_Grille", "Zone_Metal"]}

    # Coordinates inside Blender before USD export: Z = UP, -Y = FRONT (becomes +Z), X = RIGHT/LEFT
    # Parabolic/arch headband in X-Z plane from side to side.
    # Hinge anchor points at (±0.335, 0, +0.02), crown reaches Z ≈ +0.435.
    hb_pts = []
    hb_radii = []
    n_hb = 44
    for i in range(n_hb):
        # Angle from 15 deg (right hinge top) to 165 deg (left hinge top)
        t = i / (n_hb - 1)
        a = math.radians(12) + t * math.radians(156)
        # Slightly broad top shoulder silhouette (superellipse-like arch)
        ca, sa = math.cos(a), math.sin(a)
        x = 0.345 * math.copysign(abs(ca) ** 0.88, ca)
        z = 0.01 + 0.425 * (sa ** 0.82)
        hb_pts.append(Vector((x, 0.0, z)))
        # Taper slightly thicker at crown center, narrower sleek band toward hinges
        crown_weight = math.sin(math.pi * t) ** 0.7
        depth_y = 0.056 + 0.014 * crown_weight
        thick_r = 0.024 + 0.004 * crown_weight
        hb_radii.append((thick_r, depth_y))

    bm = bmesh.new()
    # Flat-ish tailored strap cross section via capsule sweep + subtle inner flatten
    add_swept_tube(bm, hb_pts, hb_radii, sides=22, cap_start=True, cap_end=True)
    groups["Zone_Shell"].append(link_object(bm, "OverEarHeadband", mats["shell"], subsurf_levels=1))

    # Underside headband silicone cushion pad tucked along the inner arch (~middle 70%)
    bm = bmesh.new()
    pad_pts = []
    pad_radii = []
    n_pad = 28
    for i in range(n_pad):
        t = 0.14 + 0.72 * (i / (n_pad - 1))
        a = math.radians(12) + t * math.radians(156)
        ca, sa = math.cos(a), math.sin(a)
        x = 0.326 * math.copysign(abs(ca) ** 0.88, ca)
        z = 0.008 + 0.402 * (sa ** 0.82)
        pad_pts.append(Vector((x, 0.0, z)))
        edge_taper = math.sin(math.pi * (i / (n_pad - 1))) ** 0.35
        pad_radii.append((0.022 * edge_taper + 0.004, 0.050 * edge_taper + 0.012))
    add_swept_tube(bm, pad_pts, pad_radii, sides=20, cap_start=True, cap_end=True)
    groups["Zone_Cushion"].append(link_object(bm, "HeadbandPad", mats["cushion"], subsurf_levels=1))

    # Left (-1) & Right (+1) earcups, cushions, rings, metallic folding hinges & sliders
    for side in (-1, 1):
        # Cup center at (±0.285, 0.008, -0.175), local +Z pointing outward (+side X) angled slightly down & forward
        cup_center = Vector((side * 0.278, -0.005, -0.175))
        # Build rotation so local +Z points outward (side, -0.10, -0.14).normalized()
        out_normal = Vector((side * 1.0, -0.11, -0.15)).normalized()
        rot_q = Vector((0, 0, 1)).rotation_difference(out_normal)
        cup_rot = rot_q.to_matrix().to_4x4()
        # Keep cup vertical axis (local Y) upright
        local_z = out_normal
        up_hint = Vector((0, 0, 1))
        local_x = up_hint.cross(local_z).normalized()
        local_y = local_z.cross(local_x).normalized()
        cup_rot = Matrix((
            (local_x.x, local_y.x, local_z.x, 0),
            (local_x.y, local_y.y, local_z.y, 0),
            (local_x.z, local_y.z, local_z.z, 0),
            (0, 0, 0, 1),
        ))
        cup_xf = Matrix.Translation(cup_center) @ cup_rot

        # 1) Outer earcup shell
        bm = bmesh.new()
        _add_rounded_oval_cup_shell(bm, cup_xf, rx=0.148, rz=0.188, depth_out=0.072)
        groups["Zone_Shell"].append(link_object(bm, f"CupShell_{side}", mats["shell"], subsurf_levels=1))

        # 2) Outer metallic/satin accent ring & clean medallion disk (no third-party logo)
        bm = bmesh.new()
        # Raised chamfer ring around cup outer face center
        ring_xf = cup_xf @ Matrix.Translation(Vector((0, 0, 0.068)))
        add_lathe(
            bm,
            [
                (0.064, -0.004),
                (0.088, -0.004),
                (0.092, 0.004),
                (0.088, 0.008),
                (0.066, 0.008),
                (0.062, 0.003),
                (0.064, -0.004),
            ],
            segments=36,
            axis_mat=ring_xf,
        )
        groups["Zone_Accent"].append(link_object(bm, f"CupRing_{side}", mats["accent"], subsurf_levels=1))

        # 3) Plush oval memory-foam cushion
        bm = bmesh.new()
        _add_plush_oval_cushion(bm, cup_xf, rx=0.148, rz=0.188)
        groups["Zone_Cushion"].append(link_object(bm, f"CupCushion_{side}", mats["cushion"], subsurf_levels=1))

        # 4) Dark acoustic inner driver scrim inside the cushion well
        bm = bmesh.new()
        add_lathe(
            bm,
            [(0.0, -0.006), (0.098, -0.006), (0.098, -0.015), (0.0, -0.015)],
            segments=32,
            axis_mat=cup_xf @ Matrix.Scale(1.22, 4, Vector((0, 1, 0))),
        )
        groups["Zone_Grille"].append(link_object(bm, f"CupScrim_{side}", mats["grille"], subsurf_levels=0))

        # 5) Brushed-metal folding hinge collar + telescopic single-stem curved slider arm (separate clean bmeshes so nothing pinches).
        # Headband ends at x ≈ ±0.338, z ≈ +0.125; overlap solidly from z = +0.145 down to the cup rim & rear trunnion!
        bm_hinge = bmesh.new()
        hinge_pts = [
            Vector((side * 0.337, 0.0, 0.145)),
            Vector((side * 0.340, 0.0, 0.088)),
            Vector((side * 0.343, 0.0, 0.032)),
        ]
        add_swept_tube(bm_hinge, hinge_pts, [(0.025, 0.056), (0.026, 0.057), (0.024, 0.052)], sides=18)
        groups["Zone_Metal"].append(link_object(bm_hinge, f"CupHingeCollar_{side}", mats["metal"], subsurf_levels=1))

        # Sleek curved slider arm descending from inside the hinge collar along the upper-back rim of the cup
        bm_arm = bmesh.new()
        arm_target = cup_center + Vector((side * 0.048, 0.032, 0.025))
        arm_pts = cubic_bezier(
            Vector((side * 0.342, 0.0, 0.045)),
            Vector((side * 0.352, 0.008, -0.035)),
            Vector((side * 0.348, 0.024, -0.105)),
            arm_target,
            18,
        )
        arm_radii = []
        for i in range(len(arm_pts)):
            t = i / (len(arm_pts) - 1)
            w = 1.0 - 0.15 * t
            arm_radii.append((0.014 * w, 0.032 * w))
        add_swept_tube(bm_arm, arm_pts, arm_radii, sides=16)
        groups["Zone_Metal"].append(link_object(bm_arm, f"CupSliderArm_{side}", mats["metal"], subsurf_levels=1))

    normalize_and_export(groups, mats, usdz_path)


# ==============================================================================
# 2D CARD ARTWORK RENDERER FOR BEATS OVER-EAR (matches CardRenderBeatsFit*.png)
# ==============================================================================

def render_over_ear_card_png(finish):
    """Render transparent 1024×1024 studio PNG from the current BeatsOverEar scene setup."""
    reset_scene()
    mats = make_zone_materials(finish)
    groups = {k: [] for k in ["Zone_Shell", "Zone_Accent", "Zone_Cushion", "Zone_Grille", "Zone_Metal"]}
    # Re-create normalized scene cleanly in memory by importing the freshly built USDZ
    # or building directly with the finish colors:
    out_usdz = os.path.join(MODELS_DIR, "BeatsOverEar.usdz")
    bpy.ops.wm.usd_import(filepath=out_usdz)

    # Apply target finish materials by zone name!
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        nm = obj.name + (obj.parent.name if obj.parent else "")
        key = None
        for cand in ("Shell", "Accent", "Cushion", "Grille", "Metal"):
            if f"Zone_{cand}" in nm:
                key = cand.lower()
                break
        if key:
            obj.data.materials.clear()
            obj.data.materials.append(mats[key])

    sc = bpy.context.scene
    # Soft studio world illumination for rich rim & satin gradients
    world = bpy.data.worlds.new("CardStudio")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.45, 0.48, 0.54, 1.0)
    bg.inputs[1].default_value = 0.75

    def add_area(name, loc, energy, size, color=(1, 1, 1)):
        ld = bpy.data.lights.new(name, "AREA")
        ld.energy = energy
        ld.size = size
        ld.color = color
        lo = bpy.data.objects.new(name, ld)
        sc.collection.objects.link(lo)
        lo.location = loc
        d = Vector((0, 0, 0)) - Vector(loc)
        lo.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()

    add_area("Overhead", (0.0, -0.4, 2.8), 320, 2.4)
    add_area("Key", (2.1, -2.4, 2.2), 260, 2.2, (1.0, 0.96, 0.92))
    add_area("Fill", (-2.4, -1.6, 1.2), 140, 2.8, (0.90, 0.95, 1.0))
    add_area("Rim", (-0.8, 2.6, 1.8), 220, 2.2)

    cam_d = bpy.data.cameras.new("CardCam")
    cam_d.lens = 75
    cam = bpy.data.objects.new("CardCam", cam_d)
    sc.collection.objects.link(cam)
    sc.camera = cam

    # Match RealityKit default hero pose (~yaw = -0.5 rad, pitch = 0.12 rad) with clean studio framing margin
    cam_dir = Vector((0.88, -1.55, 0.42)).normalized()
    cam.location = cam_dir * 2.58
    cam.rotation_euler = (Vector((0, 0, 0.0)) - cam.location).to_track_quat("-Z", "Y").to_euler()

    engines = [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    sc.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in engines else "BLENDER_EEVEE"
    try:
        sc.eevee.taa_render_samples = 64
    except Exception:
        pass
    sc.render.resolution_x = 1024
    sc.render.resolution_y = 1024
    sc.render.film_transparent = True
    vts = [i.identifier for i in sc.view_settings.bl_rna.properties["view_transform"].enum_items]
    sc.view_settings.view_transform = "AgX" if "AgX" in vts else "Filmic"

    img_dir = os.path.join(ASSETS_DIR, f"{finish['asset']}.imageset")
    os.makedirs(img_dir, exist_ok=True)
    png_path = os.path.join(img_dir, f"{finish['asset']}.png")
    sc.render.filepath = png_path
    bpy.ops.render.render(write_still=True)

    contents_json = {
        "images": [{"filename": f"{finish['asset']}.png", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(img_dir, "Contents.json"), "w") as f:
        json.dump(contents_json, f, indent=2)
        f.write("\n")
    print(f"RENDERED CARD PNG {png_path}")


if __name__ == "__main__":
    build_beats_buds(os.path.join(MODELS_DIR, "BeatsBuds.usdz"))
    build_beats_earhook(os.path.join(MODELS_DIR, "BeatsEarhook.usdz"))
    build_beats_over_ear(os.path.join(MODELS_DIR, "BeatsOverEar.usdz"))
    for fin in OVER_EAR_FINISHES:
        render_over_ear_card_png(fin)
