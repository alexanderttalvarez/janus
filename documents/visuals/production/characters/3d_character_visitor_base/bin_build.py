"""Build a stylized low-poly litter bin from the multi-view reference ``bin.png``.

Run headless:

    blender -b -P bin_build.py

Outputs (next to this script):
    bin.blend   editable Blender scene
    bin.glb     game-ready glTF binary (Y-up, metres)

Reference reading (bin.png): big three-quarter view on the left, eight smaller panels on
the right (top row: front elevation with the pictogram, two more front elevations, roof
seen from above; bottom row: four three-quarter views).

    hero (left) ........... overall stacking, plinth corner cuts, panel bevels, pictogram
    top row #1 ............ front elevation, sign plate size/position, slot read, bolt row
    top row #2 ............ front elevation, bolt placement (11 px domes, 4 per face)
    top row #4 ............ roof plan: square slab, 45 deg top bevel, mitered corners
    bottom row 1-4 ........ corner posts, rim thickness, liner rim below the shell rim

Structure: square composite litter bin - a chamfered navy plinth, four navy corner posts,
four cream shell walls between them (each carrying four navy dome bolts), a navy inner
liner, a cyan roof slab held on the posts, and a blue pictogram plate on the front wall.

All proportions come from the front elevation in the reference: 344 px tall, taken as
1.10 m, so 1 px = 3.2 mm.  The pictogram faces +Y in Blender, which lands as Godot's -Z
forward after export.
"""

import math
import os

import bmesh
import bpy
from mathutils import Vector

# --------------------------------------------------------------------------------------
# Parameters - metres, Z up, origin at the centre of the footprint on the ground
# --------------------------------------------------------------------------------------

TOTAL_H = 1.100  # Z: roof top

ROOF_W = 0.601  # plan (square); reference 188 px
ROOF_T = 0.166  # slab thickness, reference 52 px
ROOF_BEVEL = 0.066  # 45 deg bevel around the top face, reference 21 px

POST_T = 0.070  # corner post section, reference 22 px

BODY_W = 0.528  # shell plan (flush with the posts' outer faces), reference 165 px
BODY_H = 0.633  # shell wall height, base top -> rim, reference 198 px
WALL_T = 0.030  # shell wall thickness
LINER_T = 0.018  # inner liner wall thickness
LINER_DROP = 0.008  # liner rim sits this far below the shell rim

BASE_W = 0.608  # plinth plan, reference 190 px
BASE_H = 0.115  # plinth height, reference 36 px
BASE_CUT = 0.045  # 45 deg corner cut in plan
BASE_CHAMFER = 0.022  # top edge chamfer, horizontal
BASE_CHAMFER_H = 0.032  # top edge chamfer, vertical

BOLT_R = 0.0176  # dome bolt radius, reference 11 px across
BOLT_H = 0.010  # dome height above the surface
BOLT_INSET_X = 0.046  # bolt centre in from the wall edge
BOLT_INSET_TOP = 0.069  # bolt centre below the rim
BOLT_INSET_BOT = 0.046  # bolt centre above the wall's bottom

SIGN_W = 0.326  # pictogram plate, reference 102 px
SIGN_H = 0.416  # reference 130 px
SIGN_T = 0.010  # stand-off from the wall face
SIGN_R = 0.016  # rounded corner radius
SIGN_Z0 = 0.064  # plate bottom above the wall's bottom

PICTO_T = 0.005  # white pictogram relief (front-most piece)
PICTO_SCALE = 0.92  # scales ``pictogram()`` to the reference (65% x 70% of the plate)

BEVEL_FLAT = 0.005  # general part bevel
BEVEL_POST = 0.007
BEVEL_PLATE = 0.004

NAVY_HEX = "33567C"  # frame, posts, plinth, liner, bolts
CREAM_HEX = "F3D8B2"  # shell panels
CYAN_HEX = "31B3CE"  # roof slab
BLUE_HEX = "0E79AD"  # pictogram plate
WHITE_HEX = "F2EFE6"  # pictogram figure

OUT_DIR = os.path.dirname(os.path.abspath(__file__))

POST_H = TOTAL_H - BASE_H - ROOF_T  # posts run from the plinth top to the roof underside
PLATE_CZ = BASE_H + SIGN_Z0 + SIGN_H / 2.0  # pictogram plate centre height

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


