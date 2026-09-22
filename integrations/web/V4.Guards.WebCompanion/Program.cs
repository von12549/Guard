using System.Diagnostics;
using System.Net;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Hosting.Server;
using Microsoft.AspNetCore.Hosting.Server.Features;
using Microsoft.AspNetCore.StaticFiles;

namespace V4.Guards.WebCompanion;

internal static class Program
{
    private const string SessionCookie = "v4-companion-session";
    private static readonly string[] AllowedStages = ["bootstrap", "analysis", "pre", "post"];
    private static readonly Regex ProfilePattern = new("^[a-z][a-z0-9_-]*$", RegexOptions.CultureInvariant);
    private static readonly Regex ProjectIdPattern = new("^[a-f0-9]{32}$", RegexOptions.CultureInvariant);
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = false,
        WriteIndented = true
    };

    public static async Task<int> Main(string[] args)
    {
        try
        {
            var options = CompanionOptions.Parse(args);
            var workspaceState = new WorkspaceState(options.TargetRoots[0]);
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

            app.MapGet("/api/v1/session", async (HttpContext context) =>
            {
                context.Response.Cookies.Append(SessionCookie, sessionSecret, new CookieOptions
                {
                    HttpOnly = true,
                    SameSite = SameSiteMode.Strict,
                    Secure = false,
                    Path = "/",
                    IsEssential = true
                });
                try
                {
                    var workspace = await BuildWorkspace(options, workspaceState, context.RequestAborted);
                    var active = workspace.Targets.Single(target => target.Active);
                    return Results.Json(new
                    {
                        formatVersion = 1,
                        status = "ready",
                        authority = "v4-host",
                        allowedCommand = "stage.run",
                        allowedStages = AllowedStages,
                        allowedProfiles = workspace.Profiles.Select(profile => profile.Id).ToArray(),
                        activeProjectId = workspace.ActiveProjectId,
                        targetCount = workspace.Targets.Length,
                        roots = Roots(options, active.TargetRoot)
                    }, JsonOptions);
                }
                catch (HostInvocationException ex)
                {
                    return Results.Json(Error(ex.Category, ex.Message), JsonOptions, statusCode: 502);
                }
            });

            app.MapGet("/api/v1/workspace", async (HttpContext context) =>
            {
                if (!IsAuthorizedRead(context, sessionSecret))
                    return Results.Json(Error("session-refused", "A loopback session is required."), JsonOptions, statusCode: 403);
                try { return Results.Json(await BuildWorkspace(options, workspaceState, context.RequestAborted), JsonOptions); }
                catch (HostInvocationException ex)
                {
                    return Results.Json(Error(ex.Category, ex.Message), JsonOptions, statusCode: 502);
                }
            });

            app.MapGet("/api/v1/readiness/{profile}", async (HttpContext context, string profile) =>
            {
                if (!IsAuthorizedRead(context, sessionSecret))
                    return Results.Json(Error("session-refused", "A loopback session is required."), JsonOptions, statusCode: 403);
                if (!ProfilePattern.IsMatch(profile))
                    return Results.Json(Error("command-refused", "Profile is not an installed Profile ID."), JsonOptions, statusCode: 400);
                try
                {
                    var workspace = await BuildWorkspace(options, workspaceState, context.RequestAborted);
                    if (workspace.Profiles.All(item => !string.Equals(item.Id, profile, StringComparison.Ordinal)))
                        return Results.Json(Error("command-refused", "Profile is not installed in the validated package."), JsonOptions, statusCode: 400);
                    var report = await InvokeHostQuery(options,
                    [
                        "query", "doctor", "--package-root", options.PackageRoot, "--profile", profile
                    ], context.RequestAborted);
                    return Results.Json(report, JsonOptions);
                }
                catch (HostInvocationException ex)
                {
                    return Results.Json(Error(ex.Category, ex.Message), JsonOptions, statusCode: 502);
                }
            });

            app.MapPost("/api/v1/workspace/select", async (HttpContext context) =>
            {
                if (!IsAuthorizedMutation(context, sessionSecret))
                    return Results.Json(Error("session-refused", "A same-origin loopback session is required."), JsonOptions, statusCode: 403);

                WorkspaceSelection request;
                try { request = await ReadWorkspaceSelection(context.Request, context.RequestAborted); }
                catch (RequestException ex)
                {
                    return Results.Json(Error(ex.Category, ex.Message), JsonOptions, statusCode: 400);
                }

                if (!await runGate.WaitAsync(0, context.RequestAborted))
                    return Results.Json(Error("run-active", "Target switching is unavailable while a Stage run is active."), JsonOptions, statusCode: 409);
                try
                {
                    var workspace = await BuildWorkspace(options, workspaceState, context.RequestAborted);
                    var selected = workspace.Targets.SingleOrDefault(target => target.ProjectId == request.ProjectId);
                    if (selected is null)
                        return Results.Json(Error("target-refused", "Project ID is not a trusted startup Target."), JsonOptions, statusCode: 400);
                    workspaceState.Select(selected.TargetRoot);
                    return Results.Json(new
                    {
                        formatVersion = 1,
                        status = "pass",
                        authority = "v4-host",
                        activeProjectId = selected.ProjectId
                    }, JsonOptions);
                }
                catch (HostInvocationException ex)
                {
                    return Results.Json(Error(ex.Category, ex.Message), JsonOptions, statusCode: 502);
                }
                finally { runGate.Release(); }
            });

            app.MapPost("/api/v1/stages/run", async (HttpContext context) =>
            {
                if (!IsAuthorizedMutation(context, sessionSecret))
                    return Results.Json(Error("session-refused", "A same-origin loopback session is required."), JsonOptions, statusCode: 403);

                StageRequest request;
                try { request = await ReadStageRequest(context.Request, context.RequestAborted); }
                catch (RequestException ex)
                {
                    return Results.Json(Error(ex.Category, ex.Message), JsonOptions, statusCode: 400);
                }

                if (!await runGate.WaitAsync(0, context.RequestAborted))
                    return Results.Json(Error("run-active", "Another Companion-originated Stage run is active."), JsonOptions, statusCode: 409);

                try
                {
                    var workspace = await BuildWorkspace(options, workspaceState, context.RequestAborted);
                    var profile = workspace.Profiles.SingleOrDefault(item => item.Id == request.Profile);
                    if (profile is null)
                        return Results.Json(Error("command-refused", "Profile is not installed in the validated package."), JsonOptions, statusCode: 400);
                    var stage = profile.Stages.Single(item => item.Stage == request.Stage);
                    if (!stage.Enabled)
                        return Results.Json(Error("command-refused", "The selected Profile does not enable this Stage."), JsonOptions, statusCode: 400);

                    var activeTarget = workspaceState.ActiveTargetRoot;
                    var execution = await InvokeStage(options, activeTarget, request, context.RequestAborted);
                    await RefreshProjectAfterRun(options, workspaceState, activeTarget, context.RequestAborted);
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
                finally { runGate.Release(); }
            });

            await app.StartAsync();
            var address = app.Services.GetRequiredService<IServer>().Features.Get<IServerAddressesFeature>()?
                .Addresses.Single(value => value.StartsWith("http://127.0.0.1:", StringComparison.Ordinal));
            if (address is null) throw new InvalidOperationException("The loopback listener address is unavailable.");

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

    private static object[] Roots(CompanionOptions options, string targetRoot) =>
    [
        new { name = "PackageRoot", path = options.PackageRoot, access = "immutable" },
        new { name = "TargetRoot", path = targetRoot, access = "read-only" },
        new { name = "StateRoot", path = options.StateRoot, access = "v4-owned mutable" },
        new { name = "EvidenceRoot", path = options.EvidenceRoot, access = "v4-owned mutable" }
    ];

    private static async Task<WorkspaceDocument> BuildWorkspace(CompanionOptions options, WorkspaceState state, CancellationToken cancellationToken)
    {
        if (state.TrySnapshot(out var cached)) return cached;
        await state.ProjectionGate.WaitAsync(cancellationToken);
        try
        {
            if (state.TrySnapshot(out cached)) return cached;
            var profiles = await QueryProfiles(options, cancellationToken);
            var targets = new List<WorkspaceTarget>();
            foreach (var targetRoot in options.TargetRoots)
            {
                var projection = await QueryProject(options, targetRoot, cancellationToken);
                targets.Add(new WorkspaceTarget(projection.ProjectId, projection.TargetRoot,
                    projection.TargetIdentityHash, projection.Bound, projection.ProfileId,
                    projection.StateDocumentStatus, false));
            }
            state.Store(profiles.Profiles, targets.ToArray());
            if (!state.TrySnapshot(out cached)) throw new HostInvocationException("host-output-invalid", "Workspace projection cache was not established.");
            return cached;
        }
        finally { state.ProjectionGate.Release(); }
    }

    private static async Task<ProjectProjection> QueryProject(CompanionOptions options, string targetRoot, CancellationToken cancellationToken)
    {
        var result = await InvokeHostQuery(options,
        [
            "query", "project", "--package-root", options.PackageRoot, "--target-root", targetRoot,
            "--state-root", options.StateRoot, "--evidence-root", options.EvidenceRoot
        ], cancellationToken);
        return Deserialize<ProjectQueryProjection>(result, "project query").Project;
    }

    private static async Task RefreshProjectAfterRun(CompanionOptions options, WorkspaceState state, string targetRoot,
        CancellationToken cancellationToken)
    {
        try { state.Update(await QueryProject(options, targetRoot, cancellationToken)); }
        catch (HostInvocationException) { /* The Host Stage result remains authoritative even if presentation refresh fails. */ }
    }

    private static async Task<ProfileCatalogProjection> QueryProfiles(CompanionOptions options, CancellationToken cancellationToken)
    {
        var result = await InvokeHostQuery(options,
        [
            "query", "profiles", "--package-root", options.PackageRoot
        ], cancellationToken);
        return Deserialize<ProfileCatalogProjection>(result, "profile catalog query");
    }

    private static T Deserialize<T>(JsonElement value, string label)
    {
        try { return JsonSerializer.Deserialize<T>(value.GetRawText(), JsonOptions) ?? throw new JsonException($"{label} is empty."); }
        catch (JsonException ex) { throw new HostInvocationException("host-output-invalid", $"The {label} projection is invalid: {ex.Message}"); }
    }

    private static bool IsAuthorizedRead(HttpContext context, string expectedSecret) =>
        context.Request.Cookies.TryGetValue(SessionCookie, out var actualSecret) && FixedTimeEquals(actualSecret, expectedSecret);

    private static bool IsAuthorizedMutation(HttpContext context, string expectedSecret)
    {
        if (!IsAuthorizedRead(context, expectedSecret)) return false;
        var originText = context.Request.Headers.Origin.ToString();
        if (!Uri.TryCreate(originText, UriKind.Absolute, out var origin)) return false;
        return string.Equals(origin.Scheme, context.Request.Scheme, StringComparison.Ordinal) &&
            string.Equals(origin.Host, IPAddress.Loopback.ToString(), StringComparison.Ordinal) &&
            origin.Port == context.Request.Host.Port &&
            (string.IsNullOrEmpty(origin.PathAndQuery) || origin.PathAndQuery == "/");
    }

    private static bool FixedTimeEquals(string left, string right)
    {
        var leftBytes = Encoding.UTF8.GetBytes(left);
        var rightBytes = Encoding.UTF8.GetBytes(right);
        return leftBytes.Length == rightBytes.Length && CryptographicOperations.FixedTimeEquals(leftBytes, rightBytes);
    }

    private static async Task<StageRequest> ReadStageRequest(HttpRequest request, CancellationToken cancellationToken)
    {
        using var document = await ReadRequestObject(request, cancellationToken);
        var root = document.RootElement;
        RequireExactProperties(root, "stage", "profile", "withDependencies");
        var stageElement = root.GetProperty("stage");
        var profileElement = root.GetProperty("profile");
        var dependenciesElement = root.GetProperty("withDependencies");
        if (stageElement.ValueKind != JsonValueKind.String || profileElement.ValueKind != JsonValueKind.String ||
            dependenciesElement.ValueKind is not (JsonValueKind.True or JsonValueKind.False))
            throw new RequestException("invalid-input", "Request field types are invalid.");
        var stage = stageElement.GetString()!;
        var profile = profileElement.GetString()!;
        if (!AllowedStages.Contains(stage, StringComparer.Ordinal))
            throw new RequestException("command-refused", "Stage is not allowlisted.");
        if (!ProfilePattern.IsMatch(profile))
            throw new RequestException("command-refused", "Profile ID is not valid.");
        return new StageRequest(stage, profile, dependenciesElement.GetBoolean());
    }

    private static async Task<WorkspaceSelection> ReadWorkspaceSelection(HttpRequest request, CancellationToken cancellationToken)
    {
        using var document = await ReadRequestObject(request, cancellationToken);
        var root = document.RootElement;
        RequireExactProperties(root, "projectId");
        var value = root.GetProperty("projectId");
        if (value.ValueKind != JsonValueKind.String || !ProjectIdPattern.IsMatch(value.GetString()!))
            throw new RequestException("invalid-input", "Project ID is invalid.");
        return new WorkspaceSelection(value.GetString()!);
    }

    private static async Task<JsonDocument> ReadRequestObject(HttpRequest request, CancellationToken cancellationToken)
    {
        if (request.ContentType is null || !request.ContentType.StartsWith("application/json", StringComparison.OrdinalIgnoreCase))
            throw new RequestException("invalid-input", "Content-Type must be application/json.");
        try
        {
            var document = await JsonDocument.ParseAsync(request.Body, new JsonDocumentOptions
            {
                AllowTrailingCommas = false,
                CommentHandling = JsonCommentHandling.Disallow,
                MaxDepth = 8
            }, cancellationToken);
            if (document.RootElement.ValueKind != JsonValueKind.Object)
            {
                document.Dispose();
                throw new RequestException("invalid-input", "Request JSON must be an object.");
            }
            return document;
        }
        catch (JsonException ex) { throw new RequestException("invalid-input", $"Request JSON is invalid: {ex.Message}"); }
    }

    private static void RequireExactProperties(JsonElement root, params string[] names)
    {
        var known = new HashSet<string>(names, StringComparer.Ordinal);
        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (var property in root.EnumerateObject())
        {
            if (!known.Contains(property.Name)) throw new RequestException("invalid-input", $"Unknown request field: {property.Name}");
            if (!seen.Add(property.Name)) throw new RequestException("invalid-input", $"Duplicate request field: {property.Name}");
        }
        if (seen.Count != known.Count) throw new RequestException("invalid-input", $"{string.Join(", ", names)} are required.");
    }

    private static Task<HostExecution> InvokeStage(CompanionOptions options, string targetRoot, StageRequest request,
        CancellationToken cancellationToken)
    {
        var arguments = new List<string>
        {
            "stage", "run", "--stage", request.Stage,
            "--package-root", options.PackageRoot, "--target-root", targetRoot,
            "--state-root", options.StateRoot, "--evidence-root", options.EvidenceRoot,
            "--profile", request.Profile
        };
        if (request.WithDependencies) arguments.Add("--with-dependencies");
        return InvokeHost(options, arguments, cancellationToken);
    }

    private static async Task<JsonElement> InvokeHostQuery(CompanionOptions options, IReadOnlyList<string> arguments,
        CancellationToken cancellationToken)
    {
        var execution = await InvokeHost(options, arguments, cancellationToken);
        if (execution.ExitCode != 0)
            throw new HostInvocationException("host-query-refused", $"The V4 Host query failed with exit {execution.ExitCode}: {execution.Result.GetRawText()}");
        return execution.Result;
    }

    private static async Task<HostExecution> InvokeHost(CompanionOptions options, IReadOnlyList<string> arguments,
        CancellationToken requestAborted)
    {
        var start = new ProcessStartInfo(options.DotnetHost)
        {
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
            WorkingDirectory = options.PackageRoot
        };
        start.ArgumentList.Add(options.HostPath);
        foreach (var value in arguments) start.ArgumentList.Add(value);

        var inherited = new Dictionary<string, string?>(StringComparer.OrdinalIgnoreCase);
        foreach (var name in new[] { "PATH", "PATHEXT", "SystemRoot", "WINDIR", "TEMP", "TMP", "HOME", "DOTNET_ROOT", "DOTNET_HOST_PATH" })
            inherited[name] = Environment.GetEnvironmentVariable(name);
        start.Environment.Clear();
        foreach (var pair in inherited.Where(pair => !string.IsNullOrWhiteSpace(pair.Value))) start.Environment[pair.Key] = pair.Value!;
        start.Environment["POWERSHELL_TELEMETRY_OPTOUT"] = "1";
        start.Environment["DOTNET_CLI_TELEMETRY_OPTOUT"] = "1";

        using var process = Process.Start(start) ?? throw new HostInvocationException("host-unavailable", "The V4 Host did not start.");
        var stdout = process.StandardOutput.ReadToEndAsync(requestAborted);
        var stderr = process.StandardError.ReadToEndAsync(requestAborted);
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(requestAborted);
        timeout.CancelAfter(TimeSpan.FromMinutes(5));
        try { await process.WaitForExitAsync(timeout.Token); }
        catch (OperationCanceledException)
        {
            try { process.Kill(true); } catch { }
            throw new HostInvocationException("host-timeout", "The V4 Host run was cancelled or exceeded five minutes.");
        }

        var output = process.ExitCode == 0 ? await stdout : await stderr;
        try
        {
            using var result = JsonDocument.Parse(output);
            if (result.RootElement.ValueKind != JsonValueKind.Object) throw new JsonException("Host output is not an object.");
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

    private static bool PathEquals(string left, string right) => string.Equals(Path.GetFullPath(left), Path.GetFullPath(right),
        OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal);

    private sealed record StageRequest(string Stage, string Profile, bool WithDependencies);
    private sealed record WorkspaceSelection(string ProjectId);
    private sealed record HostExecution(int ExitCode, JsonElement Result);
    private sealed record ProjectQueryProjection(ProjectProjection Project);
    private sealed record ProjectProjection(string ProjectId, string TargetRoot, string TargetIdentityHash, bool Bound,
        string? ProfileId, string StateDocumentStatus);
    private sealed record ProfileCatalogProjection(ProfileProjection[] Profiles);
    private sealed record ProfileProjection(string Id, string Version, string Sha256, string ProjectIdentityId,
        string[] SelectedModules, ProfileStageProjection[] Stages);
    private sealed record ProfileStageProjection(string Stage, bool Enabled, string[] Modules);
    private sealed record WorkspaceTarget(string ProjectId, string TargetRoot, string TargetIdentityHash, bool Bound,
        string? ProfileId, string StateDocumentStatus, bool Active);
    private sealed record WorkspaceDocument(int FormatVersion, string Status, string Authority, string Concurrency,
        string ActiveProjectId, WorkspaceTarget[] Targets, ProfileProjection[] Profiles);

    private sealed class WorkspaceState(string activeTargetRoot)
    {
        private readonly object _sync = new();
        private string _activeTargetRoot = activeTargetRoot;
        private ProfileProjection[]? _profiles;
        private WorkspaceTarget[]? _targets;
        public SemaphoreSlim ProjectionGate { get; } = new(1, 1);
        public string ActiveTargetRoot { get { lock (_sync) return _activeTargetRoot; } }
        public void Select(string targetRoot) { lock (_sync) _activeTargetRoot = targetRoot; }
        public void Store(ProfileProjection[] profiles, WorkspaceTarget[] targets)
        {
            lock (_sync) { _profiles = profiles; _targets = targets; }
        }
        public void Update(ProjectProjection project)
        {
            lock (_sync)
            {
                if (_targets is null) return;
                var index = Array.FindIndex(_targets, target => PathEquals(target.TargetRoot, project.TargetRoot));
                if (index < 0) return;
                _targets[index] = new WorkspaceTarget(project.ProjectId, project.TargetRoot, project.TargetIdentityHash,
                    project.Bound, project.ProfileId, project.StateDocumentStatus, false);
            }
        }
        public bool TrySnapshot(out WorkspaceDocument document)
        {
            lock (_sync)
            {
                if (_profiles is null || _targets is null)
                {
                    document = null!;
                    return false;
                }
                var targets = _targets.Select(target => target with { Active = PathEquals(target.TargetRoot, _activeTargetRoot) }).ToArray();
                var active = targets.Single(target => target.Active);
                document = new WorkspaceDocument(1, "pass", "v4-host", "one-active-target-one-active-run",
                    active.ProjectId, targets, _profiles);
                return true;
            }
        }
    }

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

    private sealed record CompanionOptions(string PackageRoot, string[] TargetRoots, string StateRoot,
        string EvidenceRoot, string HostPath, string DotnetHost, int Port)
    {
        public static CompanionOptions Parse(string[] args)
        {
            var values = new Dictionary<string, string>(StringComparer.Ordinal);
            var targetValues = new List<string>();
            for (var index = 0; index < args.Length; index += 2)
            {
                if (index + 1 >= args.Length || !args[index].StartsWith("--", StringComparison.Ordinal))
                    throw new CompanionException(10, "invalid-input", "Startup arguments must be --name value pairs.");
                var name = args[index][2..];
                if (name == "target-root") targetValues.Add(args[index + 1]);
                else if (!values.TryAdd(name, args[index + 1]))
                    throw new CompanionException(10, "invalid-input", "Startup arguments must be unique except --target-root.");
            }
            var known = new HashSet<string>(["package-root", "state-root", "evidence-root", "host", "port"], StringComparer.Ordinal);
            var unknown = values.Keys.FirstOrDefault(value => !known.Contains(value));
            if (unknown is not null) throw new CompanionException(10, "invalid-input", $"Unknown startup argument: --{unknown}");
            string Required(string name) => values.TryGetValue(name, out var value) && !string.IsNullOrWhiteSpace(value)
                ? value : throw new CompanionException(10, "invalid-input", $"Missing --{name}.");
            if (targetValues.Count == 0) throw new CompanionException(10, "invalid-input", "At least one --target-root is required.");
            if (!int.TryParse(Required("port"), out var port) || port is < 0 or > 65535)
                throw new CompanionException(10, "invalid-input", "Port must be an integer from 0 through 65535.");

            var packageRoot = ResolveDirectory(Required("package-root"), "PackageRoot");
            var targetRoots = targetValues.Select(value => ResolveDirectory(value, "TargetRoot")).ToArray();
            if (targetRoots.Distinct(PathComparer()).Count() != targetRoots.Length)
                throw new CompanionException(10, "invalid-input", "TargetRoot values must be unique.");
            for (var left = 0; left < targetRoots.Length; left++)
            for (var right = left + 1; right < targetRoots.Length; right++)
                if (Overlaps(targetRoots[left], targetRoots[right]))
                    throw new CompanionException(11, "unsafe-path", "TargetRoot values cannot overlap each other.");

            var stateRoot = ResolveDirectory(Required("state-root"), "StateRoot");
            var evidenceRoot = ResolveDirectory(Required("evidence-root"), "EvidenceRoot");
            foreach (var mutable in new[] { ("StateRoot", stateRoot), ("EvidenceRoot", evidenceRoot) })
            {
                if (Overlaps(mutable.Item2, packageRoot) || targetRoots.Any(target => Overlaps(mutable.Item2, target)))
                    throw new CompanionException(11, "unsafe-path", $"{mutable.Item1} overlaps PackageRoot or a TargetRoot.");
            }
            if (Overlaps(stateRoot, evidenceRoot)) throw new CompanionException(11, "unsafe-path", "StateRoot and EvidenceRoot overlap.");

            var hostPath = ResolveFile(Required("host"), "V4 Host");
            if (!string.Equals(Path.GetFileName(hostPath), "v4-guards.dll", StringComparison.Ordinal))
                throw new CompanionException(10, "invalid-input", "The Host must be v4-guards.dll.");
            var dotnetHost = Environment.ProcessPath;
            if (string.IsNullOrWhiteSpace(dotnetHost) || !File.Exists(dotnetHost))
                throw new CompanionException(15, "prerequisite-missing", "The current dotnet host path is unavailable.");
            return new CompanionOptions(packageRoot, targetRoots, stateRoot, evidenceRoot, hostPath, Path.GetFullPath(dotnetHost), port);
        }

        private static string ResolveDirectory(string value, string label)
        {
            string full;
            try { full = Path.TrimEndingDirectorySeparator(Path.GetFullPath(value)); }
            catch (Exception ex) { throw new CompanionException(11, "unsafe-path", $"{label} is invalid: {ex.Message}"); }
            if (!Directory.Exists(full)) throw new CompanionException(10, "invalid-input", $"{label} does not exist: {full}");
            EnsureNoLinks(full, label);
            return full;
        }

        private static string ResolveFile(string value, string label)
        {
            string full;
            try { full = Path.GetFullPath(value); }
            catch (Exception ex) { throw new CompanionException(11, "unsafe-path", $"{label} path is invalid: {ex.Message}"); }
            if (!File.Exists(full)) throw new CompanionException(10, "invalid-input", $"{label} does not exist: {full}");
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

        private static StringComparer PathComparer() => OperatingSystem.IsWindows() ? StringComparer.OrdinalIgnoreCase : StringComparer.Ordinal;
        private static bool Overlaps(string left, string right) => IsUnder(left, right) || IsUnder(right, left);
        private static bool IsUnder(string path, string root)
        {
            var relative = Path.GetRelativePath(root, path);
            return relative == "." || (!Path.IsPathRooted(relative) && relative != ".." &&
                !relative.StartsWith($"..{Path.DirectorySeparatorChar}", StringComparison.Ordinal));
        }
    }
}
