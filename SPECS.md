# Technical Specifications

**Lua FFmpeg API for Screencasting**

## 1. Overview

### 1.1 Purpose
Provide a Lua binding to FFmpeg that exposes full command-line functionality for screencast recording, enabling expert users to programmatically control all aspects of video capture, encoding, and output.

### 1.2 Target Audience
Developers and power users with strong understanding of FFmpeg parameters, video encoding concepts, and Lua scripting.

### 1.3 Scope
- Screen capture input device configuration
- Audio input device configuration  
- Video encoding parameters
- Audio encoding parameters
- Output container and streaming options
- Real-time filter application
- Process lifecycle management

---

## 2. Architecture

### 2.1 Design Pattern
**Command Builder Pattern**: Lua API constructs FFmpeg command strings with validation, then executes via system process.

### 2.2 Components
- **Core Module** (`ffmpeg.lua`): Main API surface
- **Input Module**: Screen/audio device enumeration and configuration
- **Encoder Module**: Codec and encoding parameter management
- **Filter Module**: Video/audio filter chain construction
- **Process Module**: FFmpeg process spawning and management
- **Validator Module**: Parameter validation and error handling

### 2.3 Dependencies
- Lua 5.1+ or LuaJIT
- FFmpeg 4.0+ (system installation required)
- Platform-specific: `lua-posix` or `luawinapi` for process control

---

## 3. API Specification

### 3.1 Core Interface

```lua
local ffmpeg = require("ffmpeg")

-- Create recorder instance
local recorder = ffmpeg.Recorder:new()

-- Configuration methods
recorder:input_video(options)
recorder:input_audio(options)
recorder:output_video(options)
recorder:output_audio(options)
recorder:filter_video(filter_string)
recorder:filter_audio(filter_string)
recorder:output(path, options)

-- Execution methods
recorder:start()
recorder:stop()
recorder:pause()
recorder:resume()
recorder:get_status()
```

### 3.2 Input Configuration

#### 3.2.1 Video Input
```lua
recorder:input_video({
    device = "screen",          -- Device type: "screen", "x11grab", "gdigrab", "avfoundation"
    source = ":0.0",           -- Device-specific source identifier
    framerate = 60,            -- Capture framerate
    video_size = "1920x1080", -- Capture resolution
    offset_x = 0,              -- Capture region offset
    offset_y = 0,
    show_cursor = true,        -- Include cursor in capture
    follow_mouse = false,      -- Pan to follow cursor (if supported)
    input_format = nil,        -- Override input format
    extra_args = {}            -- Additional device-specific arguments
})
```

#### 3.2.2 Audio Input
```lua
recorder:input_audio({
    device = "pulse",          -- Device type: "pulse", "alsa", "dshow", "avfoundation"
    source = "default",        -- Device source identifier
    sample_rate = 48000,       -- Audio sample rate
    channels = 2,              -- Number of audio channels
    input_format = nil,        -- Audio input format override
    extra_args = {}
})
```

### 3.3 Output Configuration

#### 3.3.1 Video Encoding
```lua
recorder:output_video({
    codec = "libx264",         -- Video codec
    preset = "medium",         -- Encoding preset (codec-specific)
    crf = 23,                  -- Constant Rate Factor (quality)
    bitrate = nil,             -- Target bitrate (alternative to CRF)
    maxrate = nil,             -- Maximum bitrate for VBV
    bufsize = nil,             -- VBV buffer size
    pix_fmt = "yuv420p",       -- Pixel format
    profile = "high",          -- Codec profile
    level = "4.1",             -- Codec level
    tune = nil,                -- Tuning preset (e.g., "film", "animation")
    keyint = 250,              -- Maximum GOP size
    refs = 3,                  -- Reference frames
    threads = 0,               -- Encoding threads (0 = auto)
    extra_args = {}            -- Additional encoder options
})
```

#### 3.3.2 Audio Encoding
```lua
recorder:output_audio({
    codec = "aac",             -- Audio codec
    bitrate = "192k",          -- Audio bitrate
    sample_rate = 48000,       -- Output sample rate
    channels = 2,              -- Output channels
    profile = "aac_low",       -- Codec profile
    extra_args = {}
})
```

### 3.4 Filter Chains

```lua
-- Video filters (FFmpeg filter syntax)
recorder:filter_video("scale=1280:720,fps=30")

-- Audio filters
recorder:filter_audio("volume=1.5,highpass=f=200")

-- Complex filter graphs
recorder:filter_complex("[0:v]scale=1280:720[v];[0:a]volume=1.5[a]")
recorder:map("[v]", "video")
recorder:map("[a]", "audio")
```

### 3.5 Output Options

```lua
recorder:output("/path/to/output.mp4", {
    format = "mp4",            -- Container format (auto-detected if nil)
    movflags = "+faststart",   -- Format-specific flags
    metadata = {               -- Output metadata
        title = "My Screencast",
        author = "User Name"
    },
    overwrite = true,          -- Overwrite existing file
    extra_args = {}
})
```

### 3.6 Process Management

