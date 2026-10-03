shader_type canvas_item;

uniform vec3 sky_top    : source_color = vec3(0.04, 0.02, 0.10);
uniform vec3 sky_mid    : source_color = vec3(0.12, 0.04, 0.22);
uniform vec3 sky_bottom : source_color = vec3(0.26, 0.05, 0.28);
uniform vec3 grid_color : source_color = vec3(0.85, 0.15, 0.80);
uniform vec3 sun_color  : source_color = vec3(1.00, 0.35, 0.65);
uniform float speed = 0.4;
uniform float audio_pulse : hint_range(0.0, 1.0) = 0.2;
uniform float streak_energy : hint_range(0.0, 1.0) = 0.3;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;

	// Sky gradient
	vec3 col;
	if (uv.y < 0.5) {
		col = mix(sky_top, sky_mid, uv.y / 0.5);
	} else {
		col = mix(sky_mid, sky_bottom, (uv.y - 0.5) / 0.5);
	}

	// Drifting nebula clouds
	float haze = sin(uv.x * 5.0 + t * 1.2) * 0.5 + 0.5;
	haze *= sin(uv.y * 3.5 - t * 0.8) * 0.5 + 0.5;
	col += vec3(0.12, 0.02, 0.18) * haze * (0.6 + audio_pulse * 0.4);

	// Glowing sun disc
	float pulse_scale = 1.0 + audio_pulse * 0.12;
	vec2 sun_uv = (uv - vec2(0.5, 0.22)) / pulse_scale;
	sun_uv.x *= 1.2;
	float sun_d = length(sun_uv);
	float sun = smoothstep(0.24, 0.0, sun_d);
	float bands = step(0.48, fract(uv.y * 28.0));
	float band_mask = smoothstep(0.22, 0.28, uv.y);
	sun *= mix(1.0, bands, band_mask);
	col += sun_color * sun * (0.4 + audio_pulse * 0.45);
	col += sun_color * smoothstep(0.46 * pulse_scale, 0.0, sun_d) * 0.18;

	// Pinpoint twinkling stars (circular distance check inside dense grid)
	if (uv.y < 0.60) {
		vec2 star_uv = uv * vec2(200.0, 120.0);
		vec2 cell_id = floor(star_uv);
		vec2 cell_fract = fract(star_uv) - 0.5;
		float rnd = hash(cell_id);
		if (rnd > 0.965) {
			float d = length(cell_fract);
			float star_alpha = smoothstep(0.28, 0.0, d);
			float twinkle = 0.5 + 0.5 * sin(t * 3.5 + rnd * 60.0);
			col += vec3(0.9, 0.95, 1.0) * star_alpha * twinkle * 0.85;
		}
	}

	// Perspective neon grid floor
	if (uv.y > 0.62) {
		float fy = (uv.y - 0.62) / 0.38;
		float persp = 1.0 / (1.0 - fy * 0.93 + 0.02);
		float rows = fract(persp * 1.5 - t * 1.4);
		float hline = smoothstep(0.0, 0.06, rows) * smoothstep(0.14, 0.06, rows);
		float cx = (uv.x - 0.5) * persp;
		float cols = abs(fract(cx * 8.0 + 0.5) - 0.5);
		float vline = smoothstep(0.06, 0.0, cols);
		float grid = max(hline, vline);
		float fade = fy;
		float grid_lum = 0.85 + audio_pulse * 0.6;
		col += grid_color * grid * fade * grid_lum;
		col += grid_color * hline * fade * 0.35;
		col += grid_color * smoothstep(0.03, 0.0, abs(uv.y - 0.625)) * 0.4;
	}

	// Vignette
	float vig = smoothstep(1.2, 0.3, length(uv - 0.5));
	col *= mix(0.78, 1.0, vig);

	COLOR = vec4(col, 1.0);
}
