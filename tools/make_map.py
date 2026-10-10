"""做地图: 读海岸线和领地表, 把不列颠群岛切成一块块领地, 存成游戏用的「领地图」。

用法 (在游戏文件夹里, 用 python.org 的 Python 3, 不用装别的东西):
    python3 tools/make_map.py 海岸线.shp

海岸线用 Natural Earth 的 ne_10m_land.shp (公共领域, https://www.naturalearthdata.com/,
下载 ne_10m_land.zip 解压就有)。下载的原文件不放进仓库, 放进仓库的是这个工具做出来的两个文件:
    data/generated/provinces.png  每个像素是哪块领地: 红 × 256 + 绿 = 领地编号 (从 1 开始, 0 是海)
    data/generated/map.json       图的大小、每块领地的中心和邻居、海岸线

领地的形状: 从每块领地的都城出发, 沿着陆地往外长 (不能跨海), 谁先到就归谁;
走每一步的「难度」带一点平滑的随机起伏, 边界就弯弯曲曲, 不会是直线。随机数种子固定, 每次做出来都一样。
"""
import heapq
import json
import math
import os
import random
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
WORLD = os.path.join(ROOT, "data", "world_867.json")
OUT_DIR = os.path.join(ROOT, "data", "generated")

BOX = (-11.0, 49.5, 2.2, 61.2)   # 只要这个经纬度范围里整个落进来的岛 (法国那一大块会被排除)
KM_PER_PX = 0.5                  # 一个像素 = 0.5 公里
MARGIN_KM = 60                   # 四周留一圈海
R = 6371.0                       # 地球半径 (公里)
LON0, LAT0 = -4.0, 55.0          # 投影的中心 (横轴墨卡托, 跟英国地图的画法一样, 形状不走样)
SEED = 867
MIN_ISLAND_KM2 = 2.0             # 比这小的岛不要


def project(lon, lat):
    """经纬度 -> 公里 (x 往东, y 往南)。"""
    phi = math.radians(lat)
    dl = math.radians(lon - LON0)
    b = math.cos(phi) * math.sin(dl)
    x = 0.5 * R * math.log((1 + b) / (1 - b))
    y = R * (math.atan2(math.tan(phi), math.cos(dl)) - math.radians(LAT0))
    return x, -y


def read_rings(path):
    """读 shapefile 里所有多边形的每一圈。"""
    with open(path, "rb") as f:
        data = f.read()
    pos = 100
    while pos < len(data):
        _, length = struct.unpack(">ii", data[pos:pos + 8])
        rec = data[pos + 8: pos + 8 + length * 2]
        pos += 8 + length * 2
        if struct.unpack("<i", rec[:4])[0] != 5:
            continue
        nparts, npoints = struct.unpack("<ii", rec[36:44])
        parts = list(struct.unpack("<%di" % nparts, rec[44:44 + 4 * nparts])) + [npoints]
        base = 44 + 4 * nparts
        pts = struct.unpack("<%dd" % (2 * npoints), rec[base: base + 16 * npoints])
        for a, b in zip(parts, parts[1:]):
            yield [(pts[2 * i], pts[2 * i + 1]) for i in range(a, b)]


def ring_area(r):
    s = 0.0
    for (x1, y1), (x2, y2) in zip(r, r[1:] + r[:1]):
        s += x1 * y2 - x2 * y1
    return abs(s) / 2


def simplify(points, tol):
    """道格拉斯-普克算法: 去掉几乎在一条直线上的点。"""
    if len(points) < 3:
        return points
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]
    while stack:
        a, b = stack.pop()
        (ax, ay), (bx, by) = points[a], points[b]
        dx, dy = bx - ax, by - ay
        length = math.hypot(dx, dy) or 1e-9
        best, best_i = -1.0, -1
        for i in range(a + 1, b):
            px, py = points[i]
            d = abs(dy * (px - ax) - dx * (py - ay)) / length
            if d > best:
                best, best_i = d, i
        if best > tol:
            keep[best_i] = True
            stack += [(a, best_i), (best_i, b)]
    return [p for p, k in zip(points, keep) if k]


