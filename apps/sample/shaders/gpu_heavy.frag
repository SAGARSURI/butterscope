#version 460 core

// A full-screen pattern that runs a long loop for every pixel, so the GPU
// does the work and the raster thread only records one draw. Used by the
// gpu_heavy plant in the sample app.

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uIterations;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  float value = 0.0;
  for (float i = 0.0; i < 4096.0; i++) {
    if (i >= uIterations) {
      break;
    }
    value += sin(uv.x * 9.0 + i * 0.11 + uTime) * cos(uv.y * 7.0 - i * 0.07);
  }
  fragColor = vec4(0.4 + 0.1 * sin(value), 0.5, 0.9, 1.0) * 0.25;
}
