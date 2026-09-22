using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace V4.Guards.Host;

internal static class QueryRuntime
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = false,
        WriteIndented = true
    };
    private static readonly Regex IdentifierPattern = new("^[a-z][a-z0-9_-]*$", RegexOptions.CultureInvariant);
    private static readonly Regex PlanIdPattern = new("^[0-9]{8}-[a-z0-9-]+$", RegexOptions.CultureInvariant);
    private static readonly Regex HashIdPattern = new("^[a-f0-9]{32}$", RegexOptions.CultureInvariant);
    private static readonly string[] StageNames = ["bootstrap", "analysis", "pre", "post"];
    private static readonly string[] HistoricalPlanProperties =
    [
        "formatVersion", "id", "title", "goal", "acceptanceCriteria", "plannedPaths", "areaIds",
        "ruleIds", "validationCommands", "decisionPaths"
    ];

    public static int Execute(string[] args)
    {
        try
        {
            var arguments = ParseArguments(args);
            var outcome = arguments.Operation switch
            {
                "project" => Project(arguments),
                "profiles" => Profiles(arguments),
                "doctor" => Doctor(arguments),
                "runs" => Runs(arguments),
                "evidence" => Evidence(arguments),
                "plans" => Plans(arguments),
                _ => throw Invalid($"Unknown query operation: {arguments.Operation}")
            };
            ValidateOutput(outcome.PackageRoot, outcome.SchemaId, outcome.Document);
            Console.WriteLine(JsonSerializer.Serialize(outcome.Document, JsonOptions));
            return 0;
        }
        catch (QueryException ex)
        {
            return Error(ex.Code, ex.Category, ex.Message);
        }
        catch (ContractRuntime.ContractException ex)
        {
            return Error(ex.Code, ex.Category, ex.Message);
        }
        catch (System.ComponentModel.Win32Exception ex)
        {
            return Error(15, "prerequisite-missing", $"A declared query runtime is unavailable: {ex.Message}");
        }
        catch (Exception ex)
        {
            return Error(19, "internal-error", ex.Message);
        }
    }

    private static QueryOutcome Project(Arguments arguments)
    {
        arguments.RequireOnly("package-root", "target-root", "state-root", "evidence-root");
        var roots = ResolveRoots(arguments, true);
        ValidatePackage(roots.PackageRoot);
        var identityHash = HashText(OperatingSystem.IsWindows() ? roots.TargetRoot!.ToUpperInvariant() : roots.TargetRoot!);
        var projectId = identityHash[..32];
        var state = LoadState(roots.PackageRoot, roots.StateRoot, out var stateStatus);
        var instance = state?.ProjectInstances.SingleOrDefault(item => item.Id == projectId);
        if (instance is not null && (!PathEquals(instance.TargetCanonicalPath, roots.TargetRoot!) || instance.TargetIdentityHash != identityHash))
            throw Conflict("Project identity and TargetRoot binding drift.");
        if (instance is null && state?.ProjectInstances.Any(item => PathEquals(item.TargetCanonicalPath, roots.TargetRoot!)) == true)
            throw Conflict("TargetRoot is bound under a different project identity.");
        var document = new
        {
            formatVersion = 1,
            status = "pass",
            query = "project",
            authority = "v4-host",
            project = new
            {
                projectId,
                targetRoot = roots.TargetRoot,
                targetIdentityHash = identityHash,
                bound = instance is not null,
                profileId = instance?.ProfileId,
                stateDocumentStatus = stateStatus
            },
            roots = new { packageRoot = roots.PackageRoot, targetRoot = roots.TargetRoot, stateRoot = roots.StateRoot, evidenceRoot = roots.EvidenceRoot }
        };
        return new QueryOutcome(roots.PackageRoot, "project-query", document);
    }

    private static QueryOutcome Profiles(Arguments arguments)
    {
        arguments.RequireOnly("package-root");
        var packageRoot = ResolveDirectory(arguments.Required("package-root"), "PackageRoot");
        ValidatePackage(packageRoot);
        using var plugin = ReadDocument(ResolveFileUnder(packageRoot, "plugin.json", "plugin manifest"), "plugin manifest");
        var catalogRelative = RequiredString(plugin.RootElement, "profilesCatalog", "plugin manifest");
        var catalog = ResolveDirectoryUnder(packageRoot, catalogRelative, "profile catalog");
        var profiles = new List<object>();
        foreach (var directory in Directory.GetDirectories(catalog).Order(StringComparer.Ordinal))
        {
            EnsureNoLinks(catalog, directory, "profile directory");
            var profilePath = ResolveFileUnder(packageRoot, Path.GetRelativePath(packageRoot, Path.Combine(directory, "profile.json")), "profile manifest");
            using var profile = ReadDocument(profilePath, "profile manifest");
            var root = profile.RootElement;
            var selected = root.GetProperty("moduleSelections").EnumerateArray()
                .Select(item => RequiredString(item, "id", "module selection")).Order(StringComparer.Ordinal).ToArray();
            var stageConfiguration = root.GetProperty("stageConfiguration");
            var stages = StageNames.Select(stage =>
            {
                var value = stageConfiguration.GetProperty(stage);
                return new
                {
                    stage,
                    enabled = value.GetProperty("enabled").GetBoolean(),
                    modules = value.GetProperty("modules").EnumerateArray().Select(item => item.GetString()!).ToArray()
                };
            }).ToArray();
            profiles.Add(new
            {
                id = RequiredString(root, "id", "profile"),
                version = RequiredString(root, "version", "profile"),
                sha256 = HashFile(profilePath),
                projectIdentityId = RequiredString(root.GetProperty("projectIdentity"), "id", "project identity"),
                selectedModules = selected,
                stages
            });
        }
        var document = new { formatVersion = 1, status = "pass", query = "profiles", authority = "v4-host", profiles };
        return new QueryOutcome(packageRoot, "profile-catalog-query", document);
    }

    private static QueryOutcome Doctor(Arguments arguments)
    {
        arguments.RequireOnly("package-root", "profile");
        var packageRoot = ResolveDirectory(arguments.Required("package-root"), "PackageRoot");
        ValidatePackage(packageRoot);
        var profile = arguments.Required("profile");
        if (!IdentifierPattern.IsMatch(profile)) throw Invalid("Profile ID is invalid.");
        var script = ResolveFileUnder(packageRoot, "core/distribution/Test-V4Prerequisites.ps1", "prerequisite checker");
        var reportPath = Path.Combine(Path.GetTempPath(), $"v4-query-doctor-{Guid.NewGuid():N}.json");
        try
        {
            var start = PowerShellStart(script);
            foreach (var value in new[] { "-PackageRoot", packageRoot, "-Profile", profile, "-ReportPath", reportPath })
                start.ArgumentList.Add(value);
            var result = Run(start, 180, "prerequisite query");
            if (result.ExitCode is not (0 or 15))
                throw Invalid($"Prerequisite query failed: {result.Error.Trim()}");
            ContractRuntime.ValidateRegisteredDocument(packageRoot, "prerequisite-report", reportPath);
            using var report = ReadDocument(reportPath, "prerequisite report");
            var document = new
            {
                formatVersion = 1,
                status = "pass",
                query = "doctor",
                authority = "v4-host",
                report = report.RootElement.Clone()
            };
            return new QueryOutcome(packageRoot, "prerequisite-query", document);
        }
        finally
        {
            if (File.Exists(reportPath)) File.Delete(reportPath);
        }
    }

    private static QueryOutcome Runs(Arguments arguments)
    {
        arguments.RequireOnly("package-root", "state-root", "evidence-root", "project");
        var roots = ResolveRoots(arguments, false);
        ValidatePackage(roots.PackageRoot);
        var projectId = ValidateHashId(arguments.Required("project"), "Project ID");
        _ = RequireBoundProject(roots, projectId);
        var runRoot = Path.Combine(roots.EvidenceRoot, "projects", projectId, "runs");
        var runs = new List<object>();
        if (Directory.Exists(runRoot))
        {
            EnsureNoLinks(roots.EvidenceRoot, runRoot, "run catalog");
            foreach (var directory in Directory.GetDirectories(runRoot).Order(StringComparer.Ordinal))
            {
                var runId = ValidateHashId(Path.GetFileName(directory), "Run directory ID");
                EnsureNoLinks(roots.EvidenceRoot, directory, "run directory");
                var resultPath = ResolveFileUnder(roots.EvidenceRoot,
                    Path.GetRelativePath(roots.EvidenceRoot, Path.Combine(directory, "stage-result.json")), "Stage result");
                ValidateStoredDocument(roots.PackageRoot, "stage-result", resultPath, "Stage result");
                using var result = ReadDocument(resultPath, "Stage result");
                var root = result.RootElement;
                if (RequiredString(root, "runId", "Stage result") != runId)
                    throw Integrity("Stage result runId does not match its evidence directory.");
                var profile = root.GetProperty("profile");
                runs.Add(new
                {
                    runId,
                    stage = RequiredString(root, "stage", "Stage result"),
                    status = RequiredString(root, "status", "Stage result"),
                    exitCategory = RequiredString(root, "exitCategory", "Stage result"),
                    profileId = RequiredString(profile, "id", "Stage result profile"),
                    profileVersion = RequiredString(profile, "version", "Stage result profile"),
                    resultSha256 = HashFile(resultPath),
                    executedStages = root.GetProperty("executedStages").EnumerateArray().Select(item => item.GetString()!).ToArray(),
                    findingCount = root.GetProperty("findings").GetArrayLength(),
                    coverageCount = root.GetProperty("coverage").GetArrayLength()
                });
            }
        }
        var document = new { formatVersion = 1, status = "pass", query = "runs", authority = "v4-host", projectId, runs };
        return new QueryOutcome(roots.PackageRoot, "run-catalog-query", document);
    }

    private static QueryOutcome Evidence(Arguments arguments)
    {
        arguments.RequireOnly("package-root", "state-root", "evidence-root", "project", "run");
        var roots = ResolveRoots(arguments, false);
        ValidatePackage(roots.PackageRoot);
        var projectId = ValidateHashId(arguments.Required("project"), "Project ID");
        var runId = ValidateHashId(arguments.Required("run"), "Run ID");
        _ = RequireBoundProject(roots, projectId);
        var projectEvidence = Path.Combine(roots.EvidenceRoot, "projects", projectId);
        var runRoot = Path.Combine(projectEvidence, "runs", runId);
        if (!Directory.Exists(runRoot)) throw Invalid("Run evidence does not exist.");
        EnsureNoLinks(roots.EvidenceRoot, runRoot, "run evidence");
        var resultPath = ResolveFileUnder(roots.EvidenceRoot,
            Path.GetRelativePath(roots.EvidenceRoot, Path.Combine(runRoot, "stage-result.json")), "Stage result");
        ValidateStoredDocument(roots.PackageRoot, "stage-result", resultPath, "Stage result");
        using var result = ReadDocument(resultPath, "Stage result");
        if (RequiredString(result.RootElement, "runId", "Stage result") != runId)
            throw Integrity("Stage result runId does not match the requested run.");
        var files = new List<object>();
        foreach (var filePath in Directory.GetFiles(runRoot, "*", SearchOption.AllDirectories).Order(StringComparer.Ordinal))
        {
            EnsureNoLinks(roots.EvidenceRoot, filePath, "run evidence file");
            var relative = NormalizeRelative(Path.GetRelativePath(projectEvidence, filePath));
            var info = new FileInfo(filePath);
            files.Add(new
            {
                path = relative,
                kind = string.Equals(Path.GetFullPath(filePath), Path.GetFullPath(resultPath), PathComparison()) ? "stage-result" : "module-evidence",
                sha256 = HashFile(filePath),
                size = info.Length
            });
        }
        var document = new
        {
            formatVersion = 1,
            status = "pass",
            query = "evidence",
            authority = "v4-host",
            projectId,
            runId,
            resultSha256 = HashFile(resultPath),
            stageResult = result.RootElement.Clone(),
            files
        };
        return new QueryOutcome(roots.PackageRoot, "evidence-query", document);
    }

    private static QueryOutcome Plans(Arguments arguments)
    {
        arguments.RequireOnly("package-root", "target-root", "plan-root");
        var packageRoot = ResolveDirectory(arguments.Required("package-root"), "PackageRoot");
        var targetRoot = ResolveDirectory(arguments.Required("target-root"), "TargetRoot");
        ValidatePackage(packageRoot);
        PlanRuntime.VerifyPlanContractForQuery(packageRoot);
        var planRootRelative = ValidateRelative(arguments.Required("plan-root"), "Plan root");
        var planRoot = ResolveDirectoryUnder(targetRoot, planRootRelative, "Plan root");
        var plans = new List<object>();
        foreach (var jsonPath in Directory.GetFiles(planRoot, "*.plan.json", SearchOption.TopDirectoryOnly).Order(StringComparer.Ordinal))
        {
            EnsureNoLinks(targetRoot, jsonPath, "Plan JSON");
            var jsonRelative = NormalizeRelative(Path.GetRelativePath(targetRoot, jsonPath));
            var markdownPath = Regex.Replace(jsonPath, "\\.plan\\.json$", ".md", RegexOptions.CultureInvariant);
            if (!File.Exists(markdownPath)) throw Integrity($"Plan pair Markdown is missing: {jsonRelative}");
            EnsureNoLinks(targetRoot, markdownPath, "Plan Markdown");
            var markdownRelative = NormalizeRelative(Path.GetRelativePath(targetRoot, markdownPath));

            string id;
            string title;
            string kind;
            string presentationMode;
            string validation;
            if (PlanRuntime.TryReadNativePlan(targetRoot, jsonRelative, out var native))
            {
                id = native!.Id;
                title = native.Title;
                kind = "v4-native";
                presentationMode = "native-contract";
                validation = "v4-plan-valid";
            }
            else
            {
                using var historical = ReadDocument(jsonPath, "historical Plan");
                if (!IsHistoricalPlan(historical.RootElement))
                    throw Integrity($"Plan is neither valid V4-native nor a recognized V3 historical pair: {jsonRelative}");
                id = RequiredString(historical.RootElement, "id", "historical Plan");
                title = RequiredString(historical.RootElement, "title", "historical Plan");
                kind = "v3-historical";
                presentationMode = "historical-read-only";
                validation = "v3-compatibility-view";
            }
            plans.Add(new
            {
                id,
                title,
                kind,
                presentationMode,
                validation,
                jsonPath = jsonRelative,
                markdownPath = markdownRelative,
                jsonSha256 = HashFile(jsonPath),
                markdownSha256 = HashFile(markdownPath)
            });
        }
        var document = new
        {
            formatVersion = 1,
            status = "pass",
            query = "plans",
            authority = "v4-host",
            planRoot = NormalizeRelative(Path.GetRelativePath(targetRoot, planRoot)),
            plans
        };
        return new QueryOutcome(packageRoot, "plan-catalog-query", document);
    }

    private static bool IsHistoricalPlan(JsonElement root)
    {
        if (root.ValueKind != JsonValueKind.Object) return false;
        var names = root.EnumerateObject().Select(property => property.Name).ToArray();
        if (names.Length != HistoricalPlanProperties.Length || names.Distinct(StringComparer.Ordinal).Count() != names.Length ||
            names.Any(name => !HistoricalPlanProperties.Contains(name, StringComparer.Ordinal))) return false;
        if (root.GetProperty("formatVersion").ValueKind != JsonValueKind.Number ||
            !root.GetProperty("formatVersion").TryGetInt32(out var version) || version != 1) return false;
        if (!TryNonEmptyString(root, "id", out var id) || !PlanIdPattern.IsMatch(id) ||
            !TryNonEmptyString(root, "title", out _) || !TryNonEmptyString(root, "goal", out _)) return false;
        return HistoricalStringArray(root, "acceptanceCriteria", true, false) &&
            HistoricalStringArray(root, "plannedPaths", true, true) &&
            HistoricalStringArray(root, "areaIds", true, false) &&
            HistoricalStringArray(root, "ruleIds", false, false) &&
            HistoricalStringArray(root, "validationCommands", true, false) &&
            HistoricalStringArray(root, "decisionPaths", false, true);
    }

    private static bool HistoricalStringArray(JsonElement root, string name, bool required, bool relativePaths)
    {
        var value = root.GetProperty(name);
        if (value.ValueKind != JsonValueKind.Array) return false;
        var items = value.EnumerateArray().ToArray();
        if (required && items.Length == 0) return false;
        var strings = new List<string>(items.Length);
        foreach (var item in items)
        {
            if (item.ValueKind != JsonValueKind.String || string.IsNullOrWhiteSpace(item.GetString())) return false;
            var text = item.GetString()!;
            if (relativePaths)
            {
                try { _ = ValidateRelative(text, name); }
                catch (QueryException) { return false; }
            }
            strings.Add(text);
        }
        return strings.Distinct(StringComparer.Ordinal).Count() == strings.Count;
    }

    private static bool TryNonEmptyString(JsonElement root, string name, out string value)
    {
        var property = root.GetProperty(name);
        value = property.ValueKind == JsonValueKind.String ? property.GetString() ?? "" : "";
        return !string.IsNullOrWhiteSpace(value);
    }

    private static ProjectInstance RequireBoundProject(QueryRoots roots, string projectId)
    {
        var state = LoadState(roots.PackageRoot, roots.StateRoot, out _)
            ?? throw Invalid("StateRoot has no project state.");
        return state.ProjectInstances.SingleOrDefault(item => item.Id == projectId)
            ?? throw Invalid("Project is not bound in StateRoot.");
    }

    private static StateDocument? LoadState(string packageRoot, string stateRoot, out string status)
    {
        var path = Path.Combine(stateRoot, "state.json");
        if (!File.Exists(path))
        {
            status = "missing";
            return null;
        }
        EnsureNoLinks(stateRoot, path, "state document");
        ValidateStoredDocument(packageRoot, "state", path, "state document");
        try
        {
            var state = JsonSerializer.Deserialize<StateDocument>(File.ReadAllText(path), JsonOptions)
                ?? throw new JsonException("State document is empty.");
            if (state.FormatVersion != 1) throw new JsonException("State formatVersion is invalid.");
            status = "valid";
            return state;
        }
        catch (JsonException ex) { throw Conflict($"State document is invalid: {ex.Message}"); }
    }

    private static void ValidateStoredDocument(string packageRoot, string schema, string path, string label)
    {
        try { ContractRuntime.ValidateRegisteredDocument(packageRoot, schema, path); }
        catch (ContractRuntime.ContractException ex)
        {
            throw Integrity($"{label} failed registered schema validation: {ex.Message}");
        }
    }

    private static void ValidateOutput(string packageRoot, string schema, object document)
    {
        var path = Path.Combine(Path.GetTempPath(), $"v4-query-output-{Guid.NewGuid():N}.json");
        try
        {
            File.WriteAllText(path, JsonSerializer.Serialize(document, JsonOptions), new UTF8Encoding(false));
            try { ContractRuntime.ValidateRegisteredDocument(packageRoot, schema, path); }
            catch (ContractRuntime.ContractException ex)
            {
                throw new QueryException(19, "internal-error", $"Generated query output violates {schema}: {ex.Message}");
            }
        }
        finally { if (File.Exists(path)) File.Delete(path); }
    }

    private static Arguments ParseArguments(string[] args)
    {
        if (args.Length < 2 || args[0] != "query") throw Invalid("Expected 'query <operation>'.");
        var values = new Dictionary<string, string>(StringComparer.Ordinal);
        for (var index = 2; index < args.Length; index += 2)
        {
            if (index + 1 >= args.Length || !args[index].StartsWith("--", StringComparison.Ordinal))
                throw Invalid("Arguments must be --name value pairs.");
            if (!values.TryAdd(args[index][2..], args[index + 1]))
                throw Invalid($"Duplicate argument: {args[index]}");
        }
        return new Arguments(args[1], values);
    }

    private static QueryRoots ResolveRoots(Arguments arguments, bool targetRequired)
    {
        var package = ResolveDirectory(arguments.Required("package-root"), "PackageRoot");
        var state = ResolveDirectory(arguments.Required("state-root"), "StateRoot");
        var evidence = ResolveDirectory(arguments.Required("evidence-root"), "EvidenceRoot");
        var target = targetRequired ? ResolveDirectory(arguments.Required("target-root"), "TargetRoot") : null;
        foreach (var mutable in new[] { ("StateRoot", state), ("EvidenceRoot", evidence) })
        {
            if (Overlaps(mutable.Item2, package)) throw Unsafe($"{mutable.Item1} overlaps PackageRoot.");
            if (target is not null && Overlaps(mutable.Item2, target)) throw Unsafe($"{mutable.Item1} overlaps TargetRoot.");
        }
        if (Overlaps(state, evidence)) throw Unsafe("StateRoot and EvidenceRoot overlap.");
        return new QueryRoots(package, target, state, evidence);
    }

    private static void ValidatePackage(string packageRoot)
    {
        var checker = ResolveFileUnder(packageRoot, "core/runtime/Test-V4Package.ps1", "package checker");
        var start = PowerShellStart(checker);
        start.ArgumentList.Add("-PackageRoot");
        start.ArgumentList.Add(packageRoot);
        var result = Run(start, 180, "package validation");
        if (result.ExitCode != 0) throw Integrity($"Package validation failed before query: {result.Error.Trim()}");
        try
        {
            using var document = JsonDocument.Parse(result.Output);
            if (document.RootElement.GetProperty("status").GetString() != "pass") throw new JsonException("Package status is not pass.");
        }
        catch (JsonException ex) { throw Integrity($"Package validation output is invalid: {ex.Message}"); }
        ContractRuntime.ValidateRegisteredDocument(packageRoot, "query-contract",
            ResolveFileUnder(packageRoot, "core/contracts/query-contract.json", "query command contract"));
    }

    private static ProcessStartInfo PowerShellStart(string script)
    {
        var start = new ProcessStartInfo(FindExecutable("pwsh"))
        {
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };
        foreach (var value in new[] { "-NoLogo", "-NoProfile", "-NonInteractive", "-File", script })
            start.ArgumentList.Add(value);
        start.Environment["POWERSHELL_TELEMETRY_OPTOUT"] = "1";
        return start;
    }

    private static ProcessResult Run(ProcessStartInfo start, int timeoutSeconds, string label)
    {
        using var process = Process.Start(start) ?? throw new System.ComponentModel.Win32Exception($"{label} did not start.");
        var stdout = process.StandardOutput.ReadToEndAsync();
        var stderr = process.StandardError.ReadToEndAsync();
        if (!process.WaitForExit(timeoutSeconds * 1000))
        {
            process.Kill(true);
            throw new QueryException(14, "adapter-failure", $"{label} timed out.");
        }
        Task.WaitAll(stdout, stderr);
        return new ProcessResult(process.ExitCode, stdout.Result, stderr.Result);
    }

    private static string FindExecutable(string name)
    {
        var executable = OperatingSystem.IsWindows() ? $"{name}.exe" : name;
        foreach (var directory in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(Path.PathSeparator))
        {
            if (string.IsNullOrWhiteSpace(directory)) continue;
            var candidate = Path.Combine(directory.Trim('"'), executable);
            if (File.Exists(candidate)) return Path.GetFullPath(candidate);
        }
        throw new System.ComponentModel.Win32Exception($"{name} is unavailable.");
    }

    private static JsonDocument ReadDocument(string path, string label)
    {
        try { return JsonDocument.Parse(File.ReadAllBytes(path), new JsonDocumentOptions { AllowTrailingCommas = false, CommentHandling = JsonCommentHandling.Disallow }); }
        catch (Exception ex) when (ex is JsonException or IOException) { throw Integrity($"{label} is invalid: {ex.Message}"); }
    }

    private static string RequiredString(JsonElement root, string name, string label)
    {
        if (!root.TryGetProperty(name, out var value) || value.ValueKind != JsonValueKind.String || string.IsNullOrWhiteSpace(value.GetString()))
            throw Integrity($"{label} has no valid {name}.");
        return value.GetString()!;
    }

    private static string ResolveDirectory(string value, string label)
    {
        string full;
        try { full = Path.TrimEndingDirectorySeparator(Path.GetFullPath(value)); }
        catch (Exception ex) { throw Unsafe($"{label} is invalid: {ex.Message}"); }
        if (!Directory.Exists(full)) throw Invalid($"{label} does not exist: {full}");
        EnsureNoLinks(Path.GetPathRoot(full)!, full, label);
        return full;
    }

    private static string ResolveDirectoryUnder(string root, string relative, string label)
    {
        var normalized = ValidateRelative(relative, label);
        var full = Path.GetFullPath(Path.Combine(root, normalized.Replace('/', Path.DirectorySeparatorChar)));
        if (!IsUnder(full, root) || !Directory.Exists(full)) throw Unsafe($"{label} escapes its root or is missing.");
        EnsureNoLinks(root, full, label);
        return full;
    }

    private static string ResolveFileUnder(string root, string relative, string label)
    {
        var normalized = ValidateRelative(NormalizeRelative(relative), label);
        var full = Path.GetFullPath(Path.Combine(root, normalized.Replace('/', Path.DirectorySeparatorChar)));
        if (!IsUnder(full, root) || !File.Exists(full)) throw Unsafe($"{label} escapes its root or is missing.");
        EnsureNoLinks(root, full, label);
        return full;
    }

    private static string ValidateRelative(string value, string label)
    {
        if (string.IsNullOrWhiteSpace(value) || Path.IsPathRooted(value) || Regex.IsMatch(value, "^[A-Za-z]:", RegexOptions.CultureInvariant))
            throw Unsafe($"{label} must be relative.");
        var normalized = NormalizeRelative(value);
        if (normalized.Split('/').Any(segment => segment is "" or "." or "..") || normalized.Contains('*') || normalized.Contains('?'))
            throw Unsafe($"{label} contains traversal, an empty segment or a wildcard.");
        return normalized;
    }

    private static void EnsureNoLinks(string root, string path, string label)
    {
        FileSystemInfo? current = File.Exists(path) ? new FileInfo(path) : new DirectoryInfo(path);
        while (current is not null && IsUnder(current.FullName, root))
        {
            if ((current.Attributes & FileAttributes.ReparsePoint) != 0 || current.LinkTarget is not null)
                throw Unsafe($"{label} crosses a link or reparse point: {current.FullName}");
            if (PathEquals(current.FullName, root)) break;
            current = current is FileInfo file ? file.Directory : ((DirectoryInfo)current).Parent;
        }
    }

    private static string ValidateHashId(string value, string label) => HashIdPattern.IsMatch(value) ? value : throw Invalid($"{label} is invalid.");
    private static string NormalizeRelative(string value) => value.Replace('\\', '/');
    private static string HashFile(string path) => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path))).ToLowerInvariant();
    private static string HashText(string text) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(text))).ToLowerInvariant();
    private static bool Overlaps(string left, string right) => IsUnder(left, right) || IsUnder(right, left);
    private static bool IsUnder(string path, string root)
    {
        var relative = Path.GetRelativePath(root, path);
        return relative == "." || (!Path.IsPathRooted(relative) && relative != ".." && !relative.StartsWith($"..{Path.DirectorySeparatorChar}", StringComparison.Ordinal));
    }
    private static bool PathEquals(string left, string right) => string.Equals(Path.GetFullPath(left), Path.GetFullPath(right), PathComparison());
    private static StringComparison PathComparison() => OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal;

    private static int Error(int code, string category, string message)
    {
        Console.Error.WriteLine(JsonSerializer.Serialize(new { formatVersion = 1, status = "error", command = "query", exitCategory = category, message }, JsonOptions));
        return code;
    }
    private static QueryException Invalid(string message) => new(10, "invalid-input", message);
    private static QueryException Unsafe(string message) => new(11, "unsafe-path", message);
    private static QueryException Integrity(string message) => new(12, "integrity-failure", message);
    private static QueryException Conflict(string message) => new(17, "state-conflict", message);

    private sealed record QueryOutcome(string PackageRoot, string SchemaId, object Document);
    private sealed record QueryRoots(string PackageRoot, string? TargetRoot, string StateRoot, string EvidenceRoot);
    private sealed record ProcessResult(int ExitCode, string Output, string Error);
    private sealed record StateDocument(int FormatVersion, ProjectInstance[] ProjectInstances, JsonElement[] Transactions, JsonElement[] ResetReceipts);
    private sealed record ProjectInstance(string Id, string TargetCanonicalPath, string TargetIdentityHash, string ProfileId, string[] ClaimedStatePaths, string[] ClaimedEvidencePaths);

    private sealed record Arguments(string Operation, Dictionary<string, string> Values)
    {
        public string Required(string name) => Values.TryGetValue(name, out var value) && !string.IsNullOrWhiteSpace(value)
            ? value : throw Invalid($"Missing --{name}.");
        public void RequireOnly(params string[] names)
        {
            var known = new HashSet<string>(names, StringComparer.Ordinal);
            var unknown = Values.Keys.FirstOrDefault(name => !known.Contains(name));
            if (unknown is not null) throw Invalid($"Unknown argument: --{unknown}");
            foreach (var name in names) Required(name);
        }
    }

    private sealed class QueryException(int code, string category, string message) : Exception(message)
    {
        public int Code { get; } = code;
        public string Category { get; } = category;
    }
}
