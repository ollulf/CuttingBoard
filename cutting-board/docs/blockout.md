# Blocking out levels

Guide and comparison: https://claude.ai/artifact/BVfW1UhDFMKhU9hEwAnqW7

Demo scene: `res://tests/visual/blockout_demo.tscn` (built-in CSG only). Screenshot/bake check: `res://tests/visual/blockout_capture.tscn`.

## Recommendation

Use Godot's built-in CSG nodes for now. They need no addon, work in Godot 4.6 with the Compatibility renderer, support subtraction and collision, and can be baked to a plain mesh + collision shape since 4.4. If you want RealtimeCSG-style face/edge dragging later, try Cyclops Level Builder in a throwaway branch first (it often lags behind new Godot versions).

| Tool | Type | Closest to RealtimeCSG? | Godot 4.6 |
|---|---|---|---|
| Built-in CSG (CSGBox3D, CSGCombiner3D, CSGPolygon3D) | Built in | Booleans yes, in-viewport face editing no (size handles only) | Yes |
| Cyclops Level Builder | Addon (MIT) | Closest: brush blocks, face/edge editing, quick UV texturing | Repo active (last push Mar 2026); check release notes for 4.6 |
| func_godot + TrenchBroom | Addon + external editor | Quake-style brushes, very fast, but outside Godot | 2025.12 targets 4.5; usually fine on 4.6, test first |

## Workflow

1. Create a `Node3D` scene for the level. Add a `CSGCombiner3D` per structure (room, bridge) and tick **Use Collision** on it.
2. Add `CSGBox3D` children. Grid snap: enable **Use Snap** in the 3D toolbar (Transform > Configure Snap, e.g. 0.25 m). Resize with the orange handles.
3. Cut doors and windows with a child shape whose **Operation** is **Subtraction**.
4. Ramps: `CSGPolygon3D` with a triangle polygon and a depth. Stairs: stacked boxes.
5. Playtest: instance the player in the scene and walk it. CSG collision works at runtime.
6. When a part is final, select the root CSG node, then use **CSG > Bake Mesh Instance** and **Bake Collision Shape** in the 3D toolbar. Put the shape under a `StaticBody3D`, delete the CSG node, and swap in art meshes over time. CSG is slow to rebuild at runtime, so bake before shipping.

## Installing an addon (if you try one)

AssetLib tab in the editor > search the name > Download > Install (into `res://addons/`), or download the release zip and copy its `addons/<name>` folder in. Then Project > Project Settings > Plugins > enable it. Try it on a branch.
