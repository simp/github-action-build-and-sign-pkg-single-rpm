# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).



## [Unreleased]

### Added

- New env var `$CONTAINER_EXE` sets container to either `docker` or `podman`
  (default: `docker`)

### Changed

- Only process/copy the top-level `dist/*.rpm` files (only those files are
  signed)

### Fixed

- Summary of built RPMs is now legible


## [2.3.0] - 2021-12-16

### Added

- RPMs are now built with verbose logging when input `verbose` is `yes`

## [2.2.0] - 2021-07-09

### Added

- RPMs are now built and signed from separate containers
- RPMs can now be built from the EL7 RPM build container


## [2.1.0] - 2021-07-07

### Fixed

- Update simp-rake-helpers to the latest version (with conservative dep
  updates) before building.


## [2.0.0] - 2021-07-01

### Added

- Support and tests for:
  - Non-module asset RPMs (e.g., repos with their own Rakefile and RPM .spec)
  - Multiple RPM files
  - .src.rpm files
  - Public GPG keys for RPM signatures
- New output variables:
  - `rpm_file_paths`
  - `rpm_gpg_files`
  - `rpm_dist_dir`
- Updated README example to reflect ~~`@v1`~~ `@v2` release

### Removed

- Output variables:
  - `rpm_file_path`
  - `rpm_file_basename`


## [1.0.0] - 2021-06-25

Initial release!

### Added

- GitHub action to build and sign an RPM using `pkg:single`
- GitHub repo project (README, Rakefile, etc)
- GHA workflow tests for the GitHub action
- This changelog

[1.0.0]: https://github.com/simp/github-action-build-and-sign-pkg-single-rpm/releases/tag/1.0.0
[2.0.0]: https://github.com/simp/github-action-build-and-sign-pkg-single-rpm/compare/1.0.0...2.0.0
[2.1.0]: https://github.com/simp/github-action-build-and-sign-pkg-single-rpm/compare/2.0.0...2.1.0
[2.2.0]: https://github.com/simp/github-action-build-and-sign-pkg-single-rpm/compare/2.1.0...2.2.0
[2.3.0]: https://github.com/simp/github-action-build-and-sign-pkg-single-rpm/compare/2.2.0...2.3.0
[Unreleased]: https://github.com/simp/github-action-build-and-sign-pkg-single-rpm/compare/2.3.0...HEAD
