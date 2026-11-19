"""Blender batch script: raw model -> optimized, normalized USDZ for RealityKit.

Usage:
  Blender -b --factory-startup -P tools/assets/process_model.py -- \
      --in assets-raw/airpods-max/scene.gltf --out Earprint/Resources/Models/AirPodsMax.usdz \
      [--target-tris 48000] [--max-tex 1024] [--rot 0,0,0] [--drop-emissive] \
      [--exclude REGEX] [--cutout REGEX] [--join-by-material] [--jpeg-opaque] \
      [--jpeg-quality 88] [--report out.json]

Steps: import -> bake transforms -> optional rotation (Blender space, degrees XYZ)
-> drop excluded objects -> decimate to the triangle budget -> optional join by material
-> center at origin and scale so the largest side is 1.0 -> fix glTF Math(Multiply) PBR
nodes -> export USDZ (Y-up, front = +Z, textures <= max-tex) -> optional USDZ
post-process (JPEG-compress opaque PNGs, inject opacityThreshold for alpha cutouts,
and run Apple's usdzip -c compliance check).

Orientation convention inside Blender before export: up = +Z, model front faces -Y
(what Blender's Front view shows). The exporter converts that to USD Y-up, front +Z.
"""

import argparse
import json
import math
import os
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

import bpy
import mathutils
import numpy as np

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ap = argparse.ArgumentParser()
ap.add_argument("--in", dest="inp", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--target-tris", type=int, default=60000)
ap.add_argument("--max-tex", type=int, default=2048)
ap.add_argument("--rot", default="0,0,0", help="extra rotation in degrees (X,Y,Z), Blender space")
ap.add_argument("--exclude", default=None, help="regex of object or material names to delete")
ap.add_argument("--drop-emissive", action="store_true", help="disconnect emission inputs")
ap.add_argument("--emission-scale", type=float, default=None, help="multiply emission strength")
ap.add_argument("--keep-small", type=int, default=300, help="meshes with fewer tris are not decimated")
ap.add_argument("--join-by-material", action="store_true", help="join single-material meshes sharing the same material")
ap.add_argument("--jpeg-opaque", action="store_true", help="convert opaque RGB PNG textures to JPEG if smaller")
ap.add_argument("--jpeg-quality", type=int, default=88, help="JPEG quality for --jpeg-opaque (default 88)")
ap.add_argument("--cutout", default=None, help="regex of material names to set UsdPreviewSurface opacityThreshold=0.5")
ap.add_argument("--report", default=None)
a = ap.parse_args(argv)

bpy.ops.wm.read_factory_settings(use_empty=True)
p = a.inp.lower()
if p.endswith((".gltf", ".glb")):
    bpy.ops.import_scene.gltf(filepath=a.inp)
elif p.endswith((".usdz", ".usd", ".usdc", ".usda")):
    bpy.ops.wm.usd_import(filepath=a.inp)
elif p.endswith(".fbx"):
    bpy.ops.import_scene.fbx(filepath=a.inp)
elif p.endswith(".obj"):
    bpy.ops.wm.obj_import(filepath=a.inp)
else:
    raise SystemExit(f"unsupported input {a.inp}")


def tri_count(obj):
    return sum(len(pl.vertices) - 2 for pl in obj.data.polygons)


# 1. Drop non-mesh objects, bake world transforms into mesh data.
for o in list(bpy.data.objects):
    if o.type != "MESH":
        continue
    if o.data.users > 1:
        o.data = o.data.copy()
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
for o in meshes:
    mw = o.matrix_world.copy()
    o.parent = None
    o.data.transform(mw)
    o.matrix_world = mathutils.Matrix.Identity(4)
    if mw.determinant() < 0:
        o.data.flip_normals()
for o in list(bpy.data.objects):
    if o.type != "MESH":
        bpy.data.objects.remove(o, do_unlink=True)

# 2. Exclusions.
removed = []
if a.exclude:
    rx = re.compile(a.exclude)
    for o in list(bpy.data.objects):
        mats = [s.material.name for s in o.material_slots if s.material]
        if rx.search(o.name) or any(rx.search(m) for m in mats):
            removed.append(o.name)
            bpy.data.objects.remove(o, do_unlink=True)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]

# 3. Extra rotation.
rx_, ry_, rz_ = (math.radians(float(v)) for v in a.rot.split(","))
R = mathutils.Euler((rx_, ry_, rz_), "XYZ").to_matrix().to_4x4()
if R != mathutils.Matrix.Identity(4):
    for o in meshes:
        o.data.transform(R)

src_tris = sum(tri_count(o) for o in meshes)

