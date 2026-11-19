# Roomote provider patches

Out-of-tree integrations that add **Fly.io Sprites** and **Lizard** as Roomote
compute providers, shipped as an additive-only patch series so upstream can be
tracked without maintaining a fork.

The repo name still says "sprites" from the first cut. Rename with
`gh repo rename roomote-provider-patches` if you want it to match.

## Why a patch series and not a fork

**1686 added lines, 0 deletions, 10 files** (2 new files, 8 additive
insertions). That shape matters: `git am --3way` almost never conflicts on pure
insert hunks. Deletions are what break rebases. There are none.

## Series order

The series is a stack. Lizard builds on Sprites because both touch the same
registration anchors:

| Patch | Provider | Depends on |
|---|---|---|
| `0001`–`0003` | Fly.io Sprites | upstream `develop` |
| `0004`–`0006` | Lizard | `0001`–`0003` |

Apply all six for both providers. To take only Sprites, stop after `0003`.

## Files touched

| File | Sprites | Lizard |
|---|---|---|
| `packages/types/.../compute-provider.ts` | +13 | +14 |
| `packages/types/.../capabilities.ts` | +30 | +26 |
| `packages/types/.../worker-context.ts` | +2 | +2 |
| `packages/compute-providers/src/types.ts` | +26 | +26 |
| `packages/compute-providers/src/adapters/sprites.ts` | **new**, 836 | — |
| `packages/compute-providers/src/adapters/lizard.ts` | — | **new**, 528 |
| `packages/compute-providers/src/adapters/index.ts` | +1 | +1 |
| `packages/compute-providers/src/index.ts` | +1 | +1 |
| `packages/compute-providers/src/factory.ts` | +39 | +52 |
| `packages/compute-providers/package.json` | — | +1 |

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

### Fly.io Sprites

| Env var | Required | Notes |
|---|---|---|
| `SPRITE_TOKEN` | yes | Sprites API token |
| `SPRITES_API_BASE_URL` | no | defaults to `https://api.sprites.dev` |
| `SPRITES_ORGANIZATION` | no | |
| `SPRITES_TIMEOUT_MS` | no | |
| `SPRITES_SIZE` | no | `small` \| `default` \| `large` |

### Lizard

| Env var | Required | Notes |
|---|---|---|
| `LIZARD_API_KEY` | yes | `liz_` key |
| `LIZARD_PROJECT` | yes | sandboxes bill to a project |
| `LIZARD_API_URL` | no | defaults to the cloud |
| `LIZARD_TEMPLATE` | no | catalog template, defaults to `base` |
| `LIZARD_TIMEOUT_MS` | no | |
| `LIZARD_SIZE` | no | `nano`…`big`, else derived from memory |

## Known limits

### Sprites

1. **No snapshots.** The checkpoint API restores into the *source* Sprite, so it
   cannot back Roomote's snapshot-then-fork contract. Wired as standby-resume.
2. **Single URL per sandbox.** Multi-port previews need a service registry;
   `resolveDomains` only maps ports the Sprite URL or a registered service
   serves.
3. **Exit codes require a sentinel.** The simple HTTP exec endpoint has no
   exit-code channel, so attached commands are wrapped in a shell that prints
   `__ROOMOTE_EXIT__<n>`.
4. **No stderr split.** HTTP exec multiplexes streams; `stderr` is always empty.

### Lizard

1. **No custom templates.** The public CLI has no template upload flow. The
   worker must be installed into a catalog template at boot, or baked into a
   snapshot and restored.
2. **Snapshots are project-scoped.** Restore works only in the snapshot's own
   project and region — fine for single-project deployments, not for
   cross-project fan-out.
3. **Detached commands still use a sentinel.** Attached commands use the SDK's
   native exit code; detached ones append to a log file and carry the sentinel.

### Both

The worker bootstrap (`create-*-machine.ts`) and controller dispatch
(`spawn-*-worker.ts`) are **not in this series yet**. The clients are complete
and type-checked; the providers cannot run a task end to end until those land.
