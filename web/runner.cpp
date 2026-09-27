#include "nes.das.h"
#include "daScript/ast/ast.h"
#define SDL_MAIN_USE_CALLBACKS 1
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#include <emscripten.h>
#include <cstdio>
#include <memory>

namespace {
struct Session {
    das::daScriptEnvironment environment;
    das::daScriptEnvironmentGuard guard{&environment, nullptr};
    std::unique_ptr<das::ctx_nes::Standalone> context;
    bool initialized = false;
};
bool stopRequested = false, paused = false, resumeRequested = false;
template <typename F> SDL_AppResult invoke(F &&call) {
    try {
        const int code = call();
        return code < 0 ? SDL_APP_FAILURE : code > 0 ? SDL_APP_SUCCESS : SDL_APP_CONTINUE;
    } catch (const std::exception &e) {
        fprintf(stderr, "Script exception: %s\n", e.what());
        return SDL_APP_FAILURE;
    }
}
}
extern "C" EMSCRIPTEN_KEEPALIVE void web_pause(int value) { if (paused && !value) resumeRequested = true; paused = value != 0; }
extern "C" EMSCRIPTEN_KEEPALIVE void web_stop() { stopRequested = true; }
SDL_AppResult SDL_AppInit(void **appstate, int, char **) {
    stopRequested = paused = resumeRequested = false;
    setenv("DASNES_ROM", "/roms/game.nes", 1);
    auto *s = new Session();
    *appstate = s;
    return invoke([&] {
        s->context = std::make_unique<das::ctx_nes::Standalone>();
        puts("dasNES: wasm32 AOT, interpreter fallback disabled; standalone, no compiler");
        s->initialized = true;
        return s->context->app_init();
    });
}
SDL_AppResult SDL_AppIterate(void *state) {
    if (stopRequested) return SDL_APP_SUCCESS;
    if (paused) return SDL_APP_CONTINUE;
    auto &s = *static_cast<Session *>(state);
    if (resumeRequested) {
        resumeRequested = false;
        const auto result = invoke([&] { return s.context->app_resume(); });
        if (result != SDL_APP_CONTINUE) return result;
    }
    return invoke([&] { return s.context->app_frame(); });
}
SDL_AppResult SDL_AppEvent(void *state, SDL_Event *event) {
    auto &s = *static_cast<Session *>(state);
    return invoke([&] { return s.context->app_event(*event); });
}
void SDL_AppQuit(void *state, SDL_AppResult result) {
    auto *s = static_cast<Session *>(state);
    if (s && s->initialized) {
        const auto cleanup = invoke([&] { s->context->app_quit(); return 0; });
        if (cleanup == SDL_APP_FAILURE) result = cleanup;
    }
    delete s;
    SDL_Quit();
    das::clearGlobalAotLibrary();
    // SDL 3.4.16 can leave its playback AudioContext alive after SDL_Quit.
    EM_ASM({
        const audio = Module['SDL3'];
        if (audio && audio.audioContext) {
            const context = audio.audioContext;
            audio.audioContext = undefined;
            if (context.state !== 'closed') { context.close(); }
        }
        Module.onSessionEnd?.($0);
    }, result == SDL_APP_FAILURE ? 1 : 0);
}