# 4. Decimate.
if src_tris > a.target_tris:
    small = sum(tri_count(o) for o in meshes if tri_count(o) < a.keep_small)
    large = src_tris - small
    ratio = max(0.05, min(1.0, (a.target_tris - small) / max(large, 1)))
    for o in meshes:
        if tri_count(o) < a.keep_small:
            continue
        m = o.modifiers.new("Decimate", "DECIMATE")
        m.decimate_type = "COLLAPSE"
        m.ratio = ratio
        m.use_collapse_triangulate = True
        with bpy.context.temp_override(object=o, active_object=o, selected_objects=[o]):
            bpy.ops.object.modifier_apply(modifier=m.name)
else:
    ratio = 1.0

# 4b. Prune unused extra UV layers (keep active UV + any UVMap referenced by shader nodes).
referenced_uvs = set()
for ma in bpy.data.materials:
    if ma.users == 0 or not getattr(ma, "node_tree", None):
        continue
    for n in ma.node_tree.nodes:
        if n.type == "UVMAP" and n.uv_map:
            referenced_uvs.add(n.uv_map)
for o in meshes:
    uvs = o.data.uv_layers
    if len(uvs) > 1:
        keep = {uvs.active.name if uvs.active else uvs[0].name} | referenced_uvs
        for uv in list(uvs):
            if uv.name not in keep:
                uvs.remove(uv)

# 4c. Optionally join single-material meshes sharing the same material.
if a.join_by_material:
    groups = {}
    for o in meshes:
        if len(o.material_slots) == 1 and o.material_slots[0].material is not None:
            if len(o.data.uv_layers) == 1:
                o.data.uv_layers[0].name = "UVMap"
            groups.setdefault(o.material_slots[0].material.name, []).append(o)
    for mname, objs in groups.items():
        if len(objs) <= 1:
            continue
        with bpy.context.temp_override(
            object=objs[0],
            active_object=objs[0],
            selected_objects=objs,
            selected_editable_objects=objs,
        ):
            bpy.ops.object.join()
        objs[0].name = f"Mesh_{mname}"
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]

# 5. Normalize: center bbox at origin, largest side = 1.0.
lo = mathutils.Vector((1e9, 1e9, 1e9))
hi = mathutils.Vector((-1e9, -1e9, -1e9))
for o in meshes:
    for v in o.data.vertices:
        for i in range(3):
            lo[i] = min(lo[i], v.co[i])
            hi[i] = max(hi[i], v.co[i])
size = hi - lo
center = (hi + lo) / 2
s = 1.0 / max(size)
N = mathutils.Matrix.Scale(s, 4) @ mathutils.Matrix.Translation(-center)
for o in meshes:
    o.data.transform(N)
    o.data.update()

# 6. Materials: bake Math(Multiply) PBR factors so UsdPreviewSurface matches glTF,
#    handle optional emission changes, and prune unused images.
baked_channel_scales = {}


def parse_multiply_to_tex(inp):
    """If inp <- Math(MULTIPLY, factor, SeparateColor(ch) <- TexImage), return info."""
    if not inp or not inp.links:
        return None
    node = inp.links[0].from_node
    if node.type != "MATH" or node.operation != "MULTIPLY":
        return None
    i0, i1 = node.inputs[0], node.inputs[1]
    if i0.links and not i1.links:
        upstream_sock, factor = i0.links[0].from_socket, float(i1.default_value)
    elif i1.links and not i0.links:
        upstream_sock, factor = i1.links[0].from_socket, float(i0.default_value)
    else:
        return None
    up_node = upstream_sock.node
    if up_node.type == "SEPARATE_COLOR" and up_node.inputs[0].links:
        tex_node = up_node.inputs[0].links[0].from_node
        if tex_node.type == "TEX_IMAGE" and tex_node.image:
            ch_map = {"Red": 0, "Green": 1, "Blue": 2}
            ch = ch_map.get(upstream_sock.name)
            if ch is not None:
                return (node, up_node, upstream_sock, tex_node, ch, factor)
    return None


