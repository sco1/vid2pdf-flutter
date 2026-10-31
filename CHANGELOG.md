# Changelog
Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html) (`<major>`.`<minor>`.`<patch>`)

## [v1.0.0]
### Added
* #3 Add a button to abort the currently running pipeline
* #3 Terminate running FFmpeg process if application window is closed during execution

### Changed
* #4 Pipeline errors are now surfaced as a popup dialog rather than being discarded
* Pipeline now aborts if FFmpeg executable isn't found or exits with a non-zero status
* Temporary frames are now extracted to the system temp directory rather than next to the source video
* Disable macOS App Sandbox entitlement to allow invoking host FFmpeg and writing output PDFs
* PDF generation is now disabled until a valid FFmpeg executable has been resolved
* FFmpeg specification now additionally accepts a path to the executable, or a directory containing it up to two levels deep (e.g. `<dir>/ffmpeg.exe`, `<dir>/bin/ffmpeg.exe`)
* Default frame format has been switched from PNG to JPEG
* JPEG frames are now explicitly extracted at high quality (`-q:v 2`) rather than FFmpeg's bitrate-based default
* start/end timestamps are now passed to FFmpeg as input seeks rather than output seeks; this should provide a significant speedup for deep starting times as leading video decoding is skipped

### Fixed
* Temporary frame directory should be cleaned up if pipeline exits unexpectedly
* Fix FFmpeg resolution when using `ffmpeg` from system `PATH` or reading `FFMPEG_PATH` from system environment variables
* Fix click-to-browse selection in drop target not enabling the conversion button or validating file type
* All UI controls (besides the cancel button) are now disabled while the conversion pipeline is running

## [v0.1.0]
Initial release 🎉
