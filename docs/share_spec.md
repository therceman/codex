# Share Mode Spec

## Goal
Enable real-time shared Codex sessions where a running TUI can receive prompts from external clients (for example, `codex share post`) without brittle PTY automation.

## Non-goals
- Direct control of a running TUI process over PTY/IPC hacks.
- New standalone server for shared-session control.
- Forcing shared mode for all users by default.

## Product decisions (agreed)
- Default launch remains `codex` in local mode.
- Sharing is enabled from inside TUI via `/share` command (not required CLI startup flags).
- `/share` opens a command menu with exactly 4 actions:
  1. `Start sharing this session`
  2. `Join shared session`
  3. `Stop sharing`
  4. `Help / About sharing`
- `/share` view must immediately show live status (no separate refresh action):
  - `Mode: LOCAL | SHARED`
  - `Thread: <thread_id>` when shared
  - `Server: <endpoint or local daemon>`
  - `Turn: idle | running`
- `share` CLI usage examples are shown in Help (not in main `/share` menu).

## Architecture
- Reuse existing `codex app-server` as control plane and source of truth.
- TUI in shared mode is a client connected to an app-server thread.
- `codex share post` is a thin RPC client that submits turns to a target thread.
- Multiple TUI clients may attach to the same thread and observe the same events.
- A prompt is sent once per thread turn, not per attached TUI.

## Concurrency model
- Enforce one active turn per thread.
- If a second submit arrives while running, return a clear "busy" error and let caller retry.

## UX details
- TUI header/status should show session mode clearly:
  - `LOCAL`
  - `SHARED • <thread_id>`
- `/share` action availability depends on state:
  - In LOCAL: start/join enabled, stop disabled.
  - In SHARED: stop enabled, start disabled (or "already sharing"), join may act as switch.

## Help / About sharing content
- What shared mode is (shared thread-backed conversation state).
- How `codex share post` works (submits turn to thread, not to a specific TUI process).
- Multi-client behavior (all attached TUIs receive same updates).
- One-active-turn limitation.
- Example command(s):
  - `codex share post --thread <thread_id> --prompt "..."`
  - `codex share tail --thread <thread_id> [--from <event_id|timestamp>]`
  - `codex share get --thread <thread_id> [--from <event_id|timestamp>] [--limit N]`

## Implementation plan

### Phase 1 (first)
Implement TUI `/share` UX shell and session state plumbing.
- Add/extend slash command entry for `/share`.
- Render menu with 4 actions.
- Render live status block from current runtime state.
- Add LOCAL/SHARED indicator in TUI status/header.
- Help panel content for sharing.

Deliverable: user can open `/share`, inspect state, and understand usage, even before full external share submission is wired.

### Phase 2
Wire shared-mode lifecycle to app-server.
- Start/ensure local app-server on demand when user chooses "Start sharing".
- Create/resume thread and bind TUI to it.
- Implement "Join shared session" by thread id.
- Implement "Stop sharing" transition back to LOCAL.
- After "Start sharing", show explicit endpoint details:
  - `Server: <host>:<port>`
  - `Thread: <thread_id>`
  - ready examples with `--server <endpoint>` for `share post/tail/get`

Deliverable: TUI can enter/leave shared mode and join existing shared sessions.

### Phase 3
Add `codex share post` command and end-to-end turn submission.
- CLI command to submit prompt to thread.
- Stream events/output to caller.
- Busy handling and clear exit codes/errors.

Deliverable: external real-time prompt injection into shared TUI session via app-server thread.

## Open questions
- Should "Join shared session" prompt for thread id inline or use a picker/history when available?
- What endpoint policy for local auto-start server (strict localhost vs configurable)?
- Should switching threads from SHARED require explicit confirmation when unsent input exists?
