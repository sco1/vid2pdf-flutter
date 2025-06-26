# vid2pdf
[![GitHub Release](https://img.shields.io/github/v/release/sco1/vid2pdf-flutter)](https://github.com/sco1/vid2pdf-flutter/releases/latest)
![Platform Badge](https://img.shields.io/badge/Windows%20%7C%20MacOS%20%7C%20Linux-5353ff?logo=flutter&label=Platform&labelColor=3333ff)
[![GitHub License](https://img.shields.io/github/license/sco1/vid2pdf-flutter?color=magenta)](https://github.com/sco1/vid2pdf-flutter/blob/main/LICENSE)

Simple helper utility to convert a video file to PDF image series.

This is a sibling of my [`vid2pdf` Python CLI tool](https://github.com/sco1/vid2pdf).

<p align="center" width="100%">
<img width="60%" src="https://raw.githubusercontent.com/sco1/vid2pdf-flutter/refs/heads/main/doc/base_ui.png">
</p>

## Dependencies
### FFmpeg
`vid2pdf` requires FFmpeg to be available on the host system. The latest version of FFmpeg can be downloaded from [ffmpeg.org](https://www.ffmpeg.org/download.html).

### FFmpeg Detection
By default, `vid2pdf` assumes that FFmpeg is available in your system path. If this isn't an option, or you want to specify an alternate location, you can do so using the `FFMPEG_PATH` environment variable to specify FFmpeg's base directory (not the `/bin` directory).

Environment variable priority is as follows:

1. System environment variable
2. Specified via `.env` file
    - If running through Flutter, this should be located in the repository root
    - If running an OS-specific distribution, this is included as an asset in `data/flutter_assets`

If you don't want to deal with any of this, you can browse for the base directory in the UI, or just type it in.

