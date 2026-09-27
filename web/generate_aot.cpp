#include "daScript/daScript.h"
#include <fstream>
#include <iostream>
#include <emscripten.h>
DECLARE_MODULE(Module_dasSDL3);
using namespace das;

static int generate_script(const char *input, const char *output, const std::string &data) {
    TextPrinter log;
    auto access = make_smart<FsFileAccess>();
    access->addFsRoot("dassdl3", "/dassdl3");
    ModuleGroup scriptModules, compilerModules;
    CodeOfPolicies policy;
    policy.aot_module = true;
    policy.tune_frozen = true;
    policy.fail_on_lack_of_aot_export = true;
    auto script = compileDaScript(input, access, log, scriptModules, policy);
    auto compiler = compileDaScript(getDasRoot() + "/daslib/aot_cpp.das", access, log, compilerModules, policy);
    for (auto program : {script, compiler}) {
        if (program->failed()) {
            for (auto &e : program->errors) log << reportError(e.at, e.what, e.extra, e.fixme, e.cerr);
            return 1;
        }
    }
    Context scriptContext(script->getContextStackSize()), compilerContext(compiler->getContextStackSize());
    if (!script->simulate(scriptContext, log) || !compiler->simulate(compilerContext, log)) {
        for (auto program : {script, compiler})
            for (auto &e : program->errors) log << reportError(e.at, e.what, e.extra, e.fixme, e.cerr);
        return 2;
    }
    auto entry = compilerContext.findFunction("run_aot");
    if (!entry) return 3;
    vec4f args[] = {cast<Program *>::from(script.get()), cast<Context *>::from(&scriptContext), cast<CodeOfPolicies *>::from(&policy)};
    auto value = compilerContext.evalWithCatch(entry, args);
    if (auto ex = compilerContext.getException()) { log << ex << "\n"; return 4; }
    auto result = cast<char *>::to(value);
    if (!result || !*result) { log << "Empty AOT output\n"; return 5; }
    std::string generated(result);
    // Preserve timestamps when another input triggered generation but output is unchanged.
    std::ifstream previous(output, std::ios::binary);
    const std::string oldText((std::istreambuf_iterator<char>(previous)), std::istreambuf_iterator<char>());
    if (oldText == generated) return 0;
    std::ofstream file(output, std::ios::binary);
    file << generated;
    return file ? 0 : 6;
}
int main(int argc, char **argv) {
    if (argc != 3) return 7;
    // Mount only explicit build inputs/outputs in the build-time Node process.
    EM_ASM({ FS.mkdir('/host'); FS.mount(NODEFS, {root: UTF8ToString($0)}, '/host'); }, argv[1]);
    EM_ASM({ FS.mkdir('/out'); FS.mount(NODEFS, {root: UTF8ToString($0)}, '/out'); }, argv[2]);
    setDasRoot("/");
    NEED_ALL_DEFAULT_MODULES;
    NEED_MODULE(Module_dasSDL3);
    Module::Initialize();
    const char * scripts[] = {"state", "mapper", "apu", "core", "cpu", "ppu", "pacing", "web_main"};
    int result = 0;
    for (const char * name : scripts) {
        std::string input = std::string("/app/") + name + ".das";
        std::string output = std::string("/out/") + name + ".cpp";
        std::cout << "AOT wasm32: " << name << std::endl;
        result = generate_script(input.c_str(), output.c_str(), "");
        if (result) break;
    }
    const char * shared[] = {"/daslib/fio.das", "/dassdl3/sdl3_result.das", "/dassdl3/sdl3_boost.das", "/dassdl3/sdl3_pixels_boost.das", "/dassdl3/sdl3_audio_boost.das"};
    for (int i = 0; i < 5 && !result; ++i) {
        std::string output = std::string("/out/shared") + std::to_string(i) + ".cpp";
        result = generate_script(shared[i], output.c_str(), "");
    }
    Module::Shutdown();
    return result;
}
