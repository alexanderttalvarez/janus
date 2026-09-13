"""Build a stylized low-poly bench from the multi-view reference ``bench.png``.

Run headless:

    blender -b -P bench_build.py

Outputs (next to this script):
    bench.blend   editable Blender scene
    bench.glb     game-ready glTF binary (Y-up, metres)

Reference reading (bench.png panels used):
    A  three-quarter view from above/front ....... slat layout, bolt layout, frame width
    C  front elevation .......................... length : height, leg stance, no lengthwise rail
    D  three-quarter view from front/left ....... top-rail ends protruding past the posts
    E  end elevation ............................ seat depth, splay, top/bottom rails, feet
    F  three-quarter view from front/right ...... post cross-sections, foot pads
    B  top-right panel is the back side and is deliberately ignored.

Structure: backless park bench, three chunky orange timber slats, six blue dome bolts
(one per slat per end) and two blue steel end frames (two splayed posts, a top rail under
the seat, a bottom rail above the feet and one plinth foot pad per post).
"""

import math
import os

import bmesh
import bpy
from mathutils import Vector

# --------------------------------------------------------------------------------------
# Parameters - metres, Z up, origin at the centre of the footprint on the ground
# --------------------------------------------------------------------------------------

LENGTH = 1.80  # X: overall bench length

SLAT_COUNT = 3
SLAT_W = 0.180  # Y: single plank width
SLAT_GAP = 0.011  # gap between planks
SLAT_T = 0.100  # Z: plank thickness (reference planks are deliberately chunky)
SEAT_TOP = 0.480  # Z of the seat surface

BOLT_R = 0.025  # dome bolt radius
BOLT_H = 0.017  # dome bolt height (half axis)
BOLT_INSET = 0.080  # distance from the plank end to the bolt centre

POST_TX = 0.120  # post cross-section along X, at the seat
POST_BX = 0.135  # post cross-section along X, at the foot
POST_TY = 0.075  # post cross-section along Y, at the seat
POST_BY = 0.100  # post cross-section along Y, at the foot
POST_TOP_Z = SEAT_TOP - SLAT_T  # posts stop under the planks
PAD_H = 0.055  # foot pad height
POST_BOT_Z = PAD_H
POST_OUT_TOP = 0.180  # post outer face (|Y|) at the top
POST_OUT_BOT = 0.265  # post outer face (|Y|) at the foot

FRAME_X = 0.800  # frame centre-plane distance from the bench centre
PAD_X = 0.165  # foot pad size along X
PAD_Y = 0.190  # foot pad size along Y

RAIL_X = 0.100  # rail cross-section along X
TOP_RAIL_H = 0.055
BOT_RAIL_H = 0.057
TOP_RAIL_OVERHANG = 0.010  # rail end sticking out past the post (through-tenon look)
BOT_RAIL_OVERHANG = 0.025  # bottom rail sunk into the posts

WOOD_BEVEL = 0.012
METAL_BEVEL = 0.006

WOOD_HEX = "E58950"  # warm orange timber
METAL_HEX = "42638F"  # blue painted steel

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

# --------------------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------------------


def srgb_to_linear(channel):
    c = channel / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def hex_to_linear(hex_string):
    hex_string = hex_string.lstrip("#")
    rgb = [int(hex_string[i : i + 2], 16) for i in (0, 2, 4)]
    return tuple(srgb_to_linear(c) for c in rgb) + (1.0,)


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.unit_settings.length_unit = "METERS"


def make_material(name, hex_color, roughness, metallic):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = hex_to_linear(hex_color)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    mat.diffuse_color = hex_to_linear(hex_color)
    return mat


def bevel(bm, width, segments=1):
    if width <= 0.0:
        return
    bmesh.ops.bevel(
        bm,
        geom=list(bm.verts) + list(bm.edges) + list(bm.faces),
        offset=width,
        offset_type="OFFSET",
        segments=segments,
        profile=0.5,
        affect="EDGES",
        clamp_overlap=True,
        loop_slide=True,
    )


def finish(name, bm, material, collection, smooth=False):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = smooth
    obj = bpy.data.objects.new(name, mesh)
    mesh.materials.append(material)
    collection.objects.link(obj)
    return obj


def rect(cx, cy, sx, sy):
    return (cx, cy, sx, sy)


def box(name, bottom, top, z0, z1, material, collection, bevel_width=0.0):
    """Tapered box: ``bottom``/``top`` are (centre_x, centre_y, size_x, size_y)."""
    bm = bmesh.new()
    cx0, cy0, sx0, sy0 = bottom
    cx1, cy1, sx1, sy1 = top
    low = []
    high = []
    for cx, cy, sx, sy, z, bucket in ((cx0, cy0, sx0, sy0, z0, low), (cx1, cy1, sx1, sy1, z1, high)):
        for dx, dy in ((-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5)):
            bucket.append(bm.verts.new((cx + dx * sx, cy + dy * sy, z)))
    bm.verts.ensure_lookup_table()
    bm.faces.new((low[3], low[2], low[1], low[0]))
    bm.faces.new(high)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((low[i], low[j], high[j], high[i]))
    bevel(bm, bevel_width)
    return finish(name, bm, material, collection)


def dome(name, centre, radius, height, material, collection):
    bm = bmesh.new()
    try:
        bmesh.ops.create_uvsphere(bm, u_segments=14, v_segments=8, radius=1.0)
    except TypeError:  # older bmesh signature
        bmesh.ops.create_uvsphere(bm, u_segments=14, v_segments=8, diameter=1.0)
    for vert in bm.verts:
        vert.co = Vector((vert.co.x * radius, vert.co.y * radius, vert.co.z * height))
        vert.co += Vector(centre)
    return finish(name, bm, material, collection, smooth=True)


