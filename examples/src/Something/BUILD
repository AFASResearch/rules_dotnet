load("@io_bazel_rules_dotnet//dotnet:defs.bzl", "core_library")
resources = []


filegroup(
  name = "Something__data",
  srcs = [],
  visibility = ["//visibility:public"]
)

core_library(
  name = "Something",
  out = "Something.dll",
  srcs = glob(["**/*.cs"], exclude = ["**/obj/**", "**/bin/**"]),
  resources = resources,
  data = [":Something__data"],
  deps = [
    "@nuget//microsoft.netcore.app.ref"
  ],
  dotnet_context_data = "//:core_context_data",
  visibility = ["//visibility:public"]
)