def ring(size, cut=0.0):
    """Counter-clockwise plan outline (viewed from +Z): a square, optionally corner-cut."""
    h = size / 2.0
    if cut <= 0.0:
        return [(h, -h), (h, h), (-h, h), (-h, -h)]
    return [
        (h, -h + cut),
        (h, h - cut),
        (h - cut, h),
        (-h + cut, h),
        (-h, h - cut),
        (-h, -h + cut),
        (-h + cut, -h),
        (h - cut, -h),
    ]


def ring_stack(name, levels, material, collection, bevel_width=0.0):
    """Loft a vertical stack of outlines: ``levels`` = [(z, [(x, y), ...]), ...]."""
    bm = bmesh.new()
    rings = []
    for z, points in levels:
        rings.append([bm.verts.new((x, y, z)) for x, y in points])
    bm.verts.ensure_lookup_table()
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    for lower, upper in zip(rings, rings[1:]):
        n = len(lower)
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((lower[i], lower[j], upper[j], upper[i]))
    bevel(bm, bevel_width)
    return finish(name, bm, material, collection)


def dome(name, centre, radius, height, axis, material, collection):
    """Dome bolt: sphere squashed along ``axis`` (0=X, 1=Y, 2=Z) so it reads as a boss.

    Kept coarse on purpose - sixteen bolts sit on the shell, and a 35 mm dome reads round at
    gameplay distance without 224 triangles each.
    """
    bm = bmesh.new()
    try:
        bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=1.0)
    except TypeError:  # older bmesh signature
        bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, diameter=1.0)
    scale = [radius, radius, radius]
    scale[axis] = height
    for vert in bm.verts:
        vert.co = Vector(
            (vert.co.x * scale[0], vert.co.y * scale[1], vert.co.z * scale[2])
        ) + Vector(centre)
    return finish(name, bm, material, collection, smooth=True)


def plate(name, points, y0, thickness, centre_z, material, collection):
    """Extrude a pictogram polygon along +Y.

    Points are (u, v) in the sign's own plane, u to the viewer's right.  The plate lives on
    the +Y wall (Godot's forward after export), so u maps to -X and the pictogram reads the
    right way round for anyone standing in front of the bin.
    """
    bm = bmesh.new()
    low = [bm.verts.new((-u * PICTO_SCALE, y0, centre_z + v * PICTO_SCALE)) for u, v in points]
    high = [
        bm.verts.new((-u * PICTO_SCALE, y0 + thickness, centre_z + v * PICTO_SCALE)) for u, v in points
    ]
    bm.verts.ensure_lookup_table()
    bm.faces.new(low)
    bm.faces.new(list(reversed(high)))
    n = len(points)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((low[i], low[j], high[j], high[i]))
    return finish(name, bm, material, collection)


def disc(cx, cy, rx, ry, segments=12):
    return [
        (cx + rx * math.cos(2.0 * math.pi * i / segments), cy + ry * math.sin(2.0 * math.pi * i / segments))
        for i in range(segments)
    ]


# --------------------------------------------------------------------------------------
# Bin parts
# --------------------------------------------------------------------------------------

def bar(p0, p1, width):
    """Rectangle of ``width`` between two points, in the pictogram's own plane."""
    (x0, y0), (x1, y1) = p0, p1
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / length * width / 2.0, dx / length * width / 2.0
    return [(x0 + nx, y0 + ny), (x1 + nx, y1 + ny), (x1 - nx, y1 - ny), (x0 - nx, y0 - ny)]


