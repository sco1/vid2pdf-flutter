# Changelog
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) (`<major>`.`<minor>`.`<patch>`)

## [v1.0.0]
### Added
* #3 Add a button to abort the currently running pipeline

### Changed
* #4 Pipeline errors are now surfaced as a popup dialog rather than being discarded
* Pipeline now aborts if FFmpeg executable isn't found

### Fixed
* Temporary frame directory should be cleaned up if pipeline exits unexpectedly

## [v0.1.0]
Initial release 🎉
