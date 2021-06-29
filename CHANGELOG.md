# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

### Added

- Add support and tests for:
  - non-module asset RPMs (e.g., repos with their own Rakefile and RPM .spec)
  - `pkg:single` builds of multiple RPMs (includes src RPMs)
- Now exports GPG public key used to validate signed RPMs
- New output variables:
  - `rpm_dist_dir`
  - `gpg_file_path`
  - `gpg_file_basename`
- Updated README example to reflect `@v1` release

## [1.0.0] - 2021-06-25

Initial release!

### Added

- GitHub action to build and sign an RPM using `pkg:single`
- GitHub repo project (README, Rakefile, etc)
- GHA workflow tests for the GitHub action
- This changelog

[1.0.0]: https://github.com/simp/github-action-build-and-sign-pkg-single-rpm/releases/tag/1.0.0
[Unreleased]: https://github.com/simp/github-action-build-and-sign-pkg-single-rpm/compare/1.0.0...HEAD
