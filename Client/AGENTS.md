# AGENTS.md
- Goal: port the original client (decompiled in `\AnalizeVNClient`, read-only) to Godot 4 in this project, matching BEHAVIOR.
- Full rules: `.agent/rules/`. Roles: `.agent/workflows/`. Status: `docs/migration/parity_matrix.md`.
- Never read `ca.exe.c` (IDA Pro: `sub_<HEX>`) or `ca.exe.g.c` (Ghidra: `FUN_<08x>` lowercase, same base `0x00400000`) fully. Use `ida-pro` MCP (`idalib-mcp` on `ca_unpacked.exe.i64`) as the sole RE tool (REA is not used), plus targeted snippets for cross-check. Godot code is written from `docs/migration/specs/` only.
- Every spec claim needs evidence (address + pseudocode). Unknown -> `UNKNOWN`, never guess.
- A task is done only when headless tests pass and coverage/review checks are clean.
- Ask the user only for behavior-affecting `UNKNOWN`s, ambiguous readings, or broken tool setup.
