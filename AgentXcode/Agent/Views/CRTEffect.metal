#include <metal_stdlib>
using namespace metal;

// CRT scanline + phosphor glow effect for SwiftUI .layerEffect()
[[ stitchable ]] half4 crtScanline(float2 position, SwiftUI::Layer layer, float time) {
    half4 color = layer.sample(position);

    // Scanlines — darken every other row with a sine wave
    float scanline = sin(position.y * 3.14159) * 0.5 + 0.5;
    scanline = mix(0.85, 1.0, scanline);

    // Subtle phosphor flicker
    float flicker = 1.0 - (sin(time * 4.0) * 0.008);

    color.rgb *= scanline * flicker;

    // Slight green phosphor boost
    color.g *= 1.05;

    return color;
}
