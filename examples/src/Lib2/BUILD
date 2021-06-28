load("@io_bazel_rules_dotnet//dotnet:defs.bzl", "core_library")
resources = []


filegroup(
  name = "Lib2__data",
  srcs = [],
  visibility = ["//visibility:public"]
)

core_library(
  name = "Lib2",
  out = "Lib2.dll",
  srcs = glob(["**/*.cs"], exclude = ["**/obj/**", "**/bin/**"]),
  resources = resources,
  data = [":Lib2__data"],
  deps = [
    "@nuget//microsoft.netcore.app.ref"
  ],
  dotnet_context_data = "//:core_context_data",
  visibility = ["//visibility:public"]
)