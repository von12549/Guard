using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace V4.Guards.Host;

internal static class StageRuntime
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true
    };

    private static readonly string[] StageNames = ["bootstrap", "analysis", "pre", "post"];

    public static int Execute(string[] args)
    {
        StageContext? context = null;
        try
        {
            var options = ParseArguments(args);
            var roots = ResolveRoots(options);
            var package = ValidatePackage(roots.PackageRoot);
            var profile = LoadProfile(roots.PackageRoot, options.Profile);
            var binding = StateRuntime.BindForStage(roots.PackageRoot, roots.TargetRoot, roots.StateRoot, roots.EvidenceRoot, profile.Id);
            var runId = Guid.NewGuid().ToString("N");
            var requestedIndex = Array.IndexOf(StageNames, options.Stage);
            var executionStages = options.WithDependencies ? StageNames[..(requestedIndex + 1)] : [options.Stage];
            context = new StageContext(runId, options.Stage, executionStages, [], binding.ProjectId, roots, package, profile);
            var result = RunStage(context);
            WriteResult(context, result);
            WriteConsole(result, result.ExitCategory == "success");
            return ExitCode(result.ExitCategory);
        }
        catch (StageException ex)
        {
            if (context is not null)
            {
                var result = ErrorResult(context, ex.Category, ex.Message);
                try { WriteResult(context, result); } catch { }
                WriteConsole(result, false);
            }
            else
            {
                Console.Error.WriteLine(JsonSerializer.Serialize(new { formatVersion = 1, status = "error", exitCategory = ex.Category, message = ex.Message }, JsonOptions));
            }
            return ex.Code;
        }
        catch (StateRuntime.StateException ex)
        {
            Console.Error.WriteLine(JsonSerializer.Serialize(new { formatVersion = 1, status = "error", exitCategory = ex.Category, message = ex.Message }, JsonOptions));
            return ex.Code;
        }
        catch (Exception ex)
        {
            if (context is not null)
            {
                var result = ErrorResult(context, "internal-error", ex.Message);
                try { WriteResult(context, result); } catch { }
                WriteConsole(result, false);
            }
            else
            {
                Console.Error.WriteLine(JsonSerializer.Serialize(new { formatVersion = 1, status = "error", exitCategory = "internal-error", message = ex.Message }, JsonOptions));
            }
            return 19;
        }
    }

    private static StageOptions ParseArguments(string[] args)
    {
        if (args.Length < 2 || args[0] != "stage" || args[1] != "run")
            throw new StageException(10, "invalid-input", "Expected 'stage run'.");
        var values = new Dictionary<string, string>(StringComparer.Ordinal);
        var withDependencies = false;
        for (var index = 2; index < args.Length;)
        {
            if (args[index] == "--with-dependencies")
            {
                if (withDependencies) throw new StageException(10, "invalid-input", "Duplicate argument: --with-dependencies");
                withDependencies = true;
                index++;
                continue;
            }
            if (index + 1 >= args.Length || !args[index].StartsWith("--", StringComparison.Ordinal))
                throw new StageException(10, "invalid-input", "Arguments must be --name value pairs.");
            if (!values.TryAdd(args[index][2..], args[index + 1]))
                throw new StageException(10, "invalid-input", $"Duplicate argument: {args[index]}");
            index += 2;
        }

        var known = new HashSet<string>(["stage", "package-root", "target-root", "state-root", "evidence-root", "profile"], StringComparer.Ordinal);
        var unknown = values.Keys.FirstOrDefault(key => !known.Contains(key));
        if (unknown is not null) throw new StageException(10, "invalid-input", $"Unknown argument: --{unknown}");
        string Required(string name) => values.TryGetValue(name, out var value) && !string.IsNullOrWhiteSpace(value)
            ? value : throw new StageException(10, "invalid-input", $"Missing --{name}.");
        var stage = Required("stage");
        if (!StageNames.Contains(stage, StringComparer.Ordinal))
            throw new StageException(10, "invalid-input", "Stage must be bootstrap, analysis, pre or post.");
        return new StageOptions(stage, Required("package-root"), Required("target-root"), Required("state-root"),
            Required("evidence-root"), Required("profile"), withDependencies);
    }

    private static StageRoots ResolveRoots(StageOptions options)
    {
        var roots = new StageRoots(
            ResolveDirectory(options.PackageRoot, "PackageRoot"),
            ResolveDirectory(options.TargetRoot, "TargetRoot"),
            ResolveDirectory(options.StateRoot, "StateRoot"),
            ResolveDirectory(options.EvidenceRoot, "EvidenceRoot"));
        foreach (var mutable in new[] { ("StateRoot", roots.StateRoot), ("EvidenceRoot", roots.EvidenceRoot) })
        {
            if (Overlaps(mutable.Item2, roots.PackageRoot)) throw new StageException(11, "unsafe-path", $"{mutable.Item1} overlaps PackageRoot.");
            if (Overlaps(mutable.Item2, roots.TargetRoot)) throw new StageException(11, "unsafe-path", $"{mutable.Item1} overlaps TargetRoot.");
        }
        if (Overlaps(roots.StateRoot, roots.EvidenceRoot)) throw new StageException(11, "unsafe-path", "StateRoot and EvidenceRoot overlap.");
        return roots;
    }

    private static string ResolveDirectory(string value, string label)
    {
        string full;
        try { full = Path.TrimEndingDirectorySeparator(Path.GetFullPath(value)); }
        catch (Exception ex) { throw new StageException(11, "unsafe-path", $"{label} is invalid: {ex.Message}"); }
        if (!Directory.Exists(full)) throw new StageException(10, "invalid-input", $"{label} does not exist: {full}");
        EnsureNoLinks(Path.GetPathRoot(full)!, full, label);
        return full;
    }

    private static PackageValidation ValidatePackage(string packageRoot)
    {
        var checker = ResolveFileUnder(packageRoot, "core/runtime/Test-V4Package.ps1", "package checker");
        var executable = FindPowerShell();
        var start = PowerShellStart(executable, checker);
        start.ArgumentList.Add("-PackageRoot");
        start.ArgumentList.Add(packageRoot);
        var execution = RunProcess(start, 120, "package checker");
        if (execution.ExitCode != 0)
            throw new StageException(12, "integrity-failure", $"Package authority validation failed: {execution.Error.Trim()}");
        try
        {
            var result = JsonSerializer.Deserialize<PackageValidation>(execution.Output, JsonOptions)
                ?? throw new JsonException("Package result is empty.");
            if (result.FormatVersion != 1 || result.Status != "pass" || !IsHash(result.PackageHash))
                throw new JsonException("Package result identity is invalid.");
            return result;
        }
        catch (JsonException ex)
        {
            throw new StageException(12, "integrity-failure", $"Package checker output is invalid: {ex.Message}");
        }
    }

    private static ProfileDocument LoadProfile(string packageRoot, string profileId)
    {
        if (!System.Text.RegularExpressions.Regex.IsMatch(profileId, "^[a-z][a-z0-9_-]*$", System.Text.RegularExpressions.RegexOptions.CultureInvariant))
            throw new StageException(10, "invalid-input", "Profile ID is invalid.");
        var path = ResolveFileUnder(packageRoot, Path.Combine("profiles", "catalog", profileId, "profile.json"), "profile");
        try
        {
            var profile = JsonSerializer.Deserialize<ProfileDocument>(File.ReadAllText(path), JsonOptions)
                ?? throw new JsonException("Profile is empty.");
            if (profile.FormatVersion != 1 || profile.Id != profileId || string.IsNullOrWhiteSpace(profile.Version) ||
                profile.StageConfiguration is null || !StageNames.All(profile.StageConfiguration.ContainsKey))
                throw new JsonException("Profile identity or Stage configuration is invalid.");
            return profile with { Sha256 = HashFile(path), ProfileDirectory = Path.GetDirectoryName(path) };
        }
        catch (Exception ex) when (ex is JsonException or IOException)
        {
            throw new StageException(12, "integrity-failure", $"Profile is invalid: {ex.Message}");
        }
    }

    private static StageResult RunStage(StageContext context)
    {
        var authorityHashes = new Dictionary<string, string>(StringComparer.Ordinal)
        {
            ["package"] = context.Package.PackageHash,
            ["profile"] = context.Profile.Sha256!,
            ["registry"] = HashFile(ResolveFileUnder(context.Roots.PackageRoot, "modules/registry.json", "module registry")),
            ["contractsManifest"] = HashFile(ResolveFileUnder(context.Roots.PackageRoot, "core/contracts/contracts-manifest.json", "contracts manifest"))
        };
        var moduleResults = new List<ModuleResult>();
        var findings = new List<Finding>();
        var findingKeys = new HashSet<string>(StringComparer.Ordinal);
        var coverage = new List<Coverage>();
        var baselineKeys = LoadBaselines(context, authorityHashes);
        var registry = ReadJson<RegistryDocument>(ResolveFileUnder(context.Roots.PackageRoot, "modules/registry.json", "module registry"), "module registry");
        var executedStages = context.AttemptedStages;
        foreach (var executionStage in context.ExecutionStages)
        {
            executedStages.Add(executionStage);
            var stageConfig = context.Profile.StageConfiguration![executionStage];
            if (!stageConfig.Enabled) continue;
            foreach (var moduleId in stageConfig.Modules ?? [])
            {
                var entry = registry.Modules?.SingleOrDefault(item => item.Id == moduleId)
                    ?? throw new StageException(12, "integrity-failure", $"Profile module is not registered: {moduleId}");
                var manifestPath = ResolveFileUnder(context.Roots.PackageRoot, entry.ManifestPath!, $"module {moduleId} manifest");
                if (!string.Equals(HashFile(manifestPath), entry.ManifestSha256, StringComparison.Ordinal))
                    throw new StageException(12, "integrity-failure", $"Module manifest hash drift: {moduleId}");
                var manifest = ReadJson<ModuleDocument>(manifestPath, $"module {moduleId}");
                if (manifest.Id != moduleId || manifest.Stages is null || !manifest.Stages.Contains(executionStage, StringComparer.Ordinal) || manifest.Adapter is null)
                    throw new StageException(12, "integrity-failure", $"Module does not support {executionStage}: {moduleId}");
                authorityHashes[$"module.{moduleId}"] = entry.ManifestSha256!;
                ValidateModuleEnvironment(manifest);

                var adapterPath = ResolveFileUnder(context.Roots.PackageRoot, manifest.Adapter.Path!, $"module {moduleId} adapter");
                if (!string.Equals(HashFile(adapterPath), manifest.Adapter.Sha256, StringComparison.Ordinal))
                    throw new StageException(12, "integrity-failure", $"Adapter hash drift: {moduleId}");
                authorityHashes[$"adapter.{moduleId}"] = manifest.Adapter.Sha256!;

                var selection = context.Profile.ModuleSelections?.SingleOrDefault(item => item.Id == moduleId)
                    ?? throw new StageException(12, "integrity-failure", $"Profile configuration is missing for module: {moduleId}");
                var adapterResult = RunAdapter(context, executionStage, manifest, adapterPath, selection);
                var evidenceRelative = $"runs/{context.RunId}/stages/{executionStage}/modules/{moduleId}.json";
                WriteEvidence(context, evidenceRelative, JsonSerializer.Serialize(adapterResult, JsonOptions) + Environment.NewLine);
                moduleResults.Add(new ModuleResult(moduleId, adapterResult.Status == "error" ? "error" : adapterResult.Status!, evidenceRelative));

                if (adapterResult.Coverage is { Length: > 0 }) coverage.AddRange(adapterResult.Coverage);
                if (adapterResult.Status == "error")
                {
                    if (adapterResult.Coverage is not { Length: > 0 })
                        coverage.Add(new Coverage(moduleId == "synthetic-probe" ? "SYNTHETIC.INPUT" : $"MODULE.{moduleId.ToUpperInvariant().Replace('-', '_')}", 0, 1));
                    var category = AdapterErrorCategory(adapterResult.ExitCategory);
                    AddFinding(findings, findingKeys, baselineKeys,
                        new Finding($"V4.MODULE.{moduleId.ToUpperInvariant().Replace('-', '_')}", adapterResult.Message ?? $"Module {moduleId} failed.", "runtime", moduleId, "blocking"));
                    return Result(context, "error", category, executedStages, authorityHashes, moduleResults, findings, coverage);
                }
                if (adapterResult.Status is not ("pass" or "fail") || adapterResult.Findings.ValueKind != JsonValueKind.Array)
                    throw new StageException(14, "adapter-failure", $"Adapter result is invalid: {moduleId}");

                var rulePlan = LoadRulePlan(context, executionStage, manifest, selection, authorityHashes);
                if (rulePlan is not null && ((adapterResult.Status == "pass" && adapterResult.ExitCategory != "success") ||
                    (adapterResult.Status == "fail" && (adapterResult.ExitCategory != "findings-blocking" || adapterResult.Findings.GetArrayLength() == 0))))
                    throw new StageException(14, "adapter-failure", $"Adapter status/category pair is invalid: {moduleId}");
                foreach (var item in adapterResult.Findings.EnumerateArray())
                {
                    if (item.ValueKind == JsonValueKind.String)
                        AddFinding(findings, findingKeys, baselineKeys, new Finding(item.GetString()!, "input.txt", "source-syntax", moduleId, "blocking"));
                    else
                    {
                        var finding = item.Deserialize<Finding>(JsonOptions) ?? throw new StageException(14, "adapter-failure", $"Adapter finding is invalid: {moduleId}");
                        if (rulePlan is not null)
                        {
                            if (!rulePlan.TryGetValue(finding.RuleId, out var rule) ||
                                !(rule.Detectors ?? []).Contains(finding.DetectorId, StringComparer.Ordinal) ||
                                !(rule.EvidenceKinds ?? []).Contains(finding.EvidenceKind, StringComparer.Ordinal))
                                throw new StageException(14, "adapter-failure", $"Finding is not authorized by the rule execution plan: {finding.RuleId}");
                            finding = finding with { Severity = rule.Severity! };
                        }
                        AddFinding(findings, findingKeys, baselineKeys, finding);
                    }
                }
                if (adapterResult.Coverage is not { Length: > 0 }) coverage.Add(new Coverage("SYNTHETIC.INPUT", 1, 1));
                if (rulePlan is not null)
                {
                    foreach (var rule in rulePlan.Values)
                    {
                        var entries = coverage.Where(item => item.ClaimId == rule.ClaimId).ToArray();
                        var matched = entries.Sum(item => item.Matched);
                        if (entries.Length != 1 || matched < rule.MinimumMatches)
                            AddFinding(findings, findingKeys, baselineKeys,
                                new Finding(rule.RuleId!, $"{rule.ClaimId}: matched {matched}, minimum {rule.MinimumMatches}", "coverage", "v4-host", rule.Severity!));
                    }
                }
            }
            if (findings.Any(item => item.Severity == "blocking"))
                return Result(context, "fail", "findings-blocking", executedStages, authorityHashes, moduleResults, findings, coverage);
        }
        return Result(context, findings.Count > 0 ? "advisory" : "pass", "success", executedStages, authorityHashes, moduleResults, findings, coverage);
    }

    private static HashSet<string> LoadBaselines(StageContext context, Dictionary<string, string> authorityHashes)
    {
        var keys = new HashSet<string>(StringComparer.Ordinal);
        foreach (var reference in context.Profile.BaselineRefs ?? [])
        {
            var path = ResolveFileUnder(context.Profile.ProfileDirectory!, reference, $"profile baseline {reference}");
            var baseline = ReadJson<FindingBaseline>(path, $"profile baseline {reference}");
            if (baseline.FormatVersion != 1 || baseline.Findings is null)
                throw new StageException(12, "integrity-failure", $"Profile baseline is invalid: {reference}");
            authorityHashes[$"baseline.{reference.Replace('/', '.').Replace('\\', '.')}"] = HashFile(path);
            foreach (var finding in baseline.Findings)
            {
                if (string.IsNullOrWhiteSpace(finding.RuleId) || string.IsNullOrWhiteSpace(finding.Subject) ||
                    string.IsNullOrWhiteSpace(finding.EvidenceKind) || string.IsNullOrWhiteSpace(finding.DetectorId) ||
                    !keys.Add(FindingKey(finding.RuleId, finding.Subject, finding.EvidenceKind, finding.DetectorId)))
                    throw new StageException(12, "integrity-failure", $"Profile baseline has an invalid or duplicate finding: {reference}");
            }
        }
        return keys;
    }

    private static Dictionary<string, RulePlanEntry>? LoadRulePlan(StageContext context, string stage, ModuleDocument manifest,
        ModuleSelection selection, Dictionary<string, string> authorityHashes)
    {
        var authority = manifest.Authorities?.SingleOrDefault(item => item.Id == "rule-execution-plan");
        if (authority is null) return null;
        var path = ResolveFileUnder(context.Roots.PackageRoot, authority.Path!, $"module {manifest.Id} rule execution plan");
        if (!string.Equals(HashFile(path), authority.Sha256, StringComparison.Ordinal))
            throw new StageException(12, "integrity-failure", $"Rule execution plan hash drift: {manifest.Id}");
        authorityHashes[$"authority.{manifest.Id}.rule-execution-plan"] = authority.Sha256!;
        var plan = ReadJson<RuleExecutionPlan>(path, $"module {manifest.Id} rule execution plan");
        if (plan.FormatVersion != 1 || plan.ModuleId != manifest.Id || plan.Rules is null)
            throw new StageException(12, "integrity-failure", $"Rule execution plan identity is invalid: {manifest.Id}");
        var enabledClaims = new HashSet<string>(StringComparer.Ordinal);
        if (selection.Config.TryGetProperty("enabledClaims", out var configuredClaims) && configuredClaims.ValueKind == JsonValueKind.Array)
            foreach (var claim in configuredClaims.EnumerateArray()) if (claim.ValueKind == JsonValueKind.String) enabledClaims.Add(claim.GetString()!);
        var selectedRules = new HashSet<string>(context.Profile.Rules ?? [], StringComparer.Ordinal);
        var result = new Dictionary<string, RulePlanEntry>(StringComparer.Ordinal);
        foreach (var rule in plan.Rules.Where(item => item.Stage == stage && enabledClaims.Contains(item.ClaimId!) && selectedRules.Contains(item.RuleId!)))
        {
            if (string.IsNullOrWhiteSpace(rule.RuleId) || string.IsNullOrWhiteSpace(rule.ClaimId) || rule.MinimumMatches < 1 ||
                string.IsNullOrWhiteSpace(rule.Severity) || !result.TryAdd(rule.RuleId, rule))
                throw new StageException(12, "integrity-failure", $"Rule execution plan has an invalid or duplicate rule: {manifest.Id}");
        }
        if (enabledClaims.Any(claim => plan.Rules.Any(rule => rule.Stage == stage && rule.ClaimId == claim) &&
            !result.Values.Any(rule => rule.ClaimId == claim)))
            throw new StageException(12, "integrity-failure", $"Profile rules do not select every enabled {stage} claim: {manifest.Id}");
        return result;
    }

    private static void AddFinding(List<Finding> findings, HashSet<string> findingKeys, HashSet<string> baselineKeys, Finding finding)
    {
        if (string.IsNullOrWhiteSpace(finding.RuleId) || string.IsNullOrWhiteSpace(finding.Subject) ||
            string.IsNullOrWhiteSpace(finding.EvidenceKind) || string.IsNullOrWhiteSpace(finding.DetectorId))
            throw new StageException(14, "adapter-failure", "A finding has an incomplete layered identity.");
        var key = FindingKey(finding.RuleId, finding.Subject, finding.EvidenceKind, finding.DetectorId);
        if (!findingKeys.Add(key)) return;
        findings.Add(baselineKeys.Contains(key) ? finding with { Severity = "advisory" } : finding);
    }

    private static string FindingKey(string ruleId, string subject, string evidenceKind, string detectorId) =>
        $"{ruleId}\n{subject}\n{evidenceKind}\n{detectorId}";

    private static string AdapterErrorCategory(string? category) => category switch
    {
        "invalid-input" or "unsafe-path" or "integrity-failure" or "capability-denied" or "adapter-failure" or
        "prerequisite-missing" or "state-conflict" or "internal-error" => category,
        _ => "adapter-failure"
    };

    private static void ValidateModuleEnvironment(ModuleDocument manifest)
    {
        var platform = CurrentPlatform();
        if (manifest.SupportedPlatforms is null || !manifest.SupportedPlatforms.Contains(platform, StringComparer.Ordinal))
            throw new StageException(15, "prerequisite-missing", $"Module {manifest.Id} does not support platform {platform}.");
        foreach (var prerequisite in manifest.Prerequisites ?? [])
        {
            if (string.IsNullOrWhiteSpace(prerequisite.Runtime) || FindExecutable(prerequisite.Runtime) is null)
                throw new StageException(15, "prerequisite-missing", $"Module {manifest.Id} runtime is unavailable: {prerequisite.Runtime}");
        }
    }

    private static string CurrentPlatform()
    {
        var architecture = RuntimeInformation.OSArchitecture switch
        {
            Architecture.X64 => "x64",
            Architecture.Arm64 => "arm64",
            _ => RuntimeInformation.OSArchitecture.ToString().ToLowerInvariant()
        };
        var system = OperatingSystem.IsWindows() ? "win" : OperatingSystem.IsLinux() ? "linux" : OperatingSystem.IsMacOS() ? "osx" : "unknown";
        return $"{system}-{architecture}";
    }

    private static string? FindExecutable(string runtime)
    {
        var name = OperatingSystem.IsWindows() ? $"{runtime}.exe" : runtime;
        foreach (var directory in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(Path.PathSeparator))
        {
            if (string.IsNullOrWhiteSpace(directory)) continue;
            var candidate = Path.Combine(directory.Trim('"'), name);
            if (File.Exists(candidate)) return Path.GetFullPath(candidate);
        }
        return null;
    }

    private static AdapterResult RunAdapter(StageContext context, string executionStage, ModuleDocument manifest, string adapterPath, ModuleSelection selection)
    {
        if (manifest.Adapter?.Kind != "powershell" || manifest.Capabilities is null || manifest.Capabilities.Network ||
            !(manifest.Capabilities.Processes ?? []).Contains("pwsh", StringComparer.Ordinal) || manifest.Capabilities.TimeoutSeconds < 1)
            throw new StageException(13, "capability-denied", $"Module capability grant is not executable: {manifest.Id}");
        var start = PowerShellStart(FindPowerShell(), adapterPath);
        var input = JsonSerializer.Serialize(new
        {
            formatVersion = 1,
            stage = executionStage,
            targetRoot = context.Roots.TargetRoot,
            packageRoot = context.Roots.PackageRoot,
            stateRoot = context.Roots.StateRoot,
            evidenceRoot = context.Roots.EvidenceRoot,
            projectId = context.ProjectId,
            runId = context.RunId,
            config = selection.Config
        });
        start.Environment["V4_STAGE_INPUT_JSON"] = input;
        var execution = RunProcess(start, manifest.Capabilities.TimeoutSeconds, $"module {manifest.Id}");
        if (execution.ExitCode != 0)
            throw new StageException(14, "adapter-failure", $"Adapter exited {execution.ExitCode}: {execution.Error.Trim()}");
        try
        {
            var result = JsonSerializer.Deserialize<AdapterResult>(execution.Output, JsonOptions)
                ?? throw new JsonException("Adapter result is empty.");
            if (result.FormatVersion != 1) throw new JsonException("Adapter result version is invalid.");
            return result;
        }
        catch (JsonException ex)
        {
            throw new StageException(14, "adapter-failure", $"Adapter output is invalid: {ex.Message}");
        }
    }

    private static ProcessStartInfo PowerShellStart(string executable, string script)
    {
        var start = new ProcessStartInfo(executable)
        {
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true
        };
        start.ArgumentList.Add("-NoLogo");
        start.ArgumentList.Add("-NoProfile");
        start.ArgumentList.Add("-NonInteractive");
        start.ArgumentList.Add("-File");
        start.ArgumentList.Add(script);
        start.Environment["POWERSHELL_TELEMETRY_OPTOUT"] = "1";
        return start;
    }

    private static ProcessResult RunProcess(ProcessStartInfo start, int timeoutSeconds, string label)
    {
        using var process = Process.Start(start) ?? throw new StageException(14, "adapter-failure", $"{label} did not start.");
        var stdout = process.StandardOutput.ReadToEndAsync();
        var stderr = process.StandardError.ReadToEndAsync();
        if (!process.WaitForExit(timeoutSeconds * 1000))
        {
            process.Kill(true);
            throw new StageException(14, "adapter-failure", $"{label} timed out.");
        }
        Task.WaitAll(stdout, stderr);
        return new ProcessResult(process.ExitCode, stdout.Result, stderr.Result);
    }

    private static string FindPowerShell()
    {
        var executableName = OperatingSystem.IsWindows() ? "pwsh.exe" : "pwsh";
        foreach (var directory in (Environment.GetEnvironmentVariable("PATH") ?? "").Split(Path.PathSeparator))
        {
            if (string.IsNullOrWhiteSpace(directory)) continue;
            var candidate = Path.Combine(directory.Trim('"'), executableName);
            if (File.Exists(candidate)) return Path.GetFullPath(candidate);
        }
        throw new StageException(15, "prerequisite-missing", "PowerShell 7 is not available.");
    }

    private static T ReadJson<T>(string path, string label)
    {
        try { return JsonSerializer.Deserialize<T>(File.ReadAllText(path), JsonOptions) ?? throw new JsonException($"{label} is empty."); }
        catch (Exception ex) when (ex is JsonException or IOException) { throw new StageException(12, "integrity-failure", $"{label} is invalid: {ex.Message}"); }
    }

    private static string ResolveFileUnder(string root, string relative, string label)
    {
        if (string.IsNullOrWhiteSpace(relative) || Path.IsPathRooted(relative))
            throw new StageException(11, "unsafe-path", $"The {label} path must be relative.");
        var full = Path.GetFullPath(Path.Combine(root, relative));
        if (!IsUnder(full, root) || !File.Exists(full))
            throw new StageException(11, "unsafe-path", $"The {label} path escapes PackageRoot or is missing.");
        EnsureNoLinks(root, full, label);
        return full;
    }

    private static void WriteResult(StageContext context, StageResult result) =>
        WriteEvidence(context, $"runs/{context.RunId}/stage-result.json", JsonSerializer.Serialize(result, JsonOptions) + Environment.NewLine);

    private static void WriteEvidence(StageContext context, string relative, string content)
    {
        var projectRoot = Path.Combine(context.Roots.EvidenceRoot, "projects", context.ProjectId);
        var destination = Path.GetFullPath(Path.Combine(projectRoot, relative));
        if (!IsUnder(destination, projectRoot)) throw new StageException(11, "unsafe-path", "Stage evidence escapes the project claim.");
        Directory.CreateDirectory(Path.GetDirectoryName(destination)!);
        EnsureNoLinks(context.Roots.EvidenceRoot, Path.GetDirectoryName(destination)!, "Stage evidence");
        var temporary = Path.Combine(Path.GetDirectoryName(destination)!, $".{Guid.NewGuid():N}.tmp");
        File.WriteAllText(temporary, content, new UTF8Encoding(false));
        File.Move(temporary, destination, true);
    }

    private static StageResult Result(StageContext context, string status, string category, List<string> executedStages, Dictionary<string, string> hashes,
        List<ModuleResult> modules, List<Finding> findings, List<Coverage> coverage) =>
        new(1, context.RunId, context.Stage, status, category, executedStages,
            new ProfileResult(context.Profile.Id, context.Profile.Version, context.Profile.Sha256!), context.Roots,
            hashes, modules, findings, coverage);

    private static StageResult ErrorResult(StageContext context, string category, string message) =>
        Result(context, "error", category, context.AttemptedStages.Count == 0 ? [context.Stage] : [.. context.AttemptedStages],
            new Dictionary<string, string>(StringComparer.Ordinal) { ["package"] = context.Package.PackageHash, ["profile"] = context.Profile.Sha256! },
            [], [new Finding("V4.RUNTIME", message, "runtime", "v4-host", "blocking")], []);

    private static void WriteConsole(StageResult result, bool success)
    {
        var json = JsonSerializer.Serialize(result, JsonOptions);
        if (success) Console.WriteLine(json); else Console.Error.WriteLine(json);
    }

    private static int ExitCode(string category) => category switch
    {
        "success" => 0, "invalid-input" => 10, "unsafe-path" => 11, "integrity-failure" => 12,
        "capability-denied" => 13, "adapter-failure" => 14, "prerequisite-missing" => 15,
        "findings-blocking" => 16, "state-conflict" => 17, "reset-refused" => 18, _ => 19
    };

    private static string HashFile(string path) => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path))).ToLowerInvariant();
    private static bool IsHash(string? value) => value is { Length: 64 } && value.All(character => character is >= '0' and <= '9' or >= 'a' and <= 'f');
    private static bool Overlaps(string left, string right) => IsUnder(left, right) || IsUnder(right, left);
    private static bool IsUnder(string path, string root)
    {
        var relative = Path.GetRelativePath(root, path);
        return relative == "." || (!Path.IsPathRooted(relative) && relative != ".." && !relative.StartsWith($"..{Path.DirectorySeparatorChar}", StringComparison.Ordinal));
    }

    private static void EnsureNoLinks(string root, string path, string label)
    {
        var current = File.Exists(path) ? new FileInfo(path) as FileSystemInfo : new DirectoryInfo(path);
        while (current is not null && IsUnder(current.FullName, root))
        {
            if ((current.Attributes & FileAttributes.ReparsePoint) != 0 || current.LinkTarget is not null)
                throw new StageException(11, "unsafe-path", $"{label} crosses a link or reparse point: {current.FullName}");
            if (string.Equals(Path.GetFullPath(current.FullName), Path.GetFullPath(root), OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal)) break;
            current = current is FileInfo file ? file.Directory : ((DirectoryInfo)current).Parent;
        }
    }

    private sealed record StageOptions(string Stage, string PackageRoot, string TargetRoot, string StateRoot, string EvidenceRoot, string Profile, bool WithDependencies);
    private sealed record StageContext(string RunId, string Stage, string[] ExecutionStages, List<string> AttemptedStages, string ProjectId, StageRoots Roots, PackageValidation Package, ProfileDocument Profile);
    private sealed record ProcessResult(int ExitCode, string Output, string Error);
    private sealed record PackageValidation(int FormatVersion, string? Status, string PackageHash, string[]? Profiles, string[]? Modules);
    private sealed record ProfileDocument(int FormatVersion, string Id, string Version, ModuleSelection[]? ModuleSelections,
        Dictionary<string, StageConfiguration>? StageConfiguration, string[]? Rules, string[]? BaselineRefs,
        string? Sha256 = null, string? ProfileDirectory = null);
    private sealed record ModuleSelection(string Id, JsonElement Config);
    private sealed record StageConfiguration(bool Enabled, string[]? Modules);
    private sealed record RegistryDocument(int FormatVersion, RegistryEntry[]? Modules);
    private sealed record RegistryEntry(string Id, string? ManifestPath, string? ManifestSha256);
    private sealed record ModuleDocument(string? Id, string[]? SupportedPlatforms, PrerequisiteDocument[]? Prerequisites,
        AdapterDocument? Adapter, string[]? Stages, CapabilityDocument? Capabilities, AuthorityDocument[]? Authorities);
    private sealed record AdapterDocument(string? Kind, string? Path, string? Sha256);
    private sealed record PrerequisiteDocument(string? Runtime, string? VersionRange);
    private sealed record AuthorityDocument(string? Id, string? Path, string? Sha256);
    private sealed record CapabilityDocument(string[]? Processes, bool Network, int TimeoutSeconds);
    private sealed record AdapterResult(int FormatVersion, string? Status, string? ExitCategory, string? Message, JsonElement Findings, Coverage[]? Coverage);
    private sealed record RuleExecutionPlan(int FormatVersion, string? ModuleId, string? MatrixSha256, RulePlanEntry[]? Rules);
    private sealed record RulePlanEntry(string? RuleId, string? ClaimId, string? Stage, string[]? Detectors,
        string[]? EvidenceKinds, string? Severity, string? Baseline, int MinimumMatches);
    private sealed record FindingBaseline(int FormatVersion, BaselineFinding[]? Findings);
    private sealed record BaselineFinding(string? RuleId, string? Subject, string? EvidenceKind, string? DetectorId);
    private sealed record StageRoots(string PackageRoot, string TargetRoot, string StateRoot, string EvidenceRoot);
    private sealed record ProfileResult(string Id, string Version, string Sha256);
    private sealed record ModuleResult(string ModuleId, string Status, string EvidencePath);
    private sealed record Finding(string RuleId, string Subject, string EvidenceKind, string DetectorId, string Severity);
    private sealed record Coverage(string ClaimId, int Matched, int Minimum);
    private sealed record StageResult(int FormatVersion, string RunId, string Stage, string Status, string ExitCategory, List<string> ExecutedStages,
        ProfileResult Profile, StageRoots Roots, Dictionary<string, string> AuthorityHashes, List<ModuleResult> ModuleResults,
        List<Finding> Findings, List<Coverage> Coverage);

    private sealed class StageException(int code, string category, string message) : Exception(message)
    {
        public int Code { get; } = code;
        public string Category { get; } = category;
    }
}
