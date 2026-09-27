#include "daScript/daScript.h"
#include <fstream>
#include <iostream>
#ifdef __EMSCRIPTEN__
#include <emscripten.h>
#endif
DECLARE_MODULE(Module_dasSDL3);
using namespace das;

static int generate(const char *input, const char *output, const char *emitter, const std::string &sdlRoot) {
    TextPrinter log;
    ModuleGroup modules;
    auto access = make_smart<FsFileAccess>();
    access->addFsRoot("dassdl3", sdlRoot);
    CodeOfPolicies policy;
    policy.aot_module = true;
    policy.tune_frozen = true;
    policy.fail_on_lack_of_aot_export = true;
    auto program = compileDaScript(input, access, log, modules, policy);
    auto driver = compileDaScript(emitter, access, log, modules, policy);
    for (auto p : {program, driver}) {
        if (p->failed()) {
            for (auto &e : p->errors) log << reportError(e.at, e.what, e.extra, e.fixme, e.cerr);
            return 1;
        }
    }
    auto context = make_smart<Context>(program->getContextStackSize());
    Context driverContext(driver->getContextStackSize());
    if (!program->simulate(*context, log) || !driver->simulate(driverContext, log)) return 2;
    auto entry = driverContext.findFunction("emit");
    if (!entry) return 3;
    vec4f args[] = {cast<Program *>::from(program.get()), cast<Context *>::from(context.get()), cast<char *>::from(output)};
    auto value = driverContext.evalWithCatch(entry, args);
    if (auto error = driverContext.getException()) { log << error << "\n"; return 4; }
    if (!cast<bool>::to(value)) return 5;

    const std::string path = std::string(output) + "/nes.das.cpp";
    std::ifstream in(path, std::ios::binary);
    if (!in) return 6;
    std::string generated((std::istreambuf_iterator<char>(in)), std::istreambuf_iterator<char>());
    in.close();
    // Same pinned daScript catch-order workaround as native/aot.cpp.
    // Applied on every generation, never a hand edit to generated C++.
    const std::string from = "das_try_recover(__context__,";
    const std::string to = "das::SDL_AotTryRecover(__context__,";
    size_t pos = 0;
    while ((pos = generated.find(from, pos)) != std::string::npos) {
        generated.replace(pos, from.size(), to);
        pos += to.size();
    }
    if (generated.find("das_try_recover(") != std::string::npos) {
        log << "AOT try/recover emission changed; review pinned workaround\n";
        return 9;
    }
    // MSVC takes excessive time optimizing the large if-chain CPU decoder.
    // Keep that one function out of the optimizer/inliner, rather than applying
    // /Ob0 to every runtime helper, APU and PPU function in this single TU.
    // Clang/wasm keeps its normal optimizations. Fail if the emitter's shape changes.
    const std::string cpu = "inline int32_t cpu_step_";
    const auto declaration = generated.find(cpu);
    if (declaration != std::string::npos) {
        const auto definition = generated.find(cpu, declaration + cpu.size());
        const auto end = definition == std::string::npos ? std::string::npos : generated.find("\n}\n", definition);
        if (end == std::string::npos) {
            log << "Standalone CPU emission changed; review MSVC workaround\n";
            return 10;
        }
        generated.insert(end + 3, "#ifdef _MSC_VER\n#pragma optimize(\"\", on)\n#endif\n");
        generated.insert(definition, "#ifdef _MSC_VER\n#pragma optimize(\"\", off)\n__declspec(noinline)\n#endif\n");
        generated.insert(declaration, "#ifdef _MSC_VER\n__declspec(noinline)\n#endif\n");
    }
    std::ofstream out(path, std::ios::binary);
    out << generated;
    return out ? 0 : 7;
}

int main(int argc, char **argv) {
#ifdef __EMSCRIPTEN__
    if (argc != 3) return 8;
    EM_ASM({ FS.mkdir('/host'); FS.mount(NODEFS, {root: UTF8ToString($0)}, '/host'); }, argv[1]);
    EM_ASM({ FS.mkdir('/out'); FS.mount(NODEFS, {root: UTF8ToString($0)}, '/out'); }, argv[2]);
    setDasRoot("/");
#else
    if (argc != 4) return 8;
    setDasRoot(std::string(DASNES_SDL_ROOT) + "/third_party/daScript");
#endif
    NEED_ALL_DEFAULT_MODULES;
    NEED_MODULE(Module_dasSDL3);
    Module::Initialize();
    int result = 1;
    try {
#ifdef __EMSCRIPTEN__
        result = generate("/app/web_main.das", "/out", "/host/native/standalone.das", "/dassdl3");
#else
        result = generate(argv[1], argv[2], argv[3], std::string(DASNES_SDL_ROOT) + "/dassdl3");
#endif
    } catch (const std::exception &e) {
        std::cerr << "Standalone generation failed: " << e.what() << '\n';
    }
    // All Program/Context/ModuleGroup objects have already been destroyed.
    Module::Shutdown();
    return result;
}