for ma in bpy.data.materials:
    if not getattr(ma, "node_tree", None):
        continue
    nt = ma.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if bsdf is None:
        continue

    emi = bsdf.inputs.get("Emission Color")
    st = bsdf.inputs.get("Emission Strength")
    if a.drop_emissive and emi is not None:
        for l in list(emi.links):
            nt.links.remove(l)
        emi.default_value = (0, 0, 0, 1)
        if st is not None:
            st.default_value = 0.0
    elif a.emission_scale is not None and st is not None:
        st.default_value *= a.emission_scale

    tex_scales = {}
    pending = []
    for sock_name in ("Metallic", "Roughness"):
        inp = bsdf.inputs.get(sock_name)
        info = parse_multiply_to_tex(inp)
        if not info:
            continue
        math_node, sep_node, sep_sock, tex_node, ch, factor = info
        if factor <= 1e-4:
            for l in list(inp.links):
                nt.links.remove(l)
            inp.default_value = 0.0
            nt.nodes.remove(math_node)
        elif abs(factor - 1.0) <= 1e-4:
            for l in list(inp.links):
                nt.links.remove(l)
            nt.links.new(sep_sock, inp)
            nt.nodes.remove(math_node)
        else:
            tex_scales.setdefault(tex_node, {})[ch] = factor
            pending.append((inp, math_node, sep_sock, tex_node))

    for tex_node, ch_factors in tex_scales.items():
        orig = tex_node.image
        scales = tuple(round(ch_factors.get(c, 1.0), 5) for c in range(3))
        key = (orig.name, scales)
        if key not in baked_channel_scales:
            w, h = orig.size[:]
            arr = np.array(orig.pixels[:], dtype=np.float32).reshape(h, w, 4)
            for c, f in ch_factors.items():
                arr[:, :, c] = np.clip(arr[:, :, c] * f, 0.0, 1.0)
            new_name = f"{os.path.splitext(orig.name)[0]}_baked_{ma.name}.png"
            new_im = bpy.data.images.new(new_name, width=w, height=h, alpha=False)
            new_im.colorspace_settings.name = orig.colorspace_settings.name
            new_im.pixels.foreach_set(arr.ravel())
            new_im.pack()
            baked_channel_scales[key] = new_im
        tex_node.image = baked_channel_scales[key]

    for inp, math_node, sep_sock, _tex_node in pending:
        for l in list(inp.links):
            nt.links.remove(l)
        nt.links.new(sep_sock, inp)
        nt.nodes.remove(math_node)

# Remove unreachable texture nodes and unused images (e.g. dropped emissive maps).
used_images = set()
alpha_image_names = set()
for ma in bpy.data.materials:
    if ma.users == 0 or not getattr(ma, "node_tree", None):
        continue
    nt = ma.node_tree
    bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
    if not bsdf:
        continue
    if bsdf.inputs["Alpha"].links:
        src = bsdf.inputs["Alpha"].links[0].from_node
        if src.type == "TEX_IMAGE" and src.image:
            alpha_image_names.add(os.path.basename(src.image.name))
    visited = set()
    stack = [bsdf]
    while stack:
        n = stack.pop()
        if n in visited:
            continue
        visited.add(n)
        if n.type == "TEX_IMAGE" and n.image:
            used_images.add(n.image.name)
        for inp in n.inputs:
            for l in inp.links:
                stack.append(l.from_node)
    for n in list(nt.nodes):
        if n.type == "TEX_IMAGE" and n not in visited:
            nt.nodes.remove(n)

for im in list(bpy.data.images):
    if im.name not in used_images:
        bpy.data.images.remove(im)

# Downscale any packed/in-memory images above max-tex as well.
for im in bpy.data.images:
    w, h = im.size[:]
    if max(w, h) > a.max_tex:
        k = a.max_tex / max(w, h)
        im.scale(max(1, int(round(w * k))), max(1, int(round(h * k))))
        if im.packed_file:
            im.pack()

final_tris = sum(tri_count(o) for o in meshes)
os.makedirs(os.path.dirname(os.path.abspath(a.out)), exist_ok=True)

# 7. Export USDZ via Blender.
bpy.ops.wm.usd_export(
    filepath=a.out,
    export_animation=False,
    export_materials=True,
    generate_preview_surface=True,
    export_textures_mode="NEW",
    overwrite_textures=True,
    convert_orientation=True,
    export_global_forward_selection="NEGATIVE_Z",
    export_global_up_selection="Y",
    usdz_downscale_size=str(a.max_tex) if str(a.max_tex) in ("256", "512", "1024", "2048", "4096") else "KEEP",
    triangulate_meshes=True,
    export_lights=False,
    export_cameras=False,
    root_prim_path="/root",
    meters_per_unit=1.0,
)

# 8. Post-process USDZ cleanly using Apple's usdcat + sips + usdzip (-c compliance):
#    - Ensure all textures <= max_tex
#    - Optionally convert opaque PNG textures to JPEG if smaller
#    - Optionally inject inputs:opacityThreshold = 0.5 on cutout materials
cutout_patched = []
jpeg_converted = []
max_tex_actual = 0