def pictogram():
    """The classic litter pictogram: a waste bin on the left, a figure reaching into it."""
    # Parts deliberately overlap at the shoulder, neck and hips: separate plates would
    # otherwise show shadow gaps that the reference's single flat silhouette does not have.
    # Order matters - ``build_bin`` steps each piece a fraction of a millimetre further back,
    # so the figure sits in front of the bin and nothing z-fights where parts overlap.
    return [
        # figure: head, leaning torso, both arms out over the bin, legs mid-stride
        ("head", disc(0.060, 0.118, 0.020, 0.025)),
        ("torso", [(0.032, 0.102), (0.082, 0.102), (0.086, -0.020), (0.038, -0.020)]),
        ("arm_upper", bar((0.050, 0.086), (-0.028, 0.052), 0.020)),
        ("arm_lower", bar((0.052, 0.052), (0.008, 0.020), 0.018)),
        ("leg_front", bar((0.050, -0.012), (0.026, -0.170), 0.026)),
        ("leg_back", bar((0.074, -0.012), (0.096, -0.150), 0.026)),
        # bin: a rim band over an open U outline that tapers towards the ground
        ("bin_rim", [(-0.132, 0.008), (-0.024, 0.008), (-0.026, -0.014), (-0.130, -0.014)]),
        ("bin_left", [(-0.122, -0.008), (-0.106, -0.008), (-0.096, -0.174), (-0.112, -0.174)]),
        ("bin_right", [(-0.042, -0.008), (-0.026, -0.008), (-0.036, -0.174), (-0.052, -0.174)]),
        ("bin_floor", [(-0.110, -0.160), (-0.036, -0.160), (-0.037, -0.176), (-0.111, -0.176)]),
        ("bin_line", [(-0.090, -0.022), (-0.081, -0.022), (-0.083, -0.152), (-0.092, -0.152)]),
    ]


def build_bin():
    reset_scene()

    scene = bpy.context.scene
    collection = bpy.data.collections.new("Bin")
    scene.collection.children.link(collection)

    navy = make_material("bin_frame_navy", NAVY_HEX, roughness=0.44, metallic=0.10)
    cream = make_material("bin_shell_cream", CREAM_HEX, roughness=0.50, metallic=0.0)
    cyan = make_material("bin_roof_cyan", CYAN_HEX, roughness=0.32, metallic=0.0)
    blue = make_material("bin_sign_blue", BLUE_HEX, roughness=0.44, metallic=0.0)
    white = make_material("bin_mark_white", WHITE_HEX, roughness=0.55, metallic=0.0)

    # ---- plinth ----------------------------------------------------------------------
    ring_stack(
        "base",
        [
            (0.0, ring(BASE_W, BASE_CUT)),
            (BASE_H - BASE_CHAMFER_H, ring(BASE_W, BASE_CUT)),
            (BASE_H, ring(BASE_W - 2.0 * BASE_CHAMFER, BASE_CUT - BASE_CHAMFER)),
        ],
        navy,
        collection,
        bevel_width=BEVEL_FLAT,
    )

    # ---- corner posts ------------------------------------------------------------------
    post_c = BODY_W / 2.0 - POST_T / 2.0
    for sx, sy, tag in ((-1, 1, "fl"), (1, 1, "fr"), (-1, -1, "bl"), (1, -1, "br")):
        box(
            f"post_{tag}",
            rect(sx * post_c, sy * post_c, POST_T, POST_T),
            rect(sx * post_c, sy * post_c, POST_T, POST_T),
            BASE_H,
            BASE_H + POST_H,
            navy,
            collection,
            bevel_width=BEVEL_POST,
        )

    # ---- shell walls -------------------------------------------------------------------
    span = BODY_W - 2.0 * POST_T  # wall length between the posts
    wall_off = BODY_W / 2.0 - WALL_T / 2.0
    wall_top = BASE_H + BODY_H
    for face, axis, sign in (("front", 1, 1), ("back", 1, -1), ("right", 0, 1), ("left", 0, -1)):
        if axis == 1:
            bottom = top = rect(0.0, sign * wall_off, span, WALL_T)
        else:
            bottom = top = rect(sign * wall_off, 0.0, WALL_T, span)
        box(f"wall_{face}", bottom, top, BASE_H, wall_top, cream, collection, bevel_width=BEVEL_FLAT)

    # ---- inner liner -------------------------------------------------------------------
    inner = BODY_W - 2.0 * WALL_T
    liner_off = BODY_W / 2.0 - WALL_T - LINER_T / 2.0
    liner_top = wall_top - LINER_DROP
    for face, axis, sign in (("front", 1, 1), ("back", 1, -1), ("right", 0, 1), ("left", 0, -1)):
        if axis == 1:
            bottom = top = rect(0.0, sign * liner_off, inner, LINER_T)
        else:
            bottom = top = rect(sign * liner_off, 0.0, LINER_T, inner - 2.0 * LINER_T)
        box(f"liner_{face}", bottom, top, BASE_H, liner_top, navy, collection)
    box(
        "liner_floor",
        rect(0.0, 0.0, inner, inner),
        rect(0.0, 0.0, inner, inner),
        BASE_H,
        BASE_H + LINER_T,
        navy,
        collection,
    )

    # ---- dome bolts, four per wall face ------------------------------------------------
    bolt_u = span / 2.0 - BOLT_INSET_X
    bolt_z = (BASE_H + BOLT_INSET_BOT, wall_top - BOLT_INSET_TOP)
    bolt_off = BODY_W / 2.0 - BOLT_H * 0.25
    for face, axis, sign in (("front", 1, 1), ("back", 1, -1), ("right", 0, 1), ("left", 0, -1)):
        for u_sign, u_tag in ((-1, "l"), (1, "r")):
            for z, z_tag in zip(bolt_z, ("b", "t")):
                u = u_sign * bolt_u
                if axis == 1:
                    centre = (u, sign * bolt_off, z)
                else:
                    centre = (sign * bolt_off, u, z)
                dome(f"bolt_{face}_{z_tag}{u_tag}", centre, BOLT_R, BOLT_H, axis, navy, collection)

    # ---- roof --------------------------------------------------------------------------
    roof_z0 = BASE_H + POST_H
    ring_stack(
        "roof",
        [
            (roof_z0, ring(ROOF_W)),
            (roof_z0 + ROOF_T - ROOF_BEVEL, ring(ROOF_W)),
            (roof_z0 + ROOF_T, ring(ROOF_W - 2.0 * ROOF_BEVEL)),
        ],
        cyan,
        collection,
    )

    # ---- pictogram plate on the front wall ---------------------------------------------
    front_y = BODY_W / 2.0
    plate_pts = ring_rounded(SIGN_W, SIGN_H, SIGN_R)
    bm = bmesh.new()
    bottom = [bm.verts.new((u, front_y, v + PLATE_CZ)) for u, v in plate_pts]
    top = [bm.verts.new((u, front_y + SIGN_T, v + PLATE_CZ)) for u, v in plate_pts]
    bm.verts.ensure_lookup_table()
    bm.faces.new(list(reversed(bottom)))
    bm.faces.new(top)
    for i in range(len(plate_pts)):
        j = (i + 1) % len(plate_pts)
        bm.faces.new((bottom[i], bottom[j], top[j], top[i]))
    bevel(bm, BEVEL_PLATE)
    sign = finish("sign_plate", bm, blue, collection)

    picto_y = front_y + SIGN_T - 0.001  # sunk 1 mm into the plate, no coplanar faces
    for index, (suffix, polygon) in enumerate(pictogram()):
        # Each piece steps 0.25 mm further back so overlapping parts never share a plane.
        plate(f"sign_{suffix}", polygon, picto_y, PICTO_T - 0.00025 * index, PLATE_CZ, white, collection)

    # ---- root --------------------------------------------------------------------------
    root = bpy.data.objects.new("prop_bin", None)
    root.empty_display_size = 0.25
    collection.objects.link(root)
    for obj in collection.objects:
        if obj is not root:
            obj.parent = root

    return collection, sign


