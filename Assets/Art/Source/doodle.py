"""Tiny anti-aliased shape rasterizer with a hand-drawn "doodle" look.

Shapes are signed distance functions in design units (a 100 x 100 box by
default, y pointing down). Each drawn shape gets a chunky dark outline with a
slight wobble, a flat fill and one cel shadow toward the bottom right, which
together read as hand-inked stickers. Pure Python, no dependencies.

Canvas(gloss=True) draws the same shapes crisp instead (no wobble): a fill
that brightens toward the top, a light rim along the top edge and the cel
shadow, for polished UI icons. gradient() fills a shape with a vertical
gradient (UI skins).

Canvas(paint=True, supersample=2) is the illustration mode used for the game's
art: every part is shaded as a soft volume lit from the top left (cool
shadows, warm lights, optional shine for metal), casts a soft contact shadow
onto what lies behind it and gets a thin inner ink line; finish() then inks
one heavy outline around the whole silhouette, adds grain and the picture is
rendered at 2x and averaged down on save().

    canvas = Canvas(128, 128, seed="slime")
    canvas.draw(ellipse(50, 70, 30, 22), "#7fbf4d")
    canvas.save(path)
"""

import math
import random
import struct
import zlib

INK = (0.11, 0.09, 0.12)
SHADOW_TINT = (0.16, 0.12, 0.24)
# Painted mode: shadows lean cool, lights lean warm.
COOL_SHADE = (0.2, 0.15, 0.32)
WARM_LIGHT = (1.0, 0.93, 0.78)


