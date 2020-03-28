using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Blaze.Worker;
using dnlib.DotNet;
using Google.Protobuf;

namespace Compiler.Server.Multiplex
{
    public static class Program
    {
        public static void Main(string[] args)
        {
            var dotnet = args[0];
            var cscDir = Path.GetDirectoryName(args[1]);
            var csc = args[1];
            var vbcs = $@"{cscDir}\VBCSCompiler.dll";
            var pipe = GetPipeName(cscDir);
            var commitHash = GetCommitHash(csc);
            var tempDir = Path.GetTempPath();

            var cancelSource = new CancellationTokenSource();
            var serverProcess = StartServerProcess(dotnet, vbcs, pipe);
            serverProcess.Exited += (sender, args) => cancelSource.Cancel();
            serverProcess.Start();

            while (!serverProcess.HasExited)
            {
                var request = WorkRequest.Parser.ParseDelimitedFrom(Console.OpenStandardInput());

                Task.Run(async () =>
                {
                    var client = new Client(pipe, tempDir, commitHash);
                    var response = await client.Work(request, cancelSource.Token).ConfigureAwait(false);
                    
                    if (response.ExitCode == 0 && request.Arguments.Count >= 3)
                    {
                        var cscParamsFile = request.Arguments[0];
                        var unusedRefsOutput = request.Arguments[1];
                        var dll = request.Arguments[2];
                        var unusedReferences = ResolveUnusedReferences(cscParamsFile, dll);
                        File.WriteAllText(Path.GetFullPath(unusedRefsOutput), string.Join("\n", unusedReferences));
                    }

                    response.WriteDelimitedTo(Console.OpenStandardOutput());
                });
            }
        }

        private static Process StartServerProcess(string dotnet, string vbcs, string pipe)
        {
            Process serverProcess = new Process();
            var processStartInfo = new ProcessStartInfo(dotnet, $"\"{vbcs}\" -pipename:{pipe}");
            processStartInfo.RedirectStandardOutput = true;
            processStartInfo.RedirectStandardError = true;
            serverProcess.StartInfo = processStartInfo;
            serverProcess.OutputDataReceived += (sender, args) => Console.Error.WriteLine(args.Data);
            serverProcess.ErrorDataReceived += (sender, args) => Console.Error.WriteLine(args.Data);
            serverProcess.Exited += (sender, args) => 

            AppDomain.CurrentDomain.ProcessExit += (s, e) => serverProcess.Kill();
            Console.CancelKeyPress += (s, e) => serverProcess.Kill();
            return serverProcess;
        }

        private static IEnumerable<string> ResolveUnusedReferences(string cscParamsFile, string dll)
        {
            var prefix = "/reference:";
            var prefixL = prefix.Length;

            var refs = File.ReadAllText(cscParamsFile)
                .Split("\n")
                .Where(l => l.StartsWith(prefix))
                .Select(r => r.Substring(prefixL).Trim());

            var usedRefs = GetReferencedAssemblies(dll)
                .ToHashSet(StringComparer.OrdinalIgnoreCase);

            var refDll = ".ref.dll";
            var d = ".dll";

            return refs
                .Where(r =>
                {
                    var f = Path.GetFileName(r);
                    var fn = f.Substring(0, f.Length - (f.EndsWith(refDll) ? refDll.Length : d.Length));
                    return !usedRefs.Contains(fn);
                });
        }

        private static IEnumerable<string> GetReferencedAssemblies(string file)
        {
            var ctx = ModuleDef.CreateModuleContext();
            // Read all bytes so we wont keep the file open
            ModuleDefMD module = ModuleDefMD.Load(File.ReadAllBytes(Path.GetFullPath(file)), ctx);
            return module.Assembly.ManifestModule.GetAssemblyRefs().Select(r => r.Name.String);
        }

        private static string GetCommitHash(string file)
        {
            var ctx = ModuleDef.CreateModuleContext();
            // Read all bytes so we wont keep the file open
            ModuleDefMD module = ModuleDefMD.Load(File.ReadAllBytes(Path.GetFullPath(file)), ctx);
            var attribute = module.Assembly.CustomAttributes.FirstOrDefault(a => a.TypeFullName.Contains("CommitHashAttribute"));
            return attribute.ConstructorArguments[0].Value.ToString();
        }

        private static string GetPipeName(string compilerExeDirectory)
        {
            // Normalize away trailing slashes.  File APIs include / exclude this with no 
            // discernable pattern.  Easiest to normalize it here vs. auditing every caller
            // of this method.
            compilerExeDirectory = compilerExeDirectory.TrimEnd(Path.DirectorySeparatorChar);

            var pipeNameInput = $"{Environment.UserName}.{compilerExeDirectory}";
            using (var sha = SHA256.Create())
            {
                var bytes = sha.ComputeHash(Encoding.UTF8.GetBytes(pipeNameInput));
                return Convert.ToBase64String(bytes)
                    .Replace("/", "_")
                    .Replace("=", string.Empty);
            }
        }
    }
}