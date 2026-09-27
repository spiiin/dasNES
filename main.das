options gen2
require ppu
require daslib/fio
require dassdl3/sdl3_scope
require dassdl3/sdl3_pixels_boost

var nes = Nes()

def play(window : SDL_Window?; renderer : SDL_Renderer?; texture : SDL_Texture?; smoke : bool) : SdlStatus {
    if (!SDL_SetTextureScaleMode(texture, SDL_ScaleMode.SCALEMODE_NEAREST)) {
        return err(sdl_error("SDL_SetTextureScaleMode"), type<SdlUnit>)
    }
    var event = SDL_MakeEvent()
    var running = true
    var frames = 0
    var fps_frames = 0
    var fps_started = SDL_GetTicksNS()
    let play_started = fps_started
    while (running) {
        let started = SDL_GetTicksNS()
        while (is_some(poll_event(event))) { if (should_close(event, window)) { running = false } }
        if (!running) { break }
        nes.buttons = (key_down(int(SDL_Scancode.SCANCODE_Z)) ? 1 : 0) | (key_down(int(SDL_Scancode.SCANCODE_X)) ? 2 : 0) | (key_down(int(SDL_Scancode.SCANCODE_RSHIFT)) ? 4 : 0) | (key_down(int(SDL_Scancode.SCANCODE_RETURN)) ? 8 : 0) | (key_down(SDL_SCANCODE_UP) ? 16 : 0) | (key_down(SDL_SCANCODE_DOWN) ? 32 : 0) | (key_down(SDL_SCANCODE_LEFT) ? 64 : 0) | (key_down(SDL_SCANCODE_RIGHT) ? 128 : 0)
        run_frame(nes)
        texture |> upload_rgba8(nes.pixels, 1024) |> sdl_try
        renderer |> clear() |> sdl_try
        renderer |> draw_texture(texture, SDL_MakeFRect(0.0, 0.0, 768.0, 720.0)) |> sdl_try
        renderer |> present() |> sdl_try
        frames++
        let elapsed = SDL_GetTicksNS() - started
        // NTSC ~60.0988 Hz. Slow frames do not accumulate an unbounded backlog.
        if (elapsed < 16639267ul) { SDL_DelayPrecise(16639267ul - elapsed) }
        fps_frames++
        let now = SDL_GetTicksNS()
        let fps_elapsed = now - fps_started
        if (fps_elapsed >= 1000000000ul || (smoke && frames >= 3)) {
            // Count presented game frames, including rendering and frame pacing.
            let fps_tenths = int(double(fps_frames) * 10000000000.0lf / double(fps_elapsed) + 0.5lf)
            window |> set_title("dasNES | FPS: {fps_tenths / 10}.{fps_tenths % 10} | Z X Shift Enter Arrows | Esc exits") |> sdl_try
            fps_frames = 0
            fps_started = now
        }
        if (smoke && frames >= 3) { break }
    }
    let total_ns = SDL_GetTicksNS() - play_started
    let average_fps = total_ns > 0ul ? double(frames) * 1000000000.0lf / double(total_ns) : 0.0lf
    print("Rendered {frames} frames, average FPS {average_fps}, CPU cycles {nes.cycles}\n")
    return sdl_ok()
}

[export]
def main(smoke : bool) : int {
    // The launcher passes the ROM path through the process environment.
    if (!load_rom(nes, get_env_variable("DASNES_ROM"))) { return 1 }
    let result = sdl_scope() {
        with_sdl(SDL_INIT_VIDEO) |> sdl_use
        let window : SDL_Window? = with_window("dasNES | FPS: ... | Z X Shift Enter Arrows | Esc exits", 768, 720, smoke ? SDL_WINDOW_HIDDEN : 0ul) |> sdl_use
        let renderer : SDL_Renderer? = window |> with_renderer() |> sdl_use
        let texture : SDL_Texture? = renderer |> with_streaming_texture(256, 240) |> sdl_use
        return play(window, renderer, texture, smoke)
    }
    if (is_err(result)) { let e = unwrap_err(result); print("{e.operation}: {e.message}\n"); return 1 }
    return 0
}




