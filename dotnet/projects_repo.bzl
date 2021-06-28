def _root(ctx):
  return ctx.path(ctx.attr.workspace).dirname

def _args(ctx):
  args = [
    "-p=.",
    # @nuget prefix
    "-w={}".format(ctx.attr.nuget_repo),
  ]
  
  # imports
  args += ["-i @{}={}".format(label.workspace_name, ctx.path(label)) for label in ctx.attr.imports]

  args += ["--search={}".format(s) for s in ctx.attr.search]

  if ctx.attr.build_file_append:
    args.append("--append={}".format(ctx.path(ctx.attr.build_file_append)))

  args += ["-v {}={}".format(pattern, ",".join(visibilities)) for pattern, visibilities in ctx.attr.visibilities.items()]

  return args

def _cmds(ctx, args):
  return [
      str(ctx.path(ctx.attr.dotnet_binary)),
      str(ctx.path(ctx.attr._bazel_dotnet)),
      "projects",
  ] + args

def _run(ctx, args):
  r = ctx.execute(_cmds(ctx, args))
        
  if r.return_code != 0:
    print(r.stdout)
    print(r.return_code)
    fail(r.stderr)

# run git clean on new_.. to ensure clean up is done right
def _projects_ci(ctx, path, git_clean = False):
  ctx.file("projects_ci.cmd", (r"""@echo off
cd {root}
git clean -xfd {globs} >nul
{cmds}
""" if git_clean else r"""@echo off
cd {root}
{cmds}
""").format(
    root = path,
    globs = " ".join(["{}/**/BUILD".format(s) for s in ctx.attr.search]) if len(ctx.attr.search) else "**/BUILD",
    cmds = " ".join(_cmds(ctx, _args(ctx)))
  ))

# run from platform. also fix backend
def _fix(ctx):
  ctx.file("fix.cmd", r"""@echo off
cd {root}
{cmds}

bazel build ... --output_groups=targets
""".format(
    root = _root(ctx),
    globs = " ".join(["{}/**/BUILD".format(s) for s in ctx.attr.search]),
    cmds = " ".join(_cmds(ctx, _args(ctx)))
  ))

# link all search directories
def _link_search(ctx, root):
    for s in ctx.attr.search:
      p = ctx.path("{}/{}".format(root, s))
      ctx.symlink(p, s)

def _projects_repo_impl(ctx):
  _link_search(ctx, _root(ctx))

  _run(ctx, _args(ctx))

  _projects_ci(ctx, _root(ctx))
  _fix(ctx)
  ctx.file("fix.bzl", "def fix():\n  return 0")
  ctx.file("BUILD", r"""exports_files(["fix.bzl", "fix.cmd", "projects_ci.cmd"])""")

def _new_projects_repo_impl(ctx):
  args = _args(ctx)

  # link new_repo_path
  relp = ctx.path("{}/{}".format(ctx.path(ctx.attr.workspace).dirname, ctx.attr.path))
  if relp.exists:
    _link_search(ctx, relp)

    # exports: Name the exports file the same as the repo for easy imports
    args.append("-e=.bazel-projects")

    _run(ctx, args)

    _projects_ci(ctx, relp, git_clean = True)
  else:
    # add stubs
    ctx.file(".bazel-projects", "")
    ctx.file("projects_ci.cmd", "@echo off\n")

  # Add the same context data to the repo
  if ctx.attr.build_file:
    ctx.file("BUILD", ctx.read(ctx.attr.build_file))

projects_repo = repository_rule(
    _projects_repo_impl,
    local=True,
    attrs = {
        "workspace": attr.label(default = "//:WORKSPACE"),
        "search": attr.string_list(),
        "nuget_repo": attr.string(default = "nuget"),
        "imports": attr.label_list(default = []),
        "_bazel_dotnet": attr.label(default = "@bazel_dotnet//:Afas.BazelDotnet.dll", allow_single_file = True),
        "dotnet_binary": attr.label(default = "@core_sdk//:dotnet.exe", allow_single_file = True),
        "build_file_append": attr.label(default = None, allow_single_file = True),
        "visibilities": attr.string_list_dict(),
    },
)

new_projects_repo = repository_rule(
    _new_projects_repo_impl,
    local=True,
    attrs = {
        "workspace": attr.label(default = "//:WORKSPACE"),
        "search": attr.string_list(default = []),
        "path": attr.string(),
        "build_file": attr.label(allow_single_file = True, default = None),
        "nuget_repo": attr.string(),
        "imports": attr.label_list(default = []),
        "_bazel_dotnet": attr.label(default = "@bazel_dotnet//:Afas.BazelDotnet.dll", allow_single_file = True),
        "dotnet_binary": attr.label(default = "@core_sdk//:dotnet.exe", allow_single_file = True),
        "build_file_append": attr.label(default = None, allow_single_file = True),
        "visibilities": attr.string_list_dict(),
    },
)