def smoothstep(edge0, edge1, value):
    t = max(0.0, min(1.0, (value - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def rgb(value):
    """'#rrggbb' or an (r, g, b) tuple in 0..1 -> (r, g, b)."""
    if isinstance(value, tuple):
        return value
    value = value.lstrip("#")
    return tuple(int(value[index:index + 2], 16) / 255.0 for index in (0, 2, 4))


def mix(first, second, amount):
    return tuple(a + (b - a) * amount for a, b in zip(first, second))


def muted(color, amount=0.42):
    """The game's palette: [color] made dusty (pulled toward a warm grey of the
    same brightness) and a little darker."""
    r, g, b = rgb(color)
    luminance = 0.3 * r + 0.59 * g + 0.11 * b
    warm_grey = (luminance * 1.05, luminance * 0.99, luminance * 0.88)
    return tuple(max(0.0, min(1.0, (channel + (grey - channel) * amount) * 0.92)) for channel, grey in zip((r, g, b), warm_grey))


def shade_of(color, amount=0.38):
    return mix(rgb(color), SHADOW_TINT, amount)


def lighter(color, amount=0.3):
    return mix(rgb(color), (1.0, 1.0, 1.0), amount)


# ============================================
# SHAPES (signed distance, negative inside)
# ============================================

class Shape:
    def __init__(self, distance, bounds):
        self.distance = distance
        self.bounds = bounds

    def __or__(self, other):
        first, second = self.distance, other.distance
        return Shape(lambda x, y: min(first(x, y), second(x, y)), _union_bounds(self.bounds, other.bounds))

    def __sub__(self, other):
        first, second = self.distance, other.distance
        return Shape(lambda x, y: max(first(x, y), -second(x, y)), self.bounds)

    def __and__(self, other):
        first, second = self.distance, other.distance
        return Shape(lambda x, y: max(first(x, y), second(x, y)), _intersect_bounds(self.bounds, other.bounds))

    def blend(self, other, radius):
        """Smooth union (blobby join)."""
        first, second = self.distance, other.distance

        def distance(x, y):
            a, b = first(x, y), second(x, y)
            h = max(0.0, min(1.0, 0.5 + 0.5 * (b - a) / radius))
            return b + (a - b) * h - radius * h * (1.0 - h)
        return Shape(distance, _union_bounds(self.bounds, other.bounds))

    def grown(self, amount):
        inner = self.distance
        x0, y0, x1, y1 = self.bounds
        return Shape(lambda x, y: inner(x, y) - amount, (x0 - amount, y0 - amount, x1 + amount, y1 + amount))

    def moved(self, dx, dy):
        inner = self.distance
        x0, y0, x1, y1 = self.bounds
        return Shape(lambda x, y: inner(x - dx, y - dy), (x0 + dx, y0 + dy, x1 + dx, y1 + dy))

    def mirrored(self, axis_x=50.0):
        inner = self.distance
        x0, y0, x1, y1 = self.bounds
        return Shape(lambda x, y: inner(2.0 * axis_x - x, y), (2.0 * axis_x - x1, y0, 2.0 * axis_x - x0, y1))


def _union_bounds(first, second):
    return (min(first[0], second[0]), min(first[1], second[1]), max(first[2], second[2]), max(first[3], second[3]))


def _intersect_bounds(first, second):
    return (max(first[0], second[0]), max(first[1], second[1]), min(first[2], second[2]), min(first[3], second[3]))


INFINITE = (-1e9, -1e9, 1e9, 1e9)


def circle(cx, cy, radius):
    hypot = math.hypot
    return Shape(lambda x, y: hypot(x - cx, y - cy) - radius, (cx - radius, cy - radius, cx + radius, cy + radius))


def ellipse(cx, cy, rx, ry, angle=0.0):
    cos_a, sin_a = math.cos(-math.radians(angle)), math.sin(-math.radians(angle))
    hypot = math.hypot

    def distance(x, y):
        px = (x - cx) * cos_a - (y - cy) * sin_a
        py = (x - cx) * sin_a + (y - cy) * cos_a
        k0 = hypot(px / rx, py / ry)
        if k0 < 1e-6:
            return -min(rx, ry)
        k1 = hypot(px / (rx * rx), py / (ry * ry))
        return k0 * (k0 - 1.0) / k1
    reach = max(rx, ry)
    return Shape(distance, (cx - reach, cy - reach, cx + reach, cy + reach))


def box(cx, cy, half_width, half_height, radius=0.0, angle=0.0):
    cos_a, sin_a = math.cos(-math.radians(angle)), math.sin(-math.radians(angle))
    radius = min(radius, half_width, half_height)

    def distance(x, y):
        px = abs((x - cx) * cos_a - (y - cy) * sin_a) - half_width + radius
        py = abs((x - cx) * sin_a + (y - cy) * cos_a) - half_height + radius
        outside = math.hypot(max(px, 0.0), max(py, 0.0))
        return outside + min(max(px, py), 0.0) - radius
    reach = math.hypot(half_width, half_height)
    return Shape(distance, (cx - reach, cy - reach, cx + reach, cy + reach))


def capsule(x1, y1, x2, y2, radius, end_radius=None):
    """A thick line; end_radius tapers it."""
    end_radius = radius if end_radius is None else end_radius
    bx, by = x2 - x1, y2 - y1
    length_squared = bx * bx + by * by or 1e-9

    def distance(x, y):
        px, py = x - x1, y - y1
        h = max(0.0, min(1.0, (px * bx + py * by) / length_squared))
        return math.hypot(px - bx * h, py - by * h) - (radius + (end_radius - radius) * h)
    reach = max(radius, end_radius)
    return Shape(distance, (min(x1, x2) - reach, min(y1, y2) - reach, max(x1, x2) + reach, max(y1, y2) + reach))


def polygon(points):
    count = len(points)

    def distance(x, y):
        best = (x - points[0][0]) ** 2 + (y - points[0][1]) ** 2
        sign = 1.0
        previous = count - 1
        for index in range(count):
            vx, vy = points[index]
            ux, uy = points[previous]
            ex, ey = ux - vx, uy - vy
            wx, wy = x - vx, y - vy
            h = max(0.0, min(1.0, (wx * ex + wy * ey) / ((ex * ex + ey * ey) or 1e-9)))
            dx, dy = wx - ex * h, wy - ey * h
            best = min(best, dx * dx + dy * dy)
            above = y >= vy
            below = y < uy
            cross = ex * wy > ey * wx
            if (above and below and cross) or (not above and not below and not cross):
                sign = -sign
            previous = index
        return sign * math.sqrt(best)
    xs = [point[0] for point in points]
    ys = [point[1] for point in points]
    return Shape(distance, (min(xs), min(ys), max(xs), max(ys)))


def ring(cx, cy, radius, thickness):
    hypot = math.hypot
    half = thickness * 0.5
    return Shape(lambda x, y: abs(hypot(x - cx, y - cy) - radius) - half, (cx - radius - half, cy - radius - half, cx + radius + half, cy + radius + half))


def half_plane(nx, ny, offset):
    """Inside where x * nx + y * ny < offset (normal need not be unit)."""
    length = math.hypot(nx, ny)
    nx, ny, offset = nx / length, ny / length, offset / length
    return Shape(lambda x, y: x * nx + y * ny - offset, INFINITE)


def star(cx, cy, outer, inner, points=5, angle=-90.0):
    corners = []
    for index in range(points * 2):
        radius = outer if index % 2 == 0 else inner
        theta = math.radians(angle + index * 180.0 / points)
        corners.append((cx + math.cos(theta) * radius, cy + math.sin(theta) * radius))
    return polygon(corners)


def heart(cx, cy, size):
    lobe = size * 0.32
    left = circle(cx - size * 0.24, cy - size * 0.12, lobe)
    right = circle(cx + size * 0.24, cy - size * 0.12, lobe)
    point = polygon([(cx - size * 0.53, cy - size * 0.02), (cx + size * 0.53, cy - size * 0.02), (cx, cy + size * 0.5)])
    return (left | right).blend(point, size * 0.08)


def teardrop(cx, cy, radius, tip_x, tip_y):
    bulb = circle(cx, cy, radius)
    angle = math.atan2(tip_y - cy, tip_x - cx)
    side = angle + math.pi / 2.0
    tip = polygon([
        (cx + math.cos(side) * radius * 0.92, cy + math.sin(side) * radius * 0.92),
        (tip_x, tip_y),
        (cx - math.cos(side) * radius * 0.92, cy - math.sin(side) * radius * 0.92),
    ])
    return bulb.blend(tip, radius * 0.25)


def zigzag(points, width):
    shape = None
    for (x1, y1), (x2, y2) in zip(points, points[1:]):
        segment = capsule(x1, y1, x2, y2, width)
        shape = segment if shape is None else shape | segment
    return shape


# ============================================
# CANVAS
# ============================================

class ValueNoise:
    def __init__(self, seed):
        rng = random.Random(seed)
        self.values = [rng.random() for _ in range(256)]
        self.permutation = list(range(256))
        rng.shuffle(self.permutation)

    def sample(self, x, y):
        xi, yi = math.floor(x), math.floor(y)
        fx, fy = x - xi, y - yi
        fx, fy = fx * fx * (3.0 - 2.0 * fx), fy * fy * (3.0 - 2.0 * fy)
        perm, values = self.permutation, self.values

        def corner(ix, iy):
            return values[perm[(perm[ix & 255] + iy) & 255]]
        top = corner(xi, yi) + (corner(xi + 1, yi) - corner(xi, yi)) * fx
        bottom = corner(xi, yi + 1) + (corner(xi + 1, yi + 1) - corner(xi, yi + 1)) * fx
        return top + (bottom - top) * fy


class Canvas:
    def __init__(self, width, height, design_width=100.0, seed="art", outline_px=None, wobble_px=None, gloss=False, palette=None,
                 paint=False, supersample=1, light=(-0.5, -0.78, 0.62)):
        # Sizes passed in are output pixels; drawing happens at width * supersample.
        self.output_width = width
        self.output_height = height
        self.supersample = supersample
        self.width = width * supersample
        self.height = height * supersample
        self.scale = self.width / design_width
        self.pixels = [0.0] * (self.width * self.height * 4)
        self.noise = ValueNoise(seed)
        self.outline_px = (outline_px if outline_px is not None else max(2.0, width / 40.0)) * supersample
        self.wobble_px = 0.0 if gloss else (wobble_px if wobble_px is not None else max(0.5, width / 150.0)) * supersample
        self.gloss = gloss
        # Every fill color passes through this (e.g. muted); outlines don't.
        self.palette = palette or rgb
        self.paint = paint
        light_length = math.sqrt(sum(component * component for component in light))
        self.light = tuple(component / light_length for component in light)
        # Coverage of solid parts only (glows don't get a silhouette outline).
        self.solid = [0.0] * (self.width * self.height) if paint else None

    def _pixel_bounds(self, bounds, margin_px):
        x0, y0, x1, y1 = bounds
        return (max(0, int(x0 * self.scale - margin_px)), max(0, int(y0 * self.scale - margin_px)),
                min(self.width, int(x1 * self.scale + margin_px) + 1), min(self.height, int(y1 * self.scale + margin_px) + 1))

    def _blend(self, index, color, alpha):
        if alpha <= 0.0:
            return
        pixels = self.pixels
        below = pixels[index + 3]
        out_alpha = alpha + below * (1.0 - alpha)
        keep = below * (1.0 - alpha) / out_alpha
        take = alpha / out_alpha
        pixels[index] = pixels[index] * keep + color[0] * take
        pixels[index + 1] = pixels[index + 1] * keep + color[1] * take
        pixels[index + 2] = pixels[index + 2] * keep + color[2] * take
        pixels[index + 3] = out_alpha

    def draw(self, shape, fill, outline=INK, outline_px=None, shadow=0.38, shadow_offset=3.5, alpha=1.0, wobble=True, shine=0.0):
        """Outline (if any) then fill with a cel shadow toward the bottom right.
        In paint mode: a shaded volume with a thin inner line instead
        ([shine] 0..1 adds a specular highlight, for metal and slime)."""
        if self.paint and shadow:
            line_px = (self.outline_px if outline_px is None else outline_px * self.supersample) * 0.3 if outline is not None else 0.0
            self._paint(shape, fill, rgb(outline) if outline is not None else None, line_px, alpha, wobble, shine)
            return
        fill = self.palette(fill)
        shadow_color = shade_of(fill, shadow) if shadow else fill
        outline_color = rgb(outline) if outline is not None else None
        line = (self.outline_px if outline_px is None else outline_px) if outline is not None else 0.0
        scale = self.scale
        inverse = 1.0 / scale
        wobble_px = self.wobble_px if wobble else 0.0
        noise = self.noise.sample
        distance = shape.distance
        x0, y0, x1, y1 = self._pixel_bounds(shape.bounds, line + wobble_px + 2.0)
        offset_units = shadow_offset
        gloss = self.gloss and shadow
        top_y, bottom_y = shape.bounds[1], shape.bounds[3]
        span = max(1e-6, bottom_y - top_y)
        bright = lighter(fill, 0.3)
        rim_units = max(1.5, 2.6 / scale * (self.width / 72.0))
        for py in range(y0, y1):
            design_y = (py + 0.5) * inverse
            for px in range(x0, x1):
                design_x = (px + 0.5) * inverse
                d = distance(design_x, design_y) * scale
                if wobble_px:
                    d += wobble_px * (noise(px * 0.09, py * 0.09) * 2.0 - 1.0)
                if d - line > 0.75:
                    continue
                index = (py * self.width + px) * 4
                if line:
                    self._blend(index, outline_color, min(1.0, 0.5 - (d - line)) * alpha)
                coverage = max(0.0, min(1.0, 0.5 - d))
                if coverage <= 0.0:
                    continue
                color = fill
                if gloss:
                    color = mix(bright, fill, min(1.0, max(0.0, (design_y - top_y) / span) * 1.4))
                    if distance(design_x, design_y - rim_units) * scale > 0.0:
                        color = mix(color, (1.0, 1.0, 1.0), 0.35)
                if shadow:
                    lit = distance(design_x + offset_units, design_y + offset_units) * scale
                    amount = max(0.0, min(1.0, 0.5 + lit))
                    if amount > 0.0:
                        color = mix(color, shadow_color, amount)
                self._blend(index, color, coverage * alpha)

    def flat(self, shape, color, alpha=1.0):
        """No outline, no shadow (eyes, stripes, details)."""
        self.draw(shape, color, outline=None, shadow=0.0, alpha=alpha, wobble=False)
        if self.paint and alpha >= 0.9:
            self._mark_solid(shape)

    def line(self, points, width, color=INK, alpha=0.85):
        """A thin ink stroke through [points] (folds, seams, details)."""
        self.flat(zigzag(points, width), color, alpha)

    def _mark_solid(self, shape):
        scale = self.scale
        inverse = 1.0 / scale
        distance = shape.distance
        solid = self.solid
        x0, y0, x1, y1 = self._pixel_bounds(shape.bounds, 2.0)
        for py in range(y0, y1):
            design_y = (py + 0.5) * inverse
            for px in range(x0, x1):
                coverage = 0.5 - distance((px + 0.5) * inverse, design_y) * scale
                if coverage > 0.0:
                    index = py * self.width + px
                    solid[index] = max(solid[index], min(1.0, coverage))

    def _paint(self, shape, fill, line_color, line_px, alpha, wobble, shine):
        base = self.palette(fill)
        dark = mix(mix(base, COOL_SHADE, 0.22), (0.0, 0.0, 0.0), 0.2)
        light = mix(base, WARM_LIGHT, 0.24)
        sheen = mix(base, (1.0, 1.0, 1.0), 0.6)
        scale = self.scale
        inverse = 1.0 / scale
        distance = shape.distance
        wobble_px = self.wobble_px if wobble else 0.0
        noise = self.noise.sample
        lx, ly, lz = self.light
        x0, y0, x1, y1 = shape.bounds
        # How "thick" the part is: the depth of the dome its shading follows.
        thickness = max(1.0, min(40.0, min(x1 - x0, y1 - y0) * 0.42))
        step = inverse
        cast = 1.6 * self.supersample * inverse
        pixels = self.pixels
        solid = self.solid
        sqrt = math.sqrt
        px0, py0, px1, py1 = self._pixel_bounds(shape.bounds, cast * scale + wobble_px + 3.0)
        for py in range(py0, py1):
            design_y = (py + 0.5) * inverse
            for px in range(px0, px1):
                design_x = (px + 0.5) * inverse
                d_units = distance(design_x, design_y)
                d = d_units * scale
                if wobble_px:
                    d += wobble_px * (noise(px * 0.06, py * 0.06) * 2.0 - 1.0)
                coverage = max(0.0, min(1.0, 0.5 - d))
                index = (py * self.width + px) * 4
                # Contact shadow on whatever is already drawn behind this part.
                if coverage < 1.0 and pixels[index + 3] > 0.0:
                    shifted = distance(design_x - cast, design_y - cast) * scale
                    shade = max(0.0, min(1.0, 0.5 - shifted)) * (1.0 - coverage) * 0.26 * alpha
                    if shade > 0.0:
                        keep = 1.0 - shade
                        pixels[index] *= keep
                        pixels[index + 1] *= keep
                        pixels[index + 2] *= keep
                if coverage <= 0.0:
                    continue
                gradient_x = distance(design_x + step, design_y) - d_units
                gradient_y = distance(design_x, design_y + step) - d_units
                length = sqrt(gradient_x * gradient_x + gradient_y * gradient_y) or 1.0
                depth = max(0.0, min(1.0, -d_units / thickness))
                rest = 1.0 - depth
                slope = min(3.0, rest / sqrt(max(1e-4, 1.0 - rest * rest)))
                nx = gradient_x / length * slope
                ny = gradient_y / length * slope
                diffuse = (nx * lx + ny * ly + lz) / sqrt(nx * nx + ny * ny + 1.0)
                color = mix(dark, base, smoothstep(0.28, 0.5, diffuse))
                if diffuse > 0.76:
                    color = mix(color, light, smoothstep(0.76, 0.92, diffuse))
                if shine and diffuse > 0.9:
                    color = mix(color, sheen, shine * smoothstep(0.9, 0.975, diffuse))
                self._blend(index, color, coverage * alpha)
                if solid is not None and alpha >= 0.9:
                    solid_index = py * self.width + px
                    solid[solid_index] = max(solid[solid_index], coverage)
                if line_color is not None and line_px > 0.0:
                    line_alpha = coverage - max(0.0, min(1.0, 0.5 - (d + line_px)))
                    if line_alpha > 0.0:
                        self._blend(index, line_color, line_alpha * 0.85 * alpha)

    def finish(self, outline_px=None, grain=0.06):
        """Paint mode: one heavy ink outline around the whole silhouette
        (slightly varying width, like a brush), then grain."""
        width_px = (outline_px * self.supersample) if outline_px is not None else self.outline_px
        mask = self.solid if self.solid is not None else [self.pixels[index * 4 + 3] for index in range(self.width * self.height)]
        distances = self._distance_outside(mask)
        pixels = self.pixels
        noise = self.noise.sample
        ink = INK
        for py in range(self.height):
            for px in range(self.width):
                flat_index = py * self.width + px
                gap = distances[flat_index]
                if gap <= 0.0:
                    continue
                local = width_px * (0.82 + 0.36 * noise(px * 0.035 + 7.0, py * 0.035 + 3.0))
                outline_alpha = max(0.0, min(1.0, local + 0.5 - gap))
                if outline_alpha <= 0.0:
                    continue
                index = flat_index * 4
                above = pixels[index + 3]
                out_alpha = above + outline_alpha * (1.0 - above)
                if out_alpha <= 0.0:
                    continue
                under = outline_alpha * (1.0 - above)
                for channel in range(3):
                    pixels[index + channel] = (pixels[index + channel] * above + ink[channel] * under) / out_alpha
                pixels[index + 3] = out_alpha
        if grain:
            self.add_grain(grain)

    def _distance_outside(self, mask):
        """Approximate distance (px) from each pixel to the nearest solid pixel
        (two-pass chamfer); 0 inside. Partial coverage counts as a sub-pixel offset."""
        width, height = self.width, self.height
        far = 1e9
        distances = [0.0 if value >= 0.5 else (0.5 - value if value > 0.0 else far) for value in mask]
        diagonal = 1.4142
        for py in range(height):
            row = py * width
            for px in range(width):
                index = row + px
                best = distances[index]
                if best == 0.0:
                    continue
                if px > 0:
                    best = min(best, distances[index - 1] + 1.0)
                if py > 0:
                    above = index - width
                    best = min(best, distances[above] + 1.0)
                    if px > 0:
                        best = min(best, distances[above - 1] + diagonal)
                    if px < width - 1:
                        best = min(best, distances[above + 1] + diagonal)
                distances[index] = best
        for py in range(height - 1, -1, -1):
            row = py * width
            for px in range(width - 1, -1, -1):
                index = row + px
                best = distances[index]
                if best == 0.0:
                    continue
                if px < width - 1:
                    best = min(best, distances[index + 1] + 1.0)
                if py < height - 1:
                    below = index + width
                    best = min(best, distances[below] + 1.0)
                    if px < width - 1:
                        best = min(best, distances[below + 1] + diagonal)
                    if px > 0:
                        best = min(best, distances[below - 1] + diagonal)
                distances[index] = best
        return distances

    def gradient(self, shape, top, bottom, alpha=1.0, y_from=None, y_to=None):
        """Fills [shape] (no outline, no wobble) fading from [top] to [bottom]
        between y_from and y_to (design units; default: the shape's bounds)."""
        top, bottom = self.palette(top), self.palette(bottom)
        y_from = shape.bounds[1] if y_from is None else y_from
        y_to = shape.bounds[3] if y_to is None else y_to
        span = max(1e-6, y_to - y_from)
        scale = self.scale
        inverse = 1.0 / scale
        distance = shape.distance
        x0, y0, x1, y1 = self._pixel_bounds(shape.bounds, 2.0)
        for py in range(y0, y1):
            design_y = (py + 0.5) * inverse
            color = mix(top, bottom, max(0.0, min(1.0, (design_y - y_from) / span)))
            for px in range(x0, x1):
                coverage = max(0.0, min(1.0, 0.5 - distance((px + 0.5) * inverse, design_y) * scale))
                if coverage > 0.0:
                    self._blend((py * self.width + px) * 4, color, coverage * alpha)

    def glow(self, cx, cy, radius, color, strength=0.6):
        color = self.palette(color)
        scale = self.scale
        inverse = 1.0 / scale
        x0, y0, x1, y1 = self._pixel_bounds((cx - radius, cy - radius, cx + radius, cy + radius), 1.0)
        for py in range(y0, y1):
            for px in range(x0, x1):
                falloff = 1.0 - math.hypot((px + 0.5) * inverse - cx, (py + 0.5) * inverse - cy) / radius
                if falloff > 0.0:
                    self._blend((py * self.width + px) * 4, color, strength * falloff * falloff)

    def eyes(self, positions, size=3.4, color=INK, shine=True):
        for ex, ey in positions:
            self.flat(ellipse(ex, ey, size * 0.75, size), color)
            if shine:
                self.flat(circle(ex + size * 0.2, ey - size * 0.4, size * 0.3), (1.0, 1.0, 1.0))

    def add_grain(self, amount=0.05):
        """Subtle paper texture on everything drawn."""
        pixels = self.pixels
        noise = self.noise.sample
        for py in range(self.height):
            for px in range(self.width):
                index = (py * self.width + px) * 4
                if pixels[index + 3] <= 0.0:
                    continue
                factor = 1.0 + amount * (noise(px * 0.7 + 31.0, py * 0.7 + 17.0) * 2.0 - 1.0)
                for channel in range(3):
                    pixels[index + channel] = min(1.0, pixels[index + channel] * factor)

    def output_pixels(self):
        """RGBA floats at the output size (supersampled pictures are averaged down)."""
        factor = self.supersample
        if factor == 1:
            return self.pixels
        pixels = self.pixels
        out = [0.0] * (self.output_width * self.output_height * 4)
        samples = factor * factor
        for oy in range(self.output_height):
            for ox in range(self.output_width):
                red = green = blue = alpha = 0.0
                for sy in range(factor):
                    row = (oy * factor + sy) * self.width
                    for sx in range(factor):
                        index = (row + ox * factor + sx) * 4
                        weight = pixels[index + 3]
                        red += pixels[index] * weight
                        green += pixels[index + 1] * weight
                        blue += pixels[index + 2] * weight
                        alpha += weight
                out_index = (oy * self.output_width + ox) * 4
                if alpha > 0.0:
                    out[out_index] = red / alpha
                    out[out_index + 1] = green / alpha
                    out[out_index + 2] = blue / alpha
                    out[out_index + 3] = alpha / samples
        return out

    def save(self, path):
        rows = bytearray()
        pixels = self.output_pixels()
        for py in range(self.output_height):
            rows.append(0)
            for px in range(self.output_width):
                index = (py * self.output_width + px) * 4
                for channel in range(4):
                    rows.append(max(0, min(255, int(pixels[index + channel] * 255.0 + 0.5))))
        path.parent.mkdir(parents=True, exist_ok=True)

        def chunk(tag, data):
            return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        header = struct.pack(">IIBBBBB", self.output_width, self.output_height, 8, 6, 0, 0, 0)
        path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b""))
