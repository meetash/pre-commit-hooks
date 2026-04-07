# meetash/pre-commit-hooks

Shared [pre-commit](https://pre-commit.com) hooks for Ash Engineering Python services.

## Usage

Add to your `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/meetash/pre-commit-hooks
    rev: v1.0.0  # use the latest tag
    hooks:
      - id: sync-sonar-test-exclusions
      - id: format
      - id: validate
```

Then install the hooks in your repo:

```bash
lets precommit
```

## Hooks

### `sync-sonar-test-exclusions`

Keeps `sonar.test.exclusions` in `sonar-project.properties` in sync with the `[tool.coverage.run] omit` list in `pyproject.toml`.

- Runs when `pyproject.toml` or `sonar-project.properties` is staged
- Auto-updates and stages `sonar-project.properties` if it is out of sync
- Do not edit `sonar.test.exclusions` manually — edit `pyproject.toml` instead

### `format`

Runs `lets fmt` to auto-format Python files.

- Runs when any Python file is staged

### `validate`

Runs `lets val` to lint and type-check Python files.

- Runs when any Python file is staged
- Requires `lets` CLI to be installed ([installation guide](https://lets-cli.org/docs/installation))

## Releasing a new version

```bash
git tag v1.x.0
git push origin v1.x.0
```

Then bump `rev:` in the consuming repos.
