using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace V4.Guards.Host;

internal static class PlanRuntime
{
    private static readonly JsonSerializerOptions OutputOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true
    };
    private static readonly JsonSerializerOptions CanonicalOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = false
    };

    private static readonly Regex PlanIdPattern = new("^[0-9]{8}-[a-z0-9-]+$", RegexOptions.CultureInvariant);
    private static readonly HashSet<string> BoundaryNames = new(
        ["authorization", "trust-change", "activation", "engine-change", "remote-change"],
        StringComparer.Ordinal);
    private static readonly (string Left, string Right)[] ForbiddenBoundaryPairs =
    [
        ("authorization", "trust-change"),
        ("authorization", "activation"),
        ("trust-change", "activation"),
        ("engine-change", "remote-change")
    ];
    private static readonly string[] PlanProperties =
    [
        "formatVersion", "id", "title", "goal", "acceptanceCriteria", "plannedPaths", "areas",
        "risks", "decisions", "validationCommands", "dependencies", "boundaries"
    ];
    private const int MaxMembers = 16;
    private const int MaxPlanBytes = 1024 * 1024;
    private const int MaxAggregateBytes = 8 * 1024 * 1024;
    private const int MaxDependencyDepth = 8;
    private const int MaxPlannedPaths = 4096;
    private const int MaxValidationCommands = 256;
    private const int MaxRiskDecisionEntries = 256;
    private static readonly TimeSpan MaxCompositionTime = TimeSpan.FromSeconds(30);

    public static int Execute(string[] args)
    {
        try
        {
            var options = ParseArguments(args);
            var packageRoot = ResolveDirectory(options.Required("package-root"), "PackageRoot");
            VerifyPlanContract(packageRoot);

            if (options.Operation == "scaffold")
            {
                VerifyGovernanceContract(packageRoot);
                var scaffoldEvidenceRoot = ResolveDirectory(options.Required("evidence-root"), "EvidenceRoot");
                var id = options.Required("id");
                if (!PlanIdPattern.IsMatch(id)) throw Invalid("Plan ID must match YYYYMMDD-lowercase-kebab-case.");
                var output = ResolveOutput(scaffoldEvidenceRoot, options.Required("output"));
                var model = new
                {
                    formatVersion = 1,
                    state = "proposal",
                    plan = new
                    {
                        formatVersion = 1,
                        id,
                        title = options.Optional("title") ?? "Unresolved Plan title",
                        goal = options.Optional("goal") ?? "Resolve the proposal before finalization.",
                        acceptanceCriteria = Array.Empty<string>(), plannedPaths = Array.Empty<string>(),
                        areas = Array.Empty<string>(), risks = Array.Empty<string>(), decisions = Array.Empty<string>(),
                        validationCommands = Array.Empty<string>(), dependencies = Array.Empty<string>(), boundaries = Array.Empty<string>()
                    },
                    unresolvedQuestions = new[] { "Complete acceptance criteria, planned paths, areas and validation commands." }
                };
                WriteAtomic(output, JsonSerializer.Serialize(model, OutputOptions) + "\n");
                Console.WriteLine(JsonSerializer.Serialize(new { formatVersion = 1, status = "pass", exitCategory = "success", state = "proposal", id, output = NormalizeRelative(Path.GetRelativePath(scaffoldEvidenceRoot, output)), authoritative = false }, OutputOptions));
                return 0;
            }

            if (options.Operation == "verify-pair")
            {
                VerifyGovernanceContract(packageRoot);
                return VerifyPair(options);
            }

            var targetRoot = ResolveDirectory(options.Required("target-root"), "TargetRoot");

            if (options.Operation == "finalize")
            {
                VerifyGovernanceContract(packageRoot);
                return FinalizePair(options, targetRoot);
            }

            if (options.Operation == "validate")
            {
                var member = LoadPlan(targetRoot, options.Single("plan"));
                Console.WriteLine(JsonSerializer.Serialize(new
                {
                    formatVersion = 1,
                    status = "pass",
                    exitCategory = "success",
                    planId = member.Plan.Id,
                    path = member.RelativePath,
                    sha256 = member.Sha256
                }, OutputOptions));
                return 0;
            }

            VerifyGovernanceContract(packageRoot);
            var timer = Stopwatch.StartNew();
            var evidenceRoot = ResolveDirectory(options.Required("evidence-root"), "EvidenceRoot");
            var planSetId = options.Required("id");
            if (!PlanIdPattern.IsMatch(planSetId))
                throw Invalid("Plan-set ID must match YYYYMMDD-lowercase-kebab-case.");
            var planArguments = options.Many("plan");
            if (planArguments.Count < 2) throw Invalid("Plan composition requires at least two --plan arguments.");
            if (planArguments.Count > MaxMembers) throw Invalid($"Plan composition exceeds the {MaxMembers}-member limit.");
            var outputPath = ResolveOutput(evidenceRoot, options.Required("output"));
            var members = planArguments.Select(path => LoadPlan(targetRoot, path)).ToArray();
            if (members.Sum(member => (long)member.ByteCount) > MaxAggregateBytes)
                throw Invalid($"Plan composition exceeds the {MaxAggregateBytes}-byte aggregate input limit.");
            var planSet = Compose(planSetId, members);
            if (timer.Elapsed > MaxCompositionTime) throw Invalid($"Plan composition exceeded the {MaxCompositionTime.TotalSeconds:0}-second limit.");
            WriteAtomic(outputPath, JsonSerializer.Serialize(planSet, OutputOptions) + "\n");
            Console.WriteLine(JsonSerializer.Serialize(new
            {
                formatVersion = 1,
                status = "pass",
                exitCategory = "success",
                planSetId,
                output = NormalizeRelative(Path.GetRelativePath(evidenceRoot, outputPath)),
                compositionHash = planSet.CompositionHash,
                memberCount = planSet.Members.Length
            }, OutputOptions));
            return 0;
        }
        catch (PlanException ex)
        {
            Console.Error.WriteLine(JsonSerializer.Serialize(new
            {
                formatVersion = 1,
                status = "error",
                exitCategory = ex.Category,
                message = ex.Message
            }, OutputOptions));
            return ex.Code;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(JsonSerializer.Serialize(new
            {
                formatVersion = 1,
                status = "error",
                exitCategory = "internal-error",
                message = ex.Message
            }, OutputOptions));
            return 19;
        }
    }

    internal static void VerifyPlanContractForQuery(string packageRoot) => VerifyPlanContract(packageRoot);

    internal static bool TryReadNativePlan(string targetRoot, string relativePath, out NativePlanProjection? projection)
    {
        try
        {
            var member = LoadPlan(targetRoot, relativePath);
            projection = new NativePlanProjection(member.Plan.Id, member.Plan.Title, member.RelativePath, member.Sha256);
            return true;
        }
        catch (PlanException)
        {
            projection = null;
            return false;
        }
    }

    private static Arguments ParseArguments(string[] args)
    {
        if (args.Length < 2 || args[0] != "plan" || args[1] is not ("validate" or "compose" or "scaffold" or "finalize" or "verify-pair"))
            throw Invalid("Expected 'plan validate', 'plan compose', 'plan scaffold', 'plan finalize' or 'plan verify-pair'.");
        var operation = args[1];
        var values = new Dictionary<string, List<string>>(StringComparer.Ordinal);
        for (var index = 2; index < args.Length; index += 2)
        {
            if (index + 1 >= args.Length || !args[index].StartsWith("--", StringComparison.Ordinal))
                throw Invalid("Arguments must be --name value pairs.");
            var name = args[index][2..];
            if (!values.TryGetValue(name, out var list)) values[name] = list = [];
            list.Add(args[index + 1]);
        }
        var known = operation switch
        {
            "validate" => new HashSet<string>(["package-root", "target-root", "plan"], StringComparer.Ordinal),
            "compose" => new HashSet<string>(["package-root", "target-root", "evidence-root", "id", "plan", "output"], StringComparer.Ordinal),
            "scaffold" => new HashSet<string>(["package-root", "evidence-root", "id", "title", "goal", "output"], StringComparer.Ordinal),
            "verify-pair" => new HashSet<string>(["package-root", "evidence-root", "input-directory", "plan-id", "base-ref", "head-ref", "source-id", "generator-id", "policy-id"], StringComparer.Ordinal),
            _ => new HashSet<string>(["package-root", "target-root", "evidence-root", "input", "output-directory", "base-ref", "head-ref", "confirm-proposal-sha256", "source-id", "generator-id", "policy-id"], StringComparer.Ordinal)
        };
        var unknown = values.Keys.FirstOrDefault(key => !known.Contains(key));
        if (unknown is not null) throw Invalid($"Unknown argument: --{unknown}");
        foreach (var pair in values.Where(pair => pair.Key != "plan" && pair.Value.Count != 1))
            throw Invalid($"Duplicate argument: --{pair.Key}");
        return new Arguments(operation, values);
    }

    private static PlanSetDocument Compose(string id, PlanMember[] input)
    {
        var pathSet = new HashSet<string>(StringComparer.Ordinal);
        var idMap = new Dictionary<string, PlanMember>(StringComparer.Ordinal);
        foreach (var member in input)
        {
            if (!pathSet.Add(member.RelativePath)) throw Invalid($"Duplicate member path: {member.RelativePath}");
            if (!idMap.TryAdd(member.Plan.Id, member)) throw Invalid($"Duplicate Plan ID: {member.Plan.Id}");
        }

        var owners = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var member in input)
        foreach (var path in member.Plan.PlannedPaths)
        {
            if (!owners.TryAdd(path, member.Plan.Id))
                throw Invalid($"Conflicting planned path ownership: {path} is declared by {owners[path]} and {member.Plan.Id}.");
        }

        foreach (var member in input)
        foreach (var dependency in member.Plan.Dependencies)
        {
            if (dependency == member.Plan.Id) throw Invalid($"Plan {member.Plan.Id} depends on itself.");
            if (!idMap.ContainsKey(dependency)) throw Invalid($"Plan {member.Plan.Id} has an unselected dependency: {dependency}.");
        }

        var ordered = TopologicalOrder(input, idMap);
        if (DependencyDepth(ordered, idMap) > MaxDependencyDepth)
            throw Invalid($"Plan dependency graph exceeds the depth limit of {MaxDependencyDepth}.");
        AssertCompatibleBoundaries(ordered.SelectMany(member => member.Plan.Boundaries));
        var memberDocuments = ordered.Select((member, index) => new PlanSetMember(
            index + 1, member.Plan.Id, member.RelativePath, member.Sha256,
            Sorted(member.Plan.Dependencies))).ToArray();
        var union = new DerivedUnion(
            Sorted(ordered.SelectMany(member => member.Plan.PlannedPaths)),
            Sorted(ordered.SelectMany(member => member.Plan.Areas)),
            Sorted(ordered.SelectMany(member => member.Plan.Risks)),
            Sorted(ordered.SelectMany(member => member.Plan.Decisions)),
            Sorted(ordered.SelectMany(member => member.Plan.ValidationCommands)),
            Sorted(ordered.SelectMany(member => member.Plan.Boundaries)));
        if (union.PlannedPaths.Length > MaxPlannedPaths) throw Invalid($"Plan set exceeds the {MaxPlannedPaths}-path limit.");
        if (union.ValidationCommands.Length > MaxValidationCommands) throw Invalid($"Plan set exceeds the {MaxValidationCommands}-validation-command limit.");
        if (ordered.Sum(member => member.Plan.Risks.Length + member.Plan.Decisions.Length) > MaxRiskDecisionEntries)
            throw Invalid($"Plan set exceeds the {MaxRiskDecisionEntries} combined risk/decision entry limit.");
        var canonical = JsonSerializer.SerializeToUtf8Bytes(
            new { formatVersion = 1, id, members = memberDocuments, derivedUnion = union }, CanonicalOptions);
        var compositionHash = Convert.ToHexString(SHA256.HashData(canonical)).ToLowerInvariant();
        return new PlanSetDocument(1, id, memberDocuments, union, compositionHash);
    }

    private static int DependencyDepth(PlanMember[] ordered, Dictionary<string, PlanMember> idMap)
    {
        var depth = new Dictionary<string, int>(StringComparer.Ordinal);
        foreach (var member in ordered)
            depth[member.Plan.Id] = member.Plan.Dependencies.Length == 0 ? 1 : 1 + member.Plan.Dependencies.Max(id => depth[id]);
        return depth.Count == 0 ? 0 : depth.Values.Max();
    }

    private static PlanMember[] TopologicalOrder(PlanMember[] input, Dictionary<string, PlanMember> idMap)
    {
        var indegree = input.ToDictionary(member => member.Plan.Id, member => member.Plan.Dependencies.Length, StringComparer.Ordinal);
        var dependents = input.ToDictionary(member => member.Plan.Id, _ => new List<string>(), StringComparer.Ordinal);
        foreach (var member in input)
        foreach (var dependency in member.Plan.Dependencies) dependents[dependency].Add(member.Plan.Id);
        var ready = new SortedSet<string>(indegree.Where(pair => pair.Value == 0).Select(pair => pair.Key), StringComparer.Ordinal);
        var output = new List<PlanMember>();
        while (ready.Count > 0)
        {
            var id = ready.Min!;
            ready.Remove(id);
            output.Add(idMap[id]);
            foreach (var dependent in dependents[id].Order(StringComparer.Ordinal))
            {
                indegree[dependent]--;
                if (indegree[dependent] == 0) ready.Add(dependent);
            }
        }
        if (output.Count != input.Length) throw Invalid("Plan dependency graph contains a cycle.");
        return output.ToArray();
    }

    private static PlanMember LoadPlan(string targetRoot, string value)
    {
        var relative = ValidateRelativePath(value, "Plan path");
        var full = ResolveFile(targetRoot, relative, "Plan");
        byte[] bytes;
        try { bytes = File.ReadAllBytes(full); }
        catch (IOException ex) { throw Invalid($"Plan cannot be read: {ex.Message}"); }
        if (bytes.Length > MaxPlanBytes) throw Invalid($"Plan exceeds the {MaxPlanBytes}-byte document limit.");
        JsonDocument document;
        try { document = JsonDocument.Parse(bytes, new JsonDocumentOptions { AllowTrailingCommas = false, CommentHandling = JsonCommentHandling.Disallow }); }
        catch (JsonException ex) { throw Invalid($"Plan JSON is invalid: {ex.Message}"); }
        using (document)
        {
            var plan = ValidatePlanDocument(document.RootElement);
            return new PlanMember(relative, Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant(), bytes.Length, plan);
        }
    }

    private static int VerifyPair(Arguments options)
    {
        var evidenceRoot = ResolveDirectory(options.Required("evidence-root"), "EvidenceRoot");
        var directoryRelative = ValidateRelativePath(options.Required("input-directory"), "Pair directory");
        var directory = Path.GetFullPath(Path.Combine(evidenceRoot, directoryRelative.Replace('/', Path.DirectorySeparatorChar)));
        if (!IsUnder(directory, evidenceRoot) || !Directory.Exists(directory)) throw Unsafe("Pair directory escapes EvidenceRoot or is missing.");
        EnsureNoLinks(directory, "Pair directory");
        var planId = options.Required("plan-id");
        if (!PlanIdPattern.IsMatch(planId)) throw Invalid("Plan ID must match YYYYMMDD-lowercase-kebab-case.");
        var receiptPath = ResolveFile(directory, $"{planId}.pair-receipt.json", "Pair receipt");
        using var receipt = JsonDocument.Parse(File.ReadAllBytes(receiptPath));
        var root = receipt.RootElement;
        var expected = new[] { "formatVersion", "state", "planId", "proposalSha256", "baseRef", "headRef", "sourceId", "generatorId", "policyId", "jsonPath", "jsonSha256", "markdownPath", "markdownSha256" };
        var actual = root.EnumerateObject().Select(property => property.Name).ToArray();
        if (actual.Length != expected.Length || actual.Distinct(StringComparer.Ordinal).Count() != actual.Length || expected.Any(name => !actual.Contains(name, StringComparer.Ordinal)))
            throw Integrity("Pair receipt has unknown, missing or duplicate properties.");
        if (root.GetProperty("formatVersion").GetInt32() != 1 || root.GetProperty("state").GetString() != "finalized" || root.GetProperty("planId").GetString() != planId)
            throw Integrity("Pair receipt identity is invalid.");
        var baseRef = ValidateGitRef(options.Required("base-ref")); var headRef = ValidateGitRef(options.Required("head-ref"));
        var sourceId = Identity(options.Required("source-id"), "Source identity"); var generatorId = Identity(options.Required("generator-id"), "Generator identity"); var policyId = Identity(options.Required("policy-id"), "Policy identity");
        if (root.GetProperty("baseRef").GetString() != baseRef || root.GetProperty("headRef").GetString() != headRef ||
            root.GetProperty("sourceId").GetString() != sourceId || root.GetProperty("generatorId").GetString() != generatorId || root.GetProperty("policyId").GetString() != policyId)
            throw Integrity("Pair receipt provenance does not match the expected base/head/source/generator/policy.");
        var jsonName = root.GetProperty("jsonPath").GetString() ?? ""; var markdownName = root.GetProperty("markdownPath").GetString() ?? "";
        if (jsonName != $"{planId}.plan.json" || markdownName != $"{planId}.md") throw Integrity("Pair receipt file names are invalid.");
        var jsonPath = ResolveFile(directory, jsonName, "Pair JSON"); var markdownPath = ResolveFile(directory, markdownName, "Pair Markdown");
        var jsonHash = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(jsonPath))).ToLowerInvariant();
        var markdownHash = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(markdownPath))).ToLowerInvariant();
        if (jsonHash != root.GetProperty("jsonSha256").GetString() || markdownHash != root.GetProperty("markdownSha256").GetString())
            throw Integrity("Plan pair content hash mismatch.");
        using var planDocument = JsonDocument.Parse(File.ReadAllBytes(jsonPath));
        if (ValidatePlanDocument(planDocument.RootElement).Id != planId) throw Integrity("Plan pair JSON identity mismatch.");
        var receiptHash = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(receiptPath))).ToLowerInvariant();
        Console.WriteLine(JsonSerializer.Serialize(new { formatVersion = 1, status = "pass", exitCategory = "success", state = "verified", planId, jsonSha256 = jsonHash, markdownSha256 = markdownHash, receiptSha256 = receiptHash, authoritative = false }, OutputOptions));
        return 0;
    }

    private static int FinalizePair(Arguments options, string targetRoot)
    {
        var evidenceRoot = ResolveDirectory(options.Required("evidence-root"), "EvidenceRoot");
        var inputRelative = ValidateRelativePath(options.Required("input"), "Proposal path");
        var inputPath = ResolveFile(evidenceRoot, inputRelative, "Proposal");
        var bytes = File.ReadAllBytes(inputPath);
        var proposalHash = Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();
        if (!string.Equals(proposalHash, options.Required("confirm-proposal-sha256"), StringComparison.Ordinal))
            throw Invalid("Operator confirmation does not match the exact proposal SHA-256.");
        using var document = JsonDocument.Parse(bytes);
        var root = document.RootElement;
        if (root.ValueKind != JsonValueKind.Object || root.GetProperty("formatVersion").GetInt32() != 1 ||
            root.GetProperty("state").GetString() != "proposal") throw Invalid("Authoring input must be a formatVersion 1 proposal.");
        var unresolved = StringArray(root, "unresolvedQuestions", false, false);
        if (unresolved.Length != 0) throw Invalid("Proposal has unresolved questions and cannot be finalized.");
        var plan = ValidatePlanDocument(root.GetProperty("plan"));
        var baseRef = ValidateGitRef(options.Required("base-ref"));
        var headRef = ValidateGitRef(options.Required("head-ref"));
        var changed = GitNames(targetRoot, baseRef, headRef);
        if (!changed.SequenceEqual(Sorted(plan.PlannedPaths), StringComparer.Ordinal))
            throw Invalid("Proposal planned paths do not exactly match the base/head diff.");
        var outputDirectory = ValidateRelativePath(options.Required("output-directory"), "Output directory");
        var finalDirectory = Path.GetFullPath(Path.Combine(evidenceRoot, outputDirectory.Replace('/', Path.DirectorySeparatorChar)));
        if (!IsUnder(finalDirectory, evidenceRoot)) throw Unsafe("Output directory escapes EvidenceRoot.");
        var finalParent = Path.GetDirectoryName(finalDirectory)!;
        Directory.CreateDirectory(finalParent); EnsureNoLinks(finalParent, "Output directory");
        if (Directory.Exists(finalDirectory) || File.Exists(finalDirectory)) throw Invalid("Finalized pair output directory already exists and will not be overwritten.");
        var stagingDirectory = Path.Combine(finalParent, $".{Path.GetFileName(finalDirectory)}-{Guid.NewGuid():N}.tmp");
        var jsonPath = Path.Combine(finalDirectory, $"{plan.Id}.plan.json");
        var markdownPath = Path.Combine(finalDirectory, $"{plan.Id}.md");
        var receiptPath = Path.Combine(finalDirectory, $"{plan.Id}.pair-receipt.json");
        var json = JsonSerializer.Serialize(plan, OutputOptions) + "\n";
        var jsonHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(json))).ToLowerInvariant();
        var sourceId = Identity(options.Required("source-id"), "Source identity");
        var generatorId = Identity(options.Required("generator-id"), "Generator identity");
        var policyId = Identity(options.Required("policy-id"), "Policy identity");
        var markdown = RenderMarkdown(plan, proposalHash, jsonHash, baseRef, headRef, sourceId, generatorId, policyId);
        var markdownHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(markdown))).ToLowerInvariant();
        var receipt = JsonSerializer.Serialize(new
        {
            formatVersion = 1, state = "finalized", planId = plan.Id, proposalSha256 = proposalHash,
            baseRef, headRef, sourceId, generatorId, policyId,
            jsonPath = $"{plan.Id}.plan.json", jsonSha256 = jsonHash,
            markdownPath = $"{plan.Id}.md", markdownSha256 = markdownHash
        }, OutputOptions) + "\n";
        var receiptHash = Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(receipt))).ToLowerInvariant();
        try
        {
            Directory.CreateDirectory(stagingDirectory);
            WriteAtomic(Path.Combine(stagingDirectory, Path.GetFileName(jsonPath)), json);
            WriteAtomic(Path.Combine(stagingDirectory, Path.GetFileName(markdownPath)), markdown);
            WriteAtomic(Path.Combine(stagingDirectory, Path.GetFileName(receiptPath)), receipt);
            Directory.Move(stagingDirectory, finalDirectory);
        }
        finally { if (Directory.Exists(stagingDirectory)) Directory.Delete(stagingDirectory, true); }
        Console.WriteLine(JsonSerializer.Serialize(new
        {
            formatVersion = 1, status = "pass", exitCategory = "success", state = "finalized", planId = plan.Id,
            proposalSha256 = proposalHash, baseRef, headRef, sourceId, generatorId, policyId,
            jsonPath = NormalizeRelative(Path.GetRelativePath(evidenceRoot, jsonPath)),
            markdownPath = NormalizeRelative(Path.GetRelativePath(evidenceRoot, markdownPath)),
            receiptPath = NormalizeRelative(Path.GetRelativePath(evidenceRoot, receiptPath)),
            jsonSha256 = jsonHash, markdownSha256 = markdownHash, receiptSha256 = receiptHash, authoritative = false
        }, OutputOptions));
        return 0;
    }

    private static string RenderMarkdown(PlanDocument plan, string proposalHash, string jsonHash, string baseRef, string headRef,
        string sourceId, string generatorId, string policyId)
    {
        static void Section(StringBuilder value, string title, IEnumerable<string> entries)
        {
            value.Append("## ").Append(title).Append("\n\n");
            foreach (var entry in entries) value.Append("- ").Append(EscapeMarkdown(entry)).Append('\n');
            value.Append('\n');
        }
        var text = new StringBuilder().Append("# ").Append(EscapeMarkdown(plan.Title)).Append("\n\n")
            .Append("Status: `FINALIZED CANDIDATE — deliberate Target adoption required`\n\n")
            .Append("Formal Plan ID: `").Append(EscapeMarkdown(plan.Id)).Append("`.\n\n")
            .Append("## Goal\n\n").Append(EscapeMarkdown(plan.Goal)).Append("\n\n");
        Section(text, "Acceptance criteria", plan.AcceptanceCriteria);
        Section(text, "Planned paths", plan.PlannedPaths.Select(path => $"`{path}`"));
        Section(text, "Areas", plan.Areas);
        Section(text, "Risks", plan.Risks);
        Section(text, "Decisions", plan.Decisions);
        Section(text, "Validation", plan.ValidationCommands.Select(command => $"`{command}`"));
        Section(text, "Dependencies", plan.Dependencies);
        Section(text, "Boundaries", plan.Boundaries);
        text.Append("## Finalization evidence\n\n")
            .Append("- Proposal SHA-256: `").Append(proposalHash).Append("`\n")
            .Append("- Plan JSON SHA-256: `").Append(jsonHash).Append("`\n")
            .Append("- Exact diff: `").Append(baseRef).Append("...").Append(headRef).Append("`\n")
            .Append("- Source: `").Append(sourceId).Append("`\n")
            .Append("- Generator: `").Append(generatorId).Append("`\n")
            .Append("- Policy: `").Append(policyId).Append("`\n");
        return text.ToString();
    }

    private static string EscapeMarkdown(string value)
    {
        var output = new StringBuilder(value.Length + 16);
        foreach (var character in value)
        {
            if (character == '\r') { output.Append("\\r"); continue; }
            if (character == '\n') { output.Append("\\n"); continue; }
            if (char.IsControl(character)) { output.Append("\\u").Append(((int)character).ToString("x4")); continue; }
            if (character == '`') { output.Append("&#96;"); continue; }
            if ("\\*_{}[]()#+-.!|>".IndexOf(character) >= 0) output.Append('\\');
            output.Append(character);
        }
        return output.ToString();
    }

    private static string[] GitNames(string repository, string baseRef, string headRef)
    {
        var start = new ProcessStartInfo("git") { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true };
        foreach (var argument in new[] { "-C", repository, "-c", "core.quotepath=false", "diff", "--name-only", "--no-renames", "-z", $"{baseRef}...{headRef}", "--" }) start.ArgumentList.Add(argument);
        using var process = Process.Start(start) ?? throw Integrity("Git did not start.");
        var stdout = process.StandardOutput.ReadToEndAsync();
        var stderr = process.StandardError.ReadToEndAsync();
        if (!process.WaitForExit((int)MaxCompositionTime.TotalMilliseconds)) { process.Kill(true); throw Invalid("Exact-diff analysis exceeded the 30-second limit."); }
        Task.WaitAll(stdout, stderr);
        if (process.ExitCode != 0) throw Integrity($"Git diff failed: {stderr.Result.Trim()}");
        return Sorted(stdout.Result.Split('\0', StringSplitOptions.RemoveEmptyEntries).Select(NormalizeRelative));
    }

    private static string ValidateGitRef(string value)
    {
        if (!Regex.IsMatch(value, "^[A-Za-z0-9][A-Za-z0-9._/-]*$", RegexOptions.CultureInvariant) || value.Contains("..") || value.Contains("//"))
            throw Unsafe($"Unsafe Git ref: {value}");
        return value;
    }

    private static string Identity(string value, string label)
    {
        if (!Regex.IsMatch(value, "^[a-z0-9][a-z0-9._-]*$", RegexOptions.CultureInvariant))
            throw Invalid($"{label} must be a lowercase stable identifier.");
        return value;
    }

    internal static void VerifyGovernanceContract(string packageRoot)
    {
        var catalogPath = ResolveFile(packageRoot, "core/governance/governance-contract.json", "Governance contract");
        try
        {
            using var catalog = JsonDocument.Parse(File.ReadAllBytes(catalogPath));
            foreach (var entry in catalog.RootElement.GetProperty("files").EnumerateArray())
            {
                var path = RequiredString(entry, "path");
                var expected = RequiredString(entry, "sha256");
                var actual = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(ResolveFile(packageRoot, path, "Governance contract file")))).ToLowerInvariant();
                if (!string.Equals(actual, expected, StringComparison.Ordinal)) throw Integrity($"Governance contract hash mismatch: {path}");
            }
            var limits = catalog.RootElement.GetProperty("planLimits");
            if (limits.GetProperty("maxMembers").GetInt32() != MaxMembers || limits.GetProperty("maxPlanBytes").GetInt32() != MaxPlanBytes ||
                limits.GetProperty("maxAggregateBytes").GetInt32() != MaxAggregateBytes || limits.GetProperty("maxDependencyDepth").GetInt32() != MaxDependencyDepth ||
                limits.GetProperty("maxPlannedPaths").GetInt32() != MaxPlannedPaths || limits.GetProperty("maxValidationCommands").GetInt32() != MaxValidationCommands ||
                limits.GetProperty("maxRiskDecisionEntries").GetInt32() != MaxRiskDecisionEntries || limits.GetProperty("maxCompositionSeconds").GetInt32() != 30)
                throw Integrity("Governance Plan limits do not match the Host implementation.");
        }
        catch (PlanException) { throw; }
        catch (Exception ex) when (ex is JsonException or IOException or InvalidOperationException or KeyNotFoundException)
        { throw Integrity($"Governance contract is invalid: {ex.Message}"); }
    }

    private static PlanDocument ValidatePlanDocument(JsonElement root)
    {
        if (root.ValueKind != JsonValueKind.Object) throw Invalid("Plan must be a JSON object.");
        var actualProperties = root.EnumerateObject().Select(property => property.Name).ToArray();
        if (actualProperties.Distinct(StringComparer.Ordinal).Count() != actualProperties.Length)
            throw Invalid("Plan contains duplicate JSON properties.");
        var unknown = actualProperties.FirstOrDefault(name => !PlanProperties.Contains(name, StringComparer.Ordinal));
        if (unknown is not null) throw Invalid($"Plan contains unknown property: {unknown}.");
        var missing = PlanProperties.FirstOrDefault(name => !actualProperties.Contains(name, StringComparer.Ordinal));
        if (missing is not null) throw Invalid($"Plan is missing property: {missing}.");
        if (root.GetProperty("formatVersion").ValueKind != JsonValueKind.Number || !root.GetProperty("formatVersion").TryGetInt32(out var version) || version != 1)
            throw Invalid("Plan formatVersion must be 1.");
        var id = RequiredString(root, "id");
        if (!PlanIdPattern.IsMatch(id)) throw Invalid("Plan ID must match YYYYMMDD-lowercase-kebab-case.");
        var title = RequiredString(root, "title");
        var goal = RequiredString(root, "goal");
        var acceptance = StringArray(root, "acceptanceCriteria", true, true);
        var paths = StringArray(root, "plannedPaths", true, true).Select(path => ValidateRelativePath(path, "plannedPaths item")).ToArray();
        if (paths.Distinct(StringComparer.Ordinal).Count() != paths.Length) throw Invalid("plannedPaths contains duplicate normalized paths.");
        var areas = StringArray(root, "areas", true, false);
        var risks = StringArray(root, "risks", false, false);
        var decisions = StringArray(root, "decisions", false, false);
        var commands = StringArray(root, "validationCommands", true, true);
        var dependencies = StringArray(root, "dependencies", false, false);
        foreach (var dependency in dependencies)
            if (!PlanIdPattern.IsMatch(dependency)) throw Invalid($"Invalid dependency Plan ID: {dependency}.");
        var boundaries = StringArray(root, "boundaries", false, false);
        foreach (var boundary in boundaries)
            if (!BoundaryNames.Contains(boundary)) throw Invalid($"Unknown Plan boundary: {boundary}.");
        AssertCompatibleBoundaries(boundaries);
        return new PlanDocument(1, id, title, goal, acceptance, paths, areas, risks, decisions, commands, dependencies, boundaries);
    }

    private static void AssertCompatibleBoundaries(IEnumerable<string> values)
    {
        var set = values.ToHashSet(StringComparer.Ordinal);
        foreach (var pair in ForbiddenBoundaryPairs)
            if (set.Contains(pair.Left) && set.Contains(pair.Right))
                throw Invalid($"Forbidden co-bundling boundary combination: {pair.Left} + {pair.Right}.");
    }

    private static string RequiredString(JsonElement root, string name)
    {
        var value = root.GetProperty(name);
        if (value.ValueKind != JsonValueKind.String || string.IsNullOrEmpty(value.GetString()))
            throw Invalid($"Plan {name} must be a non-empty string.");
        return value.GetString()!;
    }

    private static string[] StringArray(JsonElement root, string name, bool nonEmpty, bool nonEmptyItems)
    {
        var value = root.GetProperty(name);
        if (value.ValueKind != JsonValueKind.Array) throw Invalid($"Plan {name} must be an array.");
        var items = new List<string>();
        foreach (var item in value.EnumerateArray())
        {
            if (item.ValueKind != JsonValueKind.String || (nonEmptyItems && string.IsNullOrEmpty(item.GetString())))
                throw Invalid($"Plan {name} contains an invalid string.");
            items.Add(item.GetString()!);
        }
        if (nonEmpty && items.Count == 0) throw Invalid($"Plan {name} must not be empty.");
        if (items.Distinct(StringComparer.Ordinal).Count() != items.Count) throw Invalid($"Plan {name} contains duplicates.");
        return items.ToArray();
    }

    private static void VerifyPlanContract(string packageRoot)
    {
        var schema = ResolveFile(packageRoot, "core/contracts/plan.schema.json", "Plan schema");
        var manifest = ResolveFile(packageRoot, "core/contracts/contracts-manifest.json", "contracts manifest");
        try
        {
            using var document = JsonDocument.Parse(File.ReadAllBytes(manifest));
            var entry = document.RootElement.GetProperty("files").EnumerateArray().SingleOrDefault(item =>
                item.GetProperty("path").GetString() == "core/contracts/plan.schema.json");
            if (entry.ValueKind == JsonValueKind.Undefined) throw Integrity("Plan schema is not registered in the contracts manifest.");
            var expected = entry.GetProperty("sha256").GetString();
            var actual = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(schema))).ToLowerInvariant();
            if (!string.Equals(expected, actual, StringComparison.Ordinal)) throw Integrity("Plan schema hash does not match the contracts manifest.");
        }
        catch (PlanException) { throw; }
        catch (Exception ex) when (ex is JsonException or IOException or InvalidOperationException)
        {
            throw Integrity($"Contracts manifest is invalid: {ex.Message}");
        }
    }

    private static string ResolveDirectory(string value, string label)
    {
        string full;
        try { full = Path.GetFullPath(value); }
        catch (Exception ex) { throw Unsafe($"{label} is invalid: {ex.Message}"); }
        if (!Directory.Exists(full)) throw Invalid($"{label} does not exist: {full}");
        EnsureNoLinks(full, label);
        return Path.TrimEndingDirectorySeparator(full);
    }

    private static string ResolveFile(string root, string relative, string label)
    {
        var full = Path.GetFullPath(Path.Combine(root, relative.Replace('/', Path.DirectorySeparatorChar)));
        if (!IsUnder(full, root) || !File.Exists(full)) throw Unsafe($"{label} escapes its root or is missing: {relative}");
        var file = new FileInfo(full);
        if ((file.Attributes & FileAttributes.ReparsePoint) != 0 || file.LinkTarget is not null) throw Unsafe($"{label} is a link or reparse point.");
        EnsureNoLinks(file.DirectoryName!, label);
        return full;
    }

    private static string ResolveOutput(string evidenceRoot, string value)
    {
        var relative = ValidateRelativePath(value, "Output path");
        var full = Path.GetFullPath(Path.Combine(evidenceRoot, relative.Replace('/', Path.DirectorySeparatorChar)));
        if (!IsUnder(full, evidenceRoot)) throw Unsafe("Output path escapes EvidenceRoot.");
        var parent = Path.GetDirectoryName(full)!;
        Directory.CreateDirectory(parent);
        EnsureNoLinks(parent, "Output path");
        if (File.Exists(full))
        {
            var file = new FileInfo(full);
            if ((file.Attributes & FileAttributes.ReparsePoint) != 0 || file.LinkTarget is not null) throw Unsafe("Output path is a link or reparse point.");
        }
        return full;
    }

    private static string ValidateRelativePath(string value, string label)
    {
        if (string.IsNullOrWhiteSpace(value) || Path.IsPathRooted(value) || Regex.IsMatch(value, "^[A-Za-z]:", RegexOptions.CultureInvariant))
            throw Unsafe($"{label} must be repository-relative.");
        var normalized = NormalizeRelative(value);
        var segments = normalized.Split('/');
        if (segments.Any(segment => segment is "" or "." or "..") || value.Contains('*') || value.Contains('?'))
            throw Unsafe($"{label} contains traversal, an empty segment or a wildcard: {value}");
        return normalized;
    }

    private static string NormalizeRelative(string value) => value.Replace('\\', '/');
    private static bool IsUnder(string path, string root)
    {
        var relative = Path.GetRelativePath(root, path);
        return relative == "." || (!Path.IsPathRooted(relative) && relative != ".." &&
            !relative.StartsWith($"..{Path.DirectorySeparatorChar}", StringComparison.Ordinal));
    }

    private static void EnsureNoLinks(string path, string label)
    {
        var current = new DirectoryInfo(path);
        while (current is not null)
        {
            if ((current.Attributes & FileAttributes.ReparsePoint) != 0 || current.LinkTarget is not null)
                throw Unsafe($"{label} crosses a link or reparse point: {current.FullName}");
            current = current.Parent;
        }
    }

    private static string[] Sorted(IEnumerable<string> values) => values.Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal).ToArray();
    private static void WriteAtomic(string path, string text)
    {
        var temporary = Path.Combine(Path.GetDirectoryName(path)!, $".{Path.GetFileName(path)}-{Guid.NewGuid():N}.tmp");
        try
        {
            File.WriteAllText(temporary, text, new UTF8Encoding(false));
            File.Move(temporary, path, true);
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }

    private static PlanException Invalid(string message) => new(10, "invalid-input", message);
    private static PlanException Unsafe(string message) => new(11, "unsafe-path", message);
    private static PlanException Integrity(string message) => new(12, "integrity-failure", message);

    private sealed record Arguments(string Operation, Dictionary<string, List<string>> Values)
    {
        public string Required(string name) => Values.TryGetValue(name, out var values) && values.Count == 1 && !string.IsNullOrWhiteSpace(values[0])
            ? values[0] : throw Invalid($"Missing --{name}.");
        public string Single(string name) => Required(name);
        public string? Optional(string name) => Values.TryGetValue(name, out var values) && values.Count == 1 && !string.IsNullOrWhiteSpace(values[0]) ? values[0] : null;
        public IReadOnlyList<string> Many(string name) => Values.TryGetValue(name, out var values) && values.All(value => !string.IsNullOrWhiteSpace(value))
            ? values : throw Invalid($"Missing --{name}.");
    }
    private sealed record PlanMember(string RelativePath, string Sha256, int ByteCount, PlanDocument Plan);
    private sealed record PlanDocument(int FormatVersion, string Id, string Title, string Goal, string[] AcceptanceCriteria, string[] PlannedPaths,
        string[] Areas, string[] Risks, string[] Decisions, string[] ValidationCommands, string[] Dependencies, string[] Boundaries);
    private sealed record PlanSetMember(int Order, string PlanId, string Path, string Sha256, string[] DependsOn);
    private sealed record DerivedUnion(string[] PlannedPaths, string[] Areas, string[] Risks, string[] Decisions,
        string[] ValidationCommands, string[] Boundaries);
    private sealed record PlanSetDocument(int FormatVersion, string Id, PlanSetMember[] Members, DerivedUnion DerivedUnion, string CompositionHash);
    internal sealed record NativePlanProjection(string Id, string Title, string Path, string Sha256);
    private sealed class PlanException(int code, string category, string message) : Exception(message)
    {
        public int Code { get; } = code;
        public string Category { get; } = category;
    }
}
