# Auto-Merge Dependency Bot Pull Requests

[![make](https://github.com/maxonfjvipon/deps-sentinel-action/actions/workflows/make.yml/badge.svg)](https://github.com/maxonfjvipon/deps-sentinel-action/actions/workflows/make.yml)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSES/MIT.txt)

This is a GitHub Action that scans open pull requests in the repository,
finds those opened by [Renovate](https://github.com/renovatebot/renovate) or
[Dependabot](https://docs.github.com/en/code-security/dependabot), and merges
them automatically when CI is green. If the build is red, it posts a comment
tagging the repository owner — but only once per pull request, to avoid spam.
Use it like this:

```yaml
name: renovate-merge
'on':
  schedule:
    - cron: '0 6,12,18,0 * * *'
  workflow_dispatch:
jobs:
  merge:
    runs-on: ubuntu-latest
    steps:
      - uses: maxonfjvipon/deps-sentinel-action@0.0.2
        with:
          token: ${{ secrets.RENOVATE_MERGE_TOKEN }}
          owner: octocat
```

The `owner` is the GitHub handle that gets `@mentioned` in a comment posted
by `github-actions[bot]` when CI is failing. The `token` must be a
[Personal Access Token](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
of the repository owner — it is used to post the `@rultor merge` command as
the owner when Rultor is in use, and to merge the pull request directly
otherwise.

If the repository has a `.rultor.yml` file, the merge is initiated by posting
a `@rultor merge` comment as the repository owner. Otherwise, the pull request
is merged directly via the GitHub API.

A more fine-grained configuration is also possible:

```yaml
- uses: maxonfjvipon/deps-sentinel-action@0.0.1
  with:
    token: ${{ secrets.RENOVATE_MERGE_TOKEN }}
    owner: octocat
    bot-logins: |
      renovate[bot]
      dependabot[bot]
      snyk-bot
    merge-method: merge
    rultor: auto
    required-checks: build,test
    dry-run: false
```

| Input | Default | Description |
| --- | --- | --- |
| `token` | — | PAT of the repo owner (required) |
| `owner` | — | GitHub handle to `@mention` on CI failure (required) |
| `bot-logins` | `renovate[bot]`, `dependabot[bot]` | Newline-separated list of dependency bot logins to watch |
| `merge-method` | `merge` | Merge method when not using Rultor |
| `rultor` | `auto` | `auto` detects `.rultor.yml`, `true` forces it, `false` disables it |
| `required-checks` | _(all)_ | Comma-separated checks that must pass; empty means all |
| `dry-run` | `false` | Log actions without posting comments or merging |

## How to Contribute

Fork repository, make changes, then send us a [pull request][guidelines].
We will review your changes and apply them to the `master` branch shortly,
provided they don't violate our quality standards. To avoid frustration,
before sending us your pull request please make sure all your tests pass:

```bash
make
```

You will need GNU [make] and [bats-core] installed.

## License

Copyright (c) 2026 Max Trunnikov. MIT License.

[guidelines]: https://www.yegor256.com/2014/04/15/github-guidelines.html
[make]: https://www.gnu.org/software/make/manual/make.html
[bats-core]: https://bats-core.readthedocs.io
