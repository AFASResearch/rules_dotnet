using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Pipes;
using System.Security.Principal;
using System.Threading;
using System.Threading.Tasks;
using Blaze.Worker;
using Microsoft.CodeAnalysis.CommandLine;

namespace Compiler.Server.Multiplex
{
    internal class Client
    {
        private readonly string _pipe;
        private readonly string _tempDir;
        private readonly string _commitHash;

        private static readonly int _connectTimeout = 5000;

        public Client(string pipe, string tempDir, string commitHash)
        {
            _pipe = pipe;
            _tempDir = tempDir;
            _commitHash = commitHash;
        }

        public async Task<WorkResponse> Work(WorkRequest request, CancellationToken cancellationToken)
        {
            var pipeClient =
                new NamedPipeClientStream(".", _pipe,
                    PipeDirection.InOut, PipeOptions.None,
                    TokenImpersonationLevel.Impersonation);

            await pipeClient.ConnectAsync(_connectTimeout, cancellationToken).ConfigureAwait(false);

            var cscParamsFile = request.Arguments[0];
            var args = new List<string> { "/noconfig", $"@{Path.GetFullPath(cscParamsFile)}" };

            var buildRequest = BuildRequest.Create(RequestLanguage.CSharpCompile, Directory.GetCurrentDirectory(), _tempDir, _commitHash, args);

            await buildRequest.WriteAsync(pipeClient, cancellationToken).ConfigureAwait(false);

            var buildResponseTask = BuildResponse.ReadAsync(pipeClient, cancellationToken);
            var monitorTask = MonitorDisconnectAsync(pipeClient, cancellationToken);

            await Task.WhenAny(buildResponseTask, monitorTask).ConfigureAwait(false);

            if (!buildResponseTask.IsCompleted)
            {
                return new WorkResponse
                {
                    ExitCode = 1,
                    RequestId = request.RequestId,
                    Output = "Server disconnected"
                };
            }

            if (buildResponseTask.Result is CompletedBuildResponse completedBuildResponse)
            {
                return new WorkResponse
                {
                    ExitCode = completedBuildResponse.ReturnCode,
                    RequestId = request.RequestId,
                    Output = completedBuildResponse.Output
                };
            }

            return new WorkResponse
            {
                ExitCode = 1 + (int)buildResponseTask.Result.Type,
                RequestId = request.RequestId,
                Output = $"Unknown build response type {buildResponseTask.Result.Type}"
            };
        }

        private static async Task MonitorDisconnectAsync(
            PipeStream pipeStream,
            CancellationToken cancellationToken)
        {
            var buffer = Array.Empty<byte>();

            while (!cancellationToken.IsCancellationRequested && pipeStream.IsConnected)
            {
                // Wait a tenth of a second before trying again
                await Task.Delay(100, cancellationToken).ConfigureAwait(false);

                try
                {
                    //Log($"Before poking pipe {identifier}.");
                    await pipeStream.ReadAsync(buffer, 0, 0, cancellationToken).ConfigureAwait(false);
                    //Log($"After poking pipe {identifier}.");
                }
                catch (OperationCanceledException)
                {
                }
                catch (Exception)
                {
                    // It is okay for this call to fail.  Errors will be reflected in the
                    // IsConnected property which will be read on the next iteration of the
                    //LogException(e, $"Error poking pipe {identifier}.");
                }
            }
        }
    }
}