# Documentation: https://just.systems/man/en/

set shell := ["nu", "-c"]

# Print this help
help:
    @just -l

# Format Justfile
format:
    @just --fmt --unstable

# Run and watch application for development purposes
dev:
    pnpm run server

# Build dev
build-dev:
    pnpm run dev

# Build prod
build-prod:
    #!/usr/bin/env nu
    pnpm run build
    pnpm run sign --rootUrls https://identiops.com
    let id = (open src/plugin.json | $in.id)
    let archive = $"($id)-(open src/plugin.json | $in.info.version).zip"
    mv dist $id
    ^zip $archive $id -r
    mv $id dist
    mv $archive dist

# Create a new release of this module. LEVEL can be one of: major, minor, patch, premajor, preminor, prepatch, or prerelease.
release LEVEL="patch":
    #!/usr/bin/env nu
    if (git rev-parse --abbrev-ref HEAD) != "main" {
      print -e "ERROR: A new release can only be created on the main branch."
      exit 1
    }
    if (git status --porcelain | wc -l) != "0" {
      print -e "ERROR: Repository contains uncommited changes."
      exit 1
    }
    let current_version = (git describe | str replace -r "-.*" "" | npx semver $in)
    let new_version = ($current_version | npx semver -i "{{ LEVEL }}" $in)
    print "\nChangelog:\n"
    git cliff --strip all -u -t $new_version
    input -s $"Version will be bumped from ($current_version) to ($new_version).\nPress enter to confirm.\n"
    open package.json | upsert version $new_version | save -f package.json
    open src/plugin.json | upsert info.version $new_version | save -f src/plugin.json
    open src/plugin.json | upsert info.version $new_version | save -f src/plugin.json
    open provisioning/dashboards/dashboard.json | upsert panels.0.pluginVersion $new_version | save -f provisioning/dashboards/dashboard.json
    just build-prod
    git add package.json
    git add src/plugin.json
    git add provisioning/dashboards/dashboard.json
    git cliff -t $new_version -o CHANGELOG.md
    git add CHANGELOG.md
    git commit -m $"Bump version to ($new_version)"
    git tag -s -m $"v($new_version)" $"v($new_version)"
    git push --atomic origin refs/heads/main $"refs/tags/v($new_version)"
    let archive = $"dist/(open src/plugin.json | $in.id)-(open src/plugin.json | $in.info.version).zip"
    sha256sum $archive | save $"($archive).sha256sum"
    sha1sum $archive | save $"($archive).sha1sum"
    md5sum $archive | save $"($archive).md5sum"
    git cliff --strip all --current | gh release create -F - $new_version $archive $"($archive).sha256sum" $"($archive).sha1sum" $"($archive).md5sum"
