options gen2
require ppu
require pacing
require dassdl3/sdl3_try
require math
require dassdl3/sdl3_boost
require dassdl3/sdl3_pixels_boost
require dassdl3/sdl3_audio_boost

var nes = Nes()
var clock = FrameClock()
var window : SDL_Window?
var renderer : SDL_Renderer?
var texture : SDL_Texture?
var stream : SDL_AudioStream?
var fps_started : uint64
var frames, fps_frames : int

def report(result : SdlStatus) : int {
    if (is_err(result)) { let e = unwrap_err(result); print("{e.operation}: {e.message}\n"); return -1 }
    return 0
}
def initialize() : SdlStatus {
    sdl_init(SDL_INIT_VIDEO | SDL_INIT_AUDIO) |> sdl_try
    window = create_window("dasNES", 768, 720) |> sdl_try
    renderer = create_renderer(window) |> sdl_try
    texture = SDL_CreateRGBA8Texture(renderer, 256, 240, false)
    if (texture == null) { return err(sdl_error("SDL_CreateRGBA8Texture"), type<SdlUnit>) }
    sdl_status(SDL_SetTextureScaleMode(texture, SDL_ScaleMode.SCALEMODE_NEAREST), "SDL_SetTextureScaleMode") |> sdl_try
    sdl_status(SDL_SetRenderLogicalPresentation(renderer, 256, 240, SDL_RendererLogicalPresentation.LOGICAL_PRESENTATION_LETTERBOX), "SDL_SetRenderLogicalPresentation") |> sdl_try
    stream = open_playback(audio_spec(uint(SDL_AudioFormat.AUDIO_S16LE), 1, 48000)) |> sdl_try
    var silence : array<uint8>
    resize(silence, 4800)
    stream |> put_audio(silence) |> sdl_try
    stream |> resume_audio() |> sdl_try
    clock.next_frame = SDL_GetTicksNS(); fps_started = clock.next_frame
    print("Ready: WebGL renderer {SDL_GetRendererName(renderer)}, audio 48000 Hz\n")
    return sdl_ok()
}
def draw_frame() : SdlStatus {
    nes.buttons = (key_down(int(SDL_Scancode.SCANCODE_Z)) ? 1 : 0) | (key_down(int(SDL_Scancode.SCANCODE_X)) ? 2 : 0) | (key_down(int(SDL_Scancode.SCANCODE_RSHIFT)) ? 4 : 0) | (key_down(int(SDL_Scancode.SCANCODE_RETURN)) ? 8 : 0) | (key_down(int(SDL_Scancode.SCANCODE_UP)) ? 16 : 0) | (key_down(int(SDL_Scancode.SCANCODE_DOWN)) ? 32 : 0) | (key_down(int(SDL_Scancode.SCANCODE_LEFT)) ? 64 : 0) | (key_down(int(SDL_Scancode.SCANCODE_RIGHT)) ? 128 : 0)
    if (nes.zapper) {
        var mx, my : float
        let mouse = SDL_GetMouseStateRef(mx, my)
        var w, h : int
        if (SDL_GetWindowSizeInPixelsRef(window, w, h) && w > 0 && h > 0) {
            let scale = min(float(w) / 256.0, float(h) / 240.0)
            nes.zapper_x = int((mx - (float(w) - 256.0 * scale) * 0.5) / scale)
            nes.zapper_y = int((my - (float(h) - 240.0 * scale) * 0.5) / scale)
        }
        nes.zapper_trigger = (mouse & 1u) != 0u
        if ((mouse & 4u) != 0u) { nes.zapper_x = -100; nes.zapper_y = -100; nes.zapper_trigger = true }
    }
    let count = due_frames(clock, SDL_GetTicksNS())
    for (i in 0 .. count) {
        run_frame(nes)
        let queued = stream |> queued_audio() |> sdl_try
        if (queued > 16000) { stream |> clear_audio() |> sdl_try }
        stream |> put_audio(nes.apu.pcm) |> sdl_try
    }
    texture |> upload_rgba8(nes.pixels, 1024) |> sdl_try
    renderer |> clear() |> sdl_try
    renderer |> draw_texture(texture, SDL_MakeFRect(0.0, 0.0, 256.0, 240.0)) |> sdl_try
    renderer |> present() |> sdl_try
    frames += count; fps_frames += count
    let now = SDL_GetTicksNS()
    if (now - fps_started >= 1000000000ul) {
        let fps = double(fps_frames) * 1000000000.0lf / double(now - fps_started)
        print("FPS {fps}; frames {frames}\n")
        fps_frames = 0; fps_started = now
    }
    return sdl_ok()
}
[export]
def app_init() : int {
    if (!load_rom(nes, "/roms/game.nes")) { return -1 }
    return report(initialize())
}
[export]
def app_frame() : int { return report(draw_frame()) }
[export]
def app_event(event : SDL_Event) : int { return should_close(event, window) ? 1 : 0 }
[export]
def app_quit() {
    destroy_audio_stream(stream); stream = null
    destroy_texture(texture); texture = null
    destroy_renderer(renderer); renderer = null
    destroy_window(window); window = null
    SDL_Quit()
    print("Session released after {frames} frames\n")
}

[export]
def app_resume() : int {
    clock.next_frame = SDL_GetTicksNS(); fps_started = clock.next_frame; fps_frames = 0
    return report(clear_audio(stream))
}
