"""Build tileable Godot surface maps from the four OpenRouter material images.

blender -b -P tools/blender/make_surface_detail.py -- <source PNG folder> <surface folder>
"""

from pathlib import Path
import sys

import bpy
import numpy as np


NAMES = ("metal", "concrete", "fabric", "timber")
SIZE = 512


def periodic(image):
    """Crossfade to an offset copy at each edge, with continuous corners."""
    coordinate = np.linspace(-1.0, 1.0, SIZE, dtype=np.float32)
    weight = np.clip((np.abs(coordinate) - 0.53) / 0.32, 0.0, 1.0)
    weight = weight * weight * (3.0 - 2.0 * weight)
    image = image * (1.0 - weight[:, None]) + np.roll(image, SIZE // 2, axis=0) * weight[:, None]
    return image * (1.0 - weight[None, :]) + np.roll(image, SIZE // 2, axis=1) * weight[None, :]


def blur(image, radius):
    frequency = np.fft.fftfreq(SIZE)
    gaussian = np.exp(-2.0 * (np.pi * radius * frequency) ** 2)
    return np.fft.ifft2(np.fft.fft2(image) * gaussian[:, None] * gaussian[None, :]).real


def normalize(image):
    image = image - np.median(image)
    amplitude = max(float(np.percentile(np.abs(image), 98.0)), 0.006)
    return np.clip(image / amplitude, -1.0, 1.0)


def save_png(path, rgba):
    image = bpy.data.images.new(path.stem, width=SIZE, height=SIZE, alpha=True)
    image.colorspace_settings.name = "Non-Color"
    image.pixels.foreach_set(np.ascontiguousarray(rgba, dtype=np.float32).ravel())
    image.file_format = "PNG"
    image.filepath_raw = str(path)
    image.save()
    bpy.data.images.remove(image)


def convert(source, destination, name):
    recorded = bpy.data.images.load(str(source / f"{name}.png"), check_existing=False)
    recorded.colorspace_settings.name = "Non-Color"
    recorded.scale(SIZE, SIZE)
    rgba = np.empty(SIZE * SIZE * 4, dtype=np.float32)
    recorded.pixels.foreach_get(rgba)
    pixels = rgba.reshape((SIZE, SIZE, 4))
    luminance = pixels[:, :, :3] @ np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
    bpy.data.images.remove(recorded)

    seamless = periodic(luminance)
    mid = normalize(seamless - blur(seamless, 22.0))
    micro = normalize(seamless - blur(seamless, 3.0))
    detail = 0.62 * mid + 0.38 * micro
    opacity = np.ones_like(detail)

    # Linear data: color modulation in R, roughness variation in G, relief in B.
    packed = np.stack((0.5 + detail * 0.48, 0.5 - mid * 0.46, 0.5 + micro * 0.46, opacity), axis=2)
    save_png(destination / f"{name}_data.png", packed)

    # BaseMaterial3D's multiply layer retains the existing UV maps and textures.
    tone = 0.91 + detail * 0.09
    overlay = np.stack((tone, tone, tone, opacity * 0.35), axis=2)
    save_png(destination / f"{name}_overlay.png", overlay)

    dx = (np.roll(micro, -1, axis=1) - np.roll(micro, 1, axis=1)) * 0.16
    dy = (np.roll(micro, -1, axis=0) - np.roll(micro, 1, axis=0)) * 0.16
    normal = np.stack((-dx, -dy, opacity), axis=2)
    normal /= np.linalg.norm(normal, axis=2, keepdims=True)
    save_png(destination / f"{name}_normal.png", np.dstack((normal * 0.5 + 0.5, opacity)))


source_dir, surface_dir = map(lambda value: Path(value).resolve(), sys.argv[sys.argv.index("--") + 1:])
surface_dir.mkdir(parents=True, exist_ok=True)
for surface in NAMES:
    convert(source_dir, surface_dir, surface)
