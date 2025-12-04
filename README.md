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
    :input_video({device = "x11grab", source = ":0", framerate = 30})
    :output_video({codec = "libx264", crf = 10, preset = "ultrafast"})
    :output_audio({codec = "aac", bitrate = "128k"})
    :output("screencast.mp4")
    :on_progress(function(data)
        print(string.format("PROGRESS: Frame: %d | FPS: %.1f | Time: %.1fs", 
            data.frame, data.fps, data.duration))
    end)

print("Starting recorder...")
local success, err = recorder:start()
if not success then
    print("Failed to start: " .. err)
    return
end

print("Recording for 5 seconds...")
for i = 1, 5 do
    recorder:update()
    os.execute("sleep 1")
    print("Update " .. i)
end

-- Debug: print raw stderr
print("\n=== RAW STDERR OUTPUT ===")
print(recorder:get_stderr())
print("=========================\n")

recorder:stop()
```



###### HackIT - 752963e64@tutanota.com