def rasterize(rings, w, h):
    """把所有岛涂成陆地 (1 = 陆地)。看像素中心在不在圈里 (奇偶规则)。"""
    rows = [[] for _ in range(h)]
    for ring in rings:
        for (x1, y1), (x2, y2) in zip(ring, ring[1:] + ring[:1]):
            if y1 == y2:
                continue
            lo, hi = min(y1, y2), max(y1, y2)
            for r in range(max(0, math.ceil(lo - 0.5)), min(h, math.ceil(hi - 0.5))):
                yc = r + 0.5
                rows[r].append(x1 + (yc - y1) * (x2 - x1) / (y2 - y1))
    land = bytearray(w * h)
    for r, xs in enumerate(rows):
        xs.sort()
        for a, b in zip(xs[0::2], xs[1::2]):
            c0, c1 = max(0, math.ceil(a - 0.5)), min(w, math.ceil(b - 0.5))
            if c1 > c0:
                land[r * w + c0: r * w + c1] = b"\x01" * (c1 - c0)
    return land


def noise_field(w, h, rng):
    """平滑的随机起伏 (两层: 大起伏 + 小起伏), 0 到 1。"""
    def layer(step):
        gw, gh = w // step + 2, h // step + 2
        grid = [rng.random() for _ in range(gw * gh)]
        out = [0.0] * (w * h)
        for y in range(h):
            gy, fy = divmod(y / step, 1)
            gy = int(gy)
            fy = fy * fy * (3 - 2 * fy)
            for x in range(w):
                gx, fx = divmod(x / step, 1)
                gx = int(gx)
                fx = fx * fx * (3 - 2 * fx)
                i = gy * gw + gx
                top = grid[i] + (grid[i + 1] - grid[i]) * fx
                bottom = grid[i + gw] + (grid[i + gw + 1] - grid[i + gw]) * fx
                out[y * w + x] = top + (bottom - top) * fy
        return out
    big, small = layer(40), layer(9)
    return [0.65 * a + 0.35 * b for a, b in zip(big, small)]


def grow(land, w, h, seeds, noise):
    """从每块领地的都城沿陆地往外长, 谁先到归谁。返回每个像素的领地编号 (0 = 海或者没长到)。"""
    owner = [0] * (w * h)
    dist = [math.inf] * (w * h)
    heap = []
    for cid, (sx, sy) in seeds.items():
        i = sy * w + sx
        dist[i] = 0.0
        heap.append((0.0, i, cid))
    heapq.heapify(heap)
    while heap:
        d, i, cid = heapq.heappop(heap)
        if owner[i]:
            continue
        owner[i] = cid
        x, y = i % w, i // w
        for j in (i - 1 if x > 0 else -1, i + 1 if x < w - 1 else -1, i - w if y > 0 else -1, i + w if y < h - 1 else -1):
            if j >= 0 and land[j] and not owner[j]:
                nd = d + 1.0 + 2.2 * noise[j]
                if nd < dist[j]:
                    dist[j] = nd
                    heapq.heappush(heap, (nd, j, cid))
    return owner


