load("@io_bazel_rules_dotnet//dotnet:defs.bzl", "nuget_package")

def deps():
    nuget_package(
        name = "google.protobuf",
        package = "google.protobuf",
        version = "3.11.4",
        sha256 = "9ce57391f0f3d57d5a3765c907a1685f3653eeb9c211930d960dee2cd1b618f2",
        core_lib = {
            "netcoreapp3.1": "lib/netstandard2.0/Google.Protobuf.dll",
        },
        net_deps = {
            "net45": [
               "@io_bazel_rules_dotnet//dotnet/stdlib.net:net45_system.buffers.dll",
               "@io_bazel_rules_dotnet//dotnet/stdlib.net:net45_system.runtime.compilerservices.unsafe.dll",
            ],
            "net451": [
               "@io_bazel_rules_dotnet//dotnet/stdlib.net:net451_system.buffers.dll",
               "@io_bazel_rules_dotnet//dotnet/stdlib.net:net451_system.runtime.compilerservices.unsafe.dll",
            ],
            "net452": [
               "@io_bazel_rules_dotnet//dotnet/stdlib.net:net452_system.buffers.dll",
               "@io_bazel_rules_dotnet//dotnet/stdlib.net:net452_system.runtime.compilerservices.unsafe.dll",
            ],
            "net46": [
               "@io_bazel_rules_dotnet//dotnet/stdlib.net:net46_system.buffers.dll",
               "@io_bazel_rules_dotnet//dotnet/stdlib.net:net46_system.runtime.compilerservices.unsafe.dll",
            ],
            "net461": [
               "@io_bazel_rules_dotnet//dotnet/stdlib.net:net461_system.buffers.dll",
               "@io_bazel_rules_dotnet//dotnet/stdlib.net:net461_system.runtime.compilerservices.unsafe.dll",
            ],
            "net462": [
               "@io_bazel_rules_dotnet//dotnet/stdlib.net:net462_system.buffers.dll",
               "@io_bazel_rules_dotnet//dotnet/stdlib.net:net462_system.runtime.compilerservices.unsafe.dll",
            ],
            "net47": [
               "@io_bazel_rules_dotnet//dotnet/stdlib.net:net47_system.buffers.dll",
               "@io_bazel_rules_dotnet//dotnet/stdlib.net:net47_system.runtime.compilerservices.unsafe.dll",
            ],
            "net471": [
               "@io_bazel_rules_dotnet//dotnet/stdlib.net:net471_system.buffers.dll",
               "@io_bazel_rules_dotnet//dotnet/stdlib.net:net471_system.runtime.compilerservices.unsafe.dll",
            ],
            "net472": [
               "@io_bazel_rules_dotnet//dotnet/stdlib.net:net472_system.buffers.dll",
               "@io_bazel_rules_dotnet//dotnet/stdlib.net:net472_system.runtime.compilerservices.unsafe.dll",
            ],
        },
        mono_deps = [
            "@io_bazel_rules_dotnet//dotnet/stdlib:system.buffers.dll",
            "@io_bazel_rules_dotnet//dotnet/stdlib:system.runtime.compilerservices.unsafe.dll",
        ],
        core_files = {
            "netcoreapp3.1": [
               "lib/netstandard2.0/Google.Protobuf.dll",
            ],
        },
    )