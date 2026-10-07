# Project structure

```
addons/                  third-party plugins (installed via AssetLib)
assets/                  raw + imported art assets
  animations/            .res / imported animation libraries
  audio/{music,sfx,ui,ambience}   sfx/ui/ambience and music/concepts synthesised by tools/audio; music/outside+combat played by the Music autoload
  environment/{hdri,sky} panorama HDRIs, sky materials
  fonts/
  materials/{characters,environment,props,post}   .tres StandardMaterial3D / ShaderMaterial
  meshes/{characters,environment,props}      .glb / .gltf / .obj, and .res meshes written by tools/import
  models_source/         .blend / .fbx working files (not shipped, see .gitignore)
  shaders/               .gdshader (post/ full-screen passes, ui/ overlays, include/ shared code)
  textures/{characters,environment,props,ui} albedo/normal/orm maps
  ui/{icons,sprites}
resources/               gameplay .tres data
  animations/            AnimationLibrary .tres
  audio/                 SoundBank .tres: one per game sound, played via the Sfx autoload
  data/                  (empty) future custom data records
  environments/          WorldEnvironment .tres
  factions/              FactionData .tres
  input/                 input remap / action resources
  items/                 ItemData / MaskData .tres, one per item
  physics_materials/     PhysicsMaterial .tres
  ui/                    Theme and StyleBox .tres
scenes/                  .tscn files, each with the script it owns beside it
  characters/            player, NPCs (npc_base + bandit/villager/mask_monger), bodies, masks
  environment/           level-design pieces: buildings, decoration, foliage, sky, bandit camp
  items/                 pick-up-able world items
  levels/                levels, lighting rigs, the intro sequence
  props/ ui/ vfx/
scripts/                 .gd files not owned by a single scene
  autoload/              the autoload singletons named in project.godot
  components/            reusable nodes: Health, Inventory, Equipment, HandSlot, Interactor, ...
  data/                  plain RefCounted records: DamageInfo, InventoryEntry, HotbarSlot
  level/                 level helpers: navmesh auto-bake, terrain
  npc/                   the NPC: Npc, its Brain and actions/, senses, body, GrudgeBook, LoadoutRoll
  resources/             custom Resource classes: ItemData, MaskData, FactionData, SoundBank
  utils/                 static helpers (MouseGrab)
tests/                   headless checks: tests/<name>_check.tscn, each exits with its failure count
  support/               TestWorld: shared floor, navmesh bake/sync and masked-player set-up
  visual/                windowed capture scenes for screenshots and clips (Movie Maker)
  ragdoll/               test stand for hit reactions and ragdolls, run by hand
tools/                   editor/CLI tooling, run with `godot --headless --path cutting-board -s <script>`
  audio/                 synth_sfx / synth_music / synth_voice_concepts on synth_base.gd: regenerate the synth sounds
  import/                one-off builders that write meshes and scenes (prop builders share mesh_builder.gd)
  icon_baker/            renders item icons
docs/                    concepts/, pitch/ and this file
```

Conventions:
- A scene keeps its script next to it (`scenes/ui/pause_menu.tscn` + `pause_menu.gd`), and so
  does a script used only inside one scene (`scenes/ui/paper_doll.gd` lives in
  `inventory_panel.tscn`). `scripts/` holds code shared by several scenes: autoloads, reusable
  components, custom `Resource` classes, data records, helpers.
- Moving a script: move its `.uid` file with it and rewrite every `res://` path to it
  (`.tscn`, `.tres`, `.gd`, `project.godot`, docs), then run
  `godot --headless --path cutting-board --editor --quit` to rebuild the class cache.
- Texture naming: `name_albedo`, `name_normal`, `name_orm`, `name_emission`.
- `.gitkeep` files only mark empty folders and are deleted once a folder has content.
