load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

def _dependencies():
    for name, config in {
        "bazel_skylib": {
            "sha256": "1c531376ac7e5a180e0237938a2536de0c54d93f5c278634818e0efc952dd56c",
            "urls": [
                "https://github.com/bazelbuild/bazel-skylib/releases/download/1.0.3/bazel-skylib-1.0.3.tar.gz",
                "https://mirror.bazel.build/github.com/bazelbuild/bazel-skylib/releases/download/1.0.3/bazel-skylib-1.0.3.tar.gz",
            ],
        },
    }.items():
        if not name in native.existing_rules():
            http_archive(
                name = name,
                **config
            )

def _core_download_sdk_impl(ctx):
    ctx.download_and_extract(
        url = ctx.attr.urls,
        sha256 = ctx.attr.sha256,
        output = ctx.path("."),
    )

    ctx.symlink("sdk/" + ctx.attr.version, "sdk/current")

    ctx.template(
        "BUILD.bazel",
        Label("@io_bazel_rules_dotnet//dotnet/private:BUILD.sdk.bazel"),
        executable = False,
        substitutions = {
            "{name}": ctx.attr.name,
        }
    )

core_download_sdk = repository_rule(
    _core_download_sdk_impl,
    attrs = {
        "urls": attr.string_list(),
        "sha256": attr.string(),
        "version": attr.string(),
    },
)

# Currently very simplified
def core_register_sdk(
    version = "3.1.100",
    name = "core_sdk",
    urls = [
        "https://download.visualstudio.microsoft.com/download/pr/28a2c4ff-6154-473b-bd51-c62c76171551/ea47eab2219f323596c039b3b679c3d6/dotnet-sdk-3.1.100-win-x64.zip",
    ],
    sha256 = "abcd034b230365d9454459e271e118a851969d82516b1529ee0bfea07f7aae52",
):
    _dependencies()

    core_download_sdk(
        name = name,
        version = version,
        urls = urls,
        sha256 = sha256,
    )

    native.register_toolchains(
        "@{}//:{}".format(name, name),
    )
