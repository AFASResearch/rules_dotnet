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

def _binary_impl(ctx):
    """_binary_impl emits actions for compiling executable assembly."""
    dotnet = dotnet_context(ctx)
    name = ctx.label.name

    executable = dotnet.assembly(
        dotnet,
        name = name,
        srcs = ctx.attr.srcs,
        deps = ctx.attr.deps,
        resources = ctx.attr.resources,
        out = ctx.attr.out,
        defines = ctx.attr.defines,
        unsafe = ctx.attr.unsafe,
        data = ctx.attr.data,
        executable = True,
        keyfile = ctx.attr.keyfile,
        server = ctx.executable.server,
    )

    # execroot_path is build time scenario
    # runfiles_path is runtime scenario
    launcher = dotnet.declare_file(dotnet, path = "launcher.bat")
    ctx.actions.write(
        output = launcher,
        content = r"""@echo off
SETLOCAL ENABLEEXTENSIONS
SETLOCAL ENABLEDELAYEDEXPANSION
set RUNFILES_MANIFEST_ONLY=1
REM we do not trust an already set MANIFEST_FILE because this may be a calling program
set RUNFILES_MANIFEST_FILE=""
{rlocation_function}
call :rlocation "{dotnet_path}" DOTNET_RUNNER

"%DOTNET_RUNNER%" "%~dp0{dll}" %*
""".format(
    dotnet_path = to_manifest_path(ctx, dotnet.runner),
    rlocation_function = BATCH_RLOCATION_FUNCTION,
    dll = executable.result.basename))

    # DllName.runtimeconfig.json
    runtimeconfig = write_runtimeconfig(dotnet, executable.result.basename, launcher.path)
    # DllName.deps.json
    depsjson = write_depsjson(dotnet, executable.result.basename, executable.transitive)

    runfiles = ctx.runfiles(
        files = [dotnet.runner, launcher, runtimeconfig, depsjson], 
        transitive_files = depset(
            transitive = [executable.runfiles, dotnet.host]
        )
    )

    return [
        executable,
        DefaultInfo(
            files = depset([executable.result, launcher, runtimeconfig, depsjson]),
            runfiles = runfiles,
            executable = launcher,
        ),
    ]

dotnet_binary = rule(
    _binary_impl,
    attrs = {
        "deps": attr.label_list(providers = [DotnetLibrary]),
        "resources": attr.label_list(providers = [DotnetResourceList]),
        "srcs": attr.label_list(allow_files = [".cs"]),
        "out": attr.string(),
        "defines": attr.string_list(),
        "unsafe": attr.bool(default = False),
        "data": attr.label_list(allow_files = True),
        "keyfile": attr.label(allow_files = True),
        "dotnet_context_data": attr.label(default = Label("@io_bazel_rules_dotnet//:dotnet_context_data")),
        "native_deps": attr.label(default = Label("@dotnet_sdk//:native_deps")),
    },
    toolchains = ["@io_bazel_rules_dotnet//dotnet:toolchain"],
    executable = True,
)

core_binary = rule(
    _binary_impl,
    attrs = {
        "deps": attr.label_list(providers = [DotnetLibrary]),
        "analyzers": attr.label_list(providers = [DotnetLibrary]),
        "resources": attr.label_list(providers = [DotnetResourceList]),
        "srcs": attr.label_list(allow_files = [".cs"]),
        "out": attr.string(),
        "defines": attr.string_list(),
        "unsafe": attr.bool(default = False),
        "data": attr.label_list(allow_files = True),
        "keyfile": attr.label(allow_files = True),
        "dotnet_context_data": attr.label(default = Label("@io_bazel_rules_dotnet//:core_context_data")),
        "server": attr.label(
            default = Label("@io_bazel_rules_dotnet//tools/server:Compiler.Server.Multiplex"),
            executable = True,
            cfg = "host",
        ),
        "native_deps": attr.label(default = Label("@core_sdk//:native_deps")),
    },
    toolchains = ["@io_bazel_rules_dotnet//dotnet:toolchain_core"],
    executable = True,
)

core_binary_no_server = rule(
    _binary_impl,
    attrs = {
        "deps": attr.label_list(providers = [DotnetLibrary]),
        "analyzers": attr.label_list(providers = [DotnetLibrary]),
        "resources": attr.label_list(providers = [DotnetResourceList]),
        "srcs": attr.label_list(allow_files = [".cs"]),
        "out": attr.string(),
        "defines": attr.string_list(),
        "unsafe": attr.bool(default = False),
        "data": attr.label_list(allow_files = True),
        "keyfile": attr.label(allow_files = True),
        "dotnet_context_data": attr.label(default = Label("@io_bazel_rules_dotnet//:core_context_data")),
        "server": attr.label(
            default = None,
            executable = True,
            cfg = "host",
        ),
        "native_deps": attr.label(default = Label("@core_sdk//:native_deps")),
    },
    toolchains = ["@io_bazel_rules_dotnet//dotnet:toolchain_core"],
    executable = True,
)

net_binary = rule(
    _binary_impl,
    attrs = {
        "deps": attr.label_list(providers = [DotnetLibrary]),
        "resources": attr.label_list(providers = [DotnetResourceList]),
        "srcs": attr.label_list(allow_files = [".cs"]),
        "out": attr.string(),
        "defines": attr.string_list(),
        "unsafe": attr.bool(default = False),
        "data": attr.label_list(allow_files = True),
        "keyfile": attr.label(allow_files = True),
        "dotnet_context_data": attr.label(default = Label("@io_bazel_rules_dotnet//:net_context_data")),
        "native_deps": attr.label(default = Label("@net_sdk//:native_deps")),
    },
    toolchains = ["@io_bazel_rules_dotnet//dotnet:toolchain_net"],
    executable = True,
)
