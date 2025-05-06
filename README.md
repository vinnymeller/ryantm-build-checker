# Nixpkgs Package Status Checker

A GitHub workflow that monitors the build status of packages you maintain in nixpkgs by checking r.ryantm logs.

## Purpose

[r-ryantm](https://r.ryantm.com/log/) is a bot that runs automated update scripts for nixpkgs. When successful, it creates PRs and tags maintainers. However, when updates fail, they fail silently (as far as I know) - leaving maintainers potentially unaware of available upstream updates.

This project:
1. Identifies all packages maintained by a specific maintainer handle
2. Checks the r-ryantm logs for each package
3. Creates GitHub issues when:
   - Build failures are detected
   - Log pages are missing (possibly indicating a missing or misconfigured update script)

## Setup

1. Fork this repository or copy it to your own account
2. Configure repository variables:
   - `MAINTAINER_HANDLE`: Your Nixpkgs maintainer handle (required)
   - `IGNORE_PKGS`: Comma-separated list of packages to ignore (optional)
   - `EXTRA_PACKAGE_SETS`: Comma-separated list of additional package sets to search in (optional)

Example:
```
MAINTAINER_HANDLE: vinnymeller
IGNORE_PKGS: ltex-ls,jetbrains-mono
EXTRA_PACKAGE_SETS: haskellPackages,nodePackages,python312Packages
```

3. The workflow runs daily at 8:00 UTC by default, or you can trigger it manually

## How it Works

The workflow:
1. Clones the latest nixpkgs repository
2. Uses `find_maintained.nix` to identify packages you maintain
3. For each package:
   - Checks r-ryantm logs for build failures
   - Skips packages listed in IGNORE_PKGS
   - Creates GitHub issues for failures or missing logs

This helps you stay informed about packages that need attention without having to manually monitor each one.
