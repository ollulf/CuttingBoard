# Woody clouds

**Implemented: B (ring sky).** `assets/shaders/sky/woody_sky.gdshader` is the sky of
`resources/environments/daylight.tres` and `tallow_fair.tres` (gradient and sun carried
over; clouds are left out of the ambient/reflection pass). Knobs, all inspector uniforms
on the environment's sky material:

- `cloud_cover`, `cloud_scale`: how much of the sky is wood, and slice size
- `drift_direction`, `drift_speed`: slow drift with `TIME`
- `ring_density`, `ring_strength`: growth ring count and contrast
- `bark_width`, `bark`: the dark rim around each slice
- `wood_light`, `wood_dark`: ring colours (night uses dim purple-brown tones)
- `sky_*`, `ground_*`, `sun_size_degrees`: the old gradient and sun disc

At night the moon (`scenes/environment/sky/moon.tscn`) still draws in front of the clouds.

## Concept (round 1)

Concept page: https://claude.ai/artifact/N5hJeipcuktGk1DWAqyWZy

Three ways to make the sky belong to a world of wood, built in
`tests/visual/woody_clouds/woody_clouds_capture.tscn` over the village, day and night,
through the PSX palette grade:

- **A. Whittled clouds on strings** (3D): faceted carved lumps with a flat sawn
  underside, hung on two strings and swaying like stage props. ~7 meshes per cloud
  (mergeable into one).
- **B. Ring sky shader** (`woody_sky.gdshader`): clouds drawn in the sky as end-grain
  log slices, growth rings and a dark bark rim, drifting with `TIME`. No extra draw
  calls; one sky pass with 4-octave value noise. **Recommended.**
- **C. Plywood flats on rails** (3D + `plywood.gdshader`): cut-out cloud boards with
  long grain and dark sawn edges, hanging from rails and sliding like theatre scenery.

Why B: it keeps its contrast in the day grade (which turns the sky cream and washes
out A and C), costs almost nothing, and covers the whole sky. Into the levels it would
replace the `ProceduralSkyMaterial` in `resources/environments/daylight.tres` and
`tallow_fair.tres` with a `ShaderMaterial` (done, see above).
C could be added later as a few foreground accents near the village.

Try it: `godot --path cutting-board res://tests/visual/woody_clouds/woody_clouds_capture.tscn -- --clip=B --time=day`
(`--clip=A|B|C`, `--time=day|night`; `--shots=<dir>` saves all six stills).
