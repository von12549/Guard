using System.Diagnostics;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.AspNetCore.StaticFiles;

namespace V4.Guards.WebCompanion;

internal static class Program
{
    private const string SessionCookie = "v4-companion-session";
    private static readonly string[] AllowedStages = ["bootstrap", "analysis", "pre", "post"];
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true
    };

    public static async Task<int> Main(string[] args)
    {
        try
        {
            var options = CompanionOptions.Parse(args);
            var sessionSecret = Convert.ToHexString(RandomNumberGenerator.GetBytes(32)).ToLowerInvariant();
            using var runGate = new SemaphoreSlim(1, 1);

            var builder = WebApplication.CreateBuilder(new WebApplicationOptions
            {
                Args = [],
                ContentRootPath = AppContext.BaseDirectory,
                WebRootPath = "wwwroot"
            });
            builder.Logging.ClearProviders();
            builder.WebHost.ConfigureKestrel(server =>
            {
                server.AddServerHeader = false;
                server.Limits.MaxRequestBodySize = 4096;
                server.Listen(IPAddress.Loopback, options.Port);
            });

            var app = builder.Build();
            app.Use(async (context, next) =>
            {
                context.Response.Headers.CacheControl = "no-store";
                context.Response.Headers.ContentSecurityPolicy =
                    "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'none'";
                context.Response.Headers.XContentTypeOptions = "nosniff";
                context.Response.Headers.XFrameOptions = "DENY";
                context.Response.Headers["Referrer-Policy"] = "no-referrer";
                if (!string.Equals(context.Request.Host.Host, IPAddress.Loopback.ToString(), StringComparison.Ordinal))
                {
                    await WriteError(context, 400, "invalid-host", "The Web Companion accepts only the 127.0.0.1 host.");
                    return;
                }
                await next();
            });

            app.UseDefaultFiles();
            app.UseStaticFiles(new StaticFileOptions
            {
                OnPrepareResponse = context => context.Context.Response.Headers.CacheControl = "no-store"
            });

            app.MapGet("/api/v1/session", (HttpContext context) =>
            {
                context.Response.Cookies.Append(SessionCookie, sessionSecret, new CookieOptions
                {
                    HttpOnly = true,
                    SameSite = SameSiteMode.Strict,
                    Secure = false,
                    Path = "/",
                    IsEssential = true
                });
                return Results.Json(new
                {
                    formatVersion = 1,
                    status = "ready",
                    authority = "v4-host",
                    allowedCommand = "stage.run",
                    allowedStages = AllowedStages,
                    allowedProfiles = new[] { "synthetic_profile" },
                    roots = new[]
                    {
                        new { name = "PackageRoot", path = options.PackageRoot, access = "immutable" },
                        new { name = "TargetRoot", path = options.TargetRoot, access = "read-only" },
                        new { name = "StateRoot", path = options.StateRoot, access = "v4-owned mutable" },
                        new { name = "EvidenceRoot", path = options.EvidenceRoot, access = "v4-owned mutable" }
                    }
                }, JsonOptions);
            });

            app.MapPost("/api/v1/stages/run", async (HttpContext context) =>
            {
                if (!IsAuthorizedMutation(context, sessionSecret))
                    return Results.Json(Error("session-refused", "A same-origin loopback session is required."), JsonOptions, statusCode: 403);

                StageRequest request;
                try
                {
                    request = await ReadStageRequest(context.Request, context.RequestAborted);
                }
                catch (RequestException ex)
                {
                    return Results.Json(Error(ex.Category, ex.Message), JsonOptions, statusCode: 400);
                }

                if (!await runGate.WaitAsync(0, context.RequestAborted))
                    return Results.Json(Error("run-active", "Another Companion-originated Stage run is active."), JsonOptions, statusCode: 409);

                try
                {
                    var execution = await InvokeHost(options, request, context.RequestAborted);
                    return Results.Json(new
                    {
                        formatVersion = 1,
                        command = "stage.run",
                        hostExitCode = execution.ExitCode,
                        hostResult = execution.Result
                    }, JsonOptions);
                }
                catch (HostInvocationException ex)
                {
                    return Results.Json(Error(ex.Category, ex.Message), JsonOptions, statusCode: 502);
                }
                finally
                {
                    runGate.Release();
                }
            });

            await app.StartAsync();
            var address = app.Services.GetRequiredService<IServer>().Features.Get<IServerAddressesFeature>()?
                .Addresses.Single(value => value.StartsWith("http://127.0.0.1:", StringComparison.Ordinal));
            if (address is null)
                throw new InvalidOperationException("The loopback listener address is unavailable.");

            Console.WriteLine(JsonSerializer.Serialize(new
            {
                formatVersion = 1,
                status = "ready",
                address,
                authority = "v4-host",
                allowedCommand = "stage.run"
            }));
            await app.WaitForShutdownAsync();
            return 0;
        }
        catch (CompanionException ex)
        {
            Console.Error.WriteLine(JsonSerializer.Serialize(Error(ex.Category, ex.Message), JsonOptions));
            return ex.ExitCode;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(JsonSerializer.Serialize(Error("companion-failure", ex.Message), JsonOptions));
            return 19;
        }
    }

    private static bool IsAuthorizedMutation(HttpContext context, string expectedSecret)
    {
        if (!context.Request.Cookies.TryGetValue(SessionCookie, out var actualSecret) ||
            !FixedTimeEquals(actualSecret, expectedSecret)) return false;

        var originText = context.Request.Headers.Origin.ToString();
        if (!Uri.TryCreate(originText, UriKind.Absolute, out var origin)) return false;
        if (!string.Equals(origin.Scheme, context.Request.Scheme, StringComparison.Ordinal) ||
            !string.Equals(origin.Host, IPAddress.Loopback.ToString(), StringComparison.Ordinal) ||
            origin.Port != context.Request.Host.Port) return false;
        return string.IsNullOrEmpty(origin.PathAndQuery) || origin.PathAndQuery == "/";
    }

    private static bool FixedTimeEquals(string left, string right)
    {
        var leftBytes = Encoding.UTF8.GetBytes(left);
        var rightBytes = Encoding.UTF8.GetBytes(right);
        return leftBytes.Length == rightBytes.Length && CryptographicOperations.FixedTimeEquals(leftBytes, rightBytes);
    }

    private static async Task<StageRequest> ReadStageRequest(HttpRequest request, CancellationToken cancellationToken)
    {
        if (request.ContentType is null || !request.ContentType.StartsWith("application/json", StringComparison.OrdinalIgnoreCase))
            throw new RequestException("invalid-input", "Content-Type must be application/json.");

        JsonDocument document;
        try
        {
            document = await JsonDocument.ParseAsync(request.Body, new JsonDocumentOptions
            {
                AllowTrailingCommas = false,
                CommentHandling = JsonCommentHandling.Disallow,
                MaxDepth = 8
            }, cancellationToken);
        }
        catch (JsonException ex)
        {
            throw new RequestException("invalid-input", $"Request JSON is invalid: {ex.Message}");
        }

        using (document)
        {
            if (document.RootElement.ValueKind != JsonValueKind.Object)
                throw new RequestException("invalid-input", "Request JSON must be an object.");

            var known = new HashSet<string>(["stage", "profile", "withDependencies"], StringComparer.Ordinal);
            var seen = new HashSet<string>(StringComparer.Ordinal);
            foreach (var property in document.RootElement.EnumerateObject())
            {
                if (!known.Contains(property.Name))
                    throw new RequestException("invalid-input", $"Unknown request field: {property.Name}");
                if (!seen.Add(property.Name))
                    throw new RequestException("invalid-input", $"Duplicate request field: {property.Name}");
            }
            if (seen.Count != known.Count)
                throw new RequestException("invalid-input", "stage, profile and withDependencies are required.");

            var stageElement = document.RootElement.GetProperty("stage");
            var profileElement = document.RootElement.GetProperty("profile");
            var dependenciesElement = document.RootElement.GetProperty("withDependencies");
            if (stageElement.ValueKind != JsonValueKind.String || profileElement.ValueKind != JsonValueKind.String ||
                dependenciesElement.ValueKind is not (JsonValueKind.True or JsonValueKind.False))
                throw new RequestException("invalid-input", "Request field types are invalid.");

            var stage = stageElement.GetString()!;
            var profile = profileElement.GetString()!;
            if (!AllowedStages.Contains(stage, StringComparer.Ordinal))
                throw new RequestException("command-refused", "Stage is not allowlisted.");
            if (!string.Equals(profile, "synthetic_profile", StringComparison.Ordinal))
                throw new RequestException("command-refused", "Only synthetic_profile is allowlisted for the P9.1 spike.");
            return new StageRequest(stage, profile, dependenciesElement.GetBoolean());
        }
    }

    private static async Task<HostExecution> InvokeHost(CompanionOptions options, StageRequest request, CancellationToken requestAborted)
    {
        var start = new ProcessStartInfo(options.DotnetHost)
        {
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
            WorkingDirectory = options.PackageRoot
        };
        foreach (var value in new[]
        {
            options.HostPath, "stage", "run", "--stage", request.Stage,
            "--package-root", options.PackageRoot, "--target-root", options.TargetRoot,
            "--state-root", options.StateRoot, "--evidence-root", options.EvidenceRoot,
            "--profile", request.Profile
        }) start.ArgumentList.Add(value);
        if (request.WithDependencies) start.ArgumentList.Add("--with-dependencies");

        var inherited = new Dictionary<string, string?>(StringComparer.OrdinalIgnoreCase);
        foreach (var name in new[] { "PATH", "PATHEXT", "SystemRoot", "WINDIR", "TEMP", "TMP", "HOME", "DOTNET_ROOT", "DOTNET_HOST_PATH" })
            inherited[name] = Environment.GetEnvironmentVariable(name);
        start.Environment.Clear();
        foreach (var pair in inherited.Where(pair => !string.IsNullOrWhiteSpace(pair.Value)))
            start.Environment[pair.Key] = pair.Value!;
        start.Environment["POWERSHELL_TELEMETRY_OPTOUT"] = "1";
        start.Environment["DOTNET_CLI_TELEMETRY_OPTOUT"] = "1";

        using var process = Process.Start(start) ?? throw new HostInvocationException("host-unavailable", "The V4 Host did not start.");
        var stdout = process.StandardOutput.ReadToEndAsync(requestAborted);
        var stderr = process.StandardError.ReadToEndAsync(requestAborted);
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(requestAborted);
        timeout.CancelAfter(TimeSpan.FromMinutes(5));
        try
        {
            await process.WaitForExitAsync(timeout.Token);
        }
        catch (OperationCanceledException)
        {
            try { process.Kill(true); } catch { }
            throw new HostInvocationException("host-timeout", "The V4 Host run was cancelled or exceeded five minutes.");
        }

        var output = process.ExitCode == 0 ? await stdout : await stderr;
        try
        {
            using var result = JsonDocument.Parse(output);
            if (result.RootElement.ValueKind != JsonValueKind.Object)
                throw new JsonException("Host output is not an object.");
            return new HostExecution(process.ExitCode, result.RootElement.Clone());
        }
        catch (JsonException ex)
        {
            throw new HostInvocationException("host-output-invalid", $"The V4 Host did not return structured JSON: {ex.Message}");
        }
    }

    private static object Error(string category, string message) =>
        new { formatVersion = 1, status = "error", exitCategory = category, message };

    private static async Task WriteError(HttpContext context, int statusCode, string category, string message)
    {
        context.Response.StatusCode = statusCode;
        context.Response.ContentType = "application/json";
        await context.Response.WriteAsync(JsonSerializer.Serialize(Error(category, message), JsonOptions));
    }

    private sealed record StageRequest(string Stage, string Profile, bool WithDependencies);
    private sealed record HostExecution(int ExitCode, JsonElement Result);

    private sealed class RequestException(string category, string message) : Exception(message)
    {
        public string Category { get; } = category;
    }

    private sealed class HostInvocationException(string category, string message) : Exception(message)
    {
        public string Category { get; } = category;
    }

    private sealed class CompanionException(int exitCode, string category, string message) : Exception(message)
    {
        public int ExitCode { get; } = exitCode;
        public string Category { get; } = category;
    }

    private sealed record CompanionOptions(string PackageRoot, string TargetRoot, string StateRoot,
        string EvidenceRoot, string HostPath, string DotnetHost, int Port)
    {
        public static CompanionOptions Parse(string[] args)
        {
            var values = new Dictionary<string, string>(StringComparer.Ordinal);
            for (var index = 0; index < args.Length; index += 2)
            {
                if (index + 1 >= args.Length || !args[index].StartsWith("--", StringComparison.Ordinal) ||
                    !values.TryAdd(args[index][2..], args[index + 1]))
                    throw new CompanionException(10, "invalid-input", "Startup arguments must be unique --name value pairs.");
            }
            var known = new HashSet<string>(["package-root", "target-root", "state-root", "evidence-root", "host", "port"], StringComparer.Ordinal);
            var unknown = values.Keys.FirstOrDefault(value => !known.Contains(value));
            if (unknown is not null)
                throw new CompanionException(10, "invalid-input", $"Unknown startup argument: --{unknown}");
            string Required(string name) => values.TryGetValue(name, out var value) && !string.IsNullOrWhiteSpace(value)
                ? value : throw new CompanionException(10, "invalid-input", $"Missing --{name}.");

            if (!int.TryParse(Required("port"), out var port) || port is < 0 or > 65535)
                throw new CompanionException(10, "invalid-input", "Port must be an integer from 0 through 65535.");
            var packageRoot = ResolveDirectory(Required("package-root"), "PackageRoot");
            var targetRoot = ResolveDirectory(Required("target-root"), "TargetRoot");
            var stateRoot = ResolveDirectory(Required("state-root"), "StateRoot");
            var evidenceRoot = ResolveDirectory(Required("evidence-root"), "EvidenceRoot");
            foreach (var mutable in new[] { ("StateRoot", stateRoot), ("EvidenceRoot", evidenceRoot) })
            {
                if (Overlaps(mutable.Item2, packageRoot) || Overlaps(mutable.Item2, targetRoot))
                    throw new CompanionException(11, "unsafe-path", $"{mutable.Item1} overlaps PackageRoot or TargetRoot.");
            }
            if (Overlaps(stateRoot, evidenceRoot))
                throw new CompanionException(11, "unsafe-path", "StateRoot and EvidenceRoot overlap.");

            var hostPath = ResolveFile(Required("host"), "V4 Host");
            if (!string.Equals(Path.GetFileName(hostPath), "v4-guards.dll", StringComparison.Ordinal))
                throw new CompanionException(10, "invalid-input", "The Host must be v4-guards.dll.");
            var dotnetHost = Environment.ProcessPath;
            if (string.IsNullOrWhiteSpace(dotnetHost) || !File.Exists(dotnetHost))
                throw new CompanionException(15, "prerequisite-missing", "The current dotnet host path is unavailable.");
            return new CompanionOptions(packageRoot, targetRoot, stateRoot, evidenceRoot, hostPath,
                Path.GetFullPath(dotnetHost), port);
        }

        private static string ResolveDirectory(string value, string label)
        {
            string full;
            try { full = Path.TrimEndingDirectorySeparator(Path.GetFullPath(value)); }
            catch (Exception ex) { throw new CompanionException(11, "unsafe-path", $"{label} is invalid: {ex.Message}"); }
            if (!Directory.Exists(full))
                throw new CompanionException(10, "invalid-input", $"{label} does not exist: {full}");
            EnsureNoLinks(full, label);
            return full;
        }

        private static string ResolveFile(string value, string label)
        {
            string full;
            try { full = Path.GetFullPath(value); }
            catch (Exception ex) { throw new CompanionException(11, "unsafe-path", $"{label} path is invalid: {ex.Message}"); }
            if (!File.Exists(full))
                throw new CompanionException(10, "invalid-input", $"{label} does not exist: {full}");
            var file = new FileInfo(full);
            if ((file.Attributes & FileAttributes.ReparsePoint) != 0 || file.LinkTarget is not null)
                throw new CompanionException(11, "unsafe-path", $"{label} is a link or reparse point.");
            EnsureNoLinks(file.DirectoryName!, label);
            return full;
        }

        private static void EnsureNoLinks(string path, string label)
        {
            DirectoryInfo? current = new(path);
            while (current is not null)
            {
                if ((current.Attributes & FileAttributes.ReparsePoint) != 0 || current.LinkTarget is not null)
                    throw new CompanionException(11, "unsafe-path", $"{label} crosses a link or reparse point: {current.FullName}");
                current = current.Parent;
            }
        }

        private static bool Overlaps(string left, string right) => IsUnder(left, right) || IsUnder(right, left);
        private static bool IsUnder(string path, string root)
        {
            var relative = Path.GetRelativePath(root, path);
            return relative == "." || (!Path.IsPathRooted(relative) && relative != ".." &&
                !relative.StartsWith($"..{Path.DirectorySeparatorChar}", StringComparison.Ordinal));
        }
    }
}
