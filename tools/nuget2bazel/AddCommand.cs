using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices.ComTypes;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using NuGet.Commands;
using NuGet.Common;
using NuGet.Configuration;
using NuGet.ContentModel;
using NuGet.DependencyResolver;
using NuGet.Frameworks;
using NuGet.LibraryModel;
using NuGet.PackageManagement;
using NuGet.Packaging;
using NuGet.Packaging.Core;
using NuGet.ProjectManagement;
using NuGet.Protocol;
using NuGet.Protocol.Core.Types;
using NuGet.Repositories;
using NuGet.Resolver;
using NuGet.RuntimeModel;
using NuGet.Versioning;

namespace nuget2bazel
{
    public class AddCommand
    {
        public Task Do(ProjectBazelConfig prjConfig, string package, string version, string mainFile, bool skipSha256, bool lowest, string variable)
        {
            var project = new ProjectBazelManipulator(prjConfig, mainFile, skipSha256, variable);

            return DoWithProject(package, version, project, lowest, mainFile);
        }

        public async Task DoWithProject(string package, string version, ProjectBazelManipulator project, bool lowest, string mainFile = null)
        {
            ILogger logger = new Logger();
            var settings = Settings.LoadDefaultSettings(project.ProjectConfig.RootPath, null, new MachineWideSettings());

            // ~/.nuget/packages

            using (var cache = new SourceCacheContext())
            {
                var remoteWalkContext = CreateRemoteWalkContext(settings, cache, logger);
                var localPackageExtractor = new LocalPackageExtractor(settings, logger, cache);

                var targetFramework = NuGetFramework.Parse("netcoreapp2.1");
                var targetRuntime = "win";

                var independentGraph = await GetIndependentGraph(package, version, targetFramework, remoteWalkContext);
                // We could target multiple runtimes with RuntimeGraph.Merge
                var platformSpecificGraph = await GetPlatformSpecificGraph(independentGraph, package, version, targetFramework, targetRuntime, remoteWalkContext, localPackageExtractor);

                var workspaceEntryBuilder = new WorkspaceEntryBuilder(platformSpecificGraph.Conventions, mainFile)
                    .WithTarget(new FrameworkRuntimePair(targetFramework, targetRuntime));

                var json2 = await project.GetJsonAsync();

                var localPackages = await Task.WhenAll(platformSpecificGraph.Flattened.Select(i =>
                    localPackageExtractor.EnsureLocalPackage(i.Data.Match.Provider, ToPackageIdentity(i.Data.Match))));

                foreach (var entry in localPackages.Select(workspaceEntryBuilder.Build))
                {
                    if (!SdkList.Dlls.Contains(entry.PackageIdentity.Id.ToLower()))
                    {
                        await project.AddEntry(entry);
                    }
                }

                await project.SaveJsonAsync(json2);
            }
        }

        private RemoteWalkContext CreateRemoteWalkContext(ISettings settings, SourceCacheContext cache, ILogger logger)
        {
            // nuget.org etc.
            var globalPackagesFolder = SettingsUtility.GetGlobalPackagesFolder(settings);
            var localRepository = Repository.Factory.GetCoreV3(globalPackagesFolder, FeedType.FileSystemV3);
            var sourceRepositoryProvider = new SourceRepositoryProvider(settings, Repository.Provider.GetCoreV3());

            var context = new RemoteWalkContext(cache, logger);

            context.LocalLibraryProviders.Add(new SourceRepositoryDependencyProvider(localRepository, logger, cache, 
                ignoreFailedSources: true, 
                fileCache: new LocalPackageFileCache(), 
                ignoreWarning: true, 
                isFallbackFolderSource: false));

            foreach(var remoteRepository in sourceRepositoryProvider.GetRepositories())
            {
                context.RemoteLibraryProviders.Add(new SourceRepositoryDependencyProvider(remoteRepository, logger, cache, 
                    ignoreFailedSources: cache.IgnoreFailedSources, 
                    fileCache: new LocalPackageFileCache(),
                    ignoreWarning: false, 
                    isFallbackFolderSource: false));
            }

            return context;
        }

        private static async Task<RestoreTargetGraph> GetIndependentGraph(string package, string version, NuGetFramework nuGetFramework, RemoteWalkContext context)
        {
            var result = await new RemoteDependencyWalker(context).WalkAsync(
                new LibraryRange(package, VersionRange.Parse(version), LibraryDependencyTarget.All),
                nuGetFramework,
                runtimeGraph: RuntimeGraph.Empty,
                recursive: true,
                runtimeIdentifier: null);

            return RestoreTargetGraph.Create(RuntimeGraph.Empty, new[]
            {
                result
            }, context, context.Logger, nuGetFramework, runtimeIdentifier: null);
        }

        private static async Task<RestoreTargetGraph> GetPlatformSpecificGraph(RestoreTargetGraph independentGraph,
            string package, string version, NuGetFramework framework, string runtimeIdentifier,
            RemoteWalkContext context, LocalPackageExtractor extractor)
        {
            var graphTask = independentGraph.Flattened
                .Where(m => m.Data?.Match?.Library?.Type == LibraryType.Package)
                .Select(GetRuntimeGraphTask);

            var graphs = (await Task.WhenAll(graphTask))
                .Where(i => i != null);

            var runtimeGraph = graphs.Aggregate(RuntimeGraph.Empty, RuntimeGraph.Merge);

            // This results in additional entries
            var resultWin = await new RemoteDependencyWalker(context).WalkAsync(
                new LibraryRange(package, VersionRange.Parse(version), LibraryDependencyTarget.All),
                framework,
                runtimeGraph: runtimeGraph,
                recursive: true,
                runtimeIdentifier: runtimeIdentifier);

            return RestoreTargetGraph.Create(runtimeGraph, new[]
            {
                resultWin
            }, context, context.Logger, framework, runtimeIdentifier);

            async Task<RuntimeGraph> GetRuntimeGraphTask(GraphItem<RemoteResolveResult> item)
            {
                var packageIdentity = ToPackageIdentity(item.Data.Match);

                var localPackageSourceInfo = await extractor.EnsureLocalPackage(item.Data.Match.Provider, packageIdentity);
                
                return localPackageSourceInfo?.Package?.RuntimeGraph;
            }
        }
        
        private static PackageIdentity ToPackageIdentity(RemoteMatch match)
        {
            return new PackageIdentity(match.Library.Name, match.Library.Version);
        }
    }
}
