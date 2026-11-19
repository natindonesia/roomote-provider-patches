# Roomote provider patches

Out-of-tree integrations that add **Lizard** and **Fly.io Sprites** as Roomote
compute providers, shipped as a patch series so upstream can be tracked without
maintaining a fork.

The repo name still says "sprites" from the first cut. Rename with
`gh repo rename roomote-provider-patches` if you want it to match.

## Status

| Provider | Client | Worker bootstrap | Runs a task end to end |
|---|---|---|---|
| Lizard | yes | yes | yes |
| Fly.io Sprites | yes | no | no |

Lizard is the one worth applying. Sprites is kept because its client is
type-checked and complete, but its `create-sprites-machine.ts` and
`spawn-sprites-worker.ts` are not written, so the controller throws a clear
error instead of spawning.

## Why a patch series and not a fork

**35 files, 2973 insertions, 8 deletions** (11 new files). The 8 deletions are
short rewritten lists — five `task_runs` partial-index predicates that gain
`'sprites', 'lizard'`, the controller's provider import, and two standby-provider
constant arrays. Everything else is a pure insert next to an existing
provider's insert point, so `git am --3way` rarely conflicts.

## Series order

The series is a stack. Lizard builds on Sprites because both touch the same
registration anchors:

| Patch | Provider | Depends on |
|---|---|---|
| `0001`–`0003` | Fly.io Sprites client | upstream `develop` |
| `0004`–`0006` | Lizard client | `0001`–`0003` |
| `0007` | Lizard worker bootstrap, settings, docs | `0001`–`0006` |

Apply all seven for Lizard. To take only the Sprites client, stop after `0003`.

## Files touched

| File | Sprites | Lizard |
|---|---|---|
| `packages/types/.../compute-provider.ts` | +13 | +14 |
| `packages/types/.../capabilities.ts` | +30 | +27 |
| `packages/types/.../worker-context.ts` | +2 | +2 |
| `packages/types/.../setup-compute-config.ts` | — | +150 |
| `packages/compute-providers/src/types.ts` | +26 | +26 |
| `packages/compute-providers/src/adapters/sprites.ts` | **new**, 836 | — |
| `packages/compute-providers/src/adapters/lizard.ts` | — | **new**, 695 |
| `packages/compute-providers/src/lizard/create-lizard-machine.ts` | — | **new**, 302 |
| `packages/compute-providers/src/worker-env/lizard.ts` | — | **new**, 33 |
| `packages/compute-providers/src/factory.ts` | +39 | +52 |
| `apps/controller/src/compute-providers/spawn-lizard-worker.ts` | — | **new**, 372 |
| `apps/docs/providers/compute/lizard.mdx` | — | **new**, 127 |

Every edit lands next to an existing provider's insert point. Upstream touches
those regions when adding a provider — the same frequency you add one.

## Apply

```bash
cd /path/to/Roomote
git checkout -b feat/providers origin/develop
git am --3way /path/to/roomote-provider-patches/patches/*.patch
```

## Update after upstream moves

```bash
ROOMOTE_REPO=/path/to/Roomote ./sync.sh
```

Rebuilds the branch from `origin/develop` and replays the series. On conflict it
stops and prints the resume steps.

## Regenerate after editing

```bash
cd /path/to/Roomote
git format-patch origin/develop..HEAD -o /path/to/roomote-provider-patches/patches --no-signature
```

## Drift detection

`.github/workflows/verify.yml` clones Roomote `develop`, applies the series with
`git am --3way`, and fails on drift. Runs on push, weekly, and on demand.

## Configuration

### Lizard

| Env var | Required | Notes |
|---|---|---|
| `LIZARD_API_KEY` | yes | `liz_` key |
| `LIZARD_PROJECT` | yes | sandboxes bill to a project |
| `LIZARD_API_URL` | no | defaults to the cloud |
| `LIZARD_TEMPLATE` | no | catalog template, defaults to `interpreter` (ships Node 22) |
| `LIZARD_SIZE` | no | `nano`…`big`, else raised to fit the task's memory |
| `LIZARD_TIMEOUT_MS` | no | defaults to 2 hours |
| `LIZARD_STANDBY_MAX_COUNT` | no | defaults to 10 paused sandboxes |
| `LIZARD_STANDBY_MAX_AGE_HOURS` | no | defaults to 168 |

### Fly.io Sprites

| Env var | Required | Notes |
|---|---|---|
| `SPRITE_TOKEN` | yes | Sprites API token |
| `SPRITES_API_BASE_URL` | no | defaults to `https://api.sprites.dev` |
| `SPRITES_ORGANIZATION` | no | |
| `SPRITES_TIMEOUT_MS` | no | |
| `SPRITES_SIZE` | no | `small` \| `default` \| `large` |

## How the Lizard worker is installed

Lizard has no custom-template upload flow, so the worker cannot be baked into a
template during Roomote setup. Patch `0007` installs it at boot instead:

1. Create or restore the sandbox from a catalog template.
2. Upload the worker release archive and the shipped `install-worker.sh` through
   the Lizard filesystem API.
3. Run `install-worker.sh` and fail the spawn on a non-zero exit code.
4. Destroy the sandbox on install failure; leave it paused on preview failure.

Snapshot forks reinstall the worker so the sandbox matches the current runtime
protocol. Standby resumes reuse the existing install.

## Known limits

### Lizard

1. **No custom templates.** Worker install happens at boot, which adds a few
   seconds to each fresh and forked sandbox.
2. **Snapshots are project-scoped.** Restore works only in the snapshot's own
   project and region — fine for single-project deployments, not for
   cross-project fan-out.
3. **No Docker projects.** Catalog templates ship Node, git, and Python but no
   Docker daemon, so `supportsDockerProjects` is `false`.
4. **One HTTP port exposed per call.** `exposePort` is called per requested port;
   multi-port previews work, but each call returns its own token-bearing URL.

### Fly.io Sprites

1. **No snapshots.** The checkpoint API restores into the *source* Sprite, so it
   cannot back Roomote's snapshot-then-fork contract. Wired as standby-resume.
2. **Single URL per sandbox.** Multi-port previews need a service registry;
   `resolveDomains` only maps ports the Sprite URL or a registered service
   serves.
3. **Exit codes require a sentinel.** The simple HTTP exec endpoint has no
   exit-code channel, so attached commands are wrapped in a shell that prints
   `__ROOMOTE_EXIT__<n>`.
4. **No stderr split.** HTTP exec multiplexes streams; `stderr` is always empty.
5. **No worker bootstrap.** The provider cannot spawn a task until
   `create-sprites-machine.ts` and `spawn-sprites-worker.ts` land.
