using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.Loader;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Blaze.Worker;
using dnlib.DotNet;
using Google.Protobuf;

namespace Proto
{
    public static class Program
    {
        public static void Main(string[] args)
        {
            var dotnet = args[0];
            var csc = args[1];
            var vbcs = $@"{Path.GetDirectoryName(args[1])}\VBCSCompiler.dll";

            Process serverProcess = null;
            AppDomain.CurrentDomain.ProcessExit += (s, e) => serverProcess?.Kill();

            Task.Run(() =>
            {
                var processStartInfo = new ProcessStartInfo(dotnet, $"\"{vbcs}\"");
                processStartInfo.Environment["PATHEXT"] = "";
                processStartInfo.Environment["PATH"] = "";
                serverProcess = Process.Start(processStartInfo);
                serverProcess?.WaitForExit();
            });

            // Ensure server is running
            Thread.Sleep(1000);

            while (true)
            {
                var request = WorkRequest.Parser.ParseDelimitedFrom(Console.OpenStandardInput());

                Task.Run(() =>
                {
                    var cscParamsFile = request.Arguments[0];
                    var processStartInfo = new ProcessStartInfo(dotnet, $"\"{csc}\" /shared /noconfig @{cscParamsFile}");

                    processStartInfo.Environment["PATHEXT"] = "";
                    processStartInfo.Environment["PATH"] = "";
                    processStartInfo.RedirectStandardOutput = true;
                    var process = Process.Start(processStartInfo);

                    if (process != null)
                    {
                        var output = process.StandardOutput.ReadToEnd();
                        process.WaitForExit();

                        if(process.ExitCode == 0 && request.Arguments.Count >= 3)
                        {
                            var unusedRefsOutput = request.Arguments[1];
                            var dll = request.Arguments[2];
                            var unusedReferences = ResolveUnusedReferences(cscParamsFile, dll);
                            File.WriteAllText(Path.GetFullPath(unusedRefsOutput), string.Join("\n", unusedReferences));
                        }

                        var response = new WorkResponse
                        {
                            ExitCode = process.ExitCode, 
                            RequestId = request.RequestId, 
                            Output = output
                        };

                        response.WriteDelimitedTo(Console.OpenStandardOutput());
                    }
                });
            }
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
            ModuleDefMD module = ModuleDefMD.Load(Path.GetFullPath(file), ctx);
            return module.Assembly.ManifestModule.GetAssemblyRefs().Select(r => r.Name.String);
        }
    }
}