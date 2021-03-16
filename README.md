# Bazel rules for .NET
This repository implements a minimal set of Bazel rules to build .NET projects. It is a fork of [rules_dotnet](https://github.com/AFASResearch/rules_dotnet) but the two repositories have drastically diverged. Using Bazel we build our .NET codebase consisting of close to 500 small to medium sized projects many times faster than `dotnet build`. Incremental builds on CI and during development benefit even more from Bazel thanks to its aggressive (remote) caching features.

**Please note** that currently this project is heavily tailored towards our single-consumer use-case and is implemented for Windows only. We are open for suggestions, pull-requests and general feedback to benefit a wider adoption of Bazel for .NET. Ideally we would collaborate to make `bazel/rules_dotnet` suitable for our scenarios as well but we understand that our ideas may deviate too much.

<!-- # examples -->

<!-- # No test rule -->

# IDE integration
To support IDE resolution of Bazel built .NET binaries we write a `{Project}.bazel.Props` file for each compilation action containing a list of all referenced assemblies. Using [Directory.Build.Targets](https://docs.microsoft.com/en-us/visualstudio/msbuild/customize-your-build) we overwrite the `ResolveAssemblyReferences` MSBuild Target and simply return the list from the Props file. This works but unfortunately we do sometimes encounter issues with Rider/ReSharper getting stuck in a state where it is unable to resolve certain System namespace types (after which the only recovery option is to invalidate caches). Presumably this is because Rider/ReSharper is at some point unable to read references from the Props file and then falls back to some default resolution behavior. We have taken some precautions such that the Props file should always have contents but unfortunately the issue is still quite common.

<!-- ######Plugin -->

# [BazelDotnet](https://github.com/AFASResearch/bazel-dotnet)
## NuGet
One of the main differences with [bazel/rules_dotnet](https://github.com/AFASResearch/rules_dotnet) is NuGet dependency resolution. We chose to take a similar approach as [rules_jvm_external](https://github.com/bazelbuild/rules_jvm_external) that uses Coursier to resolve and download external dependencies in one [external Bazel repository_rule](https://docs.bazel.build/versions/master/external.html). Because no Coursier-like tool exists for .NET we have implemented one called [BazelDotnet](https://github.com/AFASResearch/bazel-dotnet) using various NuGet utility libraries. Using the `BazelDotnet repository` command this tool reads a `Packages.Props` file (as used in the Microsoft provided
[CentralPackageVersions SDK](https://github.com/microsoft/MSBuildSdks/tree/master/src/CentralPackageVersions)) and produces a `@nuget` repository containing (symlinks to) all transitive NuGet dependencies linked together using generated BUILD files. In addition to NuGet logic this command is also responsible for handling various MSBuild SDK concepts such as FrameworkReferences and conflict resolution. Implementation details of the `repository` command can be found [here](https://github.com/AFASResearch/bazel-dotnet/blob/master/src/Afas.BazelDotnet.Nuget/BazelDotnet.Nuget).

## Projects
Because of our existing codebase and tooling we decided to derive `BUILD` files from `.csproj` files. A `BazelDotnet projects` command globs all `.csproj` files and converts all Package and Project references accordingly. We run the `projects` command as a repository_rule to ensure they stay in sync. This however is a bit hacky as it may result in timing issues of `BUILD` files being written and read by Bazel. To reduce the impact of this we also commit `BUILD` files to Git which is generally done for Bazel projects. Currently there are various undocumented features to add content to `BUILD` files by specifying elements in the `.csproj` file.

## Imports & Exports
Because our codebase is not fully contained in a single monorepo we also have a mechanism of loading a local folder as a repository_rule containing sources of NuGet dependencies. In this folder we also run the `projects` command to generate BUILD files and the `@nuget` repository is then able to import the local targets as overrides. These overrides can be made configurable with the use of [config_settings](https://docs.bazel.build/versions/master/configurable-attributes.html).

# Other differences to bazel/rules_dotnet
* A [Multiplex Persistent Worker](https://docs.bazel.build/versions/master/multiplex-worker.html) is implemented for C# compilation which caches and shares resources and communicates with Bazel via std pipes.
* [Reference Assemblies](https://github.com/dotnet/roslyn/blob/master/docs/features/refout.md) are produced and consumed by compilation actions. These assemblies only represent public facing APIs and therefore benefit caching.
* Unused (transitive) dependencies to compilation actions are pruned using the `unused_inputs_list` feature which also improves caching.
* We rely on [Bazel's runfiles mechanic](https://docs.bazel.build/versions/master/skylark/rules.html#runfiles) to symlink runtime dependencies for binaries & tests. To correctly resolve these runfiles we currently fabricate a `deps.json` containing relative paths and use additional probing paths to point to the runfiles root. This currently requires the `--enable_runfiles` flag on Windows.
* Because we do not want to rely on installed `C++` toolchains we use `.bat` files as launchers. Therefore currently these rules are Windows only.
* We have added support for various analyzer related flags on `context_data` and the ability to propagate analyzers via `deps`.
* Minor changes to the `DotnetLibrary` provider were made to support multiple binaries in a single library in accordance with NuGet references. The provider also propagates reference assemblies and analyzers for the relevant features.
* We have added the option to rewrite the execroot path to a fixed location using `csc -pathmap` via `context_data`. This can either be the workspace folder for better compiler warnings/errors or a shared static setting for improved remote caching.
