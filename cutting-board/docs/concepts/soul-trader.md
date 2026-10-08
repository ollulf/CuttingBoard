# Soul Trader

A wandering trader who sells goods and weapons for soul flasks (the Soul in a Bottle item)
and buys the player's junk. Concept only; nothing is wired into the game.

Concept page: https://claude.ai/artifact/K6xHiKrGUGLmDoiAqMdg2F

## Trading window

- Three columns: the trader's cart grid (its stock), a counter in the middle, the player's
  pack grid. Both grids reuse the inventory panel's footprints and rotation.
- The soul flasks in the pack are the money; paying moves flasks into its stock. No hidden
  wallet.
- Drag (or right-click) items onto the counter to buy or sell; the counter totals what you
  pay, what you get and the balance. "Shake on it" confirms the whole deal when the balance
  is not negative and everything fits.
- Price badges on each item (a red badge: an ember soul). Durability lowers the sell price.
  Puppet junk sells for 1 or 2. Masks can't be sold here (the Mask-Monger's trade).
- Optional: a haggle beat on the speech plank for deals over 5 souls.

## The trader: three looks

- **A. The Flask Peddler** (built): a stooped puppet with a corked jug head and ember
  eye-holes, pushing a two-wheeled canopy cart hung with glowing flasks; weapons on a side rack.
- **B. The Cuckoo Cabinet:** lives inside a walking clock cabinet; drawers are stock rows.
- **C. The Scale-Keeper:** its arms are a balance scale that weighs flasks against goods.

Look A is built by `tools/import/build_soul_trader.gd` into
`scenes/characters/soul_trader.tscn` (static; joints `%Torso`, `%Neck`, `%Head`, `%Jaw`,
`%ArmL/R`, `%Flask1..6` named for later animation). Capture:
`tests/visual/soul_trader_capture.tscn -- --shots=<dir> [--clip]`.
