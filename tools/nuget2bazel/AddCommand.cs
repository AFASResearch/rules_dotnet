using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices.ComTypes;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Xml;
using System.Xml.Linq;
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
using NuGet.ProjectModel;
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

                var targetFramework = NuGetFramework.Parse("netcoreapp3.1");
                var targetRuntime = "win";

                remoteWalkContext.ProjectLibraryProviders.Add(new PackageSpecReferenceDependencyProvider(GetProjects(project.ProjectConfig.RootPath, targetFramework), logger));

                var rootProject = "Root";
                var rootProjectVersion = "1.0.0";

                var independentGraph = await GetIndependentGraph(rootProject, rootProjectVersion, targetFramework, remoteWalkContext);
                // We could target multiple runtimes with RuntimeGraph.Merge
                var platformSpecificGraph = await GetPlatformSpecificGraph(independentGraph, rootProject, rootProjectVersion, targetFramework, targetRuntime, remoteWalkContext, localPackageExtractor);

                var json = await project.GetJsonAsync();

                var localPackages = await Task.WhenAll(platformSpecificGraph.Flattened
                    .Where(i => i.Key.Name != rootProject)
                    .Select(i => localPackageExtractor.EnsureLocalPackage(i.Data.Match.Provider, ToPackageIdentity(i.Data.Match))));

                var workspaceEntryBuilder = new WorkspaceEntryBuilder(platformSpecificGraph.Conventions, mainFile)
                    .WithTarget(new FrameworkRuntimePair(targetFramework, targetRuntime));
                
                // First resolve al file groups
                var resolved = localPackages.Select(workspaceEntryBuilder.ResolveGroups).ToArray();

                // Then we use them to validate deps actually contain content
                workspaceEntryBuilder.WithLocalPackages(resolved);

                foreach (var entry in resolved.SelectMany(workspaceEntryBuilder.Build))
                {
                    if (!SdkList.Dlls.Contains(entry.PackageIdentity.Id.ToLower()))
                    {
                        await project.AddEntry(entry);
                    }
                }

                await project.SaveJsonAsync(json);
            }
        }

        private IEnumerable<ExternalProjectReference> GetProjects(string rootPath, NuGetFramework framework)
        {
            var packagesProps = XElement.Load(Path.Combine(rootPath, "Packages.Props"));

            if(packagesProps == null)
            {
                throw new Exception("No package props could be found.");
            }

            var deps = packagesProps
                .Element("ItemGroup")
                .Elements("PackageReference")
                .Select(el => (el.Attribute("Update")?.Value, el.Attribute("Version")?.Value))
                .Where(Included)
                .Append(("microsoft.aspnetcore.http.features", "3.1.0"))
                .ToArray();

            bool Included((string update, string version) arg) =>
                !string.IsNullOrEmpty(arg.update) &&
                !string.IsNullOrEmpty(arg.version) &&
                !arg.version.EndsWith("-local-dev", StringComparison.OrdinalIgnoreCase);

            PackageSpec project = new PackageSpec(new List<TargetFrameworkInformation>()
            {
                new TargetFrameworkInformation
                {
                    FrameworkName = framework,
                    FrameworkReferences =
                    {
                        new FrameworkDependency("Microsoft.AspNetCore.App", FrameworkDependencyFlags.None)
                    }
                }
            });
            project.Name = "Root";
            project.Version = NuGetVersion.Parse("1.0.0");

            project.Dependencies = new List<LibraryDependency>();
            
            foreach(var (package, version) in deps)
            {
                project.Dependencies.Add(new LibraryDependency(
                    new LibraryRange(package, VersionRange.Parse(version), LibraryDependencyTarget.Package),
                    LibraryDependencyType.Build,
                    includeType: LibraryIncludeFlags.None,
                    suppressParent: LibraryIncludeFlags.All,
                    noWarn: new List<NuGetLogCode>(),
                    autoReferenced: true,
                    generatePathProperty: false));
            }

            yield return new ExternalProjectReference(
                project.Name,
                project,
                msbuildProjectPath: null,
                projectReferences: Enumerable.Empty<string>());
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
