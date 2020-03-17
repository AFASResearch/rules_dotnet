using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Blaze.Worker;
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
                processStartInfo.RedirectStandardError = true;
                processStartInfo.RedirectStandardOutput = true;
                serverProcess = Process.Start(processStartInfo);
                serverProcess?.WaitForExit();
            });

            // Ensure server is running
            Thread.Sleep(1000);

            int i = 0;
            while (true)
            {
                var request = WorkRequest.Parser.ParseDelimitedFrom(Console.OpenStandardInput());

                var argsF = Path.GetFullPath($"tmp{i++}.args");

                Task.Run(() =>
                {
                    File.WriteAllText(argsF, string.Join("\n", request.Arguments.Select(v => v)));

                    var processStartInfo = new ProcessStartInfo(dotnet, $"\"{csc}\" /shared /noconfig @{argsF}");

                    processStartInfo.Environment["PATHEXT"] = "";
                    processStartInfo.Environment["PATH"] = "";
                    processStartInfo.RedirectStandardError = true;
                    processStartInfo.RedirectStandardOutput = true;
                    var process = Process.Start(processStartInfo);

                    if (process != null)
                    {
                        var output = process.StandardOutput.ReadToEnd();
                        process.WaitForExit();

                        var response = new WorkResponse
                        {
                            ExitCode = process.ExitCode, 
                            RequestId = request.RequestId, 
                            Output = output,
                        };
                        
                        response.WriteDelimitedTo(Console.OpenStandardOutput());
                    }

                    File.Delete(argsF);

                });
            }
        }
    }
}