--[[
  @author 2025 HackIT with Claude.

  second iteration: actively working in tandem!
 
]]
-- ffmpeg.lua - Lua FFmpeg API for Screencasting
-- Provides full control over FFmpeg for expert users

local ffmpeg = {
    _VERSION = "1.0.0",
    presets = {}
}

-- Utility functions
local function escape_arg(arg)
    -- Escape shell arguments to prevent injection
    return "'" .. tostring(arg):gsub("'", "'\\''") .. "'"
end

local function table_merge(t1, t2)
    local result = {}
    for k, v in pairs(t1 or {}) do result[k] = v end
    for k, v in pairs(t2 or {}) do result[k] = v end
    return result
end

local function validate_codec(codec_type, codec_name)
    -- Basic validation - could be enhanced with actual ffmpeg -codecs parsing
    if not codec_name or codec_name == "" then
        return false, "Codec name cannot be empty"
    end
    return true
end

-- Recorder class
local Recorder = {}
Recorder.__index = Recorder

function Recorder:new()
    local instance = {
        video_inputs = {},
        audio_inputs = {},
        video_output = {},
        audio_output = {},
        outputs = {},
        video_filters = {},
        audio_filters = {},
        complex_filters = "",
        stream_maps = {},
        process = nil,
        callbacks = {},
        status = {
            running = false,
            duration = 0,
            size = 0,
            error = nil
        }
    }
    setmetatable(instance, Recorder)
    return instance
end

-- Input configuration
function Recorder:input_video(options)
    options = options or {}
    
    local input = {
        device = options.device or "x11grab",
        source = options.source or ":0",
        framerate = options.framerate or 30,
        video_size = options.video_size or "800x600",
        offset_x = options.offset_x or 0,
        offset_y = options.offset_y or 0,
        show_cursor = options.show_cursor ~= false,
        follow_mouse = options.follow_mouse or false,
        input_format = options.input_format,
        extra_args = options.extra_args or {}
    }
    
    table.insert(self.video_inputs, input)
    return self
end

function Recorder:add_input_video(options)
    return self:input_video(options)
end

function Recorder:input_audio(options)
    options = options or {}
    
    local input = {
        device = options.device or "alsa",
        source = options.source or "default",
        sample_rate = options.sample_rate or 48000,
        channels = options.channels or 2,
        input_format = options.input_format,
        extra_args = options.extra_args or {}
    }
    
    table.insert(self.audio_inputs, input)
    return self
end

function Recorder:add_input_audio(options)
    return self:input_audio(options)
end

-- Output configuration
function Recorder:output_video(options)
    options = options or {}
    
    self.video_output = {
        codec = options.codec or "libx264",
        preset = options.preset,
        crf = options.crf,
        bitrate = options.bitrate,
        maxrate = options.maxrate,
        bufsize = options.bufsize,
        pix_fmt = options.pix_fmt or "yuv420p",
        profile = options.profile,
        level = options.level,
        tune = options.tune,
        keyint = options.keyint,
        refs = options.refs,
        threads = options.threads or 0,
        extra_args = options.extra_args or {}
    }
    
    return self
end

function Recorder:output_audio(options)
    options = options or {}
    
    self.audio_output = {
        codec = options.codec or "aac",
        bitrate = options.bitrate or "192k",
        sample_rate = options.sample_rate or 48000,
        channels = options.channels or 2,
        profile = options.profile,
        extra_args = options.extra_args or {}
    }
    
    return self
end

-- Filter configuration
function Recorder:filter_video(filter_string)
    table.insert(self.video_filters, filter_string)
    return self
end

function Recorder:filter_audio(filter_string)
    table.insert(self.audio_filters, filter_string)
    return self
end

function Recorder:filter_complex(filter_string)
    self.complex_filters = filter_string
    return self
end

function Recorder:map(stream, label)
    table.insert(self.stream_maps, {stream = stream, label = label})
    return self
end

function Recorder:map_stream(input_stream, output_label)
    return self:map(input_stream, output_label)
end

-- Output file configuration
function Recorder:output(path, options)
    options = options or {}
    
    local output = {
        path = path,
        format = options.format,
        movflags = options.movflags,
        metadata = options.metadata or {},
        overwrite = options.overwrite ~= false,
        extra_args = options.extra_args or {}
    }
    
    table.insert(self.outputs, output)
    return self
end

