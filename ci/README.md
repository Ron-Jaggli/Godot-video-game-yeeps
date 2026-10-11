`debug.keystore` signs the debug APKs built by GitHub Actions
(`.github/workflows/build.yml`). It's a standard Android debug key (alias
`androiddebugkey`, password `android`). It's committed so every build is
signed the same way and installs over the previous one without wiping saves.

Never use it for a store release. Release builds need a private keystore
kept out of the repo.
