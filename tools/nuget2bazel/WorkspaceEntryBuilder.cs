using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using NuGet.Client;
using NuGet.ContentModel;
using NuGet.Frameworks;
using NuGet.Packaging;
using NuGet.Packaging.Core;
using NuGet.Repositories;

namespace nuget2bazel
{
    internal class WorkspaceEntryBuilder
    {
        // TODO check main file
        private readonly string _mainFile;
        private readonly ManagedCodeConventions _conventions;
        private readonly List<FrameworkRuntimePair> _targets;

        public WorkspaceEntryBuilder(ManagedCodeConventions conventions, string mainFile = null)
        {
            _conventions = conventions;
            _mainFile = mainFile;
            _targets = new List<FrameworkRuntimePair>();
        }

        public WorkspaceEntryBuilder WithTarget(FrameworkRuntimePair target)
        {
            _targets.Add(target);
            return this;
        }

        public WorkspaceEntryBuilder WithTarget(NuGetFramework target)
        {
            _targets.Add(new FrameworkRuntimePair(target, runtimeIdentifier: null));
            return this;
        }

        public IEnumerable<WorkspaceEntry> Build(LocalPackageSourceInfo localPackageSourceInfo)
        {
            var collection = new ContentItemCollection();
            collection.Load(localPackageSourceInfo.Package.Files);

            var libItemGroups = new List<FrameworkSpecificGroup>();
            var runtimeItemGroups = new List<FrameworkSpecificGroup>();
            var toolItemGroups = new List<FrameworkSpecificGroup>();

            foreach(var target in _targets)
            {
                SelectionCriteria criteria = _conventions.Criteria.ForFrameworkAndRuntime(target.Framework, target.RuntimeIdentifier);

                var bestCompileGroup = collection.FindBestItemGroup(criteria,
                    _conventions.Patterns.CompileRefAssemblies,
                    _conventions.Patterns.CompileLibAssemblies);
                var bestRuntimeGroup = collection.FindBestItemGroup(criteria, _conventions.Patterns.RuntimeAssemblies)
                                       // fallback to best compile group
                                       ?? bestCompileGroup;
                var bestToolGroup = collection.FindBestItemGroup(criteria, _conventions.Patterns.ToolsAssemblies);

                if(bestCompileGroup != null)
                {
                    libItemGroups.Add(new FrameworkSpecificGroup(target.Framework, bestCompileGroup.Items.Select(i => i.Path)));
                }

                if(bestRuntimeGroup != null)
                {
                    runtimeItemGroups.Add(new FrameworkSpecificGroup(target.Framework, bestRuntimeGroup.Items.Select(i => i.Path)));
                }

                if(bestToolGroup != null)
                {
                    toolItemGroups.Add(new FrameworkSpecificGroup(target.Framework, bestToolGroup.Items.Select(i => i.Path)));
                }
            }

            var depsGroups = localPackageSourceInfo.Package.Nuspec.GetDependencyGroups();
            
            var sha256 = "";

            var source = localPackageSourceInfo.Package.Id.StartsWith("afas.", StringComparison.OrdinalIgnoreCase) ||
                         localPackageSourceInfo.Package.Id.EndsWith(".by.afas", StringComparison.OrdinalIgnoreCase)
                ? "https://nuget.afasgroep.nl/api/v2/package"
                : null;

            var dlls = runtimeItemGroups
                .SelectMany(g => g.Items)
                .Select(Path.GetFileNameWithoutExtension)
                .Distinct(StringComparer.OrdinalIgnoreCase);
            if(dlls.Count() > 1)
            {
                var additionalDlls = dlls.Where(p => !string.Equals(p, localPackageSourceInfo.Package.Id, StringComparison.OrdinalIgnoreCase));

                // Some nuget packages contain multiple dll's required at compile time.
                // The bazel rules do not support this, but we can fake this by creating mock packages for each additional dll.

                // TODO add additional dep
                // TODO create additional entry
                // TODO remove from runtimeItems
                foreach (var additionalDll in additionalDlls)
                {
                    yield return new WorkspaceEntry(new PackageIdentity(localPackageSourceInfo.Package.Id, localPackageSourceInfo.Package.Version), sha256,
                        Array.Empty<PackageDependencyGroup>(), 
                        FilterSpecificDll(runtimeItemGroups, additionalDll), 
                        Array.Empty<FrameworkSpecificGroup>(), 
                        Array.Empty<FrameworkSpecificGroup>(), _mainFile, null,
                        packageSource: source,
                        name: additionalDll);
                }
                
                // Add a root package that refs all additional dlls

                var addedDeps = depsGroups.Select(d => new PackageDependencyGroup(d.TargetFramework, 
                    d.Packages.Concat(additionalDlls.Select(dll => new PackageDependency(dll)))));

                yield return new WorkspaceEntry(new PackageIdentity(localPackageSourceInfo.Package.Id, localPackageSourceInfo.Package.Version), sha256,
                    addedDeps, 
                    // In case there is a dll with the packages name we still ref it on the root package.
                    FilterSpecificDll(runtimeItemGroups, localPackageSourceInfo.Package.Id), 
                    toolItemGroups, 
                    Array.Empty<FrameworkSpecificGroup>(),  _mainFile, null, 
                    packageSource: source);
            }
            else
            {
                yield return new WorkspaceEntry(new PackageIdentity(localPackageSourceInfo.Package.Id, localPackageSourceInfo.Package.Version), sha256,
                    //  TODO For now we pass runtime as deps. This should be different elements in bazel tasks
                    depsGroups, runtimeItemGroups ?? libItemGroups, toolItemGroups, Array.Empty<FrameworkSpecificGroup>(), _mainFile, null,
                    packageSource: source);
            }
        }

        private IEnumerable<FrameworkSpecificGroup> FilterSpecificDll(IEnumerable<FrameworkSpecificGroup> groups, string dll) =>
            groups.Select(g => new FrameworkSpecificGroup(g.TargetFramework,
                g.Items.Where(f => string.Equals(Path.GetFileNameWithoutExtension(f), dll, StringComparison.OrdinalIgnoreCase))));
    }
}