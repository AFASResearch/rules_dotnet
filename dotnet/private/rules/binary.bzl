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
load("@bazel_skylib//lib:paths.bzl", "paths")

# DotnetContext, DotnetLibrary
def create_launcher(dotnet, library, shim = None):
    launch_target = shim if shim else library.result
    launcher = dotnet.declare_file(dotnet, path = "launcher.bat", sibling = launch_target)
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

%~dp0{launch_target} --additionalprobingpath "%RUNFILES_DIR%\{workspace_name}" %*
""".format(
    launch_target = launch_target.basename,
    workspace_name = dotnet.workspace_name,
    depth = "/".join([".." for _ in to_manifest_path(dotnet, launcher).split("/")[1:]])))

    # DllName.runtimeconfig.json
    runtimeconfig = write_runtimeconfig(dotnet._ctx, launch_target, launcher.path)
    # DllName.deps.json
    depsjson = write_depsjson(dotnet, library)

    runfiles = dotnet._ctx.runfiles(
        files = [launch_target, dotnet.runner, launcher, runtimeconfig, depsjson], 
        transitive_files = depset(
            transitive = [library.runfiles, dotnet.host]
        )
    )

    return DefaultInfo(
        files = depset([launch_target, library.result, launcher, runtimeconfig, depsjson]),
        runfiles = runfiles,
        executable = launcher,
    )

# copies apphost.exe and embeds target dll path to dllname.exe
def create_shim_exe(ctx, dll):
    exe = ctx.actions.declare_file(paths.replace_extension(dll.basename, ".exe"), sibling = dll)

    ctx.actions.run(
        executable = ctx.file.dotnet_binary,
        arguments = [ctx.file.bazel_dotnet.path, "shim", ctx.file.apphost.path, dll.path],
        inputs = [ctx.file.bazel_dotnet, ctx.file.apphost, dll],
        outputs = [exe],
    )

    return exe

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
        args = ["/nullable"] if ctx.attr.nullable else []
    )

    result = [assembly] + assembly.output_groups
    if ctx.attr._target_type == "exe":
        shim = create_shim_exe(ctx, assembly.result)
        result.append(create_launcher(dotnet, assembly, shim))
    else:
        # always output a DefaultInfo with a file so directly building this target will trigger actions
        result.append(DefaultInfo(
            files = depset([assembly.result]),
        ))

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
            "nullable": attr.bool(default = False),
            "data": attr.label_list(allow_files = True),
            "keyfile": attr.label(allow_files = True),
            "dotnet_context_data": attr.label(default = Label("@io_bazel_rules_dotnet//:core_context_data")),
            "server": attr.label(
                default = server_default,
                executable = True,
                cfg = "host",
            ),
            "_target_type": attr.string(default = target_type),

            # Shim dependencies
            "bazel_dotnet": attr.label(default = "@bazel_dotnet//:Afas.BazelDotnet.dll", allow_single_file = True),
            "dotnet_binary": attr.label(default = "@core_sdk//:dotnet.exe", allow_single_file = True),
            "apphost": attr.label(default = "@core_sdk//:sdk/current/AppHostTemplate/apphost.exe", allow_single_file = True),
        },
        toolchains = ["@io_bazel_rules_dotnet//dotnet:toolchain_core"],
        executable = target_type == "exe",
    )

core_library = _rule("library")
core_binary = _rule("exe")
core_binary_no_server = _rule("exe", None)
