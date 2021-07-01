# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

<!--
## [Unreleased]

### Added

### Changed

### Fixed

### Removed
-->

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
[Unreleased]: https://github.com/simp/github-action-build-and-sign-pkg-single-rpm/compare/2.0.0...HEAD