def write_png(path, w, h, owner):
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            cid = owner[y * w + x]
            raw += bytes((cid >> 8, cid & 255, 0))
    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xffffffff)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def main(shp):
    with open(WORLD, encoding="utf-8") as f:
        world = json.load(f)
    counties = world["counties"]

    rings_km = []
    for ring in read_rings(shp):
        if all(BOX[0] <= x <= BOX[2] and BOX[1] <= y <= BOX[3] for x, y in ring):
            pts = [project(x, y) for x, y in ring]
            if ring_area(pts) >= MIN_ISLAND_KM2:
                rings_km.append(pts)
    xs = [x for r in rings_km for x, _ in r]
    ys = [y for r in rings_km for _, y in r]
    x0, y0 = min(xs) - MARGIN_KM, min(ys) - MARGIN_KM
    w = math.ceil((max(xs) + MARGIN_KM - x0) / KM_PER_PX)
    h = math.ceil((max(ys) + MARGIN_KM - y0) / KM_PER_PX)
    to_px = lambda p: ((p[0] - x0) / KM_PER_PX, (p[1] - y0) / KM_PER_PX)
    rings_px = [[to_px(p) for p in r] for r in rings_km]
    print("图 %d × %d 像素, %d 个岛" % (w, h, len(rings_px)))

    land = rasterize(rings_px, w, h)
    print("陆地 %d 像素 (%.0f 平方公里)" % (sum(land), sum(land) * KM_PER_PX ** 2))

    # 都城的位置; 落在海里的话 (海岸线不够细) 挪到最近的陆地上
    seeds = {}
    seats = {}
    for n, c in enumerate(counties, start=1):
        fx, fy = to_px(project(c["lon"], c["lat"]))
        best = None
        for rad in range(0, 40):
            for dy in range(-rad, rad + 1):
                for dx in range(-rad, rad + 1):
                    x, y = int(fx) + dx, int(fy) + dy
                    if 0 <= x < w and 0 <= y < h and land[y * w + x] and (x, y) not in seeds.values():
                        d = math.hypot(x + 0.5 - fx, y + 0.5 - fy)
                        if best is None or d < best[0]:
                            best = (d, x, y)
            if best:
                break
        if best is None:
            sys.exit("%s 的都城附近找不到陆地" % c["name"])
        if best[0] > 4:
            print("  %s 的都城在海里, 挪了 %.1f 公里" % (c["name"], best[0] * KM_PER_PX))
        seeds[n] = (best[1], best[2])
        seats[n] = (best[1] + 0.5, best[2] + 0.5)

    rng = random.Random(SEED)
    owner = grow(land, w, h, seeds, noise_field(w, h, rng))

    # 没有都城的小岛: 归最近的都城
    lost = [i for i in range(w * h) if land[i] and not owner[i]]
    for i in lost:
        x, y = i % w, i // w
        owner[i] = min(seeds, key=lambda c: (seeds[c][0] - x) ** 2 + (seeds[c][1] - y) ** 2)
    print("没有都城的小岛 %d 像素, 归了最近的领地" % len(lost))

    # 每块领地: 中心、大小、范围、邻居、靠不靠海
    info = {n: {"px": 0, "sx": 0, "sy": 0, "min": [w, h], "max": [0, 0], "nb": set(), "coast": False} for n in seeds}
    for i, cid in enumerate(owner):
        if not cid:
            continue
        x, y = i % w, i // w
        a = info[cid]
        a["px"] += 1
        a["sx"] += x
        a["sy"] += y
        a["min"] = [min(a["min"][0], x), min(a["min"][1], y)]
        a["max"] = [max(a["max"][0], x), max(a["max"][1], y)]
        for j in ((i + 1) if x < w - 1 else -1, (i + w) if y < h - 1 else -1, (i - 1) if x > 0 else -1, (i - w) if y > 0 else -1):
            if j < 0:
                continue
            other = owner[j]
            if other == 0:
                a["coast"] = True
            elif other != cid:
                a["nb"].add(other)

    out_counties = []
    for n, c in enumerate(counties, start=1):
        a = info[n]
        if a["px"] == 0:
            sys.exit("%s 一个像素都没有" % c["name"])
        out_counties.append({
            "id": c["id"],
            "index": n,
            "seat": [round(seats[n][0], 1), round(seats[n][1], 1)],
            "center": [round(a["sx"] / a["px"] + 0.5, 1), round(a["sy"] / a["px"] + 0.5, 1)],
            "area_km2": round(a["px"] * KM_PER_PX ** 2),
            "rect": [a["min"][0], a["min"][1], a["max"][0] + 1 - a["min"][0], a["max"][1] + 1 - a["min"][1]],
            "neighbors": sorted(counties[m - 1]["id"] for m in a["nb"]),
            "coastal": a["coast"],
        })

    coast = []
    for r in rings_px:
        s = simplify(r + [r[0]], 0.35)
        coast.append([round(v, 1) for p in s for v in p])

    os.makedirs(OUT_DIR, exist_ok=True)
    write_png(os.path.join(OUT_DIR, "provinces.png"), w, h, owner)
    meta = {
        "说明": "tools/make_map.py 做出来的, 别手改。坐标都是领地图上的像素。",
        "width": w, "height": h, "km_per_px": KM_PER_PX,
        "projection": {"type": "横轴墨卡托", "lon0": LON0, "lat0": LAT0, "x0_km": round(x0, 3), "y0_km": round(y0, 3)},
        "counties": out_counties,
        "coastline": coast,
    }
    with open(os.path.join(OUT_DIR, "map.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, separators=(",", ":"))
    sizes = sorted(c["area_km2"] for c in out_counties)
    print("做好了: %d 块领地, 最小 %d、中间 %d、最大 %d 平方公里" % (len(out_counties), sizes[0], sizes[len(sizes) // 2], sizes[-1]))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
