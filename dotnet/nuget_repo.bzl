def _create_import(ctx, label, condition):
  # imports a single target
  if label.package:
    return "-i {}=={}".format(str(label), condition)

  # using a .bazel-projects import file from a projects repo
  return "-i @{}={}={}".format(label.workspace_name, ctx.path(label), condition)

def _nuget_repo_impl(ctx):
  r = ctx.execute([
        ctx.path(ctx.attr.dotnet_binary),
        ctx.path(ctx.attr._bazel_dotnet),
        "repository",
        ctx.path(ctx.attr.nuget_config),
    ] + [
      # Add all Packages.Props
      "-p={}".format(ctx.path(f)) for f in ctx.attr.packages_props
    ] + [
      # Add all conditional imports
      _create_import(ctx, label, condition) for label, condition in ctx.attr.imports.items()
    ])
    
  if r.return_code != 0:
    print(r.stdout)
    fail("nuget_repository failed with exit code " + repr(r.return_code) + "\n\n" + r.stderr)
    
  ctx.file("BUILD", r"""
)""")

nuget_repo = repository_rule(
    _nuget_repo_impl,
    attrs = {
        "packages_props": attr.label_list(default = ["//:Packages.Props"], allow_files = True),
        "nuget_config": attr.label(default = Label("//:nuget.config"), allow_single_file = True),
        "_bazel_dotnet": attr.label(default = "@bazel_dotnet//:Afas.BazelDotnet.dll", allow_single_file = True),
        "dotnet_binary": attr.label(default = "@core_sdk//:dotnet.exe", allow_single_file = True),
        "imports": attr.label_keyed_string_dict(allow_files = True),
    },
)
