using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace V4.Guards.Host;

internal static class TargetTrustRuntime
{
    private static readonly JsonSerializerOptions Output = new() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase, WriteIndented = true };
    private static readonly Regex PlanId = new("^[0-9]{8}-[a-z0-9-]+$", RegexOptions.CultureInvariant);

    public static int Execute(string[] args)
    {
        try
        {
            var values = Parse(args, out var operation);
            var packageRoot = Directory(values.Required("package-root"), "PackageRoot");
            var targetRoot = Directory(values.Required("target-root"), "TargetRoot");
            PlanRuntime.VerifyGovernanceContract(packageRoot);
            var baseRef = Ref(values.Required("base-ref"));
            var headRef = Ref(values.Required("head-ref"));
            var policyPath = Relative(values.Required("policy"), "Policy path");
            var policyBytes = GitBytes(targetRoot, baseRef, policyPath, true)!;
            using var policyDocument = JsonDocument.Parse(policyBytes);
            var policy = ParsePolicy(policyDocument.RootElement, policyPath);

            if (operation == "authorize") return Authorize(values, packageRoot, targetRoot, baseRef, headRef, policy, policyBytes);
            return Validate(values, packageRoot, targetRoot, baseRef, headRef, policy, policyBytes);
        }
        catch (TrustException ex)
        {
            Console.Error.WriteLine(JsonSerializer.Serialize(new { formatVersion = 1, status = "error", exitCategory = ex.Category, message = ex.Message }, Output));
            return ex.Code;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(JsonSerializer.Serialize(new { formatVersion = 1, status = "error", exitCategory = "internal-error", message = ex.Message }, Output));
            return 19;
        }
    }

    private static int Authorize(Arguments values, string packageRoot, string targetRoot, string baseRef, string headRef, Policy policy, byte[] policyBytes)
    {
        var evidenceRoot = Directory(values.Required("evidence-root"), "EvidenceRoot");
        EnsureDisjoint(evidenceRoot, targetRoot, "EvidenceRoot overlaps TargetRoot.");
        var consumingPlanId = values.Required("plan-id");
        if (!PlanId.IsMatch(consumingPlanId)) throw Invalid("Consuming Plan ID is invalid.");
        var requested = values.Many("path").Select(path => Relative(path, "Authorized path")).Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal).ToArray();
        if (requested.Length == 0) throw Invalid("At least one --path is required.");
        var changed = GitNames(targetRoot, baseRef, headRef);
        if (!requested.SequenceEqual(changed.Where(path => policy.ProtectedPaths.Any(pattern => Matches(path, pattern))).Order(StringComparer.Ordinal), StringComparer.Ordinal))
            throw Findings("Authorized paths must exactly equal the protected subset of the base/head diff.");
        var entries = requested.Select(path => new AuthorizationEntry(path, HashAt(targetRoot, baseRef, path), HashAt(targetRoot, headRef, path))).ToArray();
        if (entries.Any(entry => entry.BaseSha256 is null && entry.HeadSha256 is null)) throw Invalid("Authorization entry has no add, change or delete operation.");
        var record = new
        {
            formatVersion = 1,
            id = $"{consumingPlanId}-authorization",
            planId = consumingPlanId,
            policyId = policy.Id,
            entries,
            acceptedBy = new { kind = "human-review", authority = values.Required("accepted-by"), candidateHostVerdictAllowed = false }
        };
        var outputPath = OutputPath(evidenceRoot, values.Required("output"));
        WriteAtomic(outputPath, JsonSerializer.Serialize(record, Output) + "\n");
        Console.WriteLine(JsonSerializer.Serialize(new
        {
            formatVersion = 1, status = "pass", exitCategory = "success", kind = "target-trust-authorization-candidate",
            authoritative = false, policyId = policy.Id, planId = consumingPlanId,
            output = Normalize(Path.GetRelativePath(evidenceRoot, outputPath)),
            judge = Judge(packageRoot, policyBytes)
        }, Output));
        return 0;
    }

    private static int Validate(Arguments values, string packageRoot, string targetRoot, string baseRef, string headRef, Policy policy, byte[] policyBytes)
    {
        var authorizationPath = Relative(values.Required("authorization"), "Authorization path");
        if (!Matches(authorizationPath, policy.AuthorizationDirectory.TrimEnd('/') + "/**"))
            throw Findings("Authorization record is outside the base policy authorization directory.");
        var authorizationBytes = GitBytes(targetRoot, baseRef, authorizationPath, true)!;
        if (GitBytes(targetRoot, headRef, authorizationPath, false) is not null)
            throw Findings("Consuming change must delete the single-use authorization record.");
        using var authorizationDocument = JsonDocument.Parse(authorizationBytes);
        var authorization = ParseAuthorization(authorizationDocument.RootElement);
        if (authorization.PolicyId != policy.Id) throw Findings("Authorization policy identity mismatch.");
        var planSetPath = Relative(values.Required("plan-set"), "Plan-set path");
        var planSetBytes = GitBytes(targetRoot, headRef, planSetPath, true)!;
        using var planSetDocument = JsonDocument.Parse(planSetBytes);
        var members = planSetDocument.RootElement.GetProperty("members").EnumerateArray().Select(item => item.GetProperty("planId").GetString()).ToArray();
        if (!members.Contains(authorization.PlanId, StringComparer.Ordinal)) throw Findings("Consuming Plan is not a member of the candidate Plan set.");
        var boundaries = planSetDocument.RootElement.GetProperty("derivedUnion").GetProperty("boundaries").EnumerateArray().Select(item => item.GetString()).ToArray();
        if (!boundaries.Contains("trust-change", StringComparer.Ordinal) || boundaries.Contains("authorization", StringComparer.Ordinal))
            throw Findings("Consuming Plan set must be trust-change only and cannot self-authorize.");
        var changed = GitNames(targetRoot, baseRef, headRef);
        if (!changed.Contains(authorizationPath, StringComparer.Ordinal)) throw Findings("Authorization record is not consumed by the candidate diff.");
        var protectedChanged = changed.Where(path => path != authorizationPath && policy.ProtectedPaths.Any(pattern => Matches(path, pattern))).Order(StringComparer.Ordinal).ToArray();
        var entryPaths = authorization.Entries.Select(entry => entry.Path).Order(StringComparer.Ordinal).ToArray();
        if (!protectedChanged.SequenceEqual(entryPaths, StringComparer.Ordinal)) throw Findings("Authorization entries do not exactly cover protected changed paths.");
        foreach (var entry in authorization.Entries)
        {
            if (!policy.ProtectedPaths.Any(pattern => Matches(entry.Path, pattern))) throw Findings($"Authorization contains an unprotected path: {entry.Path}");
            if (entry.BaseSha256 != HashAt(targetRoot, baseRef, entry.Path) || entry.HeadSha256 != HashAt(targetRoot, headRef, entry.Path))
                throw Findings($"Authorization hash mismatch: {entry.Path}");
        }
        Console.WriteLine(JsonSerializer.Serialize(new
        {
            formatVersion = 1, status = "pass", exitCategory = "success", kind = "target-trust-validation",
            policyId = policy.Id, authorizationId = authorization.Id, planId = authorization.PlanId,
            protectedPaths = protectedChanged, authorizationConsumed = true, applied = false,
            unperformed = new[] { "target-apply", "pull-request-delivery", "workflow-activation", "ruleset-activation", "remote-change" },
            judge = Judge(packageRoot, policyBytes)
        }, Output));
        return 0;
    }

    private static object Judge(string packageRoot, byte[] policyBytes)
    {
        var assembly = typeof(TargetTrustRuntime).Assembly.Location;
        return new
        {
            authority = "previously-trusted-v4-host",
            hostSha256 = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(assembly))).ToLowerInvariant(),
            policySha256 = Convert.ToHexString(SHA256.HashData(policyBytes)).ToLowerInvariant(),
            governanceContractSha256 = HashFile(Path.Combine(packageRoot, "core", "governance", "governance-contract.json")),
            candidateHostVerdictAllowed = false
        };
    }

    private static Arguments Parse(string[] args, out string operation)
    {
        if (args.Length < 2 || args[0] != "target-trust" || args[1] is not ("authorize" or "validate")) throw Invalid("Expected 'target-trust authorize' or 'target-trust validate'.");
        operation = args[1];
        var values = new Dictionary<string, List<string>>(StringComparer.Ordinal);
        for (var index = 2; index < args.Length; index += 2)
        {
            if (index + 1 >= args.Length || !args[index].StartsWith("--", StringComparison.Ordinal)) throw Invalid("Arguments must be --name value pairs.");
            var name = args[index][2..];
            if (!values.TryGetValue(name, out var list)) values[name] = list = [];
            list.Add(args[index + 1]);
        }
        var known = operation == "authorize"
            ? new HashSet<string>(["package-root", "target-root", "evidence-root", "policy", "plan-id", "base-ref", "head-ref", "path", "accepted-by", "output"], StringComparer.Ordinal)
            : new HashSet<string>(["package-root", "target-root", "policy", "authorization", "plan-set", "base-ref", "head-ref"], StringComparer.Ordinal);
        var unknown = values.Keys.FirstOrDefault(key => !known.Contains(key));
        if (unknown is not null) throw Invalid($"Unknown argument: --{unknown}");
        foreach (var pair in values.Where(pair => pair.Key != "path" && pair.Value.Count != 1)) throw Invalid($"Duplicate argument: --{pair.Key}");
        return new Arguments(values);
    }

    private static Policy ParsePolicy(JsonElement root, string path)
    {
        try
        {
            ExactProperties(root, ["formatVersion", "id", "authorizationDirectory", "protectedPaths"]);
            if (root.GetProperty("formatVersion").GetInt32() != 1) throw new JsonException("formatVersion");
            var id = Required(root, "id");
            var directory = Relative(Required(root, "authorizationDirectory"), "Authorization directory");
            var protectedPaths = root.GetProperty("protectedPaths").EnumerateArray().Select(item => item.GetString() ?? "").ToArray();
            if (protectedPaths.Length == 0 || protectedPaths.Any(item => string.IsNullOrWhiteSpace(item) || item.Contains(".."))) throw new JsonException("protectedPaths");
            if (!protectedPaths.Contains(path, StringComparer.Ordinal)) throw Findings("Base policy must protect its own path.");
            return new Policy(id, directory, protectedPaths);
        }
        catch (TrustException) { throw; }
        catch (Exception ex) when (ex is JsonException or InvalidOperationException or KeyNotFoundException) { throw Integrity($"Target trust policy is invalid: {ex.Message}"); }
    }

    private static Authorization ParseAuthorization(JsonElement root)
    {
        try
        {
            ExactProperties(root, ["formatVersion", "id", "planId", "policyId", "entries", "acceptedBy"]);
            if (root.GetProperty("formatVersion").GetInt32() != 1) throw new JsonException("formatVersion");
            var entries = root.GetProperty("entries").EnumerateArray().Select(item =>
            {
                ExactProperties(item, ["path", "baseSha256", "headSha256"]);
                return new AuthorizationEntry(Relative(Required(item, "path"), "Authorization entry"), NullableHash(item, "baseSha256"), NullableHash(item, "headSha256"));
            }).ToArray();
            if (entries.Length == 0 || entries.Select(entry => entry.Path).Distinct(StringComparer.Ordinal).Count() != entries.Length) throw new JsonException("entries");
            var accepted = root.GetProperty("acceptedBy");
            ExactProperties(accepted, ["kind", "authority", "candidateHostVerdictAllowed"]);
            if (Required(accepted, "kind") != "human-review" || string.IsNullOrWhiteSpace(Required(accepted, "authority")) || accepted.GetProperty("candidateHostVerdictAllowed").GetBoolean()) throw new JsonException("acceptedBy");
            var id = Required(root, "id"); var planId = Required(root, "planId");
            if (!PlanId.IsMatch(id) || !PlanId.IsMatch(planId)) throw new JsonException("id");
            return new Authorization(id, planId, Required(root, "policyId"), entries);
        }
        catch (Exception ex) when (ex is JsonException or InvalidOperationException or KeyNotFoundException) { throw Integrity($"Target trust authorization is invalid: {ex.Message}"); }
    }

    private static string? NullableHash(JsonElement root, string name)
    {
        var value = root.GetProperty(name);
        if (value.ValueKind == JsonValueKind.Null) return null;
        var hash = value.GetString();
        if (hash is null || !Regex.IsMatch(hash, "^[a-f0-9]{64}$")) throw new JsonException(name);
        return hash;
    }

    private static string[] GitNames(string repository, string baseRef, string headRef) => Git(repository, ["diff", "--name-only", "--no-renames", "-z", $"{baseRef}...{headRef}", "--"])
        .Split('\0', StringSplitOptions.RemoveEmptyEntries).Select(Normalize).Order(StringComparer.Ordinal).ToArray();
    private static byte[]? GitBytes(string repository, string reference, string path, bool required)
    {
        var result = GitRaw(repository, ["show", $"{reference}:{path}"], false);
        if (result.Code == 0) return result.Stdout;
        if (required) throw Integrity($"Required base/head object is missing: {reference}:{path}");
        return null;
    }
    private static string? HashAt(string repository, string reference, string path)
    {
        var bytes = GitBytes(repository, reference, path, false);
        return bytes is null ? null : Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();
    }
    private static string Git(string repository, string[] arguments)
    {
        var result = GitRaw(repository, arguments, true);
        return Encoding.UTF8.GetString(result.Stdout);
    }
    private static GitResult GitRaw(string repository, string[] arguments, bool required)
    {
        var start = new ProcessStartInfo("git") { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true };
        start.ArgumentList.Add("-C"); start.ArgumentList.Add(repository); start.ArgumentList.Add("-c"); start.ArgumentList.Add("core.quotepath=false");
        foreach (var argument in arguments) start.ArgumentList.Add(argument);
        using var process = Process.Start(start) ?? throw Integrity("Git did not start.");
        using var memory = new MemoryStream();
        var stdout = process.StandardOutput.BaseStream.CopyToAsync(memory);
        var stderr = process.StandardError.ReadToEndAsync();
        if (!process.WaitForExit(30000)) { process.Kill(true); throw Invalid("Git operation timed out."); }
        Task.WaitAll(stdout, stderr);
        if (required && process.ExitCode != 0) throw Integrity($"Git operation failed: {stderr.Result.Trim()}");
        return new GitResult(process.ExitCode, memory.ToArray());
    }

    private static bool Matches(string path, string pattern)
    {
        if (pattern.EndsWith("/**", StringComparison.Ordinal)) return path.StartsWith(pattern[..^3].TrimEnd('/') + "/", StringComparison.Ordinal);
        return string.Equals(path, pattern, StringComparison.Ordinal);
    }
    private static string Directory(string value, string label) { var full = Path.GetFullPath(value); if (!System.IO.Directory.Exists(full)) throw Invalid($"{label} does not exist: {full}"); NoLinks(full, label); return Path.TrimEndingDirectorySeparator(full); }
    private static string Relative(string value, string label) { if (string.IsNullOrWhiteSpace(value) || Path.IsPathRooted(value) || Regex.IsMatch(value, "^[A-Za-z]:") || value.Contains('*') || value.Contains('?')) throw Unsafe($"{label} must be an exact relative path."); var path = Normalize(value); if (path.Split('/').Any(part => part is "" or "." or "..")) throw Unsafe($"{label} is unsafe."); return path; }
    private static string OutputPath(string root, string value) { var relative = Relative(value, "Output path"); var full = Path.GetFullPath(Path.Combine(root, relative.Replace('/', Path.DirectorySeparatorChar))); if (!Under(full, root)) throw Unsafe("Output escapes EvidenceRoot."); System.IO.Directory.CreateDirectory(Path.GetDirectoryName(full)!); NoLinks(Path.GetDirectoryName(full)!, "Output"); return full; }
    private static void EnsureDisjoint(string left, string right, string message) { if (Under(left, right) || Under(right, left)) throw Unsafe(message); }
    private static bool Under(string path, string root) { var relative = Path.GetRelativePath(root, path); return relative == "." || (!Path.IsPathRooted(relative) && relative != ".." && !relative.StartsWith($"..{Path.DirectorySeparatorChar}", StringComparison.Ordinal)); }
    private static void NoLinks(string path, string label) { for (var current = new DirectoryInfo(path); current is not null; current = current.Parent) if ((current.Attributes & FileAttributes.ReparsePoint) != 0 || current.LinkTarget is not null) throw Unsafe($"{label} crosses a link: {current.FullName}"); }
    private static string Ref(string value) { if (!Regex.IsMatch(value, "^[A-Za-z0-9][A-Za-z0-9._/-]*$") || value.Contains("..") || value.Contains("//")) throw Unsafe($"Unsafe Git ref: {value}"); return value; }
    private static string Required(JsonElement root, string name) { var value = root.GetProperty(name); return value.ValueKind == JsonValueKind.String && !string.IsNullOrWhiteSpace(value.GetString()) ? value.GetString()! : throw new JsonException(name); }
    private static void ExactProperties(JsonElement root, string[] expected) { if (root.ValueKind != JsonValueKind.Object) throw new JsonException("object"); var actual = root.EnumerateObject().Select(item => item.Name).ToArray(); if (actual.Length != expected.Length || actual.Distinct(StringComparer.Ordinal).Count() != actual.Length || expected.Any(name => !actual.Contains(name, StringComparer.Ordinal))) throw new JsonException("unknown or missing property"); }
    private static string Normalize(string value) => value.Replace('\\', '/');
    private static string HashFile(string path) => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path))).ToLowerInvariant();
    private static void WriteAtomic(string path, string text) { var temporary = Path.Combine(Path.GetDirectoryName(path)!, $".{Path.GetFileName(path)}-{Guid.NewGuid():N}.tmp"); try { File.WriteAllText(temporary, text, new UTF8Encoding(false)); File.Move(temporary, path, true); } finally { if (File.Exists(temporary)) File.Delete(temporary); } }
    private static TrustException Invalid(string message) => new(10, "invalid-input", message);
    private static TrustException Unsafe(string message) => new(11, "unsafe-path", message);
    private static TrustException Integrity(string message) => new(12, "integrity-failure", message);
    private static TrustException Findings(string message) => new(16, "findings-blocking", message);

    private sealed record Arguments(Dictionary<string, List<string>> Values)
    {
        public string Required(string name) => Values.TryGetValue(name, out var values) && values.Count == 1 && !string.IsNullOrWhiteSpace(values[0]) ? values[0] : throw Invalid($"Missing --{name}.");
        public IReadOnlyList<string> Many(string name) => Values.TryGetValue(name, out var values) ? values : [];
    }
    private sealed record Policy(string Id, string AuthorizationDirectory, string[] ProtectedPaths);
    private sealed record Authorization(string Id, string PlanId, string PolicyId, AuthorizationEntry[] Entries);
    private sealed record AuthorizationEntry(string Path, string? BaseSha256, string? HeadSha256);
    private sealed record GitResult(int Code, byte[] Stdout);
    private sealed class TrustException(int code, string category, string message) : Exception(message) { public int Code { get; } = code; public string Category { get; } = category; }
}
