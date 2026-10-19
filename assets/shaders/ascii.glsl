extern number time;
extern vec2  texSize;       // 1280x960
extern vec4  zone;          // x, y, w, h in physical screen coordinates

extern number cellW;
extern number cellH;
extern number nChars;
extern vec2  atlasCells;
extern Image atlasTex;

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
    // Match the CRT shader: convert screen coordinates to zone-local UVs.
    if (sc.x < zone.x || sc.x >= zone.x + zone.z ||
        sc.y < zone.y || sc.y >= zone.y + zone.w) {
        return vec4(0.0);
    }

    vec2 uv = (sc - zone.xy) / zone.zw;
    vec2 pixelPos = uv * texSize;

    vec2 cell = floor(pixelPos / vec2(cellW, cellH));
    vec2 centerPixel = (cell + 0.5) * vec2(cellW, cellH);
    vec2 centerUV = centerPixel / texSize;

    vec3 src = Texel(tex, centerUV).rgb;
    float lum = dot(src, vec3(0.299, 0.587, 0.114));
    float idx = floor(clamp(lum, 0.0, 0.999) * nChars);

    vec2 local = (pixelPos - cell * vec2(cellW, cellH)) / vec2(cellW, cellH);

    vec2 atlasUV = vec2((idx + local.x) / atlasCells.x, local.y);
    vec4 glyph = Texel(atlasTex, atlasUV);

    vec3 glyphColor = vec3(0.2, 1.0, 0.4);
    vec3 outColor = mix(vec3(0.0), glyphColor, glyph.a);

    return vec4(outColor, 1.0) * color;
}
