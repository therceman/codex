# Share-Share Spec

## Scope
Define the implementation for shared interactive sessions where:
- TUI can switch from `LOCAL` to `SHARED` mode via `/share`.
- A shared session is backed by `codex app-server` thread state.
- External CLI (`codex share post`) can submit prompts/turns into that shared thread.

## User flow
1. User starts TUI with `codex`.
2. User runs `/share` and selects `Start sharing this session`.
3. TUI ensures an app-server endpoint is available.
4. TUI creates/resumes a shared `thread_id` and enters `SHARED` mode.
5. User (or another process) runs:
   - `codex share post --thread <thread_id> --prompt "..."`
   - `codex share tail --thread <thread_id> [--from <event_id|timestamp>]`
   - `codex share get --thread <thread_id> [--from <event_id|timestamp>] [--limit N]`
6. Prompt is submitted to the shared thread once.
7. All TUI clients attached to that thread see the same streamed events.

## Architecture
- Reuse existing `codex app-server` JSON-RPC API as control plane.
- No separate `share-server`.
- Shared state key is `thread_id`.
- TUI and `codex share post` are RPC clients.

## Commands

### TUI `/share`
Actions:
1. Start sharing this session
2. Join shared session
3. Stop sharing
4. Help / About sharing

Status block shown immediately:
- Mode: LOCAL | SHARED
- Thread: <thread_id>
- Server: <endpoint>
- Turn: idle | running

### CLI `codex share post`
Proposed interface:
- `codex share post --thread <thread_id> --prompt "..."`
  - `codex share tail --thread <thread_id> [--from <event_id|timestamp>]`
  - `codex share get --thread <thread_id> [--from <event_id|timestamp>] [--limit N]`
Optional:
- `--server <url>`
- `--wait` (default true)
- `--json` (machine-readable output)

## Implementation plan

### Phase 1 (done)
- `/share` command + 4-action menu shell
- live status block
- help view
- local shared-mode state placeholder in TUI

### Phase 2 (next)
- app-server lifecycle and shared thread binding
- Start sharing:
  - ensure app-server (spawn local daemon if missing)
  - create/resume thread and store `shared_thread_id`
- Join sharing:
  - prompt for thread id
  - attach current TUI session to that thread
- Stop sharing:
  - detach from shared thread and return to LOCAL

### Phase 3
- implement `codex share post`
- connect to app-server, submit user turn to target thread
- stream assistant/tool events to caller
- return clear exit codes (`0` success, non-zero busy/error)

## Concurrency and correctness
- Exactly one active turn per thread.
- If a turn is already running, reject new submit with explicit `busy` error.
- Prompt submission must be thread-scoped (not broadcast to TUI processes directly).
- Multiple TUIs on same thread are read/update peers.

## UX requirements
- TUI header/footer must visibly show `LOCAL` vs `SHARED` mode.
- In SHARED mode show short thread identifier.
- `Help / About sharing` includes `codex share post` usage and behavior notes.

## Error handling
- If app-server is unavailable and cannot start: show actionable message.
- If thread id is invalid on join/post/tail/get: show not-found error.
- If network/transport fails: show endpoint + retry hint.

## Security and defaults
- Default endpoint binding should remain localhost.
- No auth changes in initial scope; rely on local-machine trust model.
- Do not expose public network ports by default.

## Open items
- Exact transport default for `share` (`stdio` child vs ws endpoint).
- How TUI enters thread-id input for `Join shared session` (inline prompt vs picker).
- Persist/reuse last shared endpoint/thread across restarts or keep session-local only.
