"""Blender batch script: render preview PNGs of a final USDZ (verifies it re-imports).

Usage:
  Blender -b --factory-startup -P tools/assets/render_preview.py -- \
      --in Earprint/Resources/Models/AirPodsMax.usdz --out docs/assets-previews/AirPodsMax.png

Renders a 3/4 hero view and a straight front view (the USD +Z side) side by side.
"""

import argparse
import math
import os
import sys
import tempfile

import bpy
import mathutils

argv = sys.argv[sys.argv.index("--") + 1:]
ap = argparse.ArgumentParser()
ap.add_argument("--in", dest="inp", required=True)
ap.add_argument("--out", required=True)
ap.add_argument("--size", type=int, default=768)
ap.add_argument("--samples", type=int, default=64)
a = ap.parse_args(argv)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.wm.usd_import(filepath=a.inp)
sc = bpy.context.scene
# Match RealityKit alpha-cutout depth testing when USD specifies opacityThreshold.
for ma in bpy.data.materials:
    if getattr(ma, "alpha_threshold", 0.0) > 0.0 and hasattr(ma, "surface_render_method"):
        ma.surface_render_method = "DITHERED"

meshes = [o for o in sc.objects if o.type == "MESH"]
dg = bpy.context.evaluated_depsgraph_get()
lo = mathutils.Vector((1e9,) * 3)
hi = mathutils.Vector((-1e9,) * 3)
for o in meshes:
    for c in o.bound_box:
        w = o.matrix_world @ mathutils.Vector(c)
        for i in range(3):
            lo[i] = min(lo[i], w[i])
            hi[i] = max(hi[i], w[i])
center = (lo + hi) / 2
radius = (hi - lo).length / 2
print("BOUNDS", tuple(round(x, 3) for x in lo), tuple(round(x, 3) for x in hi))

# World: soft studio gradient via sky-ish gray.
world = bpy.data.worlds.new("W")
sc.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs[0].default_value = (0.55, 0.57, 0.62, 1)
bg.inputs[1].default_value = 0.6


def area(name, loc, energy, size):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy = energy
    ld.size = size
    lo_ = bpy.data.objects.new(name, ld)
    sc.collection.objects.link(lo_)
    lo_.location = loc
    d = center - mathutils.Vector(loc)
    lo_.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


area("Key", (2.0, -2.5, 2.5), 250, 2.0)
area("Fill", (-2.5, -1.5, 1.0), 90, 3.0)
area("Rim", (0.0, 3.0, 2.0), 160, 2.0)

cam_d = bpy.data.cameras.new("Cam")
cam_d.lens = 70
cam = bpy.data.objects.new("Cam", cam_d)
sc.collection.objects.link(cam)
sc.camera = cam

sc.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_EEVEE_NEXT"
try:
    sc.eevee.taa_render_samples = a.samples
except Exception:
    pass
sc.render.resolution_x = a.size
sc.render.resolution_y = a.size
sc.render.film_transparent = False
sc.view_settings.view_transform = "AgX" if "AgX" in [i.identifier for i in sc.view_settings.bl_rna.properties["view_transform"].enum_items] else "Filmic"

views = {
    "hero": mathutils.Vector((1.0, -1.6, 0.75)),
    "front": mathutils.Vector((0.0, -1.0, 0.0)),
}
tmp = tempfile.mkdtemp()
files = []
for name, dirv in views.items():
    dirv.normalize()
    dist = radius / math.tan(cam_d.angle / 2) * 1.08
    cam.location = center + dirv * dist
    cam.rotation_euler = (center - cam.location).to_track_quat("-Z", "Y").to_euler()
    f = os.path.join(tmp, name + ".png")
    sc.render.filepath = f
    bpy.ops.render.render(write_still=True)
    files.append(f)

# Side-by-side composite.
imgs = [bpy.data.images.load(f) for f in files]
W, H = a.size * len(imgs), a.size
out = bpy.data.images.new("out", W, H, alpha=True)
px = [0.0] * (W * H * 4)
for k, im in enumerate(imgs):
    src = list(im.pixels)
    for y in range(H):
        row = src[y * a.size * 4:(y + 1) * a.size * 4]
        start = (y * W + k * a.size) * 4
        px[start:start + a.size * 4] = row
out.pixels = px
out.filepath_raw = a.out
out.file_format = "PNG"
out.save()
print("PREVIEW", a.out)
