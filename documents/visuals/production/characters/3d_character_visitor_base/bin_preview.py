"""Render a comparison turnaround of bin.blend with Cycles (CPU).

    blender -b bin.blend -P bin_preview.py -- /tmp/bin_shots

Writes one PNG per view into the output directory (default ``/tmp/bin_shots``).
The pictogram faces +Y in Blender, so ``front`` and the three-quarter views sit on +Y.
"""

import math
import os
import sys

import bpy
from mathutils import Vector

OUT_DIR = "/tmp/bin_shots"
argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
if argv:
    OUT_DIR = argv[0]
VIEW_FILTER = argv[1].split(",") if len(argv) > 1 else None
# ``alpha`` renders with a transparent film, which makes silhouette/proportion diffs against
# the reference easy (bin.png also carries a usable alpha channel).
ALPHA = len(argv) > 2 and argv[2] == "alpha"
os.makedirs(OUT_DIR, exist_ok=True)

TARGET = Vector((0.0, 0.0, 0.55))

VIEWS = [
    # name, camera location, look-at, ortho?, ortho scale / lens
    ("front", Vector((0.0, 3.4, 0.62)), TARGET, True, 1.62),
    ("end", Vector((3.0, 0.0, 0.62)), TARGET, True, 1.62),
    ("roof_top", Vector((0.0, 0.0, 3.0)), Vector((0.0, 0.0, 1.03)), True, 0.86),
    # long lens + long stand-off keeps the perspective as flat as the reference sheet
    ("hero34", Vector((3.90, 4.65, 3.20)), Vector((0.0, 0.0, 0.58)), False, 95.0),
    ("top34", Vector((3.55, 3.25, 4.30)), Vector((0.0, 0.0, 0.60)), False, 95.0),
    ("low34", Vector((4.45, -2.55, 1.10)), Vector((0.0, 0.0, 0.55)), False, 95.0),
]


def aim(obj, target):
    direction = target - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def add_area(name, location, target, energy, size, color=(1.0, 1.0, 1.0)):
    data = bpy.data.lights.new(name, type="AREA")
    data.energy = energy
    data.size = size
    data.color = color
    obj = bpy.data.objects.new(name, data)
    obj.location = location
    bpy.context.scene.collection.objects.link(obj)
    aim(obj, target)
    return obj


def setup_world():
    world = bpy.data.worlds.new("preview_world")
    bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.033, 0.072, 0.082, 1.0)
    bg.inputs["Strength"].default_value = 1.1


def setup_lights():
    add_area("key", (2.4, 3.0, 3.4), Vector((0.0, 0.0, 0.6)), energy=300, size=3.4, color=(1.0, 0.94, 0.88))
    add_area("fill", (-3.1, 2.2, 1.2), Vector((0.0, 0.0, 0.5)), energy=70, size=3.8, color=(0.74, 0.84, 1.0))
    add_area("rim", (-0.5, -3.2, 2.0), TARGET, energy=110, size=2.6, color=(0.78, 0.86, 1.0))


def setup_render():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 900
    scene.render.resolution_y = 640
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = ALPHA
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"


def main():
    setup_world()
    setup_lights()
    setup_render()

    cam_data = bpy.data.cameras.new("preview_cam")
    cam = bpy.data.objects.new("preview_cam", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    bpy.context.scene.camera = cam

    for name, location, target, ortho, value in VIEWS:
        if VIEW_FILTER and name not in VIEW_FILTER:
            continue
        cam.location = location
        cam_data.type = "ORTHO" if ortho else "PERSP"
        if ortho:
            cam_data.ortho_scale = value
        else:
            cam_data.lens = value
        aim(cam, target)
        bpy.context.scene.render.filepath = os.path.join(OUT_DIR, f"{name}.png")
        bpy.ops.render.render(write_still=True)
        print(f"[preview] {name} -> {bpy.context.scene.render.filepath}")


main()
