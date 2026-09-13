"""Build a stylized low-poly boy character from ``reference_02_3_figures_second_boy.png``.

Run headless:

    blender -b -P boy_build.py

Outputs (next to this script):
    boy.blend   editable Blender scene
    boy.glb     game-ready glTF binary (metres; the boy faces +Y in Blender, which becomes
                -Z after the glTF conversion, i.e. Godot's forward direction)

Reference reading (three views on the sheet):
    front ......... proportions, open jacket over a white tee, cargo shorts, socks, sneakers
    three-quarter . head depth, jacket bulk, cheek/ear shaping, pocket placement
    back .......... hood hanging on the back, hair mass covering the nape

The front view gives the layout: total height H = 1.25 m, ~3.7 heads tall, head 0.267 H,
shoulder span 0.21 H, hip span 0.21 H, feet 0.25 H apart, hands just below the hip line.
"""

import math
import os

import bmesh
import bpy
from mathutils import Vector

# --------------------------------------------------------------------------------------
# Parameters - metres, Z up, origin between the feet on the ground, facing +Y
# --------------------------------------------------------------------------------------

H = 1.25

SKIN_HEX = "F2C08C"
HAIR_HEX = "8B4A2C"
JACKET_HEX = "2E7BD8"
CLOTH_HEX = "F2F0EE"
SHORTS_HEX = "D9AE4E"
EYE_HEX = "241C18"

RING_N = 16  # columns around the body
LIMB_N = 10  # columns around limbs

# vertical landmarks, as a fraction of H measured from the sole
Z_SOLE_TOP = 0.032
Z_ANKLE = 0.150
Z_SOCK_TOP = 0.150
Z_SOCK_BOTTOM = 0.100
Z_SHOE_TOP = 0.115
Z_KNEE = 0.235
Z_SHORTS_HEM = 0.284
Z_CROTCH = 0.400
Z_JACKET_HEM = 0.405
Z_WAIST = 0.520
Z_HIP_BOTTOM = 0.388
Z_SHOULDER = 0.700
Z_NECK = 0.717
Z_CHIN = 0.730
Z_EYE = 0.786
Z_EAR_BOTTOM = 0.752
Z_EAR_TOP = 0.816
Z_HAIRLINE = 0.872  # fringe line over the forehead
Z_HAIR_SIDE = 0.806  # hair edge over the temples
Z_NAPE = 0.814  # hair edge at the back of the neck
Z_HEAD_TOP = 0.962
Z_HAIR_TOP = 1.000

# horizontal landmarks, as a fraction of H
W_HEAD = 0.222
D_HEAD = 0.212
W_SHOULDER = 0.226
W_HEM = 0.225
D_HEM = 0.162
W_HIP = 0.236
D_HIP = 0.180
W_THIGH = 0.116
W_SHIN = 0.092
W_ANKLE = 0.078
X_LEG_HIP = 0.060
X_LEG_ANKLE = 0.082
X_SHOULDER = 0.105
X_WRIST = 0.168
W_ARM = 0.090
W_HAND = 0.078
L_SHOE = 0.215
W_SHOE = 0.140
FOOT_YAW = math.radians(12.0)

EYE_H = 0.048
EYE_W = 0.024
EYE_X = 0.048

HEAD_PROFILE = [  # (t, width factor, depth factor, squareness)
    (0.00, 0.62, 0.68, 2.6),
    (0.14, 0.86, 0.88, 2.7),
    (0.36, 0.99, 1.00, 2.8),
    (0.60, 1.00, 1.02, 3.0),
    (0.83, 0.96, 0.97, 3.0),
    (1.00, 0.70, 0.74, 2.7),
]

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


def make_material(name, hex_color, roughness=0.62):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = hex_to_linear(hex_color)
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = 0.0
    mat.diffuse_color = hex_to_linear(hex_color)
    return mat


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


def superellipse(a, ex, ey, e):
    ca, sa = math.cos(a), math.sin(a)
    return (ex * math.copysign(abs(ca) ** (2.0 / e), ca),
            ey * math.copysign(abs(sa) ** (2.0 / e), sa))


