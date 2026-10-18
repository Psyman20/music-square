shader_type canvas_item;

// Modern Retro-Futuristic Multi-Theme Background Shader
// Each theme selects a distinct `bg_style` (0..4) with its own sky centerpiece,
// horizon silhouette, and floor geometry, while keeping the center dark enough
// that the neon game board squares pop with crisp contrast.
//
// bg_style:
//   0 = SYNTHWAVE (Outrun 1984): Striped sunset sun, wireframe mountain peaks, laser perspective grid
//   1 = OCEAN (Miami Vicewave): Giant crescent moon + twin planet, liquid wave grid & shimmering water reflections
//   2 = EMBER (Solar Overdrive): Blazing annular solar eclipse, cyber-city skyline, scrolling hex/diamond reactor floor
//   3 = FOREST (Cyber Arcadia): Sweeping aurora borealis, wireframe holo-prism, vector hills & circuit data-pulse grid
//   4 = MIDNIGHT (Galaxy Odyssey): Tilted ringed Saturn planet, shooting stars, nebula & cosmic warp-lane highway

uniform vec3 sky_top       : source_color = vec3(0.05, 0.02, 0.14);
uniform vec3 sky_mid       : source_color = vec3(0.16, 0.04, 0.28);
uniform vec3 sky_bottom    : source_color = vec3(0.34, 0.06, 0.32);
uniform vec3 grid_color    : source_color = vec3(0.95, 0.20, 0.80);
uniform vec3 sun_color     : source_color = vec3(1.00, 0.48, 0.68);
uniform vec3 haze_color    : source_color = vec3(0.18, 0.04, 0.24);
uniform vec3 horizon_color : source_color = vec3(0.20, 0.90, 1.00);
uniform int bg_style       : hint_range(0, 4) = 0;
uniform float speed = 0.35;
uniform float audio_pulse  : hint_range(0.0, 1.0) = 0.0;
uniform float streak_energy : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float sd_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / max(dot(ba, ba), 0.0001), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;
	float horizon_y = 0.62;

	// --- 1. Vertical Sky & Floor Base Gradient ---
	vec3 col;
	if (uv.y < 0.35) {
		col = mix(sky_top, sky_mid, uv.y / 0.35);
	} else if (uv.y < horizon_y) {
		col = mix(sky_mid, sky_bottom, (uv.y - 0.35) / (horizon_y - 0.35));
	} else {
		float floor_t = (uv.y - horizon_y) / (1.0 - horizon_y);
		col = mix(sky_bottom * 0.55, sky_top * 0.75, clamp(floor_t * 1.15, 0.0, 1.0));
	}

	// --- 2. Theme-Tinted Drifting Atmospheric Haze ---
	float haze = sin(uv.x * 5.5 + t * 1.2) * 0.5 + 0.5;
	haze *= sin(uv.y * 4.2 - t * 0.85) * 0.5 + 0.5;
	col += haze_color * haze * (0.45 + audio_pulse * 0.35 + streak_energy * 0.35);

	// --- 3. Multi-Layer Starfield (Upper Sky) ---
	float star_region = smoothstep(horizon_y - 0.04, 0.10, uv.y);
	vec2 star_grid1 = floor(uv * vec2(58.0, 92.0));
	float s1 = step(0.984, hash(star_grid1));
	float tw1 = 0.55 + 0.45 * sin(t * (3.2 + streak_energy * 5.0) + hash(star_grid1) * 40.0);
	col += mix(vec3(1.0), horizon_color, 0.35) * s1 * tw1 * star_region * (0.85 + streak_energy * 0.55);

	// Brighter 4-point retro sparkle stars
	vec2 star_uv2 = uv * vec2(26.0, 44.0);
	vec2 star_grid2 = floor(star_uv2);
	vec2 star_f2 = fract(star_uv2) - 0.5;
	float s2_seed = hash(star_grid2 + 19.7);
	if (s2_seed > 0.968 && uv.y < horizon_y - 0.08) {
		float pulse_star = 0.6 + 0.4 * sin(t * 4.5 + s2_seed * 60.0);
		float cross_flare = exp(-abs(star_f2.x) * 26.0) * exp(-abs(star_f2.y) * 9.0)
		                  + exp(-abs(star_f2.y) * 26.0) * exp(-abs(star_f2.x) * 9.0);
		col += mix(sun_color, vec3(1.0), 0.6) * cross_flare * pulse_star * star_region * 0.85;
	}

	float pulse_scale = 1.0 + audio_pulse * 0.14 + streak_energy * 0.07;

	// =========================================================================
	// STYLE 0: SYNTHWAVE ("OUTRUN 1984")
	// Classic striped gradient sun + wireframe twin mountain ranges + laser grid
	// =========================================================================
	if (bg_style == 0) {
		// Striped Outrun Sunset Sun
		vec2 sun_uv = (uv - vec2(0.5, 0.19)) / pulse_scale;
		sun_uv.x *= 0.88;
		float sun_d = length(sun_uv);
		float sun_disc = smoothstep(0.21, 0.195, sun_d);
		// Progressive retro scanline cutouts in lower 65% of sun
		float sun_local_y = clamp((sun_uv.y + 0.21) / 0.42, 0.0, 1.0);
		float stripe_freq = 28.0;
		float stripe_wave = fract(uv.y * stripe_freq - t * 0.35);
		float cut_threshold = smoothstep(0.32, 1.05, sun_local_y) * 0.68;
		float stripes = step(cut_threshold, stripe_wave);
		sun_disc *= stripes;
		vec3 sun_grad = mix(vec3(1.0, 0.92, 0.35), sun_color, clamp(sun_local_y * 1.15, 0.0, 1.0));
		col += sun_grad * sun_disc * (0.52 + audio_pulse * 0.42);
		col += sun_color * smoothstep(0.42 * pulse_scale, 0.0, sun_d) * (0.14 + audio_pulse * 0.22 + streak_energy * 0.15);

		// Twin Wireframe Mountain Ranges above horizon
		if (uv.y > 0.46 && uv.y <= horizon_y) {
			float mx = uv.x * 5.5;
			float side_boost = 0.45 + 0.65 * abs(uv.x - 0.5) * 2.0; // taller on sides, valley in center
			float m_far_h = (noise(vec2(mx * 1.1 + 2.0, 1.0)) * 0.65 + noise(vec2(mx * 2.4, 3.0)) * 0.35) * 0.11 * side_boost;
			float m_near_h = (noise(vec2(mx * 1.5 + 7.4, 2.0)) * 0.70 + noise(vec2(mx * 3.3, 5.0)) * 0.30) * 0.085 * side_boost;
			float y_far = horizon_y - m_far_h;
			float y_near = horizon_y - m_near_h;

			// Far mountain silhouette + glowing cyan ridgeline
			if (uv.y > y_far) {
				col = mix(col, sky_top * 0.45, 0.82);
				float w_mesh = abs(fract(uv.x * 24.0 + (uv.y - y_far) * 8.0) - 0.5);
				col += horizon_color * smoothstep(0.04, 0.0, w_mesh) * 0.18;
			}
			col += horizon_color * smoothstep(0.006, 0.0, abs(uv.y - y_far)) * (0.75 + audio_pulse * 0.45);

			// Near mountain silhouette + glowing magenta ridgeline
			if (uv.y > y_near) {
				col = mix(col, sky_top * 0.25, 0.92);
				float w_mesh2 = abs(fract(uv.x * 18.0 - (uv.y - y_near) * 10.0) - 0.5);
				col += grid_color * smoothstep(0.045, 0.0, w_mesh2) * 0.26;
			}
			col += sun_color * smoothstep(0.006, 0.0, abs(uv.y - y_near)) * (0.85 + audio_pulse * 0.45);
		}

		// Perspective Outrun Laser Grid Floor
		if (uv.y > horizon_y) {
			float fy = (uv.y - horizon_y) / (1.0 - horizon_y);
			float persp = 1.0 / (1.0 - fy * 0.92 + 0.02);
			float rows = fract(persp * 1.45 - t * 1.35);
			float hline = smoothstep(0.0, 0.055, rows) * smoothstep(0.13, 0.055, rows);
			float cx = (uv.x - 0.5) * persp;
			float cols = abs(fract(cx * 6.0 + 0.5) - 0.5);
			float vline = smoothstep(0.055, 0.0, cols);
			float grid = max(hline, vline);
			float grid_lum = 0.85 + audio_pulse * 0.65 + streak_energy * 0.35;
			vec3 g_col = mix(horizon_color, grid_color, clamp(fy * 1.3, 0.0, 1.0));
			col += g_col * grid * fy * grid_lum;
			col += grid_color * hline * fy * (0.32 + audio_pulse * 0.45);
		}
	}

	// =========================================================================
	// STYLE 1: OCEAN ("MIAMI VICEWAVE")
	// Crescent moon + companion planet, synth clouds & liquid neon ocean ripples
	// =========================================================================
	else if (bg_style == 1) {
		// Giant glowing Crescent Moon + Ringed Companion Moon
		vec2 moon_uv = (uv - vec2(0.5, 0.18)) / pulse_scale;
		moon_uv.x *= 0.9;
		float d_main = length(moon_uv);
		float d_shadow = length(moon_uv - vec2(0.055, -0.032));
		float crescent = smoothstep(0.185, 0.172, d_main) * smoothstep(0.148, 0.165, d_shadow);
		float full_disc_faint = smoothstep(0.185, 0.172, d_main) * 0.12;
		col += mix(sun_color, vec3(0.88, 0.98, 1.0), 0.45) * (crescent + full_disc_faint) * (0.68 + audio_pulse * 0.4);
		col += sun_color * smoothstep(0.38 * pulse_scale, 0.0, d_main) * (0.18 + audio_pulse * 0.22);

		// Small distant coral-pink companion planet at upper right
		vec2 p2_uv = uv - vec2(0.77, 0.11);
		p2_uv.x *= 0.9;
		float p2_d = length(p2_uv);
		float p2_disc = smoothstep(0.042, 0.036, p2_d);
		col += horizon_color * p2_disc * 0.65;
		col += horizon_color * smoothstep(0.09, 0.0, p2_d) * 0.18;

		// Soft drifting retro wave-clouds above horizon
		if (uv.y > 0.36 && uv.y < horizon_y) {
			float cloud_y = (uv.y - 0.36) / (horizon_y - 0.36);
			float cloud_w = sin(uv.x * 10.0 + t * 0.7 + cloud_y * 4.0) * 0.5 + 0.5;
			float cloud_band = smoothstep(0.45, 0.85, cloud_w) * smoothstep(0.0, 0.8, cloud_y);
			col += mix(sun_color, horizon_color, 0.4) * cloud_band * 0.14;
		}

		// Liquid Neon Ocean Floor with Wave Ripples & Moonlight Reflection Column
		if (uv.y > horizon_y) {
			float fy = (uv.y - horizon_y) / (1.0 - horizon_y);
			float persp = 1.0 / (1.0 - fy * 0.90 + 0.03);

			// Sine-warped liquid wave rows
			float wave_shift = sin(uv.x * 16.0 + t * 2.2 + persp * 0.8) * 0.08 * (1.0 - fy * 0.5);
			float rows = fract(persp * 1.8 - t * 1.1 + wave_shift);
			float wave_crest = smoothstep(0.0, 0.07, rows) * smoothstep(0.22, 0.07, rows);

			// Warped perspective water lanes
			float cx = (uv.x - 0.5 + sin(persp * 1.5 - t * 1.8) * 0.018) * persp;
			float cols = abs(fract(cx * 5.0 + 0.5) - 0.5);
			float v_ripple = smoothstep(0.055, 0.0, cols);

			vec3 water_col = mix(grid_color, sun_color, wave_crest * 0.5);
			col += water_col * max(wave_crest * 1.15, v_ripple * 0.75) * fy * (0.85 + audio_pulse * 0.6);

			// Shimmering center moonlight/coral reflection pillar on the water
			float refl_w = (0.06 + fy * 0.18) * (1.0 + 0.25 * sin(persp * 6.0 - t * 3.5));
			float refl_x = abs(uv.x - 0.5 + sin(persp * 4.5 - t * 2.6) * 0.025);
			float refl_mask = smoothstep(refl_w, 0.0, refl_x);
			float refl_stripes = step(0.38, fract(persp * 4.2 - t * 2.0));
			col += mix(sun_color, horizon_color, fy * 0.65) * refl_mask * refl_stripes * (0.42 + audio_pulse * 0.38);
		}
	}

	// =========================================================================
	// STYLE 2: EMBER ("SOLAR OVERDRIVE")
	// Blazing annular solar eclipse, brutalist cyber-city skyline & hex reactor floor
	// =========================================================================
	else if (bg_style == 2) {
		// Annular Solar Eclipse with Rotating Plasma Corona
		vec2 ec_uv = (uv - vec2(0.5, 0.18)) / pulse_scale;
		ec_uv.x *= 0.9;
		float ec_d = length(ec_uv);
		float angle = atan(ec_uv.y, ec_uv.x);
		float rays = sin(angle * 8.0 + t * 1.6) * 0.5 + 0.5;
		rays += sin(angle * 13.0 - t * 2.3) * 0.35;

		// Bright fiery ring around a pitch-dark eclipse void
		float ring = smoothstep(0.24, 0.165, ec_d) * smoothstep(0.125, 0.155, ec_d);
		float outer_corona = smoothstep(0.42 + rays * 0.04, 0.14, ec_d) * smoothstep(0.11, 0.155, ec_d);
		float void_core = smoothstep(0.15, 0.13, ec_d);

		col += sun_color * outer_corona * (0.38 + audio_pulse * 0.42 + streak_energy * 0.25);
		col += vec3(1.0, 0.88, 0.45) * ring * (0.85 + audio_pulse * 0.55);
		// Darken the interior of the eclipse so the fiery ring pops dramatically
		col = mix(col, sky_top * 0.15, void_core * 0.92);

		// Brutalist Cyber-City / Reactor Monolith Skyline on Horizon
		if (uv.y > 0.47 && uv.y <= horizon_y) {
			float col_id = floor(uv.x * 28.0);
			float b_seed = hash(vec2(col_id, 4.2));
			// Keep center slightly lower so board & sun have breathing room
			float center_dip = mix(0.45, 1.0, clamp(abs(uv.x - 0.5) * 2.4, 0.0, 1.0));
			float b_height = (0.025 + b_seed * 0.105) * center_dip;
			float b_top = horizon_y - b_height;
			if (uv.y > b_top) {
				col = sky_top * 0.22;
				// Tiny glowing amber/crimson skyscraper windows
				vec2 win_uv = fract(vec2(uv.x * 28.0, (uv.y - b_top) * 55.0));
				float win_mask = step(0.25, win_uv.x) * step(win_uv.x, 0.75) * step(0.3, win_uv.y) * step(win_uv.y, 0.75);
				float win_lit = step(0.45, hash(vec2(col_id, floor((uv.y - b_top) * 55.0))));
				col += mix(grid_color, sun_color, 0.5) * win_mask * win_lit * (0.45 + audio_pulse * 0.35);
			}
			// Glowing roof edge
			col += sun_color * smoothstep(0.004, 0.0, abs(uv.y - b_top)) * 0.7;
		}

		// Scrolling Diagonal / Hexagonal Plasma Grid Floor
		if (uv.y > horizon_y) {
			float fy = (uv.y - horizon_y) / (1.0 - horizon_y);
			float persp = 1.0 / (1.0 - fy * 0.91 + 0.025);
			float gx = (uv.x - 0.5) * persp * 5.5;
			float gy = persp * 1.5 - t * 1.45;

			// Diamond / Tri-grid plasma lattice
			float d1 = abs(fract((gx + gy) * 0.5) - 0.5);
			float d2 = abs(fract((gx - gy) * 0.5) - 0.5);
			float d3 = abs(fract(gy) - 0.5);
			float lattice = max(max(smoothstep(0.06, 0.0, d1), smoothstep(0.06, 0.0, d2)), smoothstep(0.05, 0.0, d3) * 0.8);

			vec3 lava_col = mix(grid_color, sun_color, smoothstep(0.2, 0.9, fy));
			col += lava_col * lattice * fy * (0.9 + audio_pulse * 0.7 + streak_energy * 0.4);
			// Glowing core nodes at intersections
			float node_glow = smoothstep(0.12, 0.0, d1) * smoothstep(0.12, 0.0, d2);
			col += vec3(1.0, 0.9, 0.5) * node_glow * fy * (0.6 + audio_pulse * 0.6);
		}
	}

	// =========================================================================
	// STYLE 3: FOREST ("CYBER ARCADIA")
	// Sweeping Aurora Borealis, 3D Wireframe Holo-Prism & Circuit Data-Pulse Grid
	// =========================================================================
	else if (bg_style == 3) {
		// Sweeping Neon Aurora Borealis Ribbons in Upper Sky
		if (uv.y < horizon_y - 0.02) {
			float ax = uv.x * 4.5;
			float aurora_y1 = 0.16 + 0.045 * sin(ax + t * 0.9) + 0.02 * cos(ax * 2.3 - t * 1.3);
			float aurora_y2 = 0.25 + 0.05 * cos(ax * 1.3 - t * 0.75) + 0.025 * sin(ax * 2.8 + t * 1.1);
			float curtain1 = smoothstep(0.11, 0.0, abs(uv.y - aurora_y1)) * (0.5 + 0.5 * sin(uv.x * 22.0 + t * 2.0));
			float curtain2 = smoothstep(0.10, 0.0, abs(uv.y - aurora_y2)) * (0.5 + 0.5 * cos(uv.x * 18.0 - t * 1.7));
			col += sun_color * curtain1 * (0.38 + audio_pulse * 0.32);
			col += horizon_color * curtain2 * (0.34 + streak_energy * 0.3);
		}

		// Floating 3D-Style Wireframe Holo-Diamond / Octahedron in Sky
		vec2 p_uv = (uv - vec2(0.5, 0.185)) / pulse_scale;
		p_uv.x *= 0.9;
		float sway = sin(t * 1.4) * 0.045;
		vec2 v_top   = vec2(0.0, -0.155);
		vec2 v_bot   = vec2(0.0,  0.155);
		vec2 v_left  = vec2(-0.145, 0.01);
		vec2 v_right = vec2( 0.145, 0.01);
		vec2 v_mid   = vec2(sway, 0.025);

		// Diamond interior hologram fill
		float d_manhattan = abs(p_uv.x) / 0.145 + abs(p_uv.y) / 0.155;
		if (d_manhattan < 1.0) {
			float holo_scan = step(0.45, fract(uv.y * 55.0 - t * 2.0));
			col += mix(grid_color, sun_color, 0.5) * (1.0 - d_manhattan * 0.6) * holo_scan * (0.28 + audio_pulse * 0.35);
		}

		// Crisp glowing vector edges of the octahedron
		float e_dist = min(min(sd_segment(p_uv, v_top, v_left), sd_segment(p_uv, v_top, v_right)),
		                   min(sd_segment(p_uv, v_bot, v_left), sd_segment(p_uv, v_bot, v_right)));
		e_dist = min(e_dist, min(sd_segment(p_uv, v_top, v_mid), sd_segment(p_uv, v_bot, v_mid)));
		e_dist = min(e_dist, min(sd_segment(p_uv, v_left, v_mid), sd_segment(p_uv, v_right, v_mid)));
		float wire = smoothstep(0.007, 0.001, e_dist);
		float wire_glow = smoothstep(0.032, 0.0, e_dist);
		col += sun_color * wire_glow * (0.45 + audio_pulse * 0.4);
		col += vec3(0.9, 1.0, 0.95) * wire * (0.9 + audio_pulse * 0.4);

		// Stepped Low-Poly Vector Hills on Horizon
		if (uv.y > 0.52 && uv.y <= horizon_y) {
			float step_x = floor(uv.x * 18.0) / 18.0;
			float hill_h = (sin(step_x * 9.5 + 1.2) * 0.5 + 0.5) * 0.065;
			float hill_y = horizon_y - hill_h;
			if (uv.y > hill_y) {
				col = sky_top * 0.35;
			}
			col += grid_color * smoothstep(0.005, 0.0, abs(uv.y - hill_y)) * 0.75;
		}

		// High-Tech Circuit / Radar Floor with Traveling Data Pulses
		if (uv.y > horizon_y) {
			float fy = (uv.y - horizon_y) / (1.0 - horizon_y);
			float persp = 1.0 / (1.0 - fy * 0.92 + 0.02);
			float rows = fract(persp * 1.35 - t * 1.1);
			float hline = smoothstep(0.0, 0.05, rows) * smoothstep(0.11, 0.05, rows);
			float cx = (uv.x - 0.5) * persp;
			float lane_id = floor(cx * 6.0 + 0.5);
			float cols = abs(fract(cx * 6.0 + 0.5) - 0.5);
			float vline = smoothstep(0.05, 0.0, cols);

			// Traveling high-speed data packets shooting along the vertical lanes
			float packet_pos = fract(persp * 0.45 - t * (1.8 + hash(vec2(lane_id, 9.1)) * 1.4) + hash(vec2(lane_id, 2.3)));
			float packet = smoothstep(0.18, 0.0, abs(packet_pos - 0.5)) * vline * 2.2;

			col += grid_color * max(hline * 0.75, vline) * fy * (0.8 + audio_pulse * 0.55);
			col += horizon_color * packet * fy * (0.95 + audio_pulse * 0.6 + streak_energy * 0.5);
		}
	}

	// =========================================================================
	// STYLE 4: MIDNIGHT ("GALAXY ODYSSEY")
	// Tilted Ringed Saturn Planet, Shooting Stars & Cosmic Starbridge Highway
	// =========================================================================
	else {
		// Periodic Shooting Stars / Meteors in Upper Sky
		vec2 m_uv = uv;
		float m_cycle = floor(t * 0.65);
		float m_phase = fract(t * 0.65);
		vec2 m_start = vec2(0.15 + hash(vec2(m_cycle, 1.0)) * 0.55, 0.06 + hash(vec2(m_cycle, 2.0)) * 0.18);
		vec2 m_dir = normalize(vec2(0.75, 0.42));
		vec2 m_head = m_start + m_dir * (m_phase * 0.55);
		vec2 m_tail = m_head - m_dir * 0.11;
		float m_dist = sd_segment(m_uv, m_tail, m_head);
		float m_fade = sin(m_phase * 3.14159);
		col += vec3(0.95, 0.92, 1.0) * smoothstep(0.0045, 0.0, m_dist) * m_fade * star_region * 0.9;

		// Giant Tilted Ringed Planet (Saturn Style)
		vec2 pl_uv = (uv - vec2(0.5, 0.185)) / pulse_scale;
		pl_uv.x *= 0.9;
		// Rotate coordinates by ~22 degrees for the tilted planetary rings
		float ca = 0.927;
		float sa = -0.374;
		vec2 r_uv = vec2(pl_uv.x * ca - pl_uv.y * sa, pl_uv.x * sa + pl_uv.y * ca);

		float planet_r = 0.125;
		float pl_d = length(pl_uv);
		float in_planet = smoothstep(planet_r + 0.005, planet_r - 0.005, pl_d);

		// Elliptical concentric rings (squashed in rotated Y)
		float ring_d = length(vec2(r_uv.x, r_uv.y * 3.6));
		float ring_band = smoothstep(0.155, 0.17, ring_d) * smoothstep(0.30, 0.275, ring_d);
		// Multi-groove ring detail
		ring_band *= (0.65 + 0.35 * sin(ring_d * 140.0));
		// Back half of ring is occluded by the planet body; front half (r_uv.y > 0) passes in front!
		float ring_front = step(0.0, r_uv.y);
		float ring_visible = ring_band * mix(1.0 - in_planet, 1.0, ring_front);

		// Planet body with atmospheric crescent rim lighting
		if (in_planet > 0.001) {
			float rim = smoothstep(0.0, planet_r, length(pl_uv - vec2(-0.035, -0.035)));
			vec3 pl_body = mix(sun_color * 0.95, sky_top * 0.35, clamp(rim * 1.15, 0.0, 1.0));
			// Subtle planetary cloud bands
			float p_bands = sin(r_uv.y * 45.0) * 0.08;
			pl_body += horizon_color * p_bands;
			col = mix(col, pl_body, in_planet);
		}
		// Add glowing planetary rim & rings
		col += sun_color * smoothstep(planet_r + 0.04, planet_r - 0.01, pl_d) * (1.0 - in_planet * 0.7) * (0.45 + audio_pulse * 0.35);
		vec3 ring_col = mix(horizon_color, sun_color, smoothstep(0.16, 0.29, ring_d));
		col += ring_col * ring_visible * (0.78 + audio_pulse * 0.45 + streak_energy * 0.3);

		// Cosmic Starbridge Warp Highway on Floor
		if (uv.y > horizon_y) {
			float fy = (uv.y - horizon_y) / (1.0 - horizon_y);
			float persp = 1.0 / (1.0 - fy * 0.92 + 0.02);
			float cx = (uv.x - 0.5) * persp;

			// Starfield reflection beneath the glass highway
			vec2 f_star_id = floor(vec2(cx * 8.0, persp * 3.0 - t * 2.0));
			float f_star = step(0.965, hash(f_star_id));
			col += vec3(0.85, 0.85, 1.0) * f_star * fy * 0.5;

			// Glowing highway rails & scrolling light-bars
			float cols = abs(fract(cx * 5.0 + 0.5) - 0.5);
			float vline = smoothstep(0.055, 0.0, cols);
			float rows = fract(persp * 1.2 - t * 1.5);
			float hline = smoothstep(0.0, 0.05, rows) * smoothstep(0.12, 0.05, rows);

			vec3 bridge_col = mix(grid_color, horizon_color, 0.5 + 0.5 * sin(cx * 1.2 + t));
			col += bridge_col * max(hline, vline * 1.15) * fy * (0.85 + audio_pulse * 0.65 + streak_energy * 0.35);
		}
	}

	// --- 4. Glowing Horizon Laser Line & Audio Shockwave Bloom ---
	float h_dist = abs(uv.y - horizon_y);
	col += mix(grid_color, horizon_color, 0.5) * smoothstep(0.010, 0.0, h_dist) * (0.75 + audio_pulse * 0.55);
	col += horizon_color * smoothstep(0.045, 0.0, h_dist) * (0.22 + audio_pulse * 0.40 + streak_energy * 0.25);

	// --- 5. Subtle Modern Retro CRT Scanlines & Arcade Vignette ---
	float crt_scan = sin(uv.y * 480.0 * 3.14159) * 0.035;
	col *= (1.0 - crt_scan);

	float vig = smoothstep(1.18, 0.32, length(uv - 0.5));
	col *= mix(0.70, 1.0, vig);

	COLOR = vec4(col, 1.0);
}
