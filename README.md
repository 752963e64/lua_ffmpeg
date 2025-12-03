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

- ffmpeg run as a background command.

```lua

local ffmpeg = require("ffmpeg")

local recorder = ffmpeg.Recorder:new()
    :input_video({device = "x11grab", source = ":0.0", framerate = 30})
    :input_audio({device = "pulse", source = "default"})
    :output_video({codec = "libx264", crf = 23, preset = "medium"})
    :output_audio({codec = "aac", bitrate = "192k"})
    :output("screencast.mp4")

print("Command: " .. recorder:get_command())
local success, err = recorder:start()
if not success then
    print("Error: " .. err)
else
    print("Recording started - press Enter to stop")
    io.read()
    recorder:stop()
    print("Recording stopped")
end
```

###### HackIT - 752963e64@tutanota.com

