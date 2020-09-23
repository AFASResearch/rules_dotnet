load(
    "@io_bazel_rules_dotnet//dotnet/private:context.bzl",
    "dotnet_context",
)
load(
    "@io_bazel_rules_dotnet//dotnet/private:providers.bzl",
    "DotnetLibrary",
)

T = provider()

def _msbuild_references_aspect_impl(target, ctx):
    if ctx.rule.kind != "core_binary" and ctx.rule.kind != "core_library":
        return [T(targets = depset())]

    dotnet = dotnet_context(ctx, ctx.rule.attr)

    deps = depset(transitive = [d[DotnetLibrary].transitive_refs for d in ctx.rule.attr.deps])

    server_args = [dotnet.runner.path, dotnet.mcs.path]
    if dotnet.execroot_pathmap:
        server_args.append(dotnet.execroot_pathmap)
    
    # Write a .Targets file for IDE integration to be picked up by MSBuild
    targetsfile = dotnet.declare_file(dotnet, path = ctx.rule.attr.name + ".csc.Targets")
    
    job_args = dotnet.actions.args()
    job_args.use_param_file("@%s", use_always = True)
    job_args.set_param_file_format("multiline")
    job_args.add("targets")
    job_args.add(targetsfile)
    job_args.add_all(deps)

    dotnet.actions.run(
        inputs = [],
        outputs = [targetsfile],
        executable = ctx.rule.executable.server,
        arguments = server_args + [job_args],
        mnemonic = "CoreCompile",
        execution_requirements = { "supports-multiplex-workers": "1", "no-cache": "1" },
        tools = [ctx.rule.executable.server],
        progress_message = (
            "Creating csc.Targets " + dotnet.label.package + ":" + dotnet.label.name
        )
    )

    targets = depset([targetsfile], transitive = [d[T].targets for d in ctx.rule.attr.deps])

    return [
        OutputGroupInfo(_targets = targets),
        T(targets = targets)
    ]

msbuild_references_aspect = aspect(
    implementation = _msbuild_references_aspect_impl,
    attr_aspects = ['deps'],
    provides = [T],
    toolchains = ["@io_bazel_rules_dotnet//dotnet:toolchain_core"],
)
