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

    public static int Execute(string[] args)
    {
        try
        {
            var options = ParseArguments(args);
            var packageRoot = ResolveDirectory(options.Required("package-root"), "PackageRoot");
            var targetRoot = ResolveDirectory(options.Required("target-root"), "TargetRoot");
            VerifyPlanContract(packageRoot);

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

            var evidenceRoot = ResolveDirectory(options.Required("evidence-root"), "EvidenceRoot");
            var planSetId = options.Required("id");
            if (!PlanIdPattern.IsMatch(planSetId))
                throw Invalid("Plan-set ID must match YYYYMMDD-lowercase-kebab-case.");
            var planArguments = options.Many("plan");
            if (planArguments.Count < 2) throw Invalid("Plan composition requires at least two --plan arguments.");
            var outputPath = ResolveOutput(evidenceRoot, options.Required("output"));
            var members = planArguments.Select(path => LoadPlan(targetRoot, path)).ToArray();
            var planSet = Compose(planSetId, members);
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
        if (args.Length < 2 || args[0] != "plan" || args[1] is not ("validate" or "compose"))
            throw Invalid("Expected 'plan validate' or 'plan compose'.");
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
        var known = operation == "validate"
            ? new HashSet<string>(["package-root", "target-root", "plan"], StringComparer.Ordinal)
            : new HashSet<string>(["package-root", "target-root", "evidence-root", "id", "plan", "output"], StringComparer.Ordinal);
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
        var canonical = JsonSerializer.SerializeToUtf8Bytes(
            new { formatVersion = 1, id, members = memberDocuments, derivedUnion = union }, CanonicalOptions);
        var compositionHash = Convert.ToHexString(SHA256.HashData(canonical)).ToLowerInvariant();
        return new PlanSetDocument(1, id, memberDocuments, union, compositionHash);
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
        JsonDocument document;
        try { document = JsonDocument.Parse(bytes, new JsonDocumentOptions { AllowTrailingCommas = false, CommentHandling = JsonCommentHandling.Disallow }); }
        catch (JsonException ex) { throw Invalid($"Plan JSON is invalid: {ex.Message}"); }
        using (document)
        {
            var plan = ValidatePlanDocument(document.RootElement);
            return new PlanMember(relative, Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant(), plan);
        }
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
        return new PlanDocument(id, title, goal, acceptance, paths, areas, risks, decisions, commands, dependencies, boundaries);
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
        public IReadOnlyList<string> Many(string name) => Values.TryGetValue(name, out var values) && values.All(value => !string.IsNullOrWhiteSpace(value))
            ? values : throw Invalid($"Missing --{name}.");
    }
    private sealed record PlanMember(string RelativePath, string Sha256, PlanDocument Plan);
    private sealed record PlanDocument(string Id, string Title, string Goal, string[] AcceptanceCriteria, string[] PlannedPaths,
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
