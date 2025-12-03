# ffmpeg.lua

Lua FFmpeg API for Screencasting


## Core Features:

- Full command-builder pattern with method chaining
- Video/audio input configuration with device control
- Complete codec and encoding parameter control
- Video/audio filter support (simple & complex)
- Multiple output support
- Built-in presets (YouTube, high quality, streaming)

## Key Methods:

- ```input_video()```, ```input_audio()``` - Configure inputs
- ```output_video()```, ```output_audio()``` - Configure encoding
- ```filter_video()```, ```filter_audio()``` - Add filters
- ```output()``` - Set output file/stream
- ```start()```, ```stop()``` - Process control
- ```to_command()``` - Preview generated FFmpeg command

### Usage Example:

```lua

local ffmpeg = require("ffmpeg")

local recorder = ffmpeg.Recorder:new()
    :input_video({device = "x11grab", source = ":0.0", framerate = 60})
    :input_audio({device = "pulse", source = "default"})
    :output_video({codec = "libx264", crf = 23, preset = "medium"})
    :output_audio({codec = "aac", bitrate = "192k"})
    :output("screencast.mp4")
    :on_start(function() print("Recording!") end)
    
recorder:start()
```

###### HackIT - 752963e64@tutanota.com

