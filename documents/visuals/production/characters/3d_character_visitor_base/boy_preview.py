"""Render a comparison turnaround of boy.blend with Cycles (CPU).

    blender -b boy.blend -P boy_preview.py -- /tmp/boy_shots [view,view,...]

Views: front, threequarter, back, side (default: all).
"""

import os
import sys

import bpy
from mathutils import Vector

OUT_DIR = "/tmp/boy_shots"
argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
if argv:
    OUT_DIR = argv[0]
VIEW_FILTER = argv[1].split(",") if len(argv) > 1 else None
os.makedirs(OUT_DIR, exist_ok=True)

TARGET = Vector((0.0, 0.0, 0.62))

VIEWS = [
    # name, camera location, ortho?, ortho scale / lens
    # the boy faces +Y, so the front camera sits on +Y
    ("front", Vector((0.0, 3.0, 0.66)), True, 1.45),
    ("threequarter", Vector((1.75, 2.35, 1.00)), False, 50.0),
    ("back", Vector((0.0, -3.0, 0.66)), True, 1.45),
    ("side", Vector((2.6, 0.0, 0.66)), True, 1.45),
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


def setup():
    scene = bpy.context.scene
    world = bpy.data.worlds.new("preview_world")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.030, 0.038, 0.058, 1.0)
    bg.inputs["Strength"].default_value = 0.85

    add_area("key", (-1.5, -1.7, 2.1), TARGET, energy=130, size=2.0, color=(1.0, 0.87, 0.74))
    add_area("fill", (1.9, -1.1, 0.9), TARGET, energy=32, size=2.2, color=(0.74, 0.83, 1.0))
    add_area("rim", (0.2, 2.0, 1.5), TARGET, energy=62, size=1.8, color=(0.78, 0.86, 1.0))

    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 560
    scene.render.resolution_y = 880
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"


def main():
    setup()
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
