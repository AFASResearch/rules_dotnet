load("@io_bazel_rules_dotnet//dotnet:defs.bzl", "core_library")
resources = []


filegroup(
  name = "Example__data",
  srcs = [],
  visibility = ["//visibility:public"]
)

core_library(
  name = "Example",
  out = "Example.dll",
  srcs = glob(["**/*.cs"], exclude = ["**/obj/**", "**/bin/**"]),
  resources = resources,
  data = [":Example__data"],
  deps = [
    "@nuget//microsoft.netcore.app.ref",
    "//src/Lib:Lib",
    "//src/Lib2:Lib2",
    "//src/Something:Something",
    "//src/Library:Library",
    "//src/Lib3:Lib3",
  ],
  dotnet_context_data = "//:core_context_data",
  visibility = ["//visibility:public"]
)