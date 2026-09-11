# Project structure

```
addons/                  third-party plugins (installed via AssetLib)
assets/                  raw + imported art assets
  animations/            .res / imported animation libraries
  audio/{music,sfx,ui}
  environment/{hdri,sky} panorama HDRIs, sky materials
  fonts/
  materials/{characters,environment,props}   .tres StandardMaterial3D / ShaderMaterial
  meshes/{characters,environment,props}      .glb / .gltf / .obj ready for import
  models_source/         .blend / .fbx working files (not shipped, see .gitignore)
  shaders/               .gdshader
  textures/{characters,environment,props,ui} albedo/normal/orm maps
  ui/{icons,sprites}
resources/               gameplay .tres data
  data/                  custom Resource definitions (items, recipes, stats)
  environments/          WorldEnvironment .tres
  input/                 input remap / action resources
  physics_materials/     PhysicsMaterial .tres
scenes/                  .tscn files
  characters/ components/ levels/ props/ ui/ vfx/
scripts/                 .gd files not owned by a single scene
  autoload/ components/ resources/ ui/ utils/
tests/                   GUT / gdUnit test scenes and scripts
docs/
```

Conventions:
- A scene keeps its script next to it (`scenes/props/knife.tscn` + `knife.gd`); `scripts/`
  holds shared code: autoloads, reusable components, custom `Resource` classes, helpers.
- Texture naming: `name_albedo`, `name_normal`, `name_orm`, `name_emission`.
- `.gitkeep` files only mark empty folders and can be deleted once a folder has content.
