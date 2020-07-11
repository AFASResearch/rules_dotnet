load(
    "@io_bazel_rules_dotnet//dotnet/private:providers.bzl",
    "DotnetLibrary",
    "DotnetResource",
)

DotnetContext = provider()

def _declare_file(dotnet, path = None, ext = None, sibling = None):
    result = path if path else dotnet._ctx.label.name
    if ext:
        result += ext
    return dotnet.actions.declare_file(result, sibling = sibling)

def new_library(
    dotnet, name = None,
    version = None,
    deps = None,
    data = None,
    result = None,
    ref_result = None,
    pdb = None,
    libs = None,
    refs = None,
    analyzers = None,
    **kwargs
):
    if not libs:
        libs = [result] if result else []

    if not refs:
        if ref_result:
            refs = [ref_result]
        else:
            refs = libs

    if not all([type(f) == "File" for f in refs]):
        fail(refs)
    
    transitive = depset(direct = deps, transitive = [a[DotnetLibrary].transitive for a in deps])
    transitive_refs = depset(direct = refs, transitive = [a[DotnetLibrary].transitive_refs for a in deps])
    transitive_analyzers = depset(direct = analyzers, transitive = [a[DotnetLibrary].transitive_analyzers for a in deps])
    runfiles = depset(
        direct = libs + ([pdb] if pdb else []),
        transitive = [a[DotnetLibrary].runfiles for a in deps] + (
            [t.files for t in data] if data else []
        )
    )

    return DotnetLibrary(
        name = dotnet.label.name if not name else name,
        label = dotnet.label,
        deps = deps,
        transitive_refs = transitive_refs,
        transitive_analyzers = transitive_analyzers,
        transitive = transitive,
        result = result,
        libs = libs,
        ref_result = ref_result,
        pdb = pdb,
        runfiles = runfiles,
        version = version,
        **kwargs
    )

def _new_resource(dotnet, name, result, identifier = None, **kwargs):
    return DotnetResource(
        name = name,
        label = dotnet.label,
        result = result,
        identifier = result.basename if not identifier else identifier,
        **kwargs
    )

def dotnet_context(ctx, attr = None):
    if not attr:
        attr = ctx.attr

    context_data = attr.dotnet_context_data
    toolchain = ctx.toolchains[context_data._toolchain_type]

    ext = ""
    if toolchain.default_dotnetos == "windows":
        ext = ".exe"

    # Handle empty toolchain for .NET on linux and osx
    if toolchain.get_dotnet_runner == None:
        runner = None
        mcs = None
        stdlib = None
        resgen = None
        tlbimp = None
    else:
        runner = toolchain.get_dotnet_runner(context_data, ext)
        mcs = toolchain.get_dotnet_mcs(context_data)
        stdlib = toolchain.get_dotnet_stdlib(context_data)
        resgen = toolchain.get_dotnet_resgen(context_data)
        tlbimp = toolchain.get_dotnet_tlbimp(context_data)

    return DotnetContext(
        # Fields
        label = ctx.label,
        toolchain = toolchain,
        actions = ctx.actions,
        assembly = toolchain.actions.assembly,
        resx = toolchain.actions.resx,
        com_ref = toolchain.actions.com_ref,
        stdlib_byname = toolchain.actions.stdlib_byname,
        exe_extension = ext,
        runner = runner,
        mcs = mcs,
        stdlib = stdlib,
        resgen = resgen,
        tlbimp = tlbimp,
        declare_file = _declare_file,
        new_library = new_library,
        new_resource = _new_resource,
        workspace_name = ctx.workspace_name,
        libVersion = context_data._libVersion,
        framework = context_data._framework,
        lib = context_data._lib,
        shared = context_data._shared,
        debug = ctx.var["COMPILATION_MODE"] == "dbg",
        extra_srcs = context_data._extra_srcs,
        no_warns = context_data._no_warns,
        analyzer_ruleset = context_data._analyzer_ruleset,
        analyzer_config = context_data._analyzer_config,
        analyzer_additionalfiles = context_data._analyzer_additionalfiles,
        warn_as_error = context_data._warn_as_error,
        host = context_data._host.files,
        execroot_pathmap = context_data._execroot_pathmap,
        _ctx = ctx,
    )

