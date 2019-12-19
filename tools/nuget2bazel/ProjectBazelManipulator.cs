using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using NuGet.Common;
using NuGet.Frameworks;
using NuGet.PackageManagement;
using NuGet.Packaging;
using NuGet.Packaging.Core;
using NuGet.ProjectManagement;
using NuGet.ProjectManagement.Projects;
using NuGet.Protocol.Core.Types;
using NuGet.Versioning;

namespace nuget2bazel
{
    public class ProjectBazelManipulator : NuGetProject
    {
        private readonly string _mainFile;
        private readonly bool _skipSha256;
        private readonly string _variable;

        public string JsonConfigPath { get; set; }
        public string WorkspacePath { get; set; }
        //public IEnumerable<NuGetProjectAction> NuGetProjectActions { get; set; }

        public ProjectBazelConfig ProjectConfig { get; private set; }

        public ProjectBazelManipulator(ProjectBazelConfig prjConfig, string mainFile, bool skipSha256, string variable)
        {
            ProjectConfig = prjConfig;
            _mainFile = mainFile;
            _skipSha256 = skipSha256;
            _variable = variable;
            JsonConfigPath = Path.Combine(ProjectConfig.RootPath, ProjectConfig.Nuget2BazelConfigName);
            WorkspacePath = Path.Combine(ProjectConfig.RootPath, ProjectConfig.BazelFileName);

            InternalMetadata.Add(NuGetProjectMetadataKeys.Name, "Root");
            InternalMetadata.Add(NuGetProjectMetadataKeys.TargetFramework, NuGetFramework.Parse("netcoreapp2.1"));
        }

        public async Task<Nuget2BazelConfig> GetJsonAsync()
        {
            if (!File.Exists(JsonConfigPath))
                using (var sw = new StreamWriter(JsonConfigPath))
                {
                    await sw.WriteAsync("{}");
                    return new Nuget2BazelConfig();
                }

            using (var reader = File.OpenText(JsonConfigPath))
            {
                return JsonConvert.DeserializeObject<Nuget2BazelConfig>(await reader.ReadToEndAsync());
            }
        }

        private async Task<string> GetWorkspaceAsync()
        {
            if (!File.Exists(WorkspacePath))
                using (var sw = new StreamWriter(WorkspacePath))
                {
                    await sw.WriteAsync("");
                    return "";
                }

            using (var reader = File.OpenText(WorkspacePath))
            {
                return await reader.ReadToEndAsync();
            }
        }

        public async Task SaveJsonAsync(Nuget2BazelConfig json)
        {
            using (var writer = new StreamWriter(JsonConfigPath, false, Encoding.UTF8))
            {
                await writer.WriteAsync(JsonConvert.SerializeObject(json, Formatting.Indented));
            }
        }

        private async Task SaveWorkspaceAsync(string workspace)
        {
            using (var writer = new StreamWriter(WorkspacePath, false, Encoding.Default))
            {
                await writer.WriteAsync(workspace);
            }
        }

        private string GetSha(Stream stream)
        {
            var hash = SHA256.Create();
            var bytes = hash.ComputeHash(stream);
            var builder = new StringBuilder();
            foreach (var t in bytes)
            {
                builder.Append(t.ToString("x2"));
            }
            return builder.ToString();
        }

        private static IEnumerable<PackageDependency> GetDependencies(Nuget2BazelConfig json)
        {
            return json.externals.Select(x => x.Key.Split("/"))
                .Select(y => new PackageDependency(y[0], VersionRange.Parse(y[1])))
                .Union(json.dependencies.Select(z => new PackageDependency(z.Key, VersionRange.Parse(z.Value))));
        }

        public override async Task<IEnumerable<PackageReference>> GetInstalledPackagesAsync(CancellationToken token)
        {
            var packages = new List<PackageReference>();

            //  Find all dependencies and convert them into packages.config style references
            foreach (var dependency in GetDependencies(await GetJsonAsync()))
            {
                // Use the minimum version of the range for the identity
                var identity = new PackageIdentity(dependency.Id, dependency.VersionRange.MinVersion);

                // Pass the actual version range as the allowed range
                packages.Add(new PackageReference(identity,
                    targetFramework: NuGetFramework.AnyFramework,
                    userInstalled: true,
                    developmentDependency: false,
                    requireReinstallation: false,
                    allowedVersions: dependency.VersionRange));
            }

            return packages;
        }

        public override async Task<bool> InstallPackageAsync(
            PackageIdentity packageIdentity,
            DownloadResourceResult downloadResourceResult,
            INuGetProjectContext nuGetProjectContext,
            CancellationToken token)
        {
            var dependency = new PackageDependency(packageIdentity.Id, new VersionRange(packageIdentity.Version));

            var json = await GetJsonAsync();
            json.dependencies.Add(packageIdentity.Id, packageIdentity.Version.ToString());
            await SaveJsonAsync(json);

            PackageReaderBase packageReader = downloadResourceResult.PackageReader
                                ?? new PackageArchiveReader(downloadResourceResult.PackageStream, leaveStreamOpen: true);
            IAsyncPackageContentReader packageContentReader = packageReader;

            var libItemGroups = await packageReader.GetLibItemsAsync(token);
            //var referenceItemGroups = await packageReader.GetReferenceItemsAsync(token);
            //var frameworkReferenceGroups = await packageReader.GetFrameworkItemsAsync(token);
            //var contentFileGroups = await packageReader.GetContentItemsAsync(token);
            //var buildFileGroups = await packageReader.GetBuildItemsAsync(token);
            var toolItemGroups = await packageReader.GetToolItemsAsync(token);
            var depsGroups = await packageReader.GetPackageDependenciesAsync(token);

            IEnumerable<FrameworkSpecificGroup> refItemGroups = await packageReader.GetItemsAsync(PackagingConstants.Folders.Ref, token);

            var sha256 = "";
            if (!_skipSha256)
            {
                sha256 = GetSha(downloadResourceResult.PackageStream);
            }
            var entry = new WorkspaceEntry(packageIdentity, sha256,
                depsGroups, libItemGroups, libItemGroups, toolItemGroups, refItemGroups, _mainFile, _variable);

            if (!SdkList.Dlls.Contains(entry.PackageIdentity.Id.ToLower()))
            {
                await AddEntry(entry);
            }

            return true;
        }

        public virtual async Task AddEntry(WorkspaceEntry entry)
        {
            var workspace = await GetWorkspaceAsync();
            var updater = new WorkspaceWriter();
            var updated = updater.AddEntry(workspace, entry, ProjectConfig.Indent);
            await SaveWorkspaceAsync(updated);
        }

        public override async Task<bool> UninstallPackageAsync(
            PackageIdentity packageIdentity,
            INuGetProjectContext nuGetProjectContext,
            CancellationToken token)
        {
            var json = await GetJsonAsync();
            json.dependencies.Remove(packageIdentity.Id);
            await SaveJsonAsync(json);

            var workspace = await GetWorkspaceAsync();
            var updater = new WorkspaceWriter();
            var updated = updater.RemoveEntry(workspace, packageIdentity.Id, ProjectConfig.Indent);
            await SaveWorkspaceAsync(updated);

            return true;
        }
    }
}