# --------------------------------------------------------------------------------------
# Bench parts
# --------------------------------------------------------------------------------------


def build_bench():
    reset_scene()

    scene = bpy.context.scene
    collection = bpy.data.collections.new("Bench")
    scene.collection.children.link(collection)

    wood = make_material("bench_wood_orange", WOOD_HEX, roughness=0.45, metallic=0.0)
    metal = make_material("bench_metal_blue", METAL_HEX, roughness=0.42, metallic=0.15)

    depth = SLAT_COUNT * SLAT_W + (SLAT_COUNT - 1) * SLAT_GAP
    pitch = SLAT_W + SLAT_GAP

    # ---- seat planks -----------------------------------------------------------------
    seat_z0 = SEAT_TOP - SLAT_T
    for i in range(SLAT_COUNT):
        cy = (i - (SLAT_COUNT - 1) / 2.0) * pitch
        box(
            f"seat_plank_{i + 1}",
            rect(0.0, cy, LENGTH, SLAT_W),
            rect(0.0, cy, LENGTH, SLAT_W),
            seat_z0,
            SEAT_TOP,
            wood,
            collection,
            bevel_width=WOOD_BEVEL,
        )

    # ---- dome bolts ------------------------------------------------------------------
    bolt_x = LENGTH / 2.0 - BOLT_INSET
    for i in range(SLAT_COUNT):
        cy = (i - (SLAT_COUNT - 1) / 2.0) * pitch
        for side, suffix in ((-1, "l"), (1, "r")):
            dome(
                f"bolt_{i + 1}{suffix}",
                (side * bolt_x, cy, SEAT_TOP - BOLT_H * 0.25),
                BOLT_R,
                BOLT_H,
                metal,
                collection,
            )

    # ---- end frames ------------------------------------------------------------------
    post_h = POST_TOP_Z - POST_BOT_Z
    post_top_cy = POST_OUT_TOP - POST_TY / 2.0
    post_bot_cy = POST_OUT_BOT - POST_BY / 2.0

    def outer_face(z):
        t = (z - POST_BOT_Z) / post_h
        return POST_OUT_BOT + t * (POST_OUT_TOP - POST_OUT_BOT)

    top_rail_half = outer_face(SEAT_TOP - SLAT_T - TOP_RAIL_H) + TOP_RAIL_OVERHANG
    top_rail_z1 = SEAT_TOP - SLAT_T
    top_rail_z0 = top_rail_z1 - TOP_RAIL_H

    bot_rail_z0 = PAD_H
    bot_rail_z1 = PAD_H + BOT_RAIL_H
    post_cy_mid = post_bot_cy + (bot_rail_z1 - POST_BOT_Z) / post_h * (post_top_cy - post_bot_cy)
    bot_rail_half = (post_cy_mid + POST_BY / 2.0) - BOT_RAIL_OVERHANG

    for side, suffix in ((-1, "l"), (1, "r")):
        x = side * FRAME_X
        short = "L" if side < 0 else "R"

        for face, sign, tag in (("front", -1, "f"), ("back", 1, "b")):
            box(
                f"leg_{short}_{tag}",
                rect(x, sign * post_bot_cy, POST_BX, POST_BY),
                rect(x, sign * post_top_cy, POST_TX, POST_TY),
                POST_BOT_Z,
                POST_TOP_Z,
                metal,
                collection,
                bevel_width=METAL_BEVEL,
            )
            pad_cy = sign * (POST_OUT_BOT - PAD_Y / 2.0)
            box(
                f"foot_{short}_{tag}",
                rect(x, pad_cy, PAD_X, PAD_Y),
                rect(x, pad_cy, PAD_X, PAD_Y),
                0.0,
                PAD_H,
                metal,
                collection,
                bevel_width=WOOD_BEVEL,
            )

        box(
            f"rail_top_{short}",
            rect(x, 0.0, RAIL_X, 2.0 * top_rail_half),
            rect(x, 0.0, RAIL_X, 2.0 * top_rail_half),
            top_rail_z0,
            top_rail_z1,
            metal,
            collection,
            bevel_width=METAL_BEVEL,
        )
        box(
            f"rail_bottom_{short}",
            rect(x, 0.0, RAIL_X, 2.0 * bot_rail_half),
            rect(x, 0.0, RAIL_X, 2.0 * bot_rail_half),
            bot_rail_z0,
            bot_rail_z1,
            metal,
            collection,
            bevel_width=METAL_BEVEL,
        )

    # ---- root ------------------------------------------------------------------------
    root = bpy.data.objects.new("prop_bench", None)
    root.empty_display_size = 0.25
    collection.objects.link(root)
    for obj in collection.objects:
        if obj is not root:
            obj.parent = root

    return collection, root


def report(collection):
    tris = 0
    verts = 0
    for obj in collection.objects:
        if obj.type != "MESH":
            continue
        verts += len(obj.data.vertices)
        tris += sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"[bench] parts={len([o for o in collection.objects if o.type == 'MESH'])} "
          f"verts={verts} tris={tris}")


def export(collection):
    blend_path = os.path.join(OUT_DIR, "bench.blend")
    glb_path = os.path.join(OUT_DIR, "bench.glb")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    bpy.ops.export_scene.gltf(filepath=glb_path, export_format="GLB", export_apply=True, export_yup=True)
    print(f"[bench] wrote {blend_path}")
    print(f"[bench] wrote {glb_path}")


def main():
    collection, _root = build_bench()
    report(collection)
    export(collection)


if __name__ == "__main__":
    main()
