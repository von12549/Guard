using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace V4.Guards.Host;

internal static class ApplicationRuntime
{
    private const string ContractRelative = "core/application/contracts/application-service-contract.json";
    private const string ContractSchemaRelative = "core/application/contracts/application-service-contract.schema.json";
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = false,
        WriteIndented = true
    };
    private static readonly JsonSerializerOptions CompactOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = false,
        WriteIndented = false
    };
    private static readonly Regex OperationPattern = new("^(setup|protection|authorities|lifecycle)$", RegexOptions.CultureInvariant);
    private static readonly Regex RelativePathPattern = new("^(?![A-Za-z]:|/|.*(?:^|/)\\.\\.(?:/|$)).+$", RegexOptions.CultureInvariant);

    public static int Execute(string[] args)
    {
        try
        {
            var arguments = Arguments.Parse(args);
            if (arguments.Action != "preview") throw Invalid($"Unknown application action: {arguments.Action}");
            arguments.RequireOnly("operation", "package-root", "target-root", "state-root", "evidence-root", "plan-root");
            var operation = arguments.Required("operation");
            if (!OperationPattern.IsMatch(operation)) throw Invalid("Application operation is not allowlisted.");
            var roots = ResolveRoots(arguments);
            VerifyApplicationContract(roots.PackageRoot);

            var project = QueryRuntime.QueryForApplication([
                "query", "project", "--package-root", roots.PackageRoot, "--target-root", roots.TargetRoot,
                "--state-root", roots.StateRoot, "--evidence-root", roots.EvidenceRoot
            ]);
            var profiles = QueryRuntime.QueryForApplication(["query", "profiles", "--package-root", roots.PackageRoot]);
            var discovery = ProfileRuntime.DiscoverForApplication(roots.PackageRoot, roots.TargetRoot);
            var projectNode = project.GetProperty("project");
            var projectId = projectNode.GetProperty("projectId").GetString()!;
            var targetSnapshot = RequiredString(discovery["target"]!.AsObject(), "snapshotSha256");
            var packageAuthority = PackageAuthorityHash(roots.PackageRoot, profiles);
            var context = new PreviewContext(roots, project, profiles, projectId, targetSnapshot, packageAuthority);
            var payload = operation switch
            {
                "setup" => SetupPayload(context),
                "protection" => ProtectionPayload(context),
                "authorities" => AuthoritiesPayload(context),
                "lifecycle" => LifecyclePayload(context),
                _ => throw Invalid("Application operation is not allowlisted.")
            };
            var operationClass = operation is "setup" or "lifecycle" ? "local-mutable-preview" : "query";
            var previewIdentity = new JsonObject
            {
                ["operation"] = operation,
                ["operationClass"] = operationClass,
                ["projectId"] = projectId,
                ["packageAuthoritySha256"] = packageAuthority,
                ["targetSnapshotSha256"] = targetSnapshot,
                ["payload"] = payload.DeepClone()
            };
            var document = new JsonObject
            {
                ["formatVersion"] = 1,
                ["status"] = "preview",
                ["authority"] = "v4-host",
                ["operation"] = operation,
                ["operationClass"] = operationClass,
                ["projectId"] = projectId,
                ["packageAuthoritySha256"] = packageAuthority,
                ["targetSnapshotSha256"] = targetSnapshot,
                ["previewHash"] = HashText(previewIdentity.ToJsonString(CompactOptions)),
                ["payload"] = payload
            };
            var payloadSchema = operation switch
            {
                "setup" => "setup-preview",
                "protection" => "protection-status",
                "authorities" => "authority-handoff",
                "lifecycle" => "lifecycle-preview",
                _ => throw Invalid("Application operation is not allowlisted.")
            };
            ValidateDocument(roots.PackageRoot, payloadSchema, payload);
            ValidateDocument(roots.PackageRoot, "application-preview", document);
            Console.WriteLine(document.ToJsonString(JsonOptions));
            return 0;
        }
        catch (ApplicationException ex)
        {
            return Error(ex.Code, ex.Category, ex.Message);
        }
        catch (Exception ex)
        {
            return Error(19, "internal-error", ex.Message);
        }
    }

    private static JsonObject SetupPayload(PreviewContext context)
    {
        var protection = BuildProtection(context);
        var project = context.Project.GetProperty("project");
        var bound = project.GetProperty("bound").GetBoolean();
        var profileId = NullableString(project, "profileId");
        var components = protection["components"]!.AsArray().Select(item => item!.AsObject()).ToDictionary(
            item => RequiredString(item, "id"), item => RequiredString(item, "status"), StringComparer.Ordinal);
        JsonObject Step(string id, string operationClass, string state, bool available, string reason) => new()
        {
            ["id"] = id, ["operationClass"] = operationClass, ["state"] = state,
            ["available"] = available, ["reason"] = reason
        };
        return new JsonObject
        {
            ["summary"] = new JsonObject
            {
                ["initialized"] = bound,
                ["profileId"] = profileId,
                ["protected"] = protection["protected"]!.GetValue<bool>(),
                ["applyAvailable"] = false
            },
            ["steps"] = new JsonArray
            {
                Step("initialize", "local-mutable-apply", bound ? "complete" : "incomplete", false,
                    bound ? "The Host project context is initialized." : "Initialization is a separate typed Host operation and is not exposed by M3."),
                Step("profile", "target-trust-change-candidate", components["accepted-non-empty-profile"] == "pass" ? "complete" : "incomplete", false,
                    profileId is null ? "No accepted installed Profile is bound." : "Profile adoption and Target trust change remain separate."),
                Step("composition", "local-mutable-apply", components["verified-immutable-composition"] == "pass" ? "complete" : "unverified", false,
                    "Composition creation and selection are not exposed by M3."),
                Step("prerequisites", "query", components["satisfied-prerequisites"] == "pass" ? "complete" : "incomplete", true,
                    "The Host prerequisite query is available and remains read-only."),
                Step("coverage", "query", components["required-stage-coverage"] == "pass" ? "complete" : "incomplete", true,
                    "Coverage is derived from the exact installed Profile projection."),
                Step("ci-candidate", "target-trust-change-candidate", "not-authorized", false,
                    "CI candidate generation and Target application require a separate implementation Plan."),
                Step("enforcement", "remote-change-candidate", "not-authorized", false,
                    "Workflow/ruleset activation and enforcement certification remain remote authorized operations.")
            }
        };
    }

    private static JsonObject ProtectionPayload(PreviewContext context) => BuildProtection(context);

    private static JsonObject BuildProtection(PreviewContext context)
    {
        var project = context.Project.GetProperty("project");
        var bound = project.GetProperty("bound").GetBoolean();
        var profileId = NullableString(project, "profileId");
        var profile = context.Profiles.GetProperty("profiles").EnumerateArray()
            .SingleOrDefault(item => string.Equals(item.GetProperty("id").GetString(), profileId, StringComparison.Ordinal));
        var profileFound = profile.ValueKind == JsonValueKind.Object;
        var selectedModules = profileFound ? profile.GetProperty("selectedModules").GetArrayLength() : 0;
        var requiredCoverage = profileFound && selectedModules > 0 && HasNonEmptyStage(profile, "pre") && HasNonEmptyStage(profile, "post");
        var nonEmptyProfile = bound && profileFound && profileId != "default" && selectedModules > 0;
        var compositionManifest = Path.Combine(context.Roots.PackageRoot, "provenance", "composition-manifest.json");
        var distributionManifest = Path.Combine(context.Roots.PackageRoot, "distribution-manifest.json");
        var verifiedComposition = File.Exists(compositionManifest) || File.Exists(distributionManifest);
        var prerequisites = false;
        var prerequisiteEvidence = profileId is null ? "No bound Profile exists." : "The Host prerequisite query did not pass.";
        if (profileFound)
        {
            var doctor = QueryRuntime.QueryForApplication(["query", "doctor", "--package-root", context.Roots.PackageRoot, "--profile", profileId!]);
            var report = doctor.GetProperty("report");
            prerequisites = string.Equals(report.GetProperty("status").GetString(), "pass", StringComparison.Ordinal);
            prerequisiteEvidence = $"Host prerequisite report: {report.GetProperty("status").GetString()}.";
        }
        var workflowPath = Path.Combine(context.Roots.TargetRoot, ".github", "workflows", "v4-guards.yml");
        var ciConfigured = File.Exists(workflowPath) && File.ReadAllText(workflowPath).Contains("v4-required", StringComparison.Ordinal);
        JsonObject Component(string id, string status, string evidence) => new()
        {
            ["id"] = id, ["status"] = status, ["evidence"] = evidence, ["required"] = true
        };
        var components = new JsonArray
        {
            Component("initialized-context", bound ? "pass" : "fail", bound ? "Host state binds the exact project identity." : "No Host state binding exists."),
            Component("accepted-non-empty-profile", nonEmptyProfile ? "pass" : "fail", nonEmptyProfile ? $"Installed Profile {profileId} selects {selectedModules} Module(s)." : "The bound Profile is missing, default/no-op, unknown or empty."),
            Component("verified-immutable-composition", verifiedComposition ? "pass" : "unverified", verifiedComposition ? "A validated installed distribution/composition manifest is present." : "This PackageRoot has no installed distribution or composition manifest."),
            Component("satisfied-prerequisites", prerequisites ? "pass" : "fail", prerequisiteEvidence),
            Component("required-stage-coverage", requiredCoverage ? "pass" : "fail", requiredCoverage ? "Installed Profile has non-empty required Pre and Post coverage." : "Required Pre/Post coverage is missing or vacuous."),
            Component("ci-authority-pin", "unverified", ciConfigured ? "A local workflow candidate exists, but no typed proof binds it to this package authority." : "No local v4-required workflow candidate was detected."),
            Component("aggregate-verdict-enforcement", "unverified", "Remote repository policy and positive/negative enforcement certification are not queried by M3.")
        };
        var protectedValue = components.All(item => RequiredString(item!.AsObject(), "status") == "pass");
        return new JsonObject
        {
            ["protected"] = protectedValue,
            ["localRunnable"] = bound && nonEmptyProfile && prerequisites,
            ["ciConfigured"] = ciConfigured,
            ["ciEnforced"] = false,
            ["components"] = components
        };
    }

    private static JsonObject AuthoritiesPayload(PreviewContext context)
    {
        var activeProfile = NullableString(context.Project.GetProperty("project"), "profileId");
        var profiles = new JsonArray();
        foreach (var profile in context.Profiles.GetProperty("profiles").EnumerateArray().OrderBy(item => item.GetProperty("id").GetString(), StringComparer.Ordinal))
        {
            var id = profile.GetProperty("id").GetString()!;
            profiles.Add(Handoff(id, "profile", profile.GetProperty("version").GetString(), profile.GetProperty("sha256").GetString()!,
                id == activeProfile ? "active" : "installed", "profile.inspect", true));
        }
        var plans = new JsonArray();
        if (TryPlanCatalog(context.Roots, out var planCatalog))
        {
            foreach (var plan in planCatalog.GetProperty("plans").EnumerateArray().OrderBy(item => item.GetProperty("id").GetString(), StringComparer.Ordinal))
            {
                var pairHash = HashText($"{plan.GetProperty("jsonSha256").GetString()}\n{plan.GetProperty("markdownSha256").GetString()}\n");
                plans.Add(Handoff(plan.GetProperty("id").GetString()!, "plan", null, pairHash,
                    plan.GetProperty("kind").GetString() == "v3-historical" ? "historical-read-only" : "available", "plan.inspect", true));
            }
        }
        var modules = new JsonArray();
        using var registry = ReadDocument(Path.Combine(context.Roots.PackageRoot, "modules", "registry.json"), "Module registry");
        foreach (var module in registry.RootElement.GetProperty("modules").EnumerateArray().OrderBy(item => item.GetProperty("id").GetString(), StringComparer.Ordinal))
        {
            var manifestPath = ResolveFileUnder(context.Roots.PackageRoot, module.GetProperty("manifestPath").GetString()!, "Module manifest");
            var actualHash = HashFile(manifestPath);
            if (actualHash != module.GetProperty("manifestSha256").GetString()) throw Integrity("Module manifest hash drift.");
            using var manifest = ReadDocument(manifestPath, "Module manifest");
            modules.Add(Handoff(module.GetProperty("id").GetString()!, "module", manifest.RootElement.GetProperty("version").GetString(), actualHash,
                "installed", "module.inspect", true));
        }
        return new JsonObject
        {
            ["profiles"] = profiles,
            ["plans"] = plans,
            ["modules"] = modules,
            ["boundaries"] = new JsonArray("target-adoption", "composition-selection", "ci-activation", "remote-enforcement", "plan-authoring", "module-lifecycle")
        };
    }

    private static JsonObject LifecyclePayload(PreviewContext context)
    {
        using var plugin = ReadDocument(Path.Combine(context.Roots.PackageRoot, "plugin.json"), "plugin manifest");
        var composed = File.Exists(Path.Combine(context.Roots.PackageRoot, "provenance", "composition-manifest.json"));
        var installed = composed || File.Exists(Path.Combine(context.Roots.PackageRoot, "distribution-manifest.json"));
        JsonObject Action(string id, string operationClass, bool available, string effect, string reason) => new()
        {
            ["id"] = id, ["operationClass"] = operationClass, ["available"] = available,
            ["effect"] = effect, ["reason"] = reason
        };
        return new JsonObject
        {
            ["current"] = new JsonObject
            {
                ["productId"] = plugin.RootElement.GetProperty("id").GetString(),
                ["version"] = plugin.RootElement.GetProperty("version").GetString(),
                ["packageAuthoritySha256"] = context.PackageAuthority,
                ["compositionKind"] = composed ? "local-extension-composition" : "base-package",
                ["verified"] = installed
            },
            ["actions"] = new JsonArray
            {
                Action("verify", "query", true, "none", "Current authority identity is available in this preview."),
                Action("compose", "local-mutable-apply", false, "installation-write", "Immutable sibling composition remains a separate explicit operation."),
                Action("select", "local-mutable-apply", false, "selection-change", "Installed selection is not exposed by M3."),
                Action("rollback", "local-mutable-apply", false, "selection-change", "Rollback requires a separately receipted selection operation."),
                Action("retention-preview", "local-mutable-preview", false, "none", "V4-TODO-019 retention preview is not implemented."),
                Action("retention-apply", "local-mutable-apply", false, "deletion", "Deletion requires the retention implementation and explicit acceptance."),
                Action("remote-activation", "remote-change-candidate", false, "remote-change", "Workflow/ruleset activation remains separately authorized.")
            }
        };
    }

    private static JsonObject Handoff(string id, string kind, string? version, string sha256, string state, string nextOperation, bool available) => new()
    {
        ["id"] = id, ["kind"] = kind, ["version"] = version, ["sha256"] = sha256,
        ["state"] = state, ["nextOperation"] = nextOperation, ["available"] = available
    };

    private static bool TryPlanCatalog(Roots roots, out JsonElement catalog)
    {
        catalog = default;
        if (!RelativePathPattern.IsMatch(roots.PlanRoot)) throw Unsafe("Plan root must be a safe relative path.");
        var planDirectory = Path.GetFullPath(Path.Combine(roots.TargetRoot, roots.PlanRoot));
        EnsureUnder(planDirectory, roots.TargetRoot, "Plan root escapes TargetRoot.");
        if (!Directory.Exists(planDirectory)) return false;
        catalog = QueryRuntime.QueryForApplication([
            "query", "plans", "--package-root", roots.PackageRoot, "--target-root", roots.TargetRoot,
            "--plan-root", roots.PlanRoot
        ]);
        return true;
    }

    private static bool HasNonEmptyStage(JsonElement profile, string stage) =>
        profile.GetProperty("stages").EnumerateArray().Any(item => item.GetProperty("stage").GetString() == stage &&
            item.GetProperty("enabled").GetBoolean() && item.GetProperty("modules").GetArrayLength() > 0);

    private static string PackageAuthorityHash(string packageRoot, JsonElement profiles)
    {
        var lines = new List<string>
        {
            $"plugin.json={HashFile(Path.Combine(packageRoot, "plugin.json"))}",
            $"core/contracts/contracts-manifest.json={HashFile(Path.Combine(packageRoot, "core", "contracts", "contracts-manifest.json"))}",
            $"{ContractRelative}={HashFile(Path.Combine(packageRoot, ContractRelative.Replace('/', Path.DirectorySeparatorChar)))}",
            $"modules/registry.json={HashFile(Path.Combine(packageRoot, "modules", "registry.json"))}"
        };
        lines.AddRange(profiles.GetProperty("profiles").EnumerateArray().OrderBy(item => item.GetProperty("id").GetString(), StringComparer.Ordinal)
            .Select(item => $"profile:{item.GetProperty("id").GetString()}={item.GetProperty("sha256").GetString()}"));
        using var registry = ReadDocument(Path.Combine(packageRoot, "modules", "registry.json"), "Module registry");
        lines.AddRange(registry.RootElement.GetProperty("modules").EnumerateArray().OrderBy(item => item.GetProperty("id").GetString(), StringComparer.Ordinal)
            .Select(item => $"module:{item.GetProperty("id").GetString()}={item.GetProperty("manifestSha256").GetString()}"));
        return HashText(string.Join("\n", lines) + "\n");
    }

    private static void VerifyApplicationContract(string packageRoot)
    {
        var contractPath = ResolveFileUnder(packageRoot, ContractRelative, "application service contract");
        var schemaPath = ResolveFileUnder(packageRoot, ContractSchemaRelative, "application service contract schema");
        ValidateArbitrarySchema(contractPath, schemaPath, "application service contract");
        using var contract = ReadDocument(contractPath, "application service contract");
        foreach (var entry in contract.RootElement.GetProperty("schemas").EnumerateArray())
        {
            var path = ResolveFileUnder(packageRoot, entry.GetProperty("path").GetString()!, "application schema");
            if (HashFile(path) != entry.GetProperty("sha256").GetString()) throw Integrity("Application schema hash drift.");
        }
    }

    private static void ValidateDocument(string packageRoot, string schemaId, JsonNode document)
    {
        using var contract = ReadDocument(ResolveFileUnder(packageRoot, ContractRelative, "application service contract"), "application service contract");
        var entries = contract.RootElement.GetProperty("schemas").EnumerateArray()
            .Where(entry => entry.GetProperty("id").GetString() == schemaId).ToArray();
        if (entries.Length != 1) throw Invalid($"Application schema is not registered: {schemaId}");
        var schemaPath = ResolveFileUnder(packageRoot, entries[0].GetProperty("path").GetString()!, "application schema");
        var documentPath = Path.Combine(Path.GetTempPath(), $"v4-application-{Guid.NewGuid():N}.json");
        try
        {
            File.WriteAllText(documentPath, document.ToJsonString(JsonOptions), new UTF8Encoding(false));
            ValidateArbitrarySchema(documentPath, schemaPath, "application preview");
        }
        finally { if (File.Exists(documentPath)) File.Delete(documentPath); }
    }

    private static void ValidateArbitrarySchema(string documentPath, string schemaPath, string label)
    {
        const string script = "if(Test-Json -LiteralPath $env:V4_APPLICATION_DOCUMENT -SchemaFile $env:V4_APPLICATION_SCHEMA -ErrorAction SilentlyContinue){exit 0}else{exit 1}";
        var start = new ProcessStartInfo("pwsh") { UseShellExecute = false, RedirectStandardError = true, RedirectStandardOutput = true, CreateNoWindow = true };
        foreach (var value in new[] { "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", script }) start.ArgumentList.Add(value);
        start.Environment["V4_APPLICATION_DOCUMENT"] = documentPath;
        start.Environment["V4_APPLICATION_SCHEMA"] = schemaPath;
        using var process = Process.Start(start) ?? throw new InvalidOperationException("PowerShell 7 did not start.");
        process.WaitForExit();
        if (process.ExitCode != 0) throw Findings($"{label} does not satisfy its installed schema.");
    }

    private static Roots ResolveRoots(Arguments arguments)
    {
        var packageRoot = ResolveDirectory(arguments.Required("package-root"), "PackageRoot");
        var targetRoot = ResolveDirectory(arguments.Required("target-root"), "TargetRoot");
        var stateRoot = ResolveDirectory(arguments.Required("state-root"), "StateRoot");
        var evidenceRoot = ResolveDirectory(arguments.Required("evidence-root"), "EvidenceRoot");
        foreach (var pair in new[] { (packageRoot, targetRoot), (packageRoot, stateRoot), (packageRoot, evidenceRoot), (targetRoot, stateRoot), (targetRoot, evidenceRoot), (stateRoot, evidenceRoot) })
            if (Overlaps(pair.Item1, pair.Item2)) throw Unsafe("Application roots must be pairwise disjoint.");
        var planRoot = arguments.Required("plan-root").Replace('\\', '/');
        if (!RelativePathPattern.IsMatch(planRoot)) throw Unsafe("Plan root must be a safe relative path.");
        return new Roots(packageRoot, targetRoot, stateRoot, evidenceRoot, planRoot);
    }

    private static string ResolveDirectory(string value, string label)
    {
        var path = Path.TrimEndingDirectorySeparator(Path.GetFullPath(value));
        if (!Directory.Exists(path)) throw Invalid($"{label} does not exist.");
        EnsureNoLinks(path, label);
        return path;
    }

    private static string ResolveFileUnder(string root, string relative, string label)
    {
        if (Path.IsPathRooted(relative)) throw Unsafe($"{label} must be relative.");
        var path = Path.GetFullPath(Path.Combine(root, relative));
        EnsureUnder(path, root, $"{label} escapes PackageRoot.");
        if (!File.Exists(path)) throw Invalid($"{label} is missing.");
        EnsureNoLinks(path, label);
        return path;
    }

    private static void EnsureNoLinks(string path, string label)
    {
        FileSystemInfo? current = File.Exists(path) ? new FileInfo(path) : new DirectoryInfo(path);
        while (current is not null)
        {
            if ((current.Attributes & FileAttributes.ReparsePoint) != 0 || current.LinkTarget is not null)
                throw Unsafe($"{label} crosses a link or reparse point: {current.FullName}");
            current = current is FileInfo file ? file.Directory : ((DirectoryInfo)current).Parent;
        }
    }

    private static void EnsureUnder(string path, string root, string message)
    {
        var relative = Path.GetRelativePath(root, path);
        if (Path.IsPathRooted(relative) || relative == ".." || relative.StartsWith($"..{Path.DirectorySeparatorChar}", StringComparison.Ordinal))
            throw Unsafe(message);
    }

    private static bool Overlaps(string left, string right) => IsUnder(left, right) || IsUnder(right, left);
    private static bool IsUnder(string path, string root)
    {
        var relative = Path.GetRelativePath(root, path);
        return relative == "." || (!Path.IsPathRooted(relative) && relative != ".." && !relative.StartsWith($"..{Path.DirectorySeparatorChar}", StringComparison.Ordinal));
    }

    private static JsonDocument ReadDocument(string path, string label)
    {
        try { return JsonDocument.Parse(File.ReadAllText(path), new JsonDocumentOptions { AllowTrailingCommas = false, CommentHandling = JsonCommentHandling.Disallow, MaxDepth = 128 }); }
        catch (Exception ex) when (ex is IOException or JsonException) { throw Invalid($"{label} is invalid: {ex.Message}"); }
    }

    private static string RequiredString(JsonObject value, string name) => value[name]?.GetValue<string>() is { Length: > 0 } text ? text : throw Invalid($"{name} is required.");
    private static string? NullableString(JsonElement value, string name) => value.GetProperty(name).ValueKind == JsonValueKind.Null ? null : value.GetProperty(name).GetString();
    private static string HashFile(string path) => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path))).ToLowerInvariant();
    private static string HashText(string text) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(text))).ToLowerInvariant();
    private static int Error(int code, string category, string message)
    {
        Console.Error.WriteLine(JsonSerializer.Serialize(new { formatVersion = 1, status = "error", exitCategory = category, message }, JsonOptions));
        return code;
    }
    private static ApplicationException Invalid(string message) => new(10, "invalid-input", message);
    private static ApplicationException Unsafe(string message) => new(11, "unsafe-path", message);
    private static ApplicationException Integrity(string message) => new(12, "integrity-failure", message);
    private static ApplicationException Findings(string message) => new(16, "findings-blocking", message);

    private sealed record Roots(string PackageRoot, string TargetRoot, string StateRoot, string EvidenceRoot, string PlanRoot);
    private sealed record PreviewContext(Roots Roots, JsonElement Project, JsonElement Profiles, string ProjectId, string TargetSnapshot, string PackageAuthority);
    private sealed class ApplicationException(int code, string category, string message) : Exception(message)
    {
        public int Code { get; } = code;
        public string Category { get; } = category;
    }

    private sealed class Arguments(string action, Dictionary<string, string> values)
    {
        public string Action { get; } = action;
        public static Arguments Parse(string[] args)
        {
            if (args.Length < 2 || args[0] != "application") throw Invalid("Expected 'application <action>'.");
            var values = new Dictionary<string, string>(StringComparer.Ordinal);
            for (var index = 2; index < args.Length; index += 2)
            {
                if (index + 1 >= args.Length || !args[index].StartsWith("--", StringComparison.Ordinal)) throw Invalid("Arguments must be --name value pairs.");
                if (!values.TryAdd(args[index][2..], args[index + 1])) throw Invalid($"Duplicate argument: {args[index]}");
            }
            return new Arguments(args[1], values);
        }
        public string Required(string name) => values.TryGetValue(name, out var value) && !string.IsNullOrWhiteSpace(value) ? value : throw Invalid($"Missing --{name}.");
        public void RequireOnly(params string[] names)
        {
            var unknown = values.Keys.FirstOrDefault(name => !names.Contains(name, StringComparer.Ordinal));
            if (unknown is not null) throw Invalid($"Unknown argument: --{unknown}");
            foreach (var name in names) _ = Required(name);
        }
    }
}
