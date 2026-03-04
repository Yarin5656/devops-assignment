# Git Branching Strategy

## Branch Model

```
main          ─────────────────────────────────────────────► (production releases)
               ↑                                   ↑
develop       ─┬─────────────────────────────────┬─►  (integration branch)
               ↑         merge PR                ↑
feature/*    ──┘   feature/my-feature ────────────┘
hotfix/*     ──────────────────────────────────────► (fast-fix → main + develop)
release/*    ──────────────────────────────────────► (freeze → tag → main)
```

### Branch Definitions

| Branch | Purpose | Lifetime | Direct push |
|--------|---------|----------|-------------|
| `main` | Production-ready code; maps 1:1 to production deploy | Permanent | ❌ PR only |
| `develop` | Integration branch; auto-deploys to staging | Permanent | ❌ PR only |
| `feature/<ticket>-<slug>` | New work (e.g. `feature/US-42-add-analytics`) | Until merged | ✅ |
| `hotfix/<slug>` | Urgent fixes; merges to both main + develop | Until merged | ✅ |
| `release/<semver>` | Release freeze (e.g. `release/1.3.0`) | Until tagged | ✅ |

---

## Flow: Feature → Develop → Main → Production

```
1. Developer creates branch from develop:
   git checkout develop && git pull
   git checkout -b feature/US-42-url-analytics

2. Push and open Pull Request → develop
   - Required checks: lint ✓, tests ✓, coverage ≥ 80% ✓, Trivy scan ✓
   - At least 1 reviewer approval

3. Merge to develop → CI auto-deploys to staging namespace

4. QA validates staging

5. Release cut:
   git checkout -b release/1.3.0 develop
   # bump version, finalize CHANGELOG
   git tag -s v1.3.0 -m "Release 1.3.0"
   git push origin release/1.3.0 --tags

6. Tag push triggers CD → production (with manual approval gate in GitHub)

7. Merge release/* → main AND back-merge → develop
```

---

## Branch Protection Rules

Configure in **GitHub → Settings → Branches → Branch protection rules**.

### `main`
- ✅ Require pull request before merging
- ✅ Require 2 approvals
- ✅ Dismiss stale pull request approvals when new commits are pushed
- ✅ Require status checks: `lint`, `test`, `security-scan`
- ✅ Require branches to be up-to-date before merging
- ✅ Restrict pushes to release managers only
- ✅ Require signed commits (optional but recommended)
- ❌ No force pushes

### `develop`
- ✅ Require pull request before merging
- ✅ Require 1 approval
- ✅ Require status checks: `lint`, `test`, `security-scan`

---

## Tagging & Release Strategy

### Format
```
v<MAJOR>.<MINOR>.<PATCH>[-<PRERELEASE>]
```

Examples:
- `v1.0.0` – stable release
- `v1.1.0-rc.1` – release candidate
- `v1.0.1` – patch/hotfix

### Image Tags
Each git tag `v1.2.3` produces Docker images:
```
ghcr.io/<org>/url-shortener:1.2.3
ghcr.io/<org>/url-shortener:1.2.3-abc1234   (with git SHA)
ghcr.io/<org>/url-shortener:1.2             (minor alias)
ghcr.io/<org>/url-shortener:latest          (main only)
```

### Tags → Deployments Mapping

| Git event | Image tag | Deploy target |
|-----------|-----------|---------------|
| push to `develop` | `develop-<sha7>` | Staging (automatic) |
| push to `main` | `main-<sha7>` | Staging (automatic) |
| push tag `v*.*.*` | `<semver>` + `<semver>-<sha7>` | Production (manual approval) |

### Semver Rules
- **PATCH** (1.0.x): bug fixes, dependency patches
- **MINOR** (1.x.0): new features, backward-compatible changes
- **MAJOR** (x.0.0): breaking API changes
