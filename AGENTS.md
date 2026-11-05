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

4. **Organize AI Placeholders in Unified Root `ai/` Folders**:
   - Never scatter AI placeholders into subcategory directories. Instead, place all AI visual assets together inside a single top-level `ai/` folder within the main visual asset directory (for example: `image/ai/` or `assets/ai/`).
   - Place all AI audio assets together inside a single top-level `ai/` folder within the main sound directory (for example: `Sounds/ai/` or `sound/ai/`).
   - Never mix AI placeholders into human-made asset folders so they can be easily reviewed, filtered, and replaced before final release.
   - When moving assets into `ai/` folders, always update and relink all scene (`.tscn`), script (`.gd`), and `.import` references so nothing breaks in Godot.
