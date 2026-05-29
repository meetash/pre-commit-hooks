# meetash/pre-commit-hooks

Shared [pre-commit](https://pre-commit.com) hooks for Ash Engineering Python services.

## Usage

Add to your `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/meetash/pre-commit-hooks
    rev: v2.0.0  # use the latest tag
    hooks:
      - id: sync-sonar-coverage-exclusions
      - id: gitleaks
      - id: check-charset
      - id: format
      - id: validate
```

Then install the hooks in your repo:

```bash
lets precommit
```

## Hooks

### `sync-sonar-coverage-exclusions`

Keeps `sonar.coverage.exclusions` in `sonar-project.properties` in sync with the `[tool.coverage.run] omit` list in `pyproject.toml` (so Sonar coverage matches what Coverage omits).

- Runs when `pyproject.toml` or `sonar-project.properties` is staged
- Auto-updates and stages `sonar-project.properties` if it is out of sync
- Do not edit `sonar.coverage.exclusions` manually — edit `pyproject.toml` instead

Upgrading from v1.x: replace the hook id `sync-sonar-test-exclusions` with `sync-sonar-coverage-exclusions`, bump `rev:` to `v2.0.0`, and remove any stale `sonar.test.exclusions` line from `sonar-project.properties` if the old hook added one.

### `gitleaks`

Runs `gitleaks git --pre-commit --staged . --redact --verbose` to detect secrets in staged changes before they are committed.

- Runs once per commit, not once per file
- Uses `.gitleaks.toml` from the consuming repository when present
- Requires the `gitleaks` binary to be installed locally

Install `gitleaks` before enabling this hook:

- macOS: `brew install gitleaks`
- Ubuntu/Debian: `sudo apt install gitleaks`
- Other Linux distributions: use your distro package manager if available, or download a release from [gitleaks releases](https://github.com/gitleaks/gitleaks/releases)

If a finding is a confirmed false positive, allow it in the consuming repository's `.gitleaks.toml` or with an inline `gitleaks:allow` comment.

### `check-charset`

Fails if staged text files contain Unicode characters that often break tooling or review, such as smart quotes, non-breaking spaces, zero-width characters, or bidi marks.

- Runs only on staged text files
- Replace reported characters with ASCII equivalents before committing

### `format`

Runs `lets fmt` to auto-format Python files.

- Runs when any Python file is staged

### `validate`

Runs `lets val` to lint and type-check Python files.

- Runs when any Python file is staged
- Requires `lets` CLI to be installed ([installation guide](https://lets-cli.org/docs/installation))

## Releasing a new version

```bash
git tag v2.x.0
git push origin v2.x.0
```

Then bump `rev:` in the consuming repos.
