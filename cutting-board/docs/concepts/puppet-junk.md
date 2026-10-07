# Puppet junk (concept)

Junk looted from dead puppets, made from their wooden bodies. Result page:
https://claude.ai/artifact/1JjVp2KqyKFKxkuDgFqWaw

Meshes: `assets/meshes/props/junk_<name>.res`, built by `tools/import/build_puppet_junk.gd`.
Preview: `tests/visual/puppet_junk_capture.tscn`.

In the game (round 2): 1, 3, 4, 5, 6, 8 and 10 are real items (`resources/items/`,
`scenes/items/`, baked icons). Villagers and bandits roll each one as an extra item
(Common 35%, Uncommon 15%, Rare 5%); walking chairs carry the dowel (35%), finger joint
(20%) and peg teeth (15%). They are only lootable and holdable for now: no crafting or
selling yet. 2, 7 and 9 stay concepts. Checked by `tests/puppet_junk_loot_check.tscn`.

| # | Mesh | Name | Suggested use | Rarity |
|---|------|------|---------------|--------|
| 1 | `finger_joint` | Cracked Finger Joint | Monger hand repair, sell | Common |
| 2 | `string_knot` | Knot of Puppet String | crafting binding | Common |
| 3 | `hinge_pin` | Knee Hinge Pin | iron scrap, nail-gun nails | Uncommon |
| 4 | `sawdust_pouch` | Sawdust Pouch | glue + sawdust filler paste | Common |
| 5 | `lacquer_flake` | Lacquer Flakes | mask paint / dye | Uncommon |
| 6 | `dowel` | Splintered Dowel | peg or shaft, fuel | Common |
| 7 | `screw_eye` | String Screw-Eye | trap / lantern hook, sell | Uncommon |
| 8 | `eye_bead` | Carved Eye Bead | sell to the Monger, mask socket perk | Rare |
| 9 | `ember_knot` | Ember Heartknot | big heal, Carver fuel, sell | Rare |
| 10 | `peg_teeth` | Peg Teeth | trophy, chair bait, sell | Uncommon |