def _dotnet_context_data(ctx):
    return struct(
        _mcs_bin = ctx.attr.mcs_bin,
        _mono_bin = ctx.attr.mono_bin,
        _lib = ctx.attr.lib,
        _tools = ctx.attr.tools,
        _shared = ctx.attr.shared,
        _host = ctx.attr.host,
        _libVersion = ctx.attr.libVersion,
        _toolchain_type = ctx.attr._toolchain_type,
        _extra_srcs = ctx.attr.extra_srcs,
        _no_warns = ctx.attr.no_warns,
        _analyzer_ruleset = ctx.file.analyzer_ruleset,
        _analyzer_config = ctx.file.analyzer_config,
        _analyzer_additionalfiles = ctx.files.analyzer_additionalfiles,
        _warn_as_error = ctx.attr.warn_as_error,
        _framework = ctx.attr.framework,
        _execroot_pathmap = ctx.attr.execroot_pathmap,
    )

dotnet_context_data = rule(
    _dotnet_context_data,
    attrs = {
        "mcs_bin": attr.label(
            allow_files = True,
            default = "@dotnet_sdk//:mcs_bin",
        ),
        "mono_bin": attr.label(
            allow_files = True,
            default = "@dotnet_sdk//:mono_bin",
        ),
        "lib": attr.label(
            allow_files = True,
            default = "@dotnet_sdk//:lib",
        ),
        "tools": attr.label(
            allow_files = True,
            default = "@dotnet_sdk//:lib",
        ),
        "shared": attr.label(
            allow_files = True,
            default = "@dotnet_sdk//:lib",
        ),
        "host": attr.label(
            allow_files = True,
            default = "@dotnet_sdk//:lib",
        ),
        "libVersion": attr.string(
            default = "4.5",
        ),
        "framework": attr.string(
            default = "",
        ),
        "_toolchain_type": attr.string(
            default = "@io_bazel_rules_dotnet//dotnet:toolchain",
        ),
        "extra_srcs": attr.label_list(
            allow_files = True,
            default = [],
        ),
        "no_warns": attr.string_list(
            default = [],
        ),
    },
)

core_context_data = rule(
    _dotnet_context_data,
    attrs = {
        "mcs_bin": attr.label(
            allow_files = True,
            default = "@core_sdk//:mcs_bin",
        ),
        "mono_bin": attr.label(
            allow_files = True,
            default = "@core_sdk//:mono_bin",
        ),
        "lib": attr.label(
            allow_files = True,
            default = "@core_sdk//:lib",
        ),
        "tools": attr.label(
            allow_files = True,
            default = "@core_sdk//:lib",
        ),
        "shared": attr.label(
            allow_files = True,
            default = "@core_sdk//:shared",
        ),
        "host": attr.label(
            allow_files = True,
            default = "@core_sdk//:host",
        ),
        "libVersion": attr.string(
            default = "",
        ),
        "framework": attr.string(
            default = "",
        ),
        "_toolchain_type": attr.string(
            default = "@io_bazel_rules_dotnet//dotnet:toolchain_core",
        ),
        "extra_srcs": attr.label_list(
            allow_files = True,
            default = [],
        ),
        "no_warns": attr.string_list(
            default = [],
        ),     
        "analyzer_ruleset": attr.label(
            default = None,
            allow_single_file = True,
        ),
        "analyzer_config": attr.label(
            default = None,
            allow_single_file = True,
        ),        
        "warn_as_error": attr.bool(
            default = False,
        ),        
        "analyzer_additionalfiles": attr.label_list(
            default = [],
            allow_files = True,
        ),        
        "execroot_pathmap": attr.string(
            default = "",
        ),        
    },
)

net_context_data = rule(
    _dotnet_context_data,
    attrs = {
        "mcs_bin": attr.label(
            allow_files = True,
            default = "@net_sdk//:mcs_bin",
        ),
        "mono_bin": attr.label(
            allow_files = True,
            default = "@net_sdk//:mono_bin",
        ),
        "lib": attr.label(
            allow_files = True,
            default = "@net_sdk//:lib",
        ),
        "tools": attr.label(
            allow_files = True,
            default = "@net_sdk//:tools",
        ),
        "shared": attr.label(
            allow_files = True,
            default = "@net_sdk//:lib",
        ),
        "host": attr.label(
            allow_files = True,
            default = "@net_sdk//:mcs_bin",
        ),
        "libVersion": attr.string(
            mandatory = True,
        ),
        "framework": attr.string(
            default = "",
        ),
        "_toolchain_type": attr.string(
            default = "@io_bazel_rules_dotnet//dotnet:toolchain_net",
        ),
        "extra_srcs": attr.label_list(
            allow_files = True,
            default = ["@net_sdk//:targetframework"],
        ),
        "no_warns": attr.string_list(
            default = [],
        ),
    },
)
