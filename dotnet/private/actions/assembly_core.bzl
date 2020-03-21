load(
    "@io_bazel_rules_dotnet//dotnet/private:common.bzl",
    "as_iterable",
)
load(
    "@io_bazel_rules_dotnet//dotnet/private:skylib/lib/paths.bzl",
    "paths",
)
load(
    "@io_bazel_rules_dotnet//dotnet/private:providers.bzl",
    "DotnetLibrary",
    "DotnetResource",
    "DotnetResourceList",
)
load(
    "@io_bazel_rules_dotnet//dotnet/private:actions/resolve.bzl",
    "ResolveVersions",
)

def _map_dep(d):
    return d.path

def _map_resource(d):
    return d.result.path + "," + d.identifier

def _make_runner_arglist(dotnet, deps, resources, output, ref_output, pdb, executable, defines, unsafe, keyfile):
    args = dotnet.actions.args()

    # /out:<file>
    args.add(output.path, format = "/out:%s")
    args.add(ref_output.path, format = "/refout:%s")

    if executable:
        target = "exe"
    else:
        target = "library"

    # /target (exe for binary, library for lib, module for module)
    args.add(target, format = "/target:%s")

    args.add("/fullpaths")
    args.add("/nostdlib")
    args.add("/langversion:latest")
    args.add("/nologo")
    args.add("/deterministic+")

    if pdb:
        args.add("-debug:full")
        args.add("-pdb:" + pdb.path)

    args.add_all(dotnet.no_warns, format_each = "/nowarn:%s")

    # /warn
    #args.add(format="/warn:%s", value=str(ctx.attr.warn))

    # /modulename:<string> only used for modules
    #libdirs = _get_libdirs(depinfo.dlls)
    #libdirs = _get_libdirs(depinfo.transitive_dlls, libdirs)

    # /lib:dir1,[dir1]
    #if libdirs:
    #  args.add(format="/lib:%s", value=libdirs)

    if deps and len(deps) > 0:
        args.add_all(deps, format_each = "/reference:%s", map_each = _map_dep)

    args.add(dotnet.stdlib, format = "/reference:%s")

    if defines and len(defines) > 0:
        args.add_all(defines, format_each = "/define:%s")

    if unsafe:
        args.add("/unsafe")

    if keyfile:
        args.add("-keyfile:" + keyfile.files.to_list()[0].path)
        
    # /debug
    #debug = ctx.var.get("BINMODE", "") == "-dbg"
    #if debug:
    #  args.add("/debug")
        
    # /warnaserror
    # TODO(jeremy): /define:name[;name2]

    for r in resources:
        if r[DotnetResourceList].result and len(r[DotnetResourceList].result) > 0:
            args.add_all(r[DotnetResourceList].result, format_each = "/resource:%s", map_each = _map_resource)

    # TODO(jeremy): /resource:filename[,identifier[,accesibility-modifier]]

    # /main:class
    #if hasattr(ctx.attr, "main_class") and ctx.attr.main_class:
    #  args.add(format="/main:%s", value=ctx.attr.main_class)

    #args.add(format="/resource:%s", value=ctx.files.resources)

    # TODO(jwall): /parallel

    return args

def emit_assembly_core(
        dotnet,
        name,
        srcs,
        deps = None,
        out = None,
        resources = None,
        executable = True,
        defines = None,
        unsafe = False,
        data = None,
        keyfile = None,
        subdir = "./",
        server = None):
    """See dotnet/toolchains.rst#binary for full documentation."""

    if name == "" and out == None:
        fail("either name or out must be set")

    if not out:
        filename = name
    else:
        filename = out

    result = dotnet.declare_file(dotnet, path = subdir + filename)
    ref_result = dotnet.declare_file(dotnet, path = subdir + paths.split_extension(filename)[0] + ".ref.dll")

    if dotnet.debug:
        pdb = dotnet.declare_file(dotnet, path = subdir + paths.split_extension(filename)[0] + ".pdb")
    else:
        pdb = None

    deps_libraries = [d[DotnetLibrary] for d in deps]

    transitive, transitive_runfiles = ResolveVersions(deps)
    deps_files = [d[DotnetLibrary].ref_result if d[DotnetLibrary].ref_result else d[DotnetLibrary].result for d in transitive.to_list()]

    runner_args = _make_runner_arglist(dotnet, deps_files, resources, result, ref_result, pdb, executable, defines, unsafe, keyfile)

    attr_srcs = [f for t in srcs for f in as_iterable(t.files)]
    runner_args.add_all(attr_srcs)

    attr_extra_srcs = [f for t in dotnet.extra_srcs for f in as_iterable(t.files)]
    runner_args.add_all(attr_extra_srcs)

    runner_args.use_param_file("@%s", use_always = True)
    runner_args.set_param_file_format("multiline")

    resource_files = [r.result for rs in resources for r in rs[DotnetResourceList].result]

    if server:
        # Write csc params to file so wa can supply the file to the server
        paramfilepath = name + ".csc.param"
        paramfile = dotnet.declare_file(dotnet, path = paramfilepath)
        dotnet.actions.write(output = paramfile, content = runner_args)
        
        worker_args = dotnet.actions.args()
        worker_args.add(paramfile.path)
        worker_args.use_param_file("@%s", use_always = True)
        worker_args.set_param_file_format("multiline")

        # Our compiler server analyzes output dll's to prune the dependency graph
        unused_refs = dotnet.declare_file(dotnet, path = name + ".unused")
        worker_args.add(unused_refs.path)
        # dll to analyze
        worker_args.add(result.path)

        dotnet.actions.run(
            inputs = attr_srcs + [paramfile] + deps_files + [dotnet.stdlib] + resource_files,
            outputs = [result, ref_result, unused_refs] + ([pdb] if pdb else []),
            executable = server,
            arguments = [dotnet.runner.path, dotnet.mcs.path, worker_args],
            mnemonic = "CoreCompile",
            execution_requirements = { "supports-multiplex-workers": "1" },
            tools = [server],
            progress_message = (
                "Compiling " + dotnet.label.package + ":" + dotnet.label.name
            ),
            unused_inputs_list = unused_refs
        )
    else:
        dotnet.actions.run(
            inputs = attr_srcs + deps_files + [dotnet.stdlib] + resource_files,
            outputs = [result, ref_result] + ([pdb] if pdb else []),
            executable = dotnet.runner,
            arguments = [dotnet.mcs.path, "/noconfig", runner_args],
            mnemonic = "CoreCompile",
            progress_message = (
                "Compiling " + dotnet.label.package + ":" + dotnet.label.name
            ),
        )

    extra = depset(direct = [result, ref_result] + [dotnet.stdlib] + ([pdb] if pdb else []), transitive = [t.files for t in data] if data else [])
    d_direct = extra.to_list()
    d_transitive = depset(transitive_runfiles)
    runfiles = depset(direct = d_direct, transitive = [d_transitive])

    return dotnet.new_library(
        dotnet = dotnet,
        name = name,
        deps = deps,
        transitive = transitive,
        result = result,
        ref_result = ref_result,
        pdb = pdb,
        runfiles = runfiles,
    )
