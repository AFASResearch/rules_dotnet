load("@io_bazel_rules_dotnet//dotnet:defs.bzl", "core_library")
resources = []


filegroup(
  name = "Lib__data",
  srcs = [],
  visibility = ["//visibility:public"]
)

core_library(
  name = "Lib",
  out = "Lib.dll",
  srcs = glob(["**/*.cs"], exclude = ["**/obj/**", "**/bin/**"]),
  resources = resources,
  data = [":Lib__data"],
  deps = [
    "@nuget//microsoft.netcore.app.ref"
  ],
  visibility = ["//visibility:public"]
)