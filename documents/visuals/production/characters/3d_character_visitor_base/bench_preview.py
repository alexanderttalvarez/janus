"""Render a comparison turnaround of bench.blend with Cycles (CPU).

    blender -b bench.blend -P bench_preview.py -- /tmp/bench_shots

Writes one PNG per view into the output directory (default ``/tmp/bench_shots``).
"""

import math
import os
import sys

import bpy
from mathutils import Vector

OUT_DIR = "/tmp/bench_shots"
argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
if argv:
    OUT_DIR = argv[0]
VIEW_FILTER = argv[1].split(",") if len(argv) > 1 else None
os.makedirs(OUT_DIR, exist_ok=True)

TARGET = Vector((0.0, 0.0, 0.26))

VIEWS = [
    # name, camera location, ortho?, ortho scale / lens
    ("front", Vector((0.0, -3.4, 0.58)), True, 1.95),
    ("end", Vector((2.6, 0.0, 0.58)), True, 0.95),
    ("hero34", Vector((-1.75, -2.25, 1.20)), False, 50.0),
    ("top34", Vector((-1.55, -1.55, 2.05)), False, 50.0),
    ("side34", Vector((1.95, 2.35, 1.00)), False, 50.0),
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
    bg.inputs["Color"].default_value = (0.024, 0.030, 0.048, 1.0)
    bg.inputs["Strength"].default_value = 0.8


def setup_lights():
    add_area("key", (-2.2, -2.6, 2.6), TARGET, energy=190, size=3.0, color=(1.0, 0.86, 0.72))
    add_area("fill", (2.9, -1.6, 1.1), TARGET, energy=45, size=3.5, color=(0.72, 0.82, 1.0))
    add_area("rim", (0.4, 3.0, 1.8), TARGET, energy=90, size=2.5, color=(0.78, 0.86, 1.0))


def setup_render():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 900
    scene.render.resolution_y = 640
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
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

    for name, location, ortho, value in VIEWS:
        if VIEW_FILTER and name not in VIEW_FILTER:
            continue
        cam.location = location
        cam_data.type = "ORTHO" if ortho else "PERSP"
        if ortho:
            cam_data.ortho_scale = value
        else:
            cam_data.lens = value
        aim(cam, TARGET)
        bpy.context.scene.render.filepath = os.path.join(OUT_DIR, f"{name}.png")
        bpy.ops.render.render(write_still=True)
        print(f"[preview] {name} -> {bpy.context.scene.render.filepath}")


main()