def ring(n, cx, cy, z, sx, sy, e=2.6, phase=0.0):
    pts = []
    for i in range(n):
        x, y = superellipse(phase + 2.0 * math.pi * i / n, sx / 2.0, sy / 2.0, e)
        pts.append((cx + x, cy + y, z))
    return pts


def transform_ring(pts, pivot, angle, scale=1.0, dy=0.0):
    """Rotate/scale a ring in the XY plane about ``pivot`` (used for splayed feet)."""
    ca, sa = math.cos(angle), math.sin(angle)
    out = []
    for x, y, z in pts:
        dx, dyv = (x - pivot[0]) * scale, (y - pivot[1]) * scale
        out.append((pivot[0] + dx * ca - dyv * sa, pivot[1] + dx * sa + dyv * ca + dy, z))
    return out


def loft(name, rings, material, collection, caps=(True, True), closed=True):
    bm = bmesh.new()
    vrings = [[bm.verts.new(p) for p in r] for r in rings]
    for a, b in zip(vrings, vrings[1:]):
        count = len(a) if closed else len(a) - 1
        for i in range(count):
            j = (i + 1) % len(a)
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if caps[0] and closed and len(vrings[0]) > 2:
        bm.faces.new(list(reversed(vrings[0])))
    if caps[1] and closed and len(vrings[-1]) > 2:
        bm.faces.new(vrings[-1])
    return finish(name, bm, material, collection)


def blob(name, cx, cy, z0, z1, sx, sy, material, collection, e=2.6, steps=4, n=RING_N,
         cy_top=None):
    rings = []
    for i in range(steps + 2):
        t = i / (steps + 1)
        s = math.sin(math.pi * (0.16 + 0.68 * t)) ** 0.5
        cy_i = cy if cy_top is None else cy + (cy_top - cy) * t
        rings.append(ring(n, cx, cy_i, z0 + (z1 - z0) * t, sx * s, sy * s, e))
    return loft(name, rings, material, collection)


def spike(name, base_centre, base_sx, base_sy, tip, material, collection, twist=0.0):
    bx, by, bz = base_centre
    bm = bmesh.new()
    verts = []
    for dx, dy in ((-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5)):
        ax, ay = dx * base_sx, dy * base_sy
        if twist:
            ca, sa = math.cos(twist), math.sin(twist)
            ax, ay = ax * ca - ay * sa, ax * sa + ay * ca
        verts.append(bm.verts.new((bx + ax, by + ay, bz)))
    apex = bm.verts.new(tip)
    bm.faces.new(list(reversed(verts)))
    for i in range(4):
        bm.faces.new((verts[i], verts[(i + 1) % 4], apex))
    return finish(name, bm, material, collection)


def add_box(name, centre, size, material, collection, bevel_width=0.0, yaw=0.0):
    cx, cy, cz = centre
    sx, sy, sz = size
    ca, sa = math.cos(yaw), math.sin(yaw)
    bm = bmesh.new()
    low, high = [], []
    for dx, dy in ((-0.5, -0.5), (0.5, -0.5), (0.5, 0.5), (-0.5, 0.5)):
        ox, oy = dx * sx * ca - dy * sy * sa, dx * sx * sa + dy * sy * ca
        low.append(bm.verts.new((cx + ox, cy + oy, cz - sz / 2)))
        high.append(bm.verts.new((cx + ox, cy + oy, cz + sz / 2)))
    bm.faces.new((low[3], low[2], low[1], low[0]))
    bm.faces.new(high)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((low[i], low[j], high[j], high[i]))
    if bevel_width > 0:
        bmesh.ops.bevel(bm, geom=list(bm.verts) + list(bm.edges) + list(bm.faces),
                        offset=bevel_width, offset_type="OFFSET", segments=1,
                        profile=0.5, affect="EDGES", clamp_overlap=True, loop_slide=True)
    return finish(name, bm, material, collection)


def assign_material(obj, material, predicate):
    """Give faces matching ``predicate(centre_matrix)`` a second material slot."""
    mesh = obj.data
    if material.name not in [m.name for m in mesh.materials]:
        mesh.materials.append(material)
    index = list(mesh.materials).index(material)
    for poly in mesh.polygons:
        centre = obj.matrix_world @ poly.center
        if predicate(centre):
            poly.material_index = index


