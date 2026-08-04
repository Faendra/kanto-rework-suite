# Distribution and Gen1Recomp auto-update

## Importable ZIP contract

The ZIP passed to Gen1Recomp must contain `manifest.json` at the archive root.
It must not contain another ZIP or wrap the package in an extra top-level
`kanto_rework_core/` directory.

The exact release asset name is:

```text
kanto_rework_core-<version>.zip
```

The CI workflow now produces two artifacts:

- `kanto_rework_core-p0`: the downloaded GitHub Actions artifact itself is
  directly importable and contains `manifest.json` at its root;
- `kanto_rework_core-release-zip`: a developer artifact containing the exact
  release ZIP as a nested file, intended for publishing rather than direct
  launcher import.

## Auto-update contract

The manifest declares:

```json
"github": "Faendra/kanto-rework-suite"
```

Gen1Recomp checks GitHub Releases for semantic-version tags and chooses a ZIP
asset, preferring `kanto_rework_core-<version>.zip`.

The `Publish Kanto Rework Core` workflow creates or updates such a release when
a tag matching this package version is pushed:

```text
kanto_rework_core-v<version>
```

## Private repository limitation

Gen1Recomp performs an unauthenticated GitHub Releases API request. A private
repository is not visible to that request. The manifest and release workflow
are ready, but in-launcher update checks will remain unavailable until either:

1. this repository becomes public; or
2. releases are mirrored to a separate public distribution repository and the
   manifest `github` field points to that public repository.
