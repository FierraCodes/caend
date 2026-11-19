#version 300 es
// Based on end4's illogical-impulse anti-flashbang shader (GPL-3.0), https://github.com/end-4/dots-hyprland
// Runs for every pixel, so the brightness estimate uses a 5x5 jittered grid (25 fetches) instead of 100
// random points: 4x fewer texture reads per pixel, same coverage of the screen.
precision highp float;

in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

const int GRID = 5;
const float CELL = 1.0 / float(GRID);

void main() {
    vec4 pixColor = texture(tex, v_texcoord);

    // Average screen colour. The jitter keeps samples off a regular lattice so thin UI lines don't alias
    vec3 total = vec3(0.0);
    for (int y = 0; y < GRID; y++)
        for (int x = 0; x < GRID; x++) {
            vec2 jitter = fract(vec2(float(x * GRID + y) * 0.618034, float(y * GRID + x) * 0.754878));
            total += texture(tex, (vec2(float(x), float(y)) + 0.15 + jitter * 0.7) * CELL).rgb;
        }
    float brightness = dot(total / float(GRID * GRID), vec3(0.2126, 0.7152, 0.0722));

    float opacity = clamp(brightness * 0.75, 0.001, 1.0);
    fragColor = vec4(pixColor.rgb * (1.0 - opacity), pixColor.a);
}