-- Command building
function Recorder:to_command()
    local cmd_parts = {"ffmpeg -hide_banner"}
    
    -- Overwrite flag
    if #self.outputs > 0 and self.outputs[1].overwrite then
        table.insert(cmd_parts, "-y")
    end
    
    -- Video inputs
    for _, input in ipairs(self.video_inputs) do
        if input.input_format then
            table.insert(cmd_parts, "-f")
            table.insert(cmd_parts, input.input_format)
        else
            table.insert(cmd_parts, "-f")
            table.insert(cmd_parts, input.device)
        end
        
        table.insert(cmd_parts, "-framerate")
        table.insert(cmd_parts, tostring(input.framerate))
        
        table.insert(cmd_parts, "-video_size")
        table.insert(cmd_parts, input.video_size)
        
        -- Add extra device-specific args
        for _, arg in ipairs(input.extra_args) do
            table.insert(cmd_parts, arg)
        end
        
        -- Cursor options (platform specific)
        if input.show_cursor then
            if input.device == "x11grab" then
                table.insert(cmd_parts, "-draw_mouse")
                table.insert(cmd_parts, "1")
            end
        end
        
        table.insert(cmd_parts, "-i")
        table.insert(cmd_parts, input.source)
    end
    
    -- Audio inputs
    for _, input in ipairs(self.audio_inputs) do
        if input.input_format then
            table.insert(cmd_parts, "-f")
            table.insert(cmd_parts, input.input_format)
        else
            table.insert(cmd_parts, "-f")
            table.insert(cmd_parts, input.device)
        end
        
        table.insert(cmd_parts, "-sample_rate")
        table.insert(cmd_parts, tostring(input.sample_rate))
        
        table.insert(cmd_parts, "-channels")
        table.insert(cmd_parts, tostring(input.channels))
        
        for _, arg in ipairs(input.extra_args) do
            table.insert(cmd_parts, arg)
        end
        
        table.insert(cmd_parts, "-i")
        table.insert(cmd_parts, input.source)
    end
    
    -- Complex filters
    if self.complex_filters ~= "" then
        table.insert(cmd_parts, "-filter_complex")
        table.insert(cmd_parts, self.complex_filters)
        
        -- Stream maps for complex filters
        for _, map in ipairs(self.stream_maps) do
            table.insert(cmd_parts, "-map")
            table.insert(cmd_parts, map.stream)
        end
    else
        -- Simple video filters
        if #self.video_filters > 0 then
            table.insert(cmd_parts, "-vf")
            table.insert(cmd_parts, table.concat(self.video_filters, ","))
        end
        
        -- Simple audio filters
        if #self.audio_filters > 0 then
            table.insert(cmd_parts, "-af")
            table.insert(cmd_parts, table.concat(self.audio_filters, ","))
        end
    end
    
    -- Video output options
    if next(self.video_output) then
        local vo = self.video_output
        
        table.insert(cmd_parts, "-c:v")
        table.insert(cmd_parts, vo.codec)
        
        if vo.preset then
            table.insert(cmd_parts, "-preset")
            table.insert(cmd_parts, vo.preset)
        end
        
        if vo.crf then
            table.insert(cmd_parts, "-crf")
            table.insert(cmd_parts, tostring(vo.crf))
        end
        
        if vo.bitrate then
            table.insert(cmd_parts, "-b:v")
            table.insert(cmd_parts, vo.bitrate)
        end
        
        if vo.maxrate then
            table.insert(cmd_parts, "-maxrate")
            table.insert(cmd_parts, vo.maxrate)
        end
        
        if vo.bufsize then
            table.insert(cmd_parts, "-bufsize")
            table.insert(cmd_parts, vo.bufsize)
        end
        
        if vo.pix_fmt then
            table.insert(cmd_parts, "-pix_fmt")
            table.insert(cmd_parts, vo.pix_fmt)
        end
        
        if vo.profile then
            table.insert(cmd_parts, "-profile:v")
            table.insert(cmd_parts, vo.profile)
        end
        
        if vo.level then
            table.insert(cmd_parts, "-level")
            table.insert(cmd_parts, vo.level)
        end
        
        if vo.tune then
            table.insert(cmd_parts, "-tune")
            table.insert(cmd_parts, vo.tune)
        end
        
        if vo.keyint then
            table.insert(cmd_parts, "-g")
            table.insert(cmd_parts, tostring(vo.keyint))
        end
        
        if vo.refs then
            table.insert(cmd_parts, "-refs")
            table.insert(cmd_parts, tostring(vo.refs))
        end
        
        if vo.threads then
            table.insert(cmd_parts, "-threads")
            table.insert(cmd_parts, tostring(vo.threads))
        end
        
        for _, arg in ipairs(vo.extra_args) do
            table.insert(cmd_parts, arg)
        end
    end
    
    -- Audio output options
    if next(self.audio_output) then
        local ao = self.audio_output
        
        table.insert(cmd_parts, "-c:a")
        table.insert(cmd_parts, ao.codec)
        
        if ao.bitrate then
            table.insert(cmd_parts, "-b:a")
            table.insert(cmd_parts, ao.bitrate)
        end
        
        if ao.sample_rate then
            table.insert(cmd_parts, "-ar")
            table.insert(cmd_parts, tostring(ao.sample_rate))
        end
        
        if ao.channels then
            table.insert(cmd_parts, "-ac")
            table.insert(cmd_parts, tostring(ao.channels))
        end
        
        if ao.profile then
            table.insert(cmd_parts, "-profile:a")
            table.insert(cmd_parts, ao.profile)
        end
        
        for _, arg in ipairs(ao.extra_args) do
            table.insert(cmd_parts, arg)
        end
    end
    
    -- Output files
    for _, output in ipairs(self.outputs) do
        if output.format then
            table.insert(cmd_parts, "-f")
            table.insert(cmd_parts, output.format)
        end
        
        if output.movflags then
            table.insert(cmd_parts, "-movflags")
            table.insert(cmd_parts, output.movflags)
        end
        
        -- Metadata
        for key, value in pairs(output.metadata) do
            table.insert(cmd_parts, "-metadata")
            table.insert(cmd_parts, key .. "=" .. value)
        end
        
        for _, arg in ipairs(output.extra_args) do
            table.insert(cmd_parts, arg)
        end
        
        table.insert(cmd_parts, output.path)
    end
    
    return table.concat(cmd_parts, " ")
