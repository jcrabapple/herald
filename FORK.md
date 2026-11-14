# Downstream fork

This is `jcrabapple/herald`, a **downstream fork** of [Giton22/kyllene](https://github.com/Giton22/kyllene)
(MIT). It tracks upstream and carries a small set of features that are not merged upstream yet, so they
can be built and shipped without waiting on upstream review. The upstream PRs stay open; if upstream
merges one, drop it from the stack here.

## Branch model

| Branch       | Role                                                              | How it moves                          |
|--------------|-------------------------------------------------------------------|---------------------------------------|
| `master`     | Pure mirror of `upstream/master`. Never carries local work.       | Fast-forward only, via the sync script |
| `downstream` | `master` + the feature stack. **Build and tag releases from here.** | Merge `master` in via the sync script  |
| `feat/*`     | The individual feature branches, mirroring the open upstream PRs. | Updated only when the feature changes  |

Keeping `master` a pure mirror means syncing it is always a clean fast-forward. All conflict resolution
happens on `downstream`, which is exactly where the local patches live.

## Feature stack (as of setup)

| Feature            | Branch                 | Upstream PR | Notes                                   |
|--------------------|------------------------|-------------|-----------------------------------------|
| Assistant profile  | `feat/assistant-profile` | #209      | Independent                              |
| Kanban viewer      | `feat/kanban-viewer`     | #411      | Already contained in `feat/widgets`      |
| Home-screen widgets| `feat/widgets`           | #412      | Stacked on kanban; merging it brings kanban |

So the integration is `master` + `feat/assistant-profile` + `feat/widgets`. Merging `feat/widgets`
already brings the kanban viewer; do not merge `feat/kanban-viewer` separately.

## Remotes

- `origin` = `https://github.com/Giton22/kyllene.git` (upstream)
- `fork`   = `git@github.com:jcrabapple/herald.git` (this repo)

## Sync with upstream

Upstream ships roughly weekly. Sync after each upstream release (or weekly). From the downstream
worktree (`~/projects/herald-downstream`):

```sh
./scripts/sync-upstream.sh --check   # report only: how far behind, nothing changed
./scripts/sync-upstream.sh           # fast-forward fork/master, merge upstream into downstream, push
```

The script refuses to reset `fork/master` if it ever has commits not in upstream. If the merge into
`downstream` conflicts, it stops and lists the conflicted files; resolve them, commit, and push. Never
force-push `master`. After a sync, verify CI on the pushed `downstream` head before tagging a release.

## Build and install (dev)

```sh
./gradlew :androidApp:installDev      # side-by-side dev build (dev.herald.android.dev)
```

A dev build has an empty `releasesRepo`, so it does not check for updates. That is fine for development.

## Ship a release

Releases are built by `.github/workflows/release.yml` when a `v*.*.*` tag is pushed. **Tag `downstream`,
not `master`.** The workflow already passes `-PreleasesRepo="$GITHUB_REPOSITORY"`, so a release built here
points the in-app update checker at this fork automatically — no code change needed.

Required repo secrets (Settings → Secrets and variables → Actions):

- `ANDROID_KEYSTORE_BASE64` — the release keystore, base64-encoded
- `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`

Without these the release job fails at the "Signing key" step. The signing key is **different from
upstream's**, so a fork APK installs fresh (it does not update in place over upstream Kyllene); sign-in
and settings are re-entered once. Desktop/Flatpak signing secrets are optional (see `release.yml`).

```sh
git checkout downstream
git tag v0.16.1 && git push fork v0.16.1   # drafts a release; publish it on GitHub
```

Use **plain `MAJOR.MINOR.PATCH` semver** with no suffix, sorting above the upstream release it is based
on. A `-fork.N` suffix breaks the build: `desktopApp`'s jpackage MSI package version must be pure
`MAJOR.MINOR.BUILD` integers and fails at configuration time (`Illegal version for 'Msi'`), which kills
the whole release job even though only the phone APK is wanted. Plain semver also keeps `versionCode`
(`major*10000 + minor*100 + patch`) increasing — a suffix is stripped before `versionCode` is computed, so
`-fork.1` → `-fork.2` would NOT raise it and the next release would not install over the last. Bump the
patch (or minor) for every fork release. Publishing the draft is what makes the app offer it as an update.

## Dropping a feature upstream merges

If upstream merges one of the open PRs, remove it from the stack: rebase `feat/widgets` to drop the
kanban commit if only #411 lands, or rebuild `downstream` from `master` without that feature branch.
Then close the corresponding upstream PR if it is fully superseded.