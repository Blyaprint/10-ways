shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;

// --- ГАЛОЧКИ ВКЛ/ВЫКЛ ---
uniform bool enable_distortion = true;
uniform bool enable_scanlines = true;
uniform bool enable_jitter = true;
uniform bool enable_flicker = true;
uniform bool enable_noise = true;
uniform bool enable_vignette_pulse = true;

// --- 1. РЫБИЙ ГЛАЗ ---
uniform float distortion : hint_range(0.0, 1.0) = 0.12;

// --- 2. СКАН-ЛИНИИ ---
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.12;
uniform float scanline_count : hint_range(50.0, 1000.0) = 180.0;
uniform float scanline_thickness : hint_range(0.1, 5.0) = 1.0;

// --- 3. ДРОЖАНИЕ (JITTER) ---
uniform float jitter_amount : hint_range(0.0, 3.0) = 1.0;
uniform float jitter_speed : hint_range(0.0, 20.0) = 12.0;

// --- 4. МЕРЦАНИЕ (FLICKER) ---
uniform float flicker_amount : hint_range(0.0, 0.2) = 0.03;
uniform float flicker_speed : hint_range(0.0, 20.0) = 8.0;

// --- 5. ШУМ (NOISE) ---
uniform float noise_amount : hint_range(0.0, 0.2) = 0.03;

// --- 6. ДЫХАНИЕ ВИНЬЕТКИ (VIGNETTE PULSE) ---
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.5;
uniform float vignette_speed : hint_range(0.0, 10.0) = 2.0;

// --- ЦВЕТА ---
uniform vec4 color_dark : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec4 color_light : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Функция случайных чисел
float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec2 uv = SCREEN_UV;

    // 3. ДРОЖАНИЕ ЭКРАНА
    if (enable_jitter) {
        float jx = floor(sin(TIME * jitter_speed) * jitter_amount);
        float jy = floor(cos(TIME * jitter_speed * 1.3) * jitter_amount);
        uv += vec2(jx, jy) / vec2(640.0, 360.0);
    }

    // 1. РЫБИЙ ГЛАЗ
    if (enable_distortion) {
        vec2 cc = uv - 0.5;
        float dist2 = dot(cc, cc);
        uv = uv + cc * dist2 * distortion;
    }

    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        COLOR = color_dark;
    } else {
        vec4 original_color = texture(screen_texture, uv);
        
        // СЧИТАЕМ ЯРКОСТЬ
        float original_lum = dot(original_color.rgb, vec3(0.299, 0.587, 0.114));
        
        // ПЛАВНАЯ ПЕРЕКРАСКА (без step!)
        // Черный станет color_dark, белый станет color_light, а серый останется серым (смешанным)
        vec3 final_color = mix(color_dark.rgb, color_light.rgb, original_lum);

        // --- НАКЛАДЫВАЕМ ЭФФЕКТЫ ---
        
        // 2. СКАН-ЛИНИИ
        if (enable_scanlines) {
            float scan = sin(uv.y * scanline_count * scanline_thickness * 3.14159);
            scan = max(0.0, scan);
            final_color *= 1.0 - scanline_strength * scan;
        }

        // 4. МЕРЦАНИЕ
        if (enable_flicker) {
            float flick = 1.0 + sin(TIME * flicker_speed) * flicker_amount;
            final_color *= flick;
        }

        // 5. ШУМ
        if (enable_noise) {
            float n = rand(uv + TIME) - 0.5;
            final_color += n * noise_amount;
        }

        // 6. ДЫХАНИЕ ВИНЬЕТКИ
        if (enable_vignette_pulse) {
            vec2 cc = uv - 0.5;
            float pulse = (sin(TIME * vignette_speed) * 0.5 + 0.5) * 0.5 + 0.5; 
            float vig = smoothstep(0.8, 0.3, length(cc));
            final_color *= mix(1.0, vig, vignette_strength * pulse);
        }

        // Ограничиваем цвет
        final_color = clamp(final_color, 0.0, 1.0);

        COLOR = vec4(final_color, 1.0);
    }
}