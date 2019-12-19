using System;
using System.Collections.Generic;
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

        public WorkspaceEntry Build(LocalPackageSourceInfo localPackageSourceInfo)
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

            return new WorkspaceEntry(new PackageIdentity(localPackageSourceInfo.Package.Id, localPackageSourceInfo.Package.Version), sha256,
                //  TODO For now we pass runtime as deps. This should be different elements in bazel tasks
                depsGroups, runtimeItemGroups ?? libItemGroups, runtimeItemGroups, toolItemGroups, Array.Empty<FrameworkSpecificGroup>(), _mainFile, null);
        }
    }
}