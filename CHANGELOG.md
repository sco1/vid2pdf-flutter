# Changelog
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) (`<major>`.`<minor>`.`<patch>`)

## [v1.0.0]
### Added
* #3 Add a button to abort the currently running pipeline
* #3 Terminate running FFmpeg process if application window is closed during execution

### Changed
* #4 Pipeline errors are now surfaced as a popup dialog rather than being discarded
* Pipeline now aborts if FFmpeg executable isn't found or exits with a non-zero status

### Fixed
* Temporary frame directory should be cleaned up if pipeline exits unexpectedly
* Fix FFmpeg resolution when using `ffmpeg` from system `PATH` or reading `FFMPEG_PATH` from system environment variables
* Fix click-to-browse selection in drop target not enabling the conversion button or validating file type

## [v0.1.0]
Initial release 🎉
