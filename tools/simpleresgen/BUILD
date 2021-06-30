load("@io_bazel_rules_dotnet//dotnet:defs.bzl", "core_binary")

core_binary(
    name = "simpleresgen",
    out = "simpleresgen.dll",
    srcs = glob(["**/*.cs"]),
    dotnet_context_data = "@io_bazel_rules_dotnet//:core_context_data",
    unsafe = True,
    visibility = ["//visibility:public"],
    deps = [
        "@nuget//microsoft.netcore.app.ref",
    ],
)
