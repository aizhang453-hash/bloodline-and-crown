// 地图着色器: 领地图 (provinces) 每个像素是领地编号, 按 lookup 表上色。
// lookup 表第 0 行: 编号 -> 颜色; 第 1 行: 编号 -> 属于哪一组 (国家 / 公国 / 王国), 组和组之间画粗线;
// 第 2 行: 编号 -> 这块地的主人 (第 5 块: 同一个国家里不同主人的地之间画一条细一点的线, 学三代分出封臣)。
// 第 3 行: 编号 -> 占领它的一方的颜色 (第 6 块: 被占领的地画斜条纹, 跟三代一样; 没被占领 alpha 是 0)。
shader_type canvas_item;

uniform sampler2D provinces : filter_nearest;
uniform sampler2D lookup : filter_nearest;
uniform vec4 sea_color : source_color = vec4(0.13, 0.22, 0.30, 1.0);
uniform int hovered = 0;
uniform int selected = 0;
uniform float time_s = 0.0;

int id_at(ivec2 p, ivec2 size) {
	p = clamp(p, ivec2(0), size - 1);
	vec4 c = texelFetch(provinces, p, 0);
	return int(round(c.r * 255.0)) * 256 + int(round(c.g * 255.0));
}

int group_of(int id) {
	vec4 c = texelFetch(lookup, ivec2(id, 1), 0);
	return int(round(c.r * 255.0)) * 256 + int(round(c.g * 255.0));
}

int lord_of(int id) {
	vec4 c = texelFetch(lookup, ivec2(id, 2), 0);
	return int(round(c.r * 255.0)) * 256 + int(round(c.g * 255.0));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float paper(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i), b = hash(i + vec2(1, 0)), c = hash(i + vec2(0, 1)), d = hash(i + vec2(1, 1));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	ivec2 size = textureSize(provinces, 0);
	vec2 tp = UV * vec2(size);
	int id = id_at(ivec2(floor(tp)), size);
	// 一个屏幕像素是几个领地图像素: 边线按屏幕像素算, 放大缩小都一样细
	float s = max(fwidth(tp.x), 0.35);
	float grain = paper(tp / 24.0) * 0.6 + paper(tp / 6.0) * 0.4;
	if (id == 0) {
		COLOR = vec4(sea_color.rgb * (0.94 + 0.1 * grain), 1.0);
	} else {
		vec3 col = texelFetch(lookup, ivec2(id, 0), 0).rgb;
		vec4 occ = texelFetch(lookup, ivec2(id, 3), 0);
		if (occ.a > 0.5) {
			float stripe = step(0.5, fract((tp.x + tp.y) / (s * 16.0)));
			col = mix(col, occ.rgb, stripe * 0.85);
		}
		col *= 0.9 + 0.14 * grain;
		int g = group_of(id);
		int lord = lord_of(id);
		bool county_edge = false;
		bool lord_edge = false;
		bool group_edge = false;
		bool coast = false;
		for (int k = 0; k < 8; k++) {
			float a = float(k) * 0.785398;
			vec2 o = vec2(cos(a), sin(a));
			int n1 = id_at(ivec2(floor(tp + o * s * 1.0)), size);
			int n2 = id_at(ivec2(floor(tp + o * s * 2.2)), size);
			if (n1 == 0 || n2 == 0) { coast = true; }
			if (n1 != id && n1 != 0) {
				county_edge = true;
				if (group_of(n1) != g) { group_edge = true; } else if (lord_of(n1) != lord) { lord_edge = true; }
			}
			if (n2 != id && n2 != 0 && group_of(n2) != g) { group_edge = true; }
		}
		if (group_edge) {
			col *= 0.32;
		} else if (lord_edge) {
			col *= 0.5;
		} else if (county_edge) {
			col = mix(col, col * 0.55, 0.6);
		}
		if (coast) {
			col *= 0.85;
		}
		if (id == hovered) {
			col = mix(col, vec3(1.0, 0.97, 0.85), 0.18);
		}
		if (id == selected) {
			col = mix(col, vec3(1.0, 0.95, 0.75), 0.30 + 0.08 * sin(time_s * 4.0));
		}
		COLOR = vec4(col, 1.0);
	}
}
