# List available recipes.
default:
  just --list

# Apply source state to the target (~).
apply:
  chezmoi apply

# Diff source state against the target.
diff:
  chezmoi diff

# Show target files with pending changes.
status:
  chezmoi status

# Check for drift between source and target.
verify:
  chezmoi verify

# Sanity-check the chezmoi environment.
doctor:
  chezmoi doctor

# Pull from git remote and apply.
update:
  chezmoi update

# Render a template file to stdout.
render FILE:
  chezmoi execute-template < '{{ FILE }}'

# Lint all repo bash (plain + rendered templates).
lint:
  ./.dev/lint-bash.sh

# Auto-format all plain bash files in place.
fmt:
  git ls-files -- '*.sh' '*.bash' | grep --invert-match -E '(^|/)symlink_' | xargs --no-run-if-empty --max-args=50 shfmt --list --indent 2 --case-indent --binary-next-line --space-redirects --write

# Install the pre-commit git hooks.
hooks:
  pre-commit install

# Check that every chezmoidata paths.* entry exists under $HOME.
check-paths:
  ./.dev/check-paths.sh
