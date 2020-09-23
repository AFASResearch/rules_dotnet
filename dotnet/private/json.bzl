"""
  Write DllName.deps.json
  Write DllName.runtimeconfig.json
"""

load(
    "@io_bazel_rules_dotnet//dotnet/private:providers.bzl",
    "DotnetLibrary",
)
load(
    "@bazel_skylib//lib:paths.bzl",
    "paths",
)

def _assembly_name(name):
    return paths.split_extension(name)[0]

def _quote(s):
    return "\"" + s + "\""

def write_runtimeconfig(ctx, dll_file, launcher_path = None):
    if type(dll_file) == "File":
      name = dll_file.basename
      file = dll_file
    else:
      name = dll_file
      file = None

    runtimeconfig = ctx.actions.declare_file(_assembly_name(name) + ".runtimeconfig.json", sibling = file)

    json = r"""
{
  "runtimeOptions": {
    "additionalProbingPaths": [
      "./"""+ launcher_path + r""".runfiles/""" + ctx.workspace_name + r"""/",
      "./"""+ paths.basename(launcher_path) + r""".runfiles/""" + ctx.workspace_name + r"""/",
      "./"
    ],
    "tfm": "netcoreapp3.1",
    "framework": {
      "name": "Microsoft.AspNetCore.App",
      "version": "3.1.0"
    }
  }
} 
""" if launcher_path else r"""
{
  "runtimeOptions": {
    "tfm": "netcoreapp3.1",
    "framework": {
      "name": "Microsoft.AspNetCore.App",
      "version": "3.1.0"
    }
  }
} 
"""

    ctx.actions.write(runtimeconfig, json)
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

def _runtime_entry_files(files, v):
  return ", ".join([r""""{name}": {obj}""".format(name = f.basename, obj = struct(
            assemblyVersion = v,
            fileVersion = "1.0.0.0"
          ).to_json()) for f in files if f.path.find("/runtimes/") == -1])

def _rid(path):
  segments = path.split('/')
  return segments[segments.index("runtimes") + 1]

def _runtime_target_entry_files(files, v):
  return ", ".join([r""""{name}": {obj}""".format(name = f.basename, obj = struct(
            rid = _rid(f.path),
            assetType = "native" if f.path.find("/lib/") == -1 else "runtime",
            assemblyVersion = v,
            fileVersion = "1.0.0.0"
          ).to_json()) for f in files if f.path.find("/runtimes/") != -1])

def _target_entries(libs):
  return ",\n".join([r"""      "{name}": {o}
        "runtime": {o} {files} {c},
        "runtimeTargets": {o} {target_files} {c}
      {c}""".format(name = name, files = _runtime_entry_files(files, v), target_files = _runtime_target_entry_files(files, v), o = "{", c = "}") for (v, name, _, files) in libs])

def _targets(libs):
  return r"""{o}
{entries}
    {c}""".format(entries = _target_entries(libs), o = "{", c = "}")

def write_depsjson(dotnet_ctx, library):
    # transitive including self
    trans = [library] + [l[DotnetLibrary] for l in library.transitive.to_list()]

    dep_files = [
        (
          l.version + ".0" if l.version else "1.0.0.0", 
          _assembly_name(l.libs[0].basename),
          paths.dirname(l.libs[0].short_path),
          l.libs,
        ) for l in trans if l.libs
    ]

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

    depsjson = dotnet_ctx.declare_file(dotnet_ctx, path = _assembly_name(library.result.basename) + ".deps.json", sibling = library.result)
    dotnet_ctx.actions.write(depsjson, json)
    return depsjson