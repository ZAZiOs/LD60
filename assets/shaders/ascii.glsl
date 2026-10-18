extern number time;
extern vec2  texSize;      // Canvas size (e.g., 320x240)
extern vec4  zone;         // x, y, w, h in screen coordinates

extern number cellW;
extern number cellH;
extern number nChars;
extern vec2  atlasCells;
extern Image atlasTex;

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    if (sc.x < zone.x || sc.x >= zone.x + zone.z ||
        sc.y < zone.y || sc.y >= zone.y + zone.w) {
        return Texel(tex, tc) * color;
    }

    vec2 uv = (sc - vec2(zone.x, zone.y)) / vec2(zone.z, zone.w);
    vec2 canvasPixel = uv * texSize;

    vec2 cell = floor(canvasPixel / vec2(cellW, cellH));
    vec2 centerCanvas = (cell + 0.5) * vec2(cellW, cellH);
    vec2 centerUV = centerCanvas / texSize;

    vec3 src = Texel(tex, centerUV).rgb;
    float lum = dot(src, vec3(0.299, 0.587, 0.114));
    float idx = floor(clamp(lum, 0.0, 1.0) * (nChars - 1.0) + 0.5);

    vec2 local = (canvasPixel - cell * vec2(cellW, cellH)) / vec2(cellW, cellH);
    vec2 atlasUV = vec2((idx + local.x) / atlasCells.x, local.y);
    vec4 glyph = Texel(atlasTex, atlasUV);

    vec3 glyphColor = vec3(0.2, 1.0, 0.4);
    vec3 outColor = mix(vec3(0.0), glyphColor, glyph.a);

    return vec4(outColor, 1.0) * color;
}