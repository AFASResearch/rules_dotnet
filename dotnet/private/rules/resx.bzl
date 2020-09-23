load(
    "@io_bazel_rules_dotnet//dotnet/private:context.bzl",
    "dotnet_context",
)
load(
    "@io_bazel_rules_dotnet//dotnet/private:providers.bzl",
    "DotnetResourceList",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

def _resx_impl(ctx):
    """dotnet_resx_impl emits actions for compiling resx to resource."""
    dotnet = dotnet_context(ctx)
    name = ctx.label.name

    # Handle case of empty toolchain on linux and darwin
    if dotnet.resx == None:
        result = dotnet.declare_file(dotnet, path = "empty.resources")
        dotnet.actions.write(output = result, content = ".net not supported on this platform")
        empty = dotnet.new_resource(dotnet = dotnet, name = name, result = result)
        return [empty, DotnetResourceList(result = [empty])]

    resource = dotnet.resx(
        dotnet,
        name = name,
        src = ctx.attr.src,
        identifier = ctx.attr.identifier,
        out = ctx.attr.out,
        customresgen = ctx.attr.simpleresgen,
    )
    return [
        resource,
        DotnetResourceList(result = [resource]),
        DefaultInfo(
            files = depset([resource.result]),
        ),
    ]

core_resx = rule(
    _resx_impl,
    attrs = {
        # source files for this target.
        "src": attr.label(allow_files = [".resx"], mandatory = True),
        "identifier": attr.string(),
        "out": attr.string(),
        "dotnet_context_data": attr.label(default = Label("@io_bazel_rules_dotnet//:core_context_data")),
        "simpleresgen": attr.label(default = Label("@io_bazel_rules_dotnet//tools/simpleresgen:simpleresgen")),
    },
    toolchains = ["@io_bazel_rules_dotnet//dotnet:toolchain_core"],
    executable = False,
)