end

-- Process management
function Recorder:start()
    if self.status.running then
        return false, "Recorder is already running"
    end
    
    local cmd = self:to_command()
    
    -- Store the command for debugging
    self.last_command = cmd
    
    -- Execute command in background
    -- For persistent recording, we need to run it asynchronously
    local bg_cmd = cmd .. " &"
    local exit_code = os.execute(bg_cmd)
    
    if not exit_code or exit_code ~= 0 then
        return false, "Failed to start ffmpeg process. Command: " .. cmd
    end
    
    self.status.running = true
    self.status.error = nil
    
    if self.callbacks.on_start then
        self.callbacks.on_start()
    end
    
    return true
end

function Recorder:stop()
    if not self.status.running then
        return false, "Recorder is not running"
    end
    
    -- Send 'q' to ffmpeg to gracefully stop (requires interactive mode)
    -- Alternative: use pkill or kill the process by PID
    os.execute("pkill -INT ffmpeg")
    
    self.status.running = false
    
    if self.callbacks.on_stop then
        self.callbacks.on_stop()
    end
    
    return true
end

function Recorder:get_command()
    return self.last_command or self:to_command()
end

function Recorder:pause()
    -- Platform-specific implementation needed (send SIGSTOP)
    return false, "Pause not yet implemented"
end

function Recorder:resume()
    -- Platform-specific implementation needed (send SIGCONT)
    return false, "Resume not yet implemented"
end

function Recorder:get_status()
    return {
        running = self.status.running,
        duration = self.status.duration,
        size = self.status.size,
        error = self.status.error
    }
end

-- Callbacks
function Recorder:on_start(callback)
    self.callbacks.on_start = callback
    return self
end

function Recorder:on_stop(callback)
    self.callbacks.on_stop = callback
    return self
end

function Recorder:on_error(callback)
    self.callbacks.on_error = callback
    return self
end

function Recorder:on_progress(callback)
    self.callbacks.on_progress = callback
    return self
end

-- Preset management
function Recorder:apply_preset(preset)
    if preset.video then
        self:output_video(preset.video)
    end
    if preset.audio then
        self:output_audio(preset.audio)
    end
    return self
end

-- Expose Recorder class
ffmpeg.Recorder = Recorder

function ffmpeg.list_devices(device_type)
    -- Platform-specific implementation needed
    -- This would parse ffmpeg -devices or use system APIs
    return {}
end

function ffmpeg.get_device_capabilities(device_type, device_id)
    -- Platform-specific implementation needed
    return {
        formats = {},
        resolutions = {},
        framerates = {}
    }
end

-- Built-in presets
ffmpeg.presets.youtube_1080p = {
    video = {
        codec = "libx264",
        preset = "medium",
        crf = 23,
        pix_fmt = "yuv420p",
        profile = "high",
        level = "4.1"
    },
    audio = {
        codec = "aac",
        bitrate = "192k",
        sample_rate = 48000
    }
}

ffmpeg.presets.high_quality = {
    video = {
        codec = "libx264",
        preset = "slower",
        crf = 18,
        pix_fmt = "yuv420p"
    },
    audio = {
        codec = "aac",
        bitrate = "320k",
        sample_rate = 48000
    }
}

ffmpeg.presets.streaming = {
    video = {
        codec = "libx264",
        preset = "ultrafast",
        tune = "zerolatency",
        crf = 23,
        keyint = 60
    },
    audio = {
        codec = "aac",
        bitrate = "128k",
        sample_rate = 44100
    }
}

return ffmpeg

