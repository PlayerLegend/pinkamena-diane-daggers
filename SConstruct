#!/usr/bin/env python

ARGUMENTS.setdefault("compiledb", "yes")

env = SConscript("godot-cpp/SConstruct")

def get_lib_filename(env, name):
    prefix = env.subst('$SHLIBPREFIX')
    suffix = env.subst('$SHLIBSUFFIX')
    return f"{prefix}{name}{env['suffix']}{suffix}"

def build_lib(base_env, name):
    lib_env = base_env.Clone()
    lib_env.Append(CPPPATH=[f"{name}/"])
    return lib_env.SharedLibrary(
        f"bin/{get_lib_filename(lib_env, name)}",
        source=Glob(f"{name}/*.cpp"),
    )

Default([build_lib(env, "BoidCPP"), build_lib(env, "CentipedeCPP")])
