# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2025-11-03

### Changed

- Updated to Lune v0.10.4
- Updated dependencies
- Now available as a binary package instead of as a script package

### Fixed

- cwd option not working from the library when sent as a path object

## [0.1.2] - 2025-08-25

### Changed

- Stop depending on stderr to detect error with scripts ([#6](https://github.com/ewd3v/lune_darklua_build/pull/6))

### Fixed

- Fix getting cwd option ([#5](https://github.com/ewd3v/lune_darklua_build/pull/5))

## [0.1.1] - 2025-05-24

### Added

- Added build scripts, which are specified with the `scripts` option.

### Removed

- Removed the jiwonz/pesde_exec package (deprecated). Darklua now has to be installed in order to use.

## [0.1.0] - 2025-05-08

Initial release

[unreleased]: https://github.com/ewd3v/lune_darklua_build/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/ewd3v/lune_darklua_build/compare/v0.1.2...v0.2.0
[0.1.2]: https://github.com/ewd3v/lune_darklua_build/compare/e2d8d914149f1049407bb9896944f32261af1c17...v0.1.2
[0.1.1]: https://github.com/ewd3v/lune_darklua_build/compare/7ecaa0c6df9d50ec5a15fc2beb90819b03892c41...e2d8d914149f1049407bb9896944f32261af1c17
[0.1.0]: https://github.com/ewd3v/lune_darklua_build/compare/61acebdbcc80815de2d9ad74b2ba4281bad7493b...7ecaa0c6df9d50ec5a15fc2beb90819b03892c41
