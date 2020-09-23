load("@io_bazel_rules_dotnet//dotnet/private:rules/binary.bzl", "core_binary_no_server")
exports_files(["deps.bzl"])

core_binary_no_server(
  name = "Compiler.Server.Multiplex",
  out = "Compiler.Server.Multiplex.dll",
  srcs = glob(["**/*.cs"], exclude = ["**/obj/**", "**/bin/**"]),
  deps = [
    "@nuget//microsoft.netcore.app.ref",
    "@nuget//dnlib",
    "@nuget//google.protobuf",
  ],
  visibility = ["//visibility:public"]
)
