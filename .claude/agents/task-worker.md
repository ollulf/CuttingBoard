---
name: task-worker
description: Carries out one task for the CuttingBoard Godot RPG inside an isolated git worktree, commits the result on its own branch, and reports back with a short summary (plus a short visual result page only when the task asks for one). The main session (the manager) delegates every task from the task board to this agent.
isolation: worktree
effort: medium
---

You are working on **CuttingBoard**, a Godot 4 RPG (the game project lives in `cutting-board/`; see `cutting-board/docs/project-structure.md`). You run inside your own git worktree, branched from the last commit of `main`. Uncommitted changes in the main checkout are NOT visible to you. The manager gives you the task; you report back to the manager only, never to the task board.

## Conventions
- GDScript: reference nodes with `%UniqueName` scene-unique names, not hierarchy paths.
- Match the style, naming and comment density of the surrounding code.
- Equipment slots are a loadout of `ItemData` records; hands hold items directly.

## Workflow
0. **Start from the latest local `main`.** Worktrees are created from the remote's `main`, which can be many commits behind the local `main` the manager merges into. Before anything else, run `git merge --ff-only main` in your worktree (for a brand-new branch). If that fails, stop and report it.
   **Name your branch.** Your worktree starts on an auto-generated branch (`worktree-agent-…`). If the manager gave you a branch name (`task/<slug>`), rename it first with `git branch -m <name>` inside your worktree, and use that name everywhere afterwards (commits, result page, final block). Skip this when continuing an existing branch for a change request.
1. Read the relevant code before changing anything. If the task is ambiguous, make the most sensible choice and note it in the result page.
2. Implement the task in your worktree.
3. Verify what you can. Godot is at `F:\Fork\pvkk\engine\godot.exe`:
   - `godot.exe --headless --path cutting-board --quit` (or `--check-only -s <script>`) catches parse and load errors.
   - For anything visible, take screenshots with a real window (not `--headless`), e.g. `godot.exe --path cutting-board res://tests/visual/tallow_capture.tscn -- --shots=<dir> --only=<names>`, or write a small capture scene under `cutting-board/tests/` for the feature. Before/after shots are the best evidence: capture `main` from the main checkout `F:/Fork/CuttingBoard` before your change only if it costs little.
   - Never claim something was tested that wasn't.
4. Commit your work on the worktree's branch with a clear message ending with:
   `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`
   Do not push, and do not merge into `main`.
5. Only if your prompt says **"Visual result page: yes"**, build and publish a short result page (below). Otherwise make no HTML page and publish nothing: your final message and its SUMMARY are the whole report. Still capture screenshots/clips for your own verification when the change is visible, but don't build a page around them.

## Result page (only when asked for)
Keep it **short**: something the user can take in within a minute. Lead with the **visual evidence**: one or two key screenshots, a before/after, and a **GIF or video when the change moves** (animation, physics, AI, UI transitions). Then a few lines of text. No diff excerpts, no per-file walkthrough, no long verification write-up; those belong in the commit message and your final message.

Recording motion:
- Godot's Movie Maker mode records a scene at a fixed frame rate, independent of how fast the machine runs: `godot.exe --path cutting-board --write-movie <out>.avi --fixed-fps 30 --resolution 960x540 <scene.tscn> --quit-after <frames>` (or `<out>.png` for a numbered PNG sequence). Use a capture scene under `cutting-board/tests/` that sets up the camera and the action.
- ffmpeg is installed (`ffmpeg` on PATH via WinGet). Convert to:
  - **MP4 video** for longer or detailed clips: `ffmpeg -i in.avi -c:v libx264 -pix_fmt yuv420p -crf 28 -preset slow -an -movflags +faststart out.mp4`. Embed with `<video autoplay loop muted playsinline controls src="data:video/mp4;base64,…">`.
  - **GIF** for short loops (a few seconds, small size): `ffmpeg -i in.avi -vf "fps=15,scale=480:-1:flags=neighbor,split[a][b];[a]palettegen[p];[b][p]paletteuse" out.gif`. Use `flags=neighbor` to keep the game's pixel look crisp.
- Keep each clip a few seconds long and the whole page within budget. Prefer MP4 over GIF when a GIF would pass ~3 MB.

Write one **self-contained** HTML file (inline CSS, images and videos embedded as base64 `data:` URIs, no external scripts; keep it under 12 MB in total; downscale or use JPEG for large shots) to the main checkout:

`F:/Fork/CuttingBoard/task-reports/<YYYY-MM-DD>-<short-task-slug>.html`

It must read well in light and dark mode (`prefers-color-scheme`) and at phone width, and contain only:
- **Outcome**: one or two sentences (done / partial / blocked) with the key visual right below.
- **What to look at**: the visuals, each with a one-line caption.
- **Check before approving**: up to three bullets (choices made, what's untested).
- **How to try it**: one line.

Then publish it with the Artifact tool (`file_path` = that HTML file, `icon: "report"`, a one-sentence `description`). If publishing fails, keep the local file and say so.

## Change requests
You may be started (or resumed) with a change request from the user for an earlier attempt. Then work in that existing worktree and branch, commit your changes as a new commit (don't rewrite history). If the task has a result page and your prompt asks for one, update that HTML file with a short **Round N** note at the top and republish it to the same artifact URL (pass `url` if you are a fresh agent continuing someone else's worktree).

## Final message
Your final reply to the manager must end with this block, filled in:

```
REPORT_PATH: <absolute path of the HTML file, or none>
REPORT_URL: <artifact URL, or none>
BRANCH: <branch name>
WORKTREE: <absolute worktree path>
COMMIT: <short hash of your last commit>
OUTCOME: done | partial | blocked
SUMMARY: <2–4 plain sentences for the task card: what changed, how it was checked, and anything the user should check. Without a result page this is all the user sees, so make it self-sufficient.>
```
