load("@io_bazel_rules_dotnet//dotnet/private:rules/binary.bzl", "core_binary_no_server")
exports_files(["deps.bzl"])

core_binary_no_server(
  name = "Compiler.Server.Multiplex",
  out = "Compiler.Server.Multiplex.dll",
  srcs = glob(["**/*.cs"], exclude = ["**/obj/**", "**/bin/**"]),
  deps = [
    #Adding built-in .Net libs
    "@dnlib//:netcoreapp3.1_core",
    "@google.protobuf//:netcoreapp3.1_core",
    "@io_bazel_rules_dotnet//dotnet/stdlib.core:netstandard.dll",
    "@io_bazel_rules_dotnet//dotnet/stdlib.core:microsoft.csharp.dll",
    "@io_bazel_rules_dotnet//dotnet/stdlib.core:system.reflection.dll"
  ],
  server = None,
  visibility = ["//visibility:public"]
)
