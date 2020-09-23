load(
    "@io_bazel_rules_dotnet//dotnet/private:context.bzl",
    "dotnet_context",
)
load(
    "@io_bazel_rules_dotnet//dotnet/private:providers.bzl",
    "DotnetLibrary",
    "DotnetResourceList",
)
load(
    "@io_bazel_rules_dotnet//dotnet/private:json.bzl",
    "write_runtimeconfig",
    "write_depsjson",
)
load(
    "@io_bazel_rules_dotnet//dotnet/private:runfiles.bzl",
    "to_manifest_path",
    "BATCH_RLOCATION_FUNCTION",
)

# DotnetContext, DotnetLibrary
def create_launcher(dotnet, library):
    launcher = dotnet.declare_file(dotnet, path = "launcher.bat", sibling = library.result)
    dotnet.actions.write(
        output = launcher,
        content = r"""@echo off
SETLOCAL ENABLEEXTENSIONS
SETLOCAL ENABLEDELAYEDEXPANSION

REM direct invocations
if "%RUNFILES_DIR%"=="" (
    SET RUNFILES_DIR=%~df0.runfiles
)

REM invocations from inside a .runfiles folder
if not exist "%RUNFILES_DIR%" (
    set RUNFILES_DIR=%~DP0{depth}
)

set RUNFILES_MANIFEST_ONLY=1
REM we do not trust an already set MANIFEST_FILE because this may be a calling program
set RUNFILES_MANIFEST_FILE=""
{rlocation_function}
call :rlocation "{dotnet_path}" DOTNET_RUNNER

"%DOTNET_RUNNER%" --additionalprobingpath "%RUNFILES_DIR%\{workspace_name}" "\\?\%~dp0{dll}" %*
""".format(
    dotnet_path = to_manifest_path(dotnet, dotnet.runner),
    rlocation_function = BATCH_RLOCATION_FUNCTION,
    dll = library.result.basename,
    workspace_name = dotnet.workspace_name,
    depth = "/".join([".." for _ in to_manifest_path(dotnet, launcher).split("/")[1:]])))

    # DllName.runtimeconfig.json
    runtimeconfig = write_runtimeconfig(dotnet._ctx, library.result, launcher.path)
    # DllName.deps.json
    depsjson = write_depsjson(dotnet, library)

    runfiles = dotnet._ctx.runfiles(
        files = [dotnet.runner, launcher, runtimeconfig, depsjson], 
        transitive_files = depset(
            transitive = [library.runfiles, dotnet.host]
        )
    )

    return DefaultInfo(
        files = depset([library.result, launcher, runtimeconfig, depsjson]),
        runfiles = runfiles,
        executable = launcher,
    )

def _rule_impl(ctx):
    """_rule_impl emits actions for compiling executable assembly."""
    dotnet = dotnet_context(ctx)
    name = ctx.label.name

    assembly = dotnet.assembly(
        dotnet,
        name = name,
        target_type = ctx.attr._target_type,
        srcs = ctx.attr.srcs,
        deps = ctx.attr.deps,
        resources = ctx.attr.resources,
        out = ctx.attr.out,
        defines = ctx.attr.defines,
        data = ctx.attr.data,
        unsafe = ctx.attr.unsafe,
        keyfile = ctx.attr.keyfile,
        server = ctx.executable.server,
    )

    result = [assembly] + assembly.output_groups
    if ctx.attr._target_type == "exe":
        result.append(create_launcher(dotnet, assembly))

    return result

def _rule(target_type, server_default = Label("@io_bazel_rules_dotnet//tools/server:Compiler.Server.Multiplex")):
    return rule(
        _rule_impl,
        attrs = {
            "deps": attr.label_list(providers = [DotnetLibrary]),
            "resources": attr.label_list(providers = [DotnetResourceList]),
            "srcs": attr.label_list(allow_files = [".cs"]),
            "out": attr.string(),
            "defines": attr.string_list(),
            "unsafe": attr.bool(default = False),
            "data": attr.label_list(allow_files = True),
            "keyfile": attr.label(allow_files = True),
            "dotnet_context_data": attr.label(default = Label("@io_bazel_rules_dotnet//:core_context_data")),
            "server": attr.label(
                default = server_default,
                executable = True,
                cfg = "host",
            ),
            "_target_type": attr.string(default = target_type)
        },
        toolchains = ["@io_bazel_rules_dotnet//dotnet:toolchain_core"],
        executable = target_type == "exe",
    )

core_library = _rule("library")
core_binary = _rule("exe")
core_binary_no_server = _rule("exe", None)
