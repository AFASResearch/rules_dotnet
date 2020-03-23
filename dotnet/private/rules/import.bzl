load(
    "@io_bazel_rules_dotnet//dotnet/private:context.bzl",
    "dotnet_context",
    "new_library",
)
load(
    "@io_bazel_rules_dotnet//dotnet/private:providers.bzl",
    "DotnetLibrary",
)

def _import_library_impl(ctx):
    """net_import_library_impl emits actions for importing an external dll (for example provided by nuget)."""
    name = ctx.label.name

    deps = ctx.attr.deps
    src = ctx.attr.src
    result = src.files.to_list()[0]

    library = new_library(
        dotnet = ctx,
        name = name,
        version = ctx.attr.version,
        deps = deps,
        data = ctx.attr.data,
        result = result,
    )

    return [
        library,
        DefaultInfo(
            files = depset([library.result]),
            runfiles = ctx.runfiles(files = [], transitive_files = library.runfiles),
        ),
    ]

dotnet_import_library = rule(
    _import_library_impl,
    attrs = {
        "deps": attr.label_list(providers = [DotnetLibrary]),
        "src": attr.label(allow_files = [".dll", ".exe"], mandatory = True),
        "data": attr.label_list(allow_files = True),
        "version": attr.string(),
    },
    executable = False,
)

dotnet_import_binary = rule(
    _import_library_impl,
    attrs = {
        "deps": attr.label_list(providers = [DotnetLibrary]),
        "src": attr.label(allow_files = [".dll", ".exe"], mandatory = True),
        "data": attr.label_list(allow_files = True),
        "version": attr.string(),
    },
    executable = False,
)

core_import_library = rule(
    _import_library_impl,
    attrs = {
        "deps": attr.label_list(providers = [DotnetLibrary]),
        "src": attr.label(allow_files = [".dll", ".exe"], mandatory = True),
        "data": attr.label_list(allow_files = True),
        "version": attr.string(),
    },
    executable = False,
)

core_import_binary = rule(
    _import_library_impl,
    attrs = {
        "deps": attr.label_list(providers = [DotnetLibrary]),
        "src": attr.label(allow_files = [".dll", ".exe"], mandatory = True),
        "data": attr.label_list(allow_files = True),
        "version": attr.string(),
    },
    executable = False,
)

net_import_library = rule(
    _import_library_impl,
    attrs = {
        "deps": attr.label_list(providers = [DotnetLibrary]),
        "src": attr.label(allow_files = [".dll", ".exe"], mandatory = True),
        "data": attr.label_list(allow_files = True),
        "version": attr.string(),
    },
    executable = False,
)

net_import_binary = rule(
    _import_library_impl,
    attrs = {
        "deps": attr.label_list(providers = [DotnetLibrary]),
        "src": attr.label(allow_files = [".dll", ".exe"], mandatory = True),
        "data": attr.label_list(allow_files = True),
        "version": attr.string(),
    },
    executable = False,
)
