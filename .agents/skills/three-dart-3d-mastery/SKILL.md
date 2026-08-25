---
name: three-dart-3d-mastery
description: Advanced 3D WebGL and three_dart development skill for Flutter. Covers GLTF/GLB loading, material shader manipulation, procedural foliage, dynamic lighting, particle systems, spatial optimization, and memory management.
---

# ThreeDart & 3D World Mastery

## 1. 3D Engine Fundamentals in Flutter
- **Engine Stack**: `flutter_gl_flutterflow` + `three_dart_flutterflow` + `three_dart_jsm_flutterflow`.
- **Render Loop Discipline**: Always check `!mounted || _disposed` before `render()` or `requestAnimationFrame`. Use `16ms` ticks with delta-time calculation for fluid animations.
- **Resource Cleanup**: Geometries and materials should be recycled or properly disposed.

## 2. GLTF/GLB Loading & Optimization
- **Caching**: Cache loaded GLTF scenes (`Map<String, three.Object3D>`) and use `.clone(true)` to avoid redundant network/file decoding.
- **Scale Normalization**: Automatically calculate `Box3().setFromObject(obj)` to compute bounding height and normalize target scales smoothly.
- **Materials & Color Override**: Traverse meshes (`child is three.Mesh`) to apply custom `MeshPhongMaterial` or `MeshStandardMaterial` with custom roughness, metalness, and emissive highlights.

## 3. Spatial Distribution & Anti-Clutter
- **Poisson Disk / Minimum Distance**: Check squared distance `(dx*dx + dz*dz) >= minSpacing^2` before placing any new entity.
- **Biomes & Clusters**: Group entities by logical category (e.g. Palm oasis, Forest grove, Palace courtyards, Treasure alcoves) with jittered offsets.
- **Entity Cap**: Enforce an active scene cap (e.g. 50-60 items) and use tier/evolution scaling to represent large counts without dropping framerate.

## 4. Celestial Lighting & Environment
- **Multi-Light Setup**:
  - `AmbientLight` (soft sky tint) for ambient radiance.
  - `DirectionalLight` (warm celestial sun) for key highlights.
  - `DirectionalLight` (cool fill light) from the opposite angle to fill shadows.
- **Volumetric Fog**: Use `Fog` or `FogExp2` matching the sky/horizon color to create depth, infinity, and soft silhouettes.
