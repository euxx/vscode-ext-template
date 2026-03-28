# vscode-ext-template

Template repository for VS Code extensions. Contains shared tooling configuration.

## What's Shared

| File                            | Purpose                                |
| ------------------------------- | -------------------------------------- |
| `.husky/pre-commit`             | Pre-commit hook: runs lint-staged      |
| `.gitignore`                    | Ignore patterns for git                |
| `.oxlintrc.json` (optional)     | oxlint rules (zero-config by default)  |
| `.vscode/launch.json`           | VS Code debug launch configuration     |
| `AGENTS.md`                     | Copilot agent conventions              |
| `.vscodeignore`                 | Files excluded from packaged extension |
| `DEVELOPMENT.md`                | Development setup and scripts          |
| `RELEASE.md`                    | Release process                        |
| `.github/workflows/ci.yml`      | GitHub CI workflow                     |
| `.github/workflows/release.yml` | GitHub release workflow                |

## Creating a New Extension

```bash
# Clone this template
git clone https://github.com/PUBLISHER/vscode-ext-template my-extension
cd my-extension

# Remove template git history
rm -rf .git && git init && git add -A && git commit -m "chore: init from template"

# Install dependencies (resolves to latest stable versions)
npm install

# Edit package.json: set name, displayName, description, publisher, version
# Add your source files in src/ and tests/
```

### Checklist: places to update after cloning

| File                                       | What to change                                                      |
| ------------------------------------------ | ------------------------------------------------------------------- |
| `package.json`                             | `name`, `displayName`, `description`, `publisher`, `repository.url` |
| `LICENSE`                                  | `YEAR` and `extension-name` in the copyright line                   |
| `.github/workflows/release.yml`            | Two occurrences of `extension-name` in the vsix filename            |
| `CHANGELOG.md`                             | Replace `YYYY-MM-DD` with the actual release date                   |
| `RELEASE.md` (after `<!-- END-SHARED -->`) | Replace GitHub compare URL with your full changelog link            |
| `README.md`                                | Replace this file entirely with your extension's documentation      |
| `images/icon.png`                          | Add your extension icon (see [Icon Spec](#icon-spec) below)         |

## Syncing Config Updates to Existing Projects

When shared config files change, run the sync script for each extension:

```bash
./scripts/sync.sh /path/to/my-extension

./scripts/sync.sh ~/projects/editor-tweaks
./scripts/sync.sh ~/projects/github-copilot-usage
./scripts/sync.sh ~/projects/github-copilot-buddy
./scripts/sync.sh ~/projects/claude-skills-for-copilot
```

The script shows a diff for each changed file and asks for confirmation before copying.

## Icon Spec

All icons follow this standard:

| Property        | Value                               |
| --------------- | ----------------------------------- |
| Canvas          | 128×128 px                          |
| Background rect | `x=4 y=4 width=120 height=120`      |
| Corner radius   | `rx=24 ry=24`                       |
| Background fill | `#222222`                           |
| Border          | `stroke="#444444" stroke-width="2"` |
| Export size     | 400×400 PNG (1x Retina)             |

## License

Under the [MIT](LICENSE) License.
