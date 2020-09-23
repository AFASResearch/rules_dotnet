load(
    "@io_bazel_rules_dotnet//dotnet/private:context.bzl",
    "dotnet_context",
    "new_library",
)
load(
    "@io_bazel_rules_dotnet//dotnet/private:providers.bzl",
    "DotnetLibrary",
)
load(
    "@io_bazel_rules_dotnet//dotnet/private:rules/binary.bzl",
    "create_launcher",
)

def _import_library_impl(ctx):
    """net_import_library_impl emits actions for importing an external dll (for example provided by nuget)."""
    library = new_library(
        dotnet = ctx,
        name = ctx.label.name,
        version = ctx.attr.version,
        deps = ctx.attr.deps,
        data = ctx.attr.data,
        result = ctx.file.src if hasattr(ctx.file, "src") else None,
        libs = ctx.files.libs if ctx.files.libs else ctx.files.src,
        refs = ctx.files.src if ctx.files.src else ctx.files.refs,
        analyzers = ctx.files.analyzers,
    )

    return [
        library,
        DefaultInfo(
            runfiles = ctx.runfiles(transitive_files = library.runfiles)
        )
    ]

def _import_binary_impl(ctx):
    library = _import_library_impl(ctx)[0]
    dotnet = dotnet_context(ctx)
    
    return [
        library,
        create_launcher(dotnet, library)
    ]

core_import_library = rule(
    _import_library_impl,
    attrs = {
        "deps": attr.label_list(providers = [DotnetLibrary]),
        "src": attr.label(allow_single_file = [".dll", ".exe"]),
        "libs": attr.label_list(allow_files = [".dll", ".exe"]),
        "refs": attr.label_list(allow_files = [".dll", ".exe"]),
        "analyzers": attr.label_list(allow_files = [".dll"]),
        "data": attr.label_list(allow_files = True),
        "version": attr.string(),
    },
    executable = False,
)

core_import_binary = rule(
    _import_binary_impl,
    attrs = {
        "deps": attr.label_list(providers = [DotnetLibrary]),
        "src": attr.label(allow_single_file = [".dll", ".exe"], mandatory = True),
        "libs": attr.label_list(allow_files = [".dll", ".exe"]),
        "data": attr.label_list(allow_files = True),
        "analyzers": attr.label_list(allow_files = [".dll"]),
        "version": attr.string(),
        "dotnet_context_data": attr.label(default = Label("@io_bazel_rules_dotnet//:core_context_data")),
    },
    toolchains = ["@io_bazel_rules_dotnet//dotnet:toolchain_core"],
    executable = True,
)
