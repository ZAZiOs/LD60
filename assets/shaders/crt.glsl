// CRT shader
// Applies barrel distortion, glow, scanlines, flicker, and vignette
// only inside the specified 'zone' rectangle.

extern number time;
extern vec2  texSize;   // Canvas size (e.g., 320x240)
extern vec4  zone;      // x, y, w, h in screen coordinates

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

vec2 barrel(vec2 uv, float k) {
    vec2 c = uv - 0.5;
    float r2 = dot(c, c);
    c *= 1.0 + k * r2;
    return c + 0.5;
}

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    // If outside the zone, render raw scene without any CRT effect
    if (sc.x < zone.x || sc.x >= zone.x + zone.z ||
        sc.y < zone.y || sc.y >= zone.y + zone.w) {
        return Texel(tex, tc) * color;
    }

    // Normalized coordinates relative to the zone (0..1)
    vec2 uv = (sc - vec2(zone.x, zone.y)) / vec2(zone.z, zone.w);

    // Apply barrel distortion relative to the zone
    vec2 duv = barrel(uv, 0.08);

    // If distorted pixels go outside the zone, render black (monitor edge)
    if (duv.x < 0.0 || duv.x > 1.0 || duv.y < 0.0 || duv.y > 1.0) {
        return vec4(0.0, 0.0, 0.0, 1.0);
    }

    // Sample the canvas directly using duv (0..1)
    vec4 base = Texel(tex, duv) * color;

    // Glow (bloom)
    vec3 glow = vec3(0.0);
    float radius = 1.1 / texSize.x;
    for (int i = 0; i < 8; i++) {
        float a = float(i) * 0.785398;
        vec2 off = vec2(cos(a), sin(a)) * radius;
        vec4 s = Texel(tex, duv + off);
        float b = max(s.r, max(s.g, s.b));
        glow += s.rgb * smoothstep(0.2, 0.8, b);
    }
    glow /= 8.0;
    vec3 col = base.rgb + glow * 0.4;

    // Scanlines (use texSize.y for frequency relative to canvas height)
    float fine   = sin(duv.y * texSize.y * 4.6);
    float coarse = sin(duv.y * texSize.y * 0.3);
    
    float scan = 0.85 + 0.15 * (0.7 * fine + 0.3 * coarse); 
    
    vec3 lineColor = vec3(0.35); 
    col = mix(col * scan, lineColor * scan, 0.1); 
    
    // Flicker (step-like)
    float t = floor(time * 1.0);
    float rnd = hash(vec2(t, 1.0)); 
    float flicker = 0.95 + 0.05 * rnd;
    col *= flicker;

    // Vignette (relative to the zone)
    float vign = smoothstep(0.95, 0.35, distance(uv, vec2(0.5)));
    col *= mix(0.75, 1.0, vign);

    return vec4(col, 1.0);
}