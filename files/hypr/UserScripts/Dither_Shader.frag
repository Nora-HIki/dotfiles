#version 320 es
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
layout(location = 0) out vec4 fragColor;

// --- SETTINGS ---

// Color Depth: Lower = more fried. 
// 2.0  = Unreadable (1-bit)
// 8.0  = Windows 95 style (Readable-ish)
// 32.0 = Nice retro vibe (Daily drivable)
const float STEPS = 8.0;

// Pixel Size: Higher = chunkier pixels (Mosaic)
// 1.0 = Native resolution (Tiny noise)
// 2.0 = 1/2 resolution (Retro console)
// 4.0 = 1/4 resolution (Doom style)
const float MOSAIC = 1.0; 

// ----------------

float bayer2(vec2 xy) {
    xy = floor(mod(xy, 2.0));
    return xy.x * 2.0 + xy.y * 3.0 - xy.x * xy.y * 4.0;
}

float getBayer(vec2 xy) {
    float low = bayer2(xy);
    float high = bayer2(floor(xy * 0.5));
    return (4.0 * low + high) / 16.0;
}

void main() {
    // 1. Pixelate (Mosaic Effect)
    vec2 coord = v_texcoord;
    if (MOSAIC > 1.0) {
        vec2 size = vec2(textureSize(tex, 0));
        vec2 grid = size / MOSAIC;
        coord = floor(coord * grid) / grid;
    }
    
    vec4 color = texture(tex, coord);
    
    // 2. Dither Pattern
    // We adjust gl_FragCoord by MOSAIC so the noise pattern matches the big pixels
    float dither = getBayer(gl_FragCoord.xy / MOSAIC);
    
    // 3. Apply Color Crunch
    float spread = 1.0 / (STEPS - 1.0);
    vec3 noisyColor = color.rgb + (dither - 0.5) * spread;
    vec3 finalColor = floor(noisyColor * (STEPS - 1.0) + 0.5) / (STEPS - 1.0);

    fragColor = vec4(finalColor, color.a);
}
