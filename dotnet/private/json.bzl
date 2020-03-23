"""
  Write DllName.deps.json
  Write DllName.runtimeconfig.json
"""

load(
    "@io_bazel_rules_dotnet//dotnet/private:providers.bzl",
    "DotnetLibrary",
)
load(
    "@io_bazel_rules_dotnet//dotnet/private:skylib/lib/paths.bzl",
    "paths",
)

def _assembly_name(name):
    return paths.split_extension(name)[0]

def _quote(s):
    return "\"" + s + "\""

def write_runtimeconfig(dotnet_ctx, dll_name, launcher_path):
    runtimeconfig = dotnet_ctx.declare_file(dotnet_ctx, path = _assembly_name(dll_name) + ".runtimeconfig.json")
    dotnet_ctx.actions.write(runtimeconfig, r"""
{
  "runtimeOptions": {
    "additionalProbingPaths": [
      "./"""+ launcher_path + r""".runfiles/""" + dotnet_ctx.workspace_name + r"""/",
      "./"
    ],
    "tfm": "netcoreapp3.1",
    "framework": {
      "name": "Microsoft.AspNetCore.App",
      "version": "3.1.0"
    }
  }
} 
""")
    return runtimeconfig

def write_depsjson(dotnet_ctx, dll_name, transitive):
    dep_files = [
        (d[DotnetLibrary].version + ".0" if d[DotnetLibrary].version else "1.0.0.0", d[DotnetLibrary].result) for d in transitive.to_list()
    ]
    #  + [
    #     ("1.0.0.0", f) for f in ctx.attr.native_deps.files.to_list()
    # ]

    libs = "{\n" + ",\n".join(["  " + _quote(_assembly_name(f.basename)) + r""": {
    "type": "package",
    "serviceable": true,
    "sha512": "",
    "path": """ + _quote(paths.dirname(f.short_path)) + r"""
  }""" for (v, f) in dep_files]) + "\n}"

    targets = "{\n" + ",\n".join(["  " + _quote(_assembly_name(f.basename)) + r""": {
    "runtime": {
        """ + _quote(f.basename) + r""": {
          "assemblyVersion": """ + _quote(v) + r""",
          "fileVersion": "1.0.0.0"
        }
    }
  }""" for (v, f) in dep_files]) + "\n}"

    json = r"""
{
  "runtimeTarget": {
      "name": ".NETCoreApp,Version=v3.1"
  },
  "targets": {
    ".NETCoreApp,Version=v3.1": """ + targets + r"""
  },
  "libraries": """ + libs + r"""
}
"""

    depsjson = dotnet_ctx.declare_file(dotnet_ctx, path = _assembly_name(dll_name) + ".deps.json")
    dotnet_ctx.actions.write(depsjson, json)
    return depsjson