def ring_rounded(size_x, size_y, radius, segments=3):
    """Rounded rectangle outline in the plate's local plane (metres, centred on 0, 0)."""
    hx = size_x / 2.0 - radius
    hy = size_y / 2.0 - radius
    points = []
    for cx, cy, start in (
        (hx, hy, 0.0),
        (-hx, hy, math.pi / 2.0),
        (-hx, -hy, math.pi),
        (hx, -hy, 3.0 * math.pi / 2.0),
    ):
        for i in range(segments + 1):
            angle = start + (math.pi / 2.0) * i / segments
            points.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    return points


def report(collection):
    tris = 0
    verts = 0
    for obj in collection.objects:
        if obj.type != "MESH":
            continue
        verts += len(obj.data.vertices)
        tris += sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"[bin] parts={len([o for o in collection.objects if o.type == 'MESH'])} "
          f"verts={verts} tris={tris}")


def export():
    blend_path = os.path.join(OUT_DIR, "bin.blend")
    glb_path = os.path.join(OUT_DIR, "bin.glb")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    bpy.ops.export_scene.gltf(filepath=glb_path, export_format="GLB", export_apply=True, export_yup=True)
    print(f"[bin] wrote {blend_path}")
    print(f"[bin] wrote {glb_path}")


def main():
    collection, _sign = build_bin()
    report(collection)
    export()


if __name__ == "__main__":
    main()
