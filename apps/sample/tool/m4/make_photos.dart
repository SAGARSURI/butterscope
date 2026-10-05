// Generates the six gallery photos in assets/photos: 4032 x 3024 (12 MP,
// a phone camera's size) landscapes painted from fixed seeds, so the
// files are the same every time and owe nothing to anyone.
//
// Run from apps/sample, then commit the files:
//
//   fvm dart run tool/m4/make_photos.dart

import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

const int width = 4032;
const int height = 3024;
const int photoCount = 6;

void main() {
  for (var index = 0; index < photoCount; index++) {
    final photo = paintLandscape(Random(1000 + index));
    final path = 'assets/photos/photo_${index + 1}.jpg';
    File(path).writeAsBytesSync(img.encodeJpg(photo, quality: 85));
    stdout.writeln('$path: ${File(path).lengthSync()} bytes');
  }
}

/// A sky, a sun and three ranges of hills, with a little grain so the
/// photo compresses like a real one.
img.Image paintLandscape(Random random) {
  final photo = img.Image(width: width, height: height);
  final hue = random.nextDouble();
  final ridges = [
    for (var layer = 0; layer < 3; layer++) Ridge.random(random, layer),
  ];
  final sunX = width * (0.2 + 0.6 * random.nextDouble());
  final sunY = height * (0.15 + 0.2 * random.nextDouble());
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final sky = skyColour(hue, y / height, x - sunX, y - sunY);
      final colour = ridges.fold(sky, (c, ridge) => ridge.over(c, x, y));
      final grain = random.nextInt(9) - 4;
      photo.setPixelRgb(
        x,
        y,
        (colour.r + grain).clamp(0, 255),
        (colour.g + grain).clamp(0, 255),
        (colour.b + grain).clamp(0, 255),
      );
    }
  }
  return photo;
}

/// A colour as three channels from 0 to 255.
typedef Rgb = ({int r, int g, int b});

/// The sky at height [t] (0 at the top), brightened near the sun, which is
/// [dx], [dy] pixels away.
Rgb skyColour(double hue, double t, double dx, double dy) {
  final glow = exp(-(dx * dx + dy * dy) / (2 * 260.0 * 260.0));
  final base = hsv(hue, 0.45 - 0.3 * t, 0.65 + 0.3 * t);
  return (
    r: (base.r + (255 - base.r) * glow).round(),
    g: (base.g + (245 - base.g) * glow).round(),
    b: (base.b + (200 - base.b) * glow).round(),
  );
}

/// One range of hills: a sum of two waves, darker and lower for nearer
/// layers.
class Ridge {
  new(this.baseline, this.amplitude, this.wave, this.phase, this.colour);

  factory random(Random random, int layer) {
    final hue = 0.25 + 0.15 * random.nextDouble();
    return Ridge(
      height * (0.45 + 0.15 * layer),
      height * (0.04 + 0.04 * random.nextDouble()),
      2 * pi / (width * (0.3 + 0.4 * random.nextDouble())),
      2 * pi * random.nextDouble(),
      hsv(hue, 0.5, 0.55 - 0.15 * layer),
    );
  }

  final double baseline;
  final double amplitude;
  final double wave;
  final double phase;
  final Rgb colour;

  /// [below] unless ([x], [y]) is under this ridge's skyline.
  Rgb over(Rgb below, int x, int y) {
    final skyline =
        baseline +
        amplitude * sin(wave * x + phase) +
        amplitude / 3 * sin(3.1 * wave * x + 2 * phase);
    return y >= skyline ? colour : below;
  }
}

/// [h], [s], [v] from 0 to 1 as 8-bit channels.
Rgb hsv(double h, double s, double v) {
  final sector = (h * 6).floor() % 6;
  final f = h * 6 - (h * 6).floor();
  final p = v * (1 - s);
  final q = v * (1 - f * s);
  final t = v * (1 - (1 - f) * s);
  final (r, g, b) = switch (sector) {
    0 => (v, t, p),
    1 => (q, v, p),
    2 => (p, v, t),
    3 => (p, q, v),
    4 => (t, p, v),
    _ => (v, p, q),
  };
  return (r: (r * 255).round(), g: (g * 255).round(), b: (b * 255).round());
}
