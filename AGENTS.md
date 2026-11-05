# Project Versioning, Watermark & Git Commit Rules

Follow these rules whenever making any code, scene, asset, or configuration alteration in this repository:

1. **Increment Project Version & Watermark Before Committing**:
   - Before creating a commit for any alteration, increment the minor integer part of the version string `0.<N>` to `0.<N+1>` (for example: `0.23` -> `0.24`, `0.9` -> `0.10`, `0.99` -> `0.100`). Never roll over the major version to `1.0` automatically.
   - Update the version across all locations so the in-game watermark and project metadata stay synchronized:
     - `scripts/global.gd`: Update `const GAME_VERSION: String = "<version>"` / watermark label (`pre-alpha version <version>`).
     - `project.godot`: Update `config/version="<version>"` under `[application]`.
     - `README.md` (if present): Update any version/status badge to `pre-alpha <version>`.

2. **Automatic Local Commit for Rollback Safety**:
   - Stage and create a local Git commit after completing each alteration so the project always has a clean rollback point.
   - Format the commit message following the repository's standard:
     `<version> <concise lowercase summary of changes>`
     *(Example: `0.24 add AGENTS.md versioning, watermark, and commit workflow rules`)*

3. **Never Push Without Explicit Approval**:
   - **Never** run `git push` automatically.
   - Only push to the remote repository when the user explicitly asks to push.

4. **Organize AI-Made Visual & Audio Placeholders in `ai/` Subfolders**:
   - Whenever creating or adding any AI-generated or AI-edited visual (sprites, textures, UI) or audio (voice acting, SFX, music) asset, always place it inside an `ai/` subfolder within the appropriate category folder (for example: `image/<category>/ai/<filename>.png` or `Sounds/<category>/ai/<filename>.mp3`).
   - Never mix AI visual or audio placeholders directly into the main asset directories so they can be easily filtered and replaced before final release.
   - If moving existing AI placeholder assets into `ai/` subfolders, update all scene (`.tscn`), script (`.gd`), and `.import` references so nothing breaks in Godot.
