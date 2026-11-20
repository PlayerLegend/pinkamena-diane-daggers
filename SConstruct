#!/usr/bin/env python
import os
import sys

ARGUMENTS.setdefault("compiledb", "yes")

env = SConscript("godot-cpp/SConstruct")

# Header files
env.Append(CPPPATH=["BoidCPP/"])

# Source files
sources = Glob("BoidCPP/*.cpp")

# The filename for the dynamic library for this GDExtension.
# $SHLIBPREFIX is a platform specific prefix for the dynamic library ('lib' on Unix, '' on Windows).
# $SHLIBSUFFIX is the platform specific suffix for the dynamic library (for example '.dll' on Windows).
# env["suffix"] includes the build's feature tags (e.g. '.windows.template_debug.x86_64')
# (see https://docs.godotengine.org/en/stable/tutorials/export/feature_tags.html).
# The final path should match a path in the '.gdextension' file.
lib_filename = "{}BoidCPP{}{}".format(env.subst('$SHLIBPREFIX'), env["suffix"], env.subst('$SHLIBSUFFIX'))

# Creates a SCons target for the path with our sources.
library = env.SharedLibrary(
    "project/bin/{}".format(lib_filename),
    source=sources,
)

# Selects the shared library as the default target.
Default(library)
