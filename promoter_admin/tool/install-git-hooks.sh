#!/bin/sh
# Point this repo's git hooks at promoter_admin/tool/git-hooks (version sync on commit).
set -eu
root=$(git rev-parse --show-toplevel)
cd "$root"
git config core.hooksPath promoter_admin/tool/git-hooks
echo "Git hooks installed (core.hooksPath=promoter_admin/tool/git-hooks)"
echo "Commits that change pubspec.yaml will auto-update native/AppVersion.xcconfig."