# --------------------------------------------------------------------------------------
# Character
# --------------------------------------------------------------------------------------


def build_boy():
    reset_scene()
    scene = bpy.context.scene
    collection = bpy.data.collections.new("Boy")
    scene.collection.children.link(collection)

    skin = make_material("boy_skin", SKIN_HEX, 0.60)
    hair = make_material("boy_hair_brown", HAIR_HEX, 0.72)
    jacket = make_material("boy_jacket_blue", JACKET_HEX, 0.58)
    cloth = make_material("boy_cloth_white", CLOTH_HEX, 0.66)
    shorts = make_material("boy_shorts_tan", SHORTS_HEX, 0.68)
    eye_mat = make_material("boy_eye_dark", EYE_HEX, 0.35)

    f = lambda frac: frac * H

    # ---- head ----------------------------------------------------------------------
    head_z0, head_z1 = f(Z_CHIN) - 0.022, f(Z_HEAD_TOP)

    def head_factors(t):
        for (t0, fx0, fy0, e0), (t1, fx1, fy1, e1) in zip(HEAD_PROFILE, HEAD_PROFILE[1:]):
            if t <= t1:
                k = (t - t0) / (t1 - t0)
                return (fx0 + (fx1 - fx0) * k, fy0 + (fy1 - fy0) * k, e0 + (e1 - e0) * k)
        last = HEAD_PROFILE[-1]
        return last[1], last[2], last[3]

    head_rings = []
    for t, _fx, _fy, _e in HEAD_PROFILE:
        fx, fy, e = head_factors(t)
        head_rings.append(ring(RING_N, 0.0, 0.0, head_z0 + (head_z1 - head_z0) * t,
                               f(W_HEAD) * fx, f(D_HEAD) * fy, e))
    loft("head", head_rings, skin, collection)

    def head_surface_y(x, z):
        t = max(0.0, min(1.0, (z - head_z0) / (head_z1 - head_z0)))
        fx, fy, e = head_factors(t)
        hx = f(W_HEAD) * fx / 2.0
        hy = f(D_HEAD) * fy / 2.0
        ratio = min(1.0, abs(x) / hx)
        return hy * (1.0 - ratio ** e) ** (1.0 / e)

    loft("neck", [ring(LIMB_N, 0, 0.004, f(Z_NECK) - 0.040, 0.064, 0.062, 2.4),
                  ring(LIMB_N, 0, 0.004, f(Z_CHIN) + 0.010, 0.058, 0.058, 2.4)],
         skin, collection)

    for side, tag in ((-1, "L"), (1, "R")):
        blob(f"ear_{tag}", side * f(W_HEAD) * 0.51, -0.010, f(Z_EAR_BOTTOM), f(Z_EAR_TOP),
             0.040, 0.056, skin, collection, e=2.2, steps=3, n=LIMB_N)

    # eyes: flat dark ovals bedded into the face
    for side, tag in ((-1, "L"), (1, "R")):
        cx = side * f(EYE_X)
        surface = head_surface_y(cx, f(Z_EYE))
        blob(f"eye_{tag}", cx, surface - 0.004, f(Z_EYE) - EYE_H / 2, f(Z_EYE) + EYE_H / 2,
             EYE_W, 0.020, eye_mat, collection, e=2.0, steps=3, n=LIMB_N)

    # ---- hair ----------------------------------------------------------------------
    # A single noisy dome: the hair is a shell of the head pushed outward, with a jagged
    # bottom edge and a spiky crown, which reads like the reference's faceted tresses.
    hair_top = f(Z_HAIR_TOP)
    fringe_z, nape_z, side_z = f(Z_HAIRLINE), f(Z_NAPE), f(Z_HAIR_SIDE)

    def hash_noise(i, t, seed=0.0):
        v = math.sin(i * 12.9898 + t * 78.233 + seed) * 43758.5453
        return (v - math.floor(v)) * 2.0 - 1.0

    def bottom_z(i):
        a = 2.0 * math.pi * i / RING_N
        s, c = math.sin(a), math.cos(a)
        z = nape_z + (fringe_z - nape_z) * max(0.0, s) ** 1.4 - (nape_z - side_z) * abs(c) ** 1.6
        return z + 0.008 * hash_noise(i, 0.0, 3.1)

    crown = [
        (0.00, 1.16, 1.12, 2.6, 0.00),
        (0.30, 1.28, 1.22, 2.8, 0.10),
        (0.58, 1.24, 1.20, 3.0, 0.16),
        (0.80, 1.08, 1.06, 3.0, 0.55),
        (0.93, 0.76, 0.78, 2.8, 1.00),
    ]
    shell = []
    for t, sxf, syf, e, spikiness in crown:
        pts = []
        for i in range(RING_N):
            a = 2.0 * math.pi * i / RING_N
            n = hash_noise(i, t)
            spread = 1.0 + (0.045 + 0.100 * spikiness) * n
            x, y = superellipse(a, f(W_HEAD) * sxf * spread / 2.0,
                                f(D_HEAD) * syf * spread / 2.0, e)
            base = bottom_z(i)
            z = base + (hair_top - base) * t + (0.008 + 0.055 * spikiness) * n
            pts.append((x, y, z))
        shell.append(pts)

    bm = bmesh.new()
    vrings = [[bm.verts.new(p) for p in r] for r in shell]
    for a_ring, b_ring in zip(vrings, vrings[1:]):
        for i in range(RING_N):
            j = (i + 1) % RING_N
            bm.faces.new((a_ring[i], a_ring[j], b_ring[j], b_ring[i]))
    # spiky crown: triangles from the top ring up to peak / down to valley centres
    centre_pt = bm.verts.new((0.0, 0.0, hair_top + 0.012))
    for i in range(RING_N):
        j = (i + 1) % RING_N
        bm.faces.new((vrings[-1][i], vrings[-1][j], centre_pt))
    # inner rim so the shell is a closed solid
    rim = [bm.verts.new((x * 0.86, y * 0.86, z)) for (x, y, z) in shell[0]]
    for i in range(RING_N):
        j = (i + 1) % RING_N
        bm.faces.new((rim[j], rim[i], vrings[0][i], vrings[0][j]))
    bm.faces.new(list(reversed(rim)))
    finish("hair", bm, hair, collection)

    # discrete clumps where the hair kicks up, as on the reference (metres, absolute)
    for i, (bx, by, bz, sx, sy, tip, tw) in enumerate([
        (0.000, 0.085, 1.150, 0.110, 0.100, (0.015, 0.152, 1.236), 0.10),
        (0.100, 0.045, 1.145, 0.100, 0.092, (0.172, 0.076, 1.214), 0.55),
        (-0.105, 0.040, 1.140, 0.100, 0.092, (-0.176, 0.070, 1.204), -0.55),
        (0.058, -0.078, 1.180, 0.100, 0.100, (0.078, -0.118, 1.266), 0.30),
        (-0.062, -0.072, 1.180, 0.100, 0.100, (-0.088, -0.112, 1.258), -0.35),
        (0.000, -0.108, 1.140, 0.120, 0.100, (0.000, -0.168, 1.198), 0.0),
    ]):
        spike(f"hair_point_{i + 1}", (bx, by, bz), sx, sy, tip, hair, collection, twist=tw)

    # ---- torso: jacket shell with the tee colour-blocked into the front -------------
    torso_profile = [
        (Z_JACKET_HEM, 1.00, 1.00),
        (0.470, 0.99, 0.99),
        (0.560, 0.99, 1.00),
        (0.645, 0.97, 0.99),
        (Z_SHOULDER + 0.014, 0.95, 0.94),
        (Z_NECK + 0.014, 0.56, 0.66),
    ]
    torso_rings = []
    tee_cols = {(RING_N // 4 - 1) % RING_N, RING_N // 4, (RING_N // 4 + 1) % RING_N}
    for zf, fx, fy in torso_profile:
        r = ring(RING_N, 0.0, 0.0, f(zf), f(W_HEM) * fx, f(D_HEM) * fy, 2.8)
        for c in tee_cols:
            x, y, z = r[c]
            r[c] = (x * 0.86, y * 0.86, z)  # recessed so the jacket edges read
        torso_rings.append(r)
    torso = loft("torso", torso_rings, jacket, collection)
    assign_material(torso, cloth,
                    lambda p: p.y > 0 and abs(math.atan2(p.x, p.y)) < math.radians(20.0))

    loft("collar", [ring(RING_N, 0, 0.006, f(Z_NECK) - 0.006, f(W_HEM) * 0.58, f(D_HEM) * 0.74, 2.6),
                    ring(RING_N, 0, 0.006, f(Z_NECK) + 0.028, f(W_HEM) * 0.50, f(D_HEM) * 0.66, 2.6)],
         jacket, collection)

    blob("hood", 0.0, -0.072, f(0.520), f(Z_NECK) + 0.036, f(0.232), f(0.162),
         jacket, collection, e=2.9, steps=5, cy_top=-0.036)

    # ---- arms ----------------------------------------------------------------------
    # the sleeves hang wide of the torso and flare outward toward the cuff, which is what
    # makes the reference silhouette widest at the elbow line
    for side, tag in ((-1, "L"), (1, "R")):
        s = side
        loft(f"sleeve_{tag}", [
            ring(LIMB_N, s * f(X_SHOULDER), 0.0, f(Z_SHOULDER) + 0.014, f(W_ARM) * 1.10, f(W_ARM) * 1.04, 2.4),
            ring(LIMB_N, s * f(0.126), -0.002, f(0.640), f(W_ARM) * 1.06, f(W_ARM) * 1.00, 2.4),
            ring(LIMB_N, s * f(0.148), -0.002, f(0.570), f(W_ARM) * 0.98, f(W_ARM) * 0.94, 2.4),
            ring(LIMB_N, s * f(0.162), -0.002, f(0.505), f(W_ARM) * 0.90, f(W_ARM) * 0.88, 2.4),
            ring(LIMB_N, s * f(X_WRIST), -0.002, f(0.468), f(W_ARM) * 0.84, f(W_ARM) * 0.82, 2.4),
        ], jacket, collection)
        blob(f"hand_{tag}", s * f(X_WRIST) * 0.99, -0.006, f(0.362), f(0.452),
             f(W_HAND), f(W_HAND) * 0.90, skin, collection, e=2.4, steps=3, n=LIMB_N)

    # ---- shorts --------------------------------------------------------------------
    loft("shorts_hip", [
        ring(RING_N, 0, 0, f(Z_WAIST) + 0.014, f(W_HEM) * 0.96, f(D_HEM) * 0.98, 2.8),
        ring(RING_N, 0, 0, f(0.450), f(W_HIP), f(D_HIP), 2.8),
        ring(RING_N, 0, 0, f(Z_HIP_BOTTOM), f(W_HIP) * 0.99, f(D_HIP) * 0.97, 2.8),
    ], shorts, collection)

    for side, tag in ((-1, "L"), (1, "R")):
        s = side
        loft(f"shorts_leg_{tag}", [
            ring(LIMB_N, s * f(X_LEG_HIP) * 0.92, 0.0, f(Z_CROTCH) + 0.004, f(W_THIGH) * 1.16, f(W_THIGH) * 1.10, 2.4),
            ring(LIMB_N, s * f(0.068), 0.0, f(0.350), f(W_THIGH) * 1.06, f(W_THIGH) * 1.00, 2.4),
            ring(LIMB_N, s * f(0.072), 0.0, f(Z_SHORTS_HEM), f(W_THIGH) * 1.02, f(W_THIGH) * 0.98, 2.4),
        ], shorts, collection)
        add_box(f"pocket_{tag}", (s * f(0.104), 0.0, f(0.344)), (0.024, 0.050, 0.058),
                shorts, collection, bevel_width=0.007)

    # ---- legs, socks, shoes --------------------------------------------------------
    for side, tag in ((-1, "L"), (1, "R")):
        s = side
        loft(f"leg_{tag}", [
            ring(LIMB_N, s * f(X_LEG_HIP) * 0.94, 0.0, f(Z_CROTCH) + 0.012, f(W_THIGH) * 0.94, f(W_THIGH) * 0.88, 2.4),
            ring(LIMB_N, s * f(0.066), 0.0, f(Z_SHORTS_HEM) - 0.014, f(W_THIGH) * 0.92, f(W_THIGH) * 0.86, 2.4),
            ring(LIMB_N, s * f(0.073), 0.0, f(Z_KNEE), f(W_SHIN) * 1.10, f(W_SHIN) * 1.06, 2.4),
            ring(LIMB_N, s * f(0.079), 0.0, f(0.190), f(W_ANKLE) * 1.06, f(W_ANKLE) * 1.04, 2.4),
            ring(LIMB_N, s * f(X_LEG_ANKLE), 0.0, f(Z_ANKLE), f(W_ANKLE), f(W_ANKLE), 2.4),
        ], skin, collection)
        loft(f"sock_{tag}", [
            ring(LIMB_N, s * f(0.080), 0.0, f(Z_SOCK_TOP), f(W_ANKLE) * 1.14, f(W_ANKLE) * 1.12, 2.4),
            ring(LIMB_N, s * f(X_LEG_ANKLE), 0.0, f(Z_SOCK_BOTTOM), f(W_ANKLE) * 1.10, f(W_ANKLE) * 1.10, 2.4),
        ], cloth, collection)

        pivot = (s * f(X_LEG_ANKLE), 0.0)
        yaw = -s * FOOT_YAW
        cx = s * f(X_LEG_ANKLE)
        shoe_rings = [
            ring(12, cx, -0.012, f(Z_SOLE_TOP), f(W_SHOE) * 0.94, f(L_SHOE) * 0.88, 2.9),
            ring(12, cx, -0.012, f(0.060), f(W_SHOE) * 1.02, f(L_SHOE) * 0.94, 2.9),
            ring(12, cx, -0.018, f(0.088), f(W_SHOE) * 0.94, f(L_SHOE) * 0.80, 2.7),
            ring(12, cx, 0.006, f(Z_SHOE_TOP), f(W_SHOE) * 0.62, f(0.080), 2.5),
        ]
        loft(f"shoe_{tag}", [transform_ring(r, pivot, yaw) for r in shoe_rings],
             jacket, collection)
        sole_rings = [
            ring(12, cx, -0.014, 0.0, f(W_SHOE) * 0.92, f(L_SHOE) * 0.90, 2.9),
            ring(12, cx, -0.014, f(Z_SOLE_TOP) + 0.012, f(W_SHOE) * 1.00, f(L_SHOE) * 0.96, 2.9),
        ]
        loft(f"sole_{tag}", [transform_ring(r, pivot, yaw) for r in sole_rings],
             cloth, collection)
        add_box(f"toe_{tag}", (cx, f(0.058), f(0.044)), (f(W_SHOE) * 0.88, f(L_SHOE) * 0.36, f(0.052)),
                cloth, collection, bevel_width=0.009, yaw=yaw)
        add_box(f"strap_{tag}", (cx, -f(0.010), f(0.100)), (f(W_SHOE) * 1.06, f(0.070), f(0.024)),
                cloth, collection, bevel_width=0.005, yaw=yaw)

    # ---- root ----------------------------------------------------------------------
    root = bpy.data.objects.new("char_boy_hoodie", None)
    root.empty_display_size = 0.25
    collection.objects.link(root)
    for obj in collection.objects:
        if obj is not root:
            obj.parent = root
    return collection, root


def report(collection):
    verts = tris = parts = 0
    for obj in collection.objects:
        if obj.type != "MESH":
            continue
        parts += 1
        verts += len(obj.data.vertices)
        tris += sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"[boy] parts={parts} verts={verts} tris={tris}")


def export(collection):
    blend_path = os.path.join(OUT_DIR, "boy.blend")
    glb_path = os.path.join(OUT_DIR, "boy.glb")
    bpy.ops.wm.save_as_mainfile(filepath=blend_path)
    bpy.ops.export_scene.gltf(filepath=glb_path, export_format="GLB", export_apply=True,
                              export_yup=True)
    print(f"[boy] wrote {blend_path}")
    print(f"[boy] wrote {glb_path}")


def main():
    collection, _root = build_boy()
    report(collection)
    export(collection)


if __name__ == "__main__":
    main()
