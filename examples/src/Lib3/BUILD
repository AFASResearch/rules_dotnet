load("@io_bazel_rules_dotnet//dotnet:defs.bzl", "core_library")
resources = []


filegroup(
  name = "Lib3__data",
  srcs = [],
  visibility = ["//visibility:public"]
)

core_library(
  name = "Lib3",
  out = "Lib3.dll",
  srcs = glob(["**/*.cs"], exclude = ["**/obj/**", "**/bin/**"]),
  resources = resources,
  data = [":Lib3__data"],
  deps = [
    "@nuget//microsoft.netcore.app.ref"
  ],
  dotnet_context_data = "//:core_context_data",
  visibility = ["//visibility:public"]
)