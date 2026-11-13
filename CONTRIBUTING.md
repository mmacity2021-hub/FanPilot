# Contribuer

## Prérequis

- Rust stable (`rustup`)
- Node.js 20+
- `flatpak-builder`

## Workflow

1. Fork
2. `git checkout -b feat/ma-fonctionnalite`
3. Commits au format [Conventional Commits](https://www.conventionalcommits.org/)
4. `./scripts/build-flatpak.sh` doit passer
5. PR avec description claire

## Style

- Rust : `cargo fmt`, `cargo clippy -- -D warnings`
- JS/TS : `npm run lint`
- Commits : `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`

## Review

Toute PR nécessite au moins une review. Voir [GOVERNANCE.md](GOVERNANCE.md).
