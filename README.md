<p align="center" width="100%">
<img width="200" src="https://raw.githubusercontent.com/sco1/vid2pdf-flutter/refs/heads/main/assets/icon/app_icon.png">
</p>
<h1 align="center"> vid2pdf </h1>

<p align="center">
<img alt="GitHub Release" src="https://img.shields.io/github/v/release/sco1/vid2pdf-flutter">
<img alt="Platform" src="https://img.shields.io/badge/Windows%20%7C%20MacOS%20%7C%20Linux-5353ff?logo=flutter&label=Platform&labelColor=3333ff">
<img alt="GitHub License" src="https://img.shields.io/github/license/sco1/vid2pdf-flutter?color=magenta">
</p>

Simple helper utility to convert a video file to PDF image series.

This is a sibling of my [`vid2pdf` Python CLI tool](https://github.com/sco1/vid2pdf).

<p align="center" width="100%">
<img width="60%" src="https://raw.githubusercontent.com/sco1/vid2pdf-flutter/refs/heads/main/doc/base_ui.png">
</p>

## Installation
### External Dependencies
#### FFmpeg
`vid2pdf` requires FFmpeg to be available on the host system. The latest version of FFmpeg can be downloaded from [ffmpeg.org](https://www.ffmpeg.org/download.html).

### Prebuilt Binaries
OS-specific binaries for all supported platforms are [built in CI](https://github.com/sco1/vid2pdf-flutter/blob/main/.github/workflows/release_artifacts.yml) for every tagged release. The latest release may be found [here](https://github.com/sco1/vid2pdf-flutter/releases/latest).

### Running From Source
With Flutter installed, obtain the source code by cloning this repository or downloading from a [tagged release](https://github.com/sco1/vid2pdf-flutter/releases/). You can then execute directly using `flutter run`, or build with `flutter build <platform>`.

## Usage
### FFmpeg Path
By default, `vid2pdf` assumes that FFmpeg is available in your system path. If this isn't an option, or you want to specify an alternate location, you can do so using the `FFMPEG_PATH` environment variable to specify FFmpeg's base directory (not the `/bin` directory).

Environment variable priority is as follows:

1. System environment variable
2. Specified via `.env` file
    - If running through Flutter, this should be located in the repository root
    - If running an OS-specific distribution, this is included as an asset in `data/flutter_assets`

The specified path will now automatically be filled on app launch. If you don't want to deal with any of this, you can browse for the base directory in the UI or just type it in.

### Source Video
The source video can be dragged & dropped into the UI element, or the element can be clicked on to open a picker prompt. Multi-file selection currently not allowed.

### Timestamp Specification
Start & end timestamps can be specified according to FFmpeg's [time duration specification syntax](https://www.ffmpeg.org/ffmpeg-utils.html#time-duration-syntax):

- `[HH:]MM:SS[.m...]`
- `S+[.m...][s|ms|us]`

For example, to specify `1` minute & `5` seconds, you can use `01:05.5` or `65.5`.

To use the video's start and/or end times, their respective fields can be left blank.

### Frame Type
By default, frames are extracted to PNG to avoid compression losses during PDF generation, however this comes at the expense of runtime & a potentially large PDF filesize. For use cases where it's not critical to maintain image fidelity, you can try using JPEG instead.