patch_tmp = tempfile.mkdtemp(prefix="earprint_usd_")
try:
    with zipfile.ZipFile(a.out, "r") as zf:
        zf.extractall(patch_tmp)

    usdc_files = [f for f in os.listdir(patch_tmp) if f.endswith(".usdc")]
    if not usdc_files:
        raise RuntimeError(f"No .usdc found inside {a.out}")
    usdc_path = os.path.join(patch_tmp, usdc_files[0])
    usda_path = os.path.join(patch_tmp, "scene.usda")
    subprocess.run(["/usr/bin/usdcat", usdc_path, "-o", usda_path], check=True)
    usda_txt = open(usda_path, "r").read()
    modified_usda = False

    tex_dir = os.path.join(patch_tmp, "textures")
    if os.path.isdir(tex_dir):
        for fname in sorted(os.listdir(tex_dir)):
            fpath = os.path.join(tex_dir, fname)
            if not os.path.isfile(fpath):
                continue
            # Query dimensions and alpha channel via sips.
            sips_info = subprocess.check_output(
                ["/usr/bin/sips", "-g", "pixelWidth", "-g", "pixelHeight", "-g", "hasAlpha", fpath],
                text=True,
            )
            pw = int(re.search(r"pixelWidth:\s*(\d+)", sips_info).group(1))
            ph = int(re.search(r"pixelHeight:\s*(\d+)", sips_info).group(1))
            has_alpha = "hasAlpha: yes" in sips_info

            # Downscale if still larger than max_tex.
            if max(pw, ph) > a.max_tex:
                subprocess.run(
                    ["/usr/bin/sips", "-Z", str(a.max_tex), fpath],
                    check=True,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                )
                sips_info = subprocess.check_output(
                    ["/usr/bin/sips", "-g", "pixelWidth", "-g", "pixelHeight", fpath],
                    text=True,
                )
                pw = int(re.search(r"pixelWidth:\s*(\d+)", sips_info).group(1))
                ph = int(re.search(r"pixelHeight:\s*(\d+)", sips_info).group(1))
                modified_usda = True  # force repack

            max_tex_actual = max(max_tex_actual, pw, ph)

            # Convert opaque PNGs to JPEG when --jpeg-opaque is enabled.
            if a.jpeg_opaque and fname.lower().endswith(".png") and fname not in alpha_image_names:
                # Even if PNG header says hasAlpha=yes, check if alpha is actually all-opaque via Blender.
                really_has_alpha = False
                if has_alpha:
                    tmp_im = bpy.data.images.load(fpath, check_existing=False)
                    arr = np.array(tmp_im.pixels[:], dtype=np.float32).reshape(-1, 4)
                    really_has_alpha = bool(arr[:, 3].min() < 0.995)
                    bpy.data.images.remove(tmp_im)
                if not really_has_alpha:
                    jpg_name = os.path.splitext(fname)[0] + ".jpg"
                    jpg_path = os.path.join(tex_dir, jpg_name)
                    subprocess.run(
                        ["/usr/bin/sips", "-s", "format", "jpeg", "-s", "formatOptions", str(a.jpeg_quality), fpath, "--out", jpg_path],
                        check=True,
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL,
                    )
                    if os.path.getsize(jpg_path) < os.path.getsize(fpath):
                        os.remove(fpath)
                        usda_txt = usda_txt.replace(f"./textures/{fname}", f"./textures/{jpg_name}")
                        jpeg_converted.append(jpg_name)
                        modified_usda = True
                    else:
                        os.remove(jpg_path)

    if a.cutout:
        cut_rx = re.compile(a.cutout)
        out_lines = []
        cur_mat = None
        for line in usda_txt.splitlines(True):
            m_mat = re.match(r'\s*def Material "([^"]+)"', line)
            if m_mat:
                cur_mat = m_mat.group(1)
            out_lines.append(line)
            if cur_mat and cut_rx.search(cur_mat) and "float inputs:opacity.connect" in line:
                indent = line[: len(line) - len(line.lstrip())]
                out_lines.append(f"{indent}float inputs:opacityThreshold = 0.5\n")
                cutout_patched.append(cur_mat)
                modified_usda = True
        usda_txt = "".join(out_lines)

    if modified_usda:
        open(usda_path, "w").write(usda_txt)
        subprocess.run(["/usr/bin/usdcat", usda_path, "-o", usdc_path], check=True)
        os.remove(usda_path)
        os.remove(a.out)
        subprocess.run(
            ["/usr/bin/usdzip", "-c", "-a", usdc_path, a.out],
            check=True,
            cwd=patch_tmp,
        )
    else:
        os.remove(usda_path)
finally:
    shutil.rmtree(patch_tmp, ignore_errors=True)

file_size = os.path.getsize(a.out)
rep = {
    "input": a.inp,
    "output": a.out,
    "file_bytes": file_size,
    "file_mb": round(file_size / (1024 * 1024), 2),
    "source_tris": src_tris,
    "final_tris": final_tris,
    "decimate_ratio": round(ratio, 4),
    "meshes": len(meshes),
    "materials": len([m for m in bpy.data.materials if m.users]),
    "removed": removed,
    "cutout_patched": sorted(set(cutout_patched)),
    "jpeg_converted": len(jpeg_converted),
    "source_size": [round(x, 4) for x in size],
    "scale": s,
    "max_texture": max_tex_actual,
}
print("REPORT", json.dumps(rep))
if a.report:
    with open(a.report, "w") as f:
        json.dump(rep, f, indent=2)
