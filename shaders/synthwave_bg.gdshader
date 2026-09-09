shader_type canvas_item;

// Animated synthwave background: deep gradient sky, drifting nebula haze,
// twinkling stars, and a perspective neon grid floor at the bottom.
// Tuned for a portrait 540x960 board game — dark enough that neon squares pop.

uniform vec3 sky_top    : source_color = vec3(0.05, 0.03, 0.12);
uniform vec3 sky_mid    : source_color = vec3(0.16, 0.05, 0.28);
uniform vec3 sky_bottom : source_color = vec3(0.35, 0.06, 0.35);
uniform vec3 grid_color : source_color = vec3(0.90, 0.20, 0.85);
uniform vec3 sun_color  : source_color = vec3(1.00, 0.45, 0.70);
uniform float speed = 0.35;
uniform float audio_pulse : hint_range(0.0, 1.0) = 0.0;
uniform float streak_energy : hint_range(0.0, 1.0) = 0.0;

// cheap hash for stars
float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;

	// --- vertical sky gradient ---
	vec3 col;
	if (uv.y < 0.5) {
		col = mix(sky_top, sky_mid, uv.y / 0.5);
	} else {
		col = mix(sky_mid, sky_bottom, (uv.y - 0.5) / 0.5);
	}

	// --- slow drifting nebula haze (reactive to audio & streak) ---
	float haze = sin(uv.x * 6.0 + t * 1.3) * 0.5 + 0.5;
	haze *= sin(uv.y * 4.0 - t * 0.9) * 0.5 + 0.5;
	col += vec3(0.10, 0.02, 0.14) * haze * (0.5 + audio_pulse * 0.35 + streak_energy * 0.4);

	// --- glowing sun disc (expands and pulses to beats) ---
	float pulse_scale = 1.0 + audio_pulse * 0.16 + streak_energy * 0.08;
	vec2 sun_uv = (uv - vec2(0.5, 0.18)) / pulse_scale;
	sun_uv.x *= 0.9;
	float sun_d = length(sun_uv);
	float sun = smoothstep(0.22, 0.0, sun_d);
	// horizontal cutout bands across the lower half of the sun
	float bands = step(0.5, fract(uv.y * 30.0));
	float band_mask = smoothstep(0.18, 0.24, uv.y); // only cut below its middle
	sun *= mix(1.0, bands, band_mask);
	col += sun_color * sun * (0.35 + audio_pulse * 0.45);
	// soft outer sun glow
	col += sun_color * smoothstep(0.42 * pulse_scale, 0.0, sun_d) * (0.08 + audio_pulse * 0.22 + streak_energy * 0.15);

	// --- twinkling stars in the upper sky (accelerate with streak) ---
	float star_region = smoothstep(0.55, 0.15, uv.y);
	vec2 grid_id = floor(uv * vec2(60.0, 90.0));
	float star = hash(grid_id);
	star = step(0.985, star);
	float twinkle = 0.6 + 0.4 * sin(t * (3.0 + streak_energy * 5.0) + hash(grid_id) * 30.0);
	col += vec3(0.9, 0.85, 1.0) * star * twinkle * star_region * (0.8 + streak_energy * 0.6);

	// --- perspective neon grid on the floor (bottom of screen) ---
	if (uv.y > 0.62) {
		float fy = (uv.y - 0.62) / 0.38;           // 0 at horizon -> 1 at bottom
		float persp = 1.0 / (1.0 - fy * 0.92 + 0.02); // rows bunch near horizon
		// horizontal lines scrolling toward the viewer
		float rows = fract(persp * 1.4 - t * 1.2);
		float hline = smoothstep(0.0, 0.06, rows) * smoothstep(0.14, 0.06, rows);
		// vertical lines fanning out with perspective
		float cx = (uv.x - 0.5) * persp;
		float cols = abs(fract(cx * 6.0 + 0.5) - 0.5);
		float vline = smoothstep(0.06, 0.0, cols);
		float grid = max(hline, vline);
		float fade = fy;                            // brighter toward the bottom
		float grid_lum = 0.8 + audio_pulse * 0.65 + streak_energy * 0.35;
		col += grid_color * grid * fade * grid_lum;
		col += grid_color * hline * fade * (0.3 + audio_pulse * 0.45);     // extra glow on rows
		// subtle horizon shockwave bloom
		col += grid_color * smoothstep(0.035, 0.0, abs(uv.y - 0.625)) * audio_pulse * 0.5;
	}

	// --- vignette ---
	float vig = smoothstep(1.15, 0.35, length(uv - 0.5));
	col *= mix(0.75, 1.0, vig);

	COLOR = vec4(col, 1.0);
}