```lua
-- Start recording
local success, err = recorder:start()

-- Get current status
local status = recorder:get_status()
-- Returns: { running = bool, duration = seconds, size = bytes, error = string }

-- Pause/resume (if supported by format)
recorder:pause()
recorder:resume()

-- Stop recording
recorder:stop()

-- Register callbacks
recorder:on_start(function() print("Recording started") end)
recorder:on_stop(function() print("Recording stopped") end)
recorder:on_error(function(err) print("Error: " .. err) end)
recorder:on_progress(function(data) 
    print(string.format("Time: %s, Size: %d bytes", data.time, data.size))
end)
```

---

## 4. Device Enumeration

### 4.1 List Available Devices
```lua
-- List video devices
local video_devices = ffmpeg.list_devices("video")
-- Returns: { { name = "Screen 1", id = ":0.0" }, ... }

-- List audio devices  
local audio_devices = ffmpeg.list_devices("audio")
-- Returns: { { name = "Microphone", id = "default" }, ... }

-- Query device capabilities
local caps = ffmpeg.get_device_capabilities("video", ":0.0")
-- Returns: { formats = {...}, resolutions = {...}, framerates = {...} }
```

---

## 5. Validation & Error Handling

### 5.1 Parameter Validation
- Validate codec availability before execution
- Check resolution/framerate compatibility
- Verify file path writability
- Validate filter syntax (basic check)

### 5.2 Error Reporting
```lua
local success, error_msg = recorder:start()
if not success then
    print("Failed to start: " .. error_msg)
end

-- Structured error returns
-- error_msg format: "CATEGORY: Description (FFmpeg output)"
```

### 5.3 FFmpeg Output Capture
- Capture stderr for progress reporting
- Parse progress data (time, bitrate, size)
- Expose raw FFmpeg output for debugging

---

## 6. Advanced Features

### 6.1 Multi-Input Recording
```lua
-- Add multiple video inputs
recorder:add_input_video({ device = "x11grab", source = ":0.0" })
recorder:add_input_video({ device = "v4l2", source = "/dev/video0" })

-- Map inputs to outputs
recorder:map_stream("0:v", "video")   -- Screen to video
recorder:map_stream("1:v", "overlay") -- Webcam to overlay
```

### 6.2 Streaming Support
```lua
recorder:output("rtmp://example.com/live/stream", {
    format = "flv",
    extra_args = { "-preset", "ultrafast", "-tune", "zerolatency" }
})
```

### 6.3 Command Preview
```lua
-- Get generated FFmpeg command without executing
local cmd = recorder:to_command()
print("Would execute: " .. cmd)
```

### 6.4 Preset System
```lua
-- Built-in presets
ffmpeg.presets.youtube_1080p = {
    video = { codec = "libx264", preset = "medium", crf = 23, ... },
    audio = { codec = "aac", bitrate = "192k" }
}

recorder:apply_preset(ffmpeg.presets.youtube_1080p)
```

---

## 7. Implementation Requirements

### 7.1 Platform Support
- **Linux**: X11grab, PulseAudio/ALSA
- **macOS**: AVFoundation
- **Windows**: GDI grab, DirectShow

### 7.2 Process Management
- Non-blocking execution via coroutines or threading
- Graceful shutdown handling (SIGTERM/SIGINT)
- Process cleanup on errors
- PID tracking for process control

### 7.3 Performance Considerations
- Minimize Lua overhead (avoid string concatenation in loops)
- Efficient stderr parsing for progress updates
- Lazy validation (only when needed)

### 7.4 Security
- Sanitize file paths to prevent injection
- Validate all user-provided filter strings
- Escape shell arguments properly
- Limit process privileges where possible

---

## 8. Testing Requirements

### 8.1 Unit Tests
- Parameter validation logic
- Command string generation
- Error handling paths
- Device enumeration

### 8.2 Integration Tests
- Record 10-second test clips per platform
- Verify output file integrity (ffprobe)
- Test common codec/format combinations
- Stress test with high bitrates/resolutions

### 8.3 Platform-Specific Tests
- X11grab with different window managers
- PulseAudio vs ALSA on Linux
- DirectShow on Windows
- AVFoundation on macOS

---

## 9. Documentation Requirements

### 9.1 API Reference
- Complete function signatures
- Parameter descriptions with valid ranges
- Return value specifications
- Code examples for each function

### 9.2 User Guide
- Quick start tutorial
- Common recipes (streaming, high quality, low latency)
- Troubleshooting guide
- FFmpeg compatibility matrix

### 9.3 Examples
- Basic screencast
- Picture-in-picture with webcam
- Live streaming setup
- Custom filter examples
- Multi-monitor recording

---

## 10. Future Considerations

### 10.1 Potential Enhancements
- Hardware encoding support (NVENC, QSV, VideoToolbox)
- Real-time preview window
- Segment recording (automatic file splitting)
- Post-processing pipeline
- Audio mixing multiple sources
- Watermark/overlay support

### 10.2 API Stability
- Version semantic versioning
- Deprecation policy for API changes
- Backward compatibility strategy

###### HackIT - 752963e64@tutanota.com

