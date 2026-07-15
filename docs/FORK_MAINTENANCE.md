# Maintaining the newyorkthink/neowall fork

This repository is a fork of `1ay1/neowall`. The fork keeps its changes as
ordinary commits on top of upstream `main`, so future upstream work can be
merged normally.

## What this fork changes

- Connects configured `channels [...]` image files to multipass shader
  `iChannel0..3` inputs.
- Binds `CHANNEL_SOURCE_TEXTURE` during rendering and refreshes the binding
  when a cycling image replaces an existing texture.
- Publishes tested Debian 12, Ubuntu 22.04, and Ubuntu 24.04 `.deb` packages.

## Sync upstream safely

GitHub's **Sync fork** button is sufficient when GitHub reports no conflicts.
For a reviewable command-line sync, use a temporary branch and pull request:

```bash
git remote add upstream https://github.com/1ay1/neowall.git
git fetch upstream
git switch main
git pull --ff-only origin main
git switch -c sync/upstream-main
git merge upstream/main
git push -u origin sync/upstream-main
```

Open a pull request from `sync/upstream-main` to `main`, let all Actions checks
finish, then merge it. Do not force-push published release tags.

Conflicts, if any, should normally be limited to the external-texture code in:

- `src/output/output.c`
- `src/render/render.c`
- `src/shader/shader_multipass.c`
- `include/neowall/shader/shader_multipass.h`

Keep the fork's texture binding behavior when resolving those conflicts, then
run the normal Build and Quality workflows before merging.

## Publish a stable Debian-family release

1. Merge and validate all source changes on `main`.
2. Set the same semantic version in `meson.build` and `.github/RELEASE_DEB`.
3. Commit and push both version changes together.

Changing `.github/RELEASE_DEB` on `main` starts the release workflow. It builds
three packages, generates `SHA256SUMS.txt`, creates the matching `vX.Y.Z` tag,
and uploads everything to GitHub Releases. The workflow can also be run
manually from the Actions page with an explicit version.
