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
    launcher_name = paths.basename(launcher_path)
    dotnet_ctx.actions.write(runtimeconfig, r"""
{
  "runtimeOptions": {
    "additionalProbingPaths": [
      "./"""+ launcher_path + r""".runfiles/""" + dotnet_ctx.workspace_name + r"""/",
      "./"""+ launcher_name + r""".runfiles/""" + dotnet_ctx.workspace_name + r"""/",
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

def _lib_entries(libs):
  return ",\n".join([r"""    "{name}": {o}
      "type": "package",
      "serviceable": true,
      "sha512": "",
      "path": "{path}"
    {c}""".format(name = name, path = path, o = "{", c = "}") for (_, name, path, _) in libs])

def _libs(libs):
  return r"""{o}
{entries}
  {c}""".format(entries = _lib_entries(libs), o = "{", c = "}")

def _target_entry_files(files, v):
  return ",\n".join([r"""          "{name}": {o}
            "assemblyVersion": "{v}",
            "fileVersion": "1.0.0.0"
          {c}""".format(name = f.basename, v = v, o = "{", c = "}") for f in files])

def _target_entries(libs):
  return ",\n".join([r"""      "{name}": {o}
        "runtime": {o}
{files}
        {c}
      {c}""".format(name = name, files = _target_entry_files(files, v), o = "{", c = "}") for (v, name, _, files) in libs])

def _targets(libs):
  return r"""{o}
{entries}
    {c}""".format(entries = _target_entries(libs), o = "{", c = "}")

def write_depsjson(dotnet_ctx, dll_name, transitive):
    dep_files = [
        (
          d[DotnetLibrary].version + ".0" if d[DotnetLibrary].version else "1.0.0.0", 
          _assembly_name(d[DotnetLibrary].libs[0].basename),
          paths.dirname(d[DotnetLibrary].libs[0].short_path),
          d[DotnetLibrary].libs,
        ) for d in transitive.to_list() if d[DotnetLibrary].libs
    ]
    #  + [
    #     ("1.0.0.0", f) for f in ctx.attr.native_deps.files.to_list()
    # ]

    libs = _libs(dep_files)
    targets = _targets(dep_files)

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