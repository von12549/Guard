using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace V4.Guards.Host;

internal static class StateRuntime
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    public static int Execute(string[] args)
    {
        try
        {
            if (args.Length < 2 || args[0] != "state")
                throw new StateException(10, "invalid-input", "Expected a state command.");
            var values = ParsePairs(args, 2);
            var result = args[1] switch
            {
                "bind" => Bind(values),
                "put" => Put(values),
                "recover" => RecoverCommand(values),
                _ => throw new StateException(10, "invalid-input", $"Unknown state command: {args[1]}")
            };
            Console.WriteLine(JsonSerializer.Serialize(result, JsonOptions));
            return 0;
        }
        catch (StateException ex)
        {
            Console.Error.WriteLine(JsonSerializer.Serialize(new { formatVersion = 1, status = "error", exitCategory = ex.Category, message = ex.Message }, JsonOptions));
            return ex.Code;
        }
        catch (Exception ex)
        {
            Console.Error.WriteLine(JsonSerializer.Serialize(new { formatVersion = 1, status = "error", exitCategory = "internal-error", message = ex.Message }, JsonOptions));
            return 19;
        }
    }

    private static object Bind(Dictionary<string, string> values)
    {
        RequireOnly(values, "package-root", "target-root", "state-root", "evidence-root", "profile");
        var roots = ResolveRoots(values, true);
        var profile = Required(values, "profile");
        if (!Regex.IsMatch(profile, "^[a-z][a-z0-9_-]*$", RegexOptions.CultureInvariant))
            throw new StateException(10, "invalid-input", "Profile ID is invalid.");

        var recovered = RecoverPrepared(roots.StateRoot);
        var state = LoadState(roots.StateRoot);
        var identityHash = HashText(CanonicalIdentity(roots.TargetRoot!));
        var projectId = identityHash[..32];
        var existing = state.ProjectInstances.SingleOrDefault(item => item.Id == projectId);
        var created = false;
        if (existing is null)
        {
            if (state.ProjectInstances.Any(item => PathEquals(item.TargetCanonicalPath, roots.TargetRoot!)))
                throw new StateException(17, "state-conflict", "TargetRoot is already bound under a different project identity.");
            Directory.CreateDirectory(Path.Combine(roots.StateRoot, "projects", projectId, "data"));
            Directory.CreateDirectory(Path.Combine(roots.EvidenceRoot, "projects", projectId));
            state.ProjectInstances.Add(new ProjectInstance(projectId, roots.TargetRoot!, identityHash, profile,
                [$"projects/{projectId}"], [$"projects/{projectId}"]));
            SaveState(roots.StateRoot, state);
            created = true;
        }
        else if (!PathEquals(existing.TargetCanonicalPath, roots.TargetRoot!) || existing.TargetIdentityHash != identityHash)
        {
            throw new StateException(17, "state-conflict", "Project identity collision or canonical target drift.");
        }

        return new { formatVersion = 1, status = "pass", command = "state.bind", projectId, created, recoveredTransactions = recovered, roots };
    }

    private static object Put(Dictionary<string, string> values)
    {
        RequireOnly(values, "package-root", "state-root", "evidence-root", "project", "relative-path", "content");
        var roots = ResolveRoots(values, false);
        var recovered = RecoverPrepared(roots.StateRoot);
        var state = LoadState(roots.StateRoot);
        var projectId = Required(values, "project");
        if (!Regex.IsMatch(projectId, "^[a-f0-9]{32}$", RegexOptions.CultureInvariant) || state.ProjectInstances.All(item => item.Id != projectId))
            throw new StateException(10, "invalid-input", "Project is not bound.");
        var relative = NormalizeRelative(Required(values, "relative-path"), "state data path");
        var projectData = Path.Combine(roots.StateRoot, "projects", projectId, "data");
        var destination = ResolveForWrite(projectData, relative, "state data path");
        Directory.CreateDirectory(Path.GetDirectoryName(destination)!);
        EnsureNoLinks(roots.StateRoot, Path.GetDirectoryName(destination)!, "state data path");
        var payload = new UTF8Encoding(false).GetBytes(Required(values, "content"));
        var transaction = AtomicWrite(roots.StateRoot, destination, payload, "state-write", projectId);
        state.Transactions.Add(new TransactionSummary(transaction.Id, transaction.Kind, "applied", transaction.PayloadHash, projectId));
        SaveState(roots.StateRoot, state);
        return new { formatVersion = 1, status = "pass", command = "state.put", projectId, path = relative, transactionId = transaction.Id, recoveredTransactions = recovered };
    }

    private static object RecoverCommand(Dictionary<string, string> values)
    {
        RequireOnly(values, "package-root", "state-root", "evidence-root");
        var roots = ResolveRoots(values, false);
        var recovered = RecoverPrepared(roots.StateRoot);
        return new { formatVersion = 1, status = "pass", command = "state.recover", recoveredTransactions = recovered };
    }

    private static Dictionary<string, string> ParsePairs(string[] args, int start)
    {
        var values = new Dictionary<string, string>(StringComparer.Ordinal);
        for (var index = start; index < args.Length; index += 2)
        {
            if (index + 1 >= args.Length || !args[index].StartsWith("--", StringComparison.Ordinal))
                throw new StateException(10, "invalid-input", "Arguments must be --name value pairs.");
            if (!values.TryAdd(args[index][2..], args[index + 1]))
                throw new StateException(10, "invalid-input", $"Duplicate argument: {args[index]}");
        }
        return values;
    }

    private static void RequireOnly(Dictionary<string, string> values, params string[] names)
    {
        var known = new HashSet<string>(names, StringComparer.Ordinal);
        var unknown = values.Keys.FirstOrDefault(key => !known.Contains(key));
        if (unknown is not null) throw new StateException(10, "invalid-input", $"Unknown argument: --{unknown}");
        foreach (var name in names) Required(values, name);
    }

    private static string Required(Dictionary<string, string> values, string name) =>
        values.TryGetValue(name, out var value) && !string.IsNullOrWhiteSpace(value)
            ? value : throw new StateException(10, "invalid-input", $"Missing --{name}.");

    private static StateRoots ResolveRoots(Dictionary<string, string> values, bool targetRequired)
    {
        var package = ResolveExistingDirectory(Required(values, "package-root"), "PackageRoot");
        var state = ResolveExistingDirectory(Required(values, "state-root"), "StateRoot");
        var evidence = ResolveExistingDirectory(Required(values, "evidence-root"), "EvidenceRoot");
        var target = targetRequired ? ResolveExistingDirectory(Required(values, "target-root"), "TargetRoot") : null;
        foreach (var mutable in new[] { ("StateRoot", state), ("EvidenceRoot", evidence) })
        {
            if (Overlaps(mutable.Item2, package)) throw new StateException(11, "unsafe-path", $"{mutable.Item1} overlaps PackageRoot.");
            if (target is not null && Overlaps(mutable.Item2, target)) throw new StateException(11, "unsafe-path", $"{mutable.Item1} overlaps TargetRoot.");
        }
        if (Overlaps(state, evidence)) throw new StateException(11, "unsafe-path", "StateRoot and EvidenceRoot overlap.");
        return new StateRoots(package, target, state, evidence);
    }

    private static string ResolveExistingDirectory(string value, string label)
    {
        string full;
        try { full = Path.TrimEndingDirectorySeparator(Path.GetFullPath(value)); }
        catch (Exception ex) { throw new StateException(11, "unsafe-path", $"{label} is invalid: {ex.Message}"); }
        if (!Directory.Exists(full)) throw new StateException(10, "invalid-input", $"{label} does not exist: {full}");
        EnsureNoLinks(Path.GetPathRoot(full)!, full, label);
        return full;
    }

    private static string ResolveForWrite(string root, string relative, string label)
    {
        var full = Path.GetFullPath(Path.Combine(root, relative));
        if (!IsUnder(full, root)) throw new StateException(11, "unsafe-path", $"{label} escapes its claimed root.");
        var existing = full;
        while (!File.Exists(existing) && !Directory.Exists(existing))
            existing = Path.GetDirectoryName(existing) ?? throw new StateException(11, "unsafe-path", $"{label} has no existing ancestor.");
        EnsureNoLinks(root, existing, label);
        return full;
    }

    private static string NormalizeRelative(string value, string label)
    {
        if (Path.IsPathRooted(value)) throw new StateException(11, "unsafe-path", $"{label} must be relative.");
        var normalized = value.Replace('\\', '/').Trim('/');
        if (normalized.Length == 0 || normalized.Split('/').Any(part => part is "" or "." or ".."))
            throw new StateException(11, "unsafe-path", $"{label} contains traversal or an empty segment.");
        return normalized;
    }

    private static void EnsureNoLinks(string root, string path, string label)
    {
        var current = new FileInfo(path) as FileSystemInfo;
        if (Directory.Exists(path)) current = new DirectoryInfo(path);
        while (current is not null && IsUnder(current.FullName, root))
        {
            if ((current.Attributes & FileAttributes.ReparsePoint) != 0 || current.LinkTarget is not null)
                throw new StateException(11, "unsafe-path", $"{label} crosses a link or reparse point: {current.FullName}");
            if (PathEquals(current.FullName, root)) break;
            current = current is FileInfo file ? file.Directory : ((DirectoryInfo)current).Parent;
        }
    }

    private static bool Overlaps(string left, string right) => IsUnder(left, right) || IsUnder(right, left);
    private static bool IsUnder(string path, string root)
    {
        var relative = Path.GetRelativePath(root, path);
        return relative == "." || (!Path.IsPathRooted(relative) && relative != ".." && !relative.StartsWith($"..{Path.DirectorySeparatorChar}", StringComparison.Ordinal));
    }
    private static bool PathEquals(string left, string right) => string.Equals(Path.GetFullPath(left), Path.GetFullPath(right), OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal);
    private static string CanonicalIdentity(string path) => OperatingSystem.IsWindows() ? path.ToUpperInvariant() : path;
    private static string HashText(string text) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(text))).ToLowerInvariant();
    private static string HashBytes(byte[] bytes) => Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();

    private static StateDocument LoadState(string stateRoot)
    {
        var path = Path.Combine(stateRoot, "state.json");
        if (!File.Exists(path)) return new StateDocument(1, [], [], []);
        EnsureNoLinks(stateRoot, path, "state document");
        try { return JsonSerializer.Deserialize<StateDocument>(File.ReadAllText(path), JsonOptions) ?? throw new JsonException("State is empty."); }
        catch (Exception ex) when (ex is JsonException or IOException) { throw new StateException(17, "state-conflict", $"State document is invalid: {ex.Message}"); }
    }

    private static void SaveState(string stateRoot, StateDocument state)
    {
        var payload = new UTF8Encoding(false).GetBytes(JsonSerializer.Serialize(state, JsonOptions) + Environment.NewLine);
        AtomicWrite(stateRoot, Path.Combine(stateRoot, "state.json"), payload, "state-document", null);
    }

    private static TransactionJournal AtomicWrite(string stateRoot, string destination, byte[] payload, string kind, string? projectId)
    {
        var id = Guid.NewGuid().ToString("N");
        var destinationRelative = Path.GetRelativePath(stateRoot, destination).Replace('\\', '/');
        if (!IsUnder(destination, stateRoot)) throw new StateException(11, "unsafe-path", "Transaction destination escapes StateRoot.");
        Directory.CreateDirectory(Path.GetDirectoryName(destination)!);
        var temp = Path.Combine(Path.GetDirectoryName(destination)!, $".v4-tx-{id}.tmp");
        File.WriteAllBytes(temp, payload);
        var journal = new TransactionJournal(1, id, kind, "prepared", projectId, destinationRelative,
            Path.GetRelativePath(stateRoot, temp).Replace('\\', '/'), HashBytes(payload));
        WriteJournal(stateRoot, journal);
        File.Move(temp, destination, true);
        journal = journal with { Status = "applied" };
        WriteJournal(stateRoot, journal);
        return journal;
    }

    private static void WriteJournal(string stateRoot, TransactionJournal journal)
    {
        var directory = Path.Combine(stateRoot, "transactions");
        Directory.CreateDirectory(directory);
        var path = Path.Combine(directory, $"{journal.Id}.json");
        var temp = Path.Combine(directory, $".{journal.Id}-{Guid.NewGuid():N}.tmp");
        File.WriteAllText(temp, JsonSerializer.Serialize(journal, JsonOptions) + Environment.NewLine, new UTF8Encoding(false));
        File.Move(temp, path, true);
    }

    private static int RecoverPrepared(string stateRoot)
    {
        var directory = Path.Combine(stateRoot, "transactions");
        if (!Directory.Exists(directory)) return 0;
        EnsureNoLinks(stateRoot, directory, "transaction journal directory");
        var recovered = 0;
        var failures = new List<string>();
        foreach (var path in Directory.EnumerateFiles(directory, "*.json").Order(StringComparer.Ordinal))
        {
            TransactionJournal journal;
            try
            {
                EnsureNoLinks(stateRoot, path, "transaction journal");
                journal = JsonSerializer.Deserialize<TransactionJournal>(File.ReadAllText(path), JsonOptions) ?? throw new JsonException("Journal is empty.");
            }
            catch (Exception ex) { failures.Add($"invalid journal {Path.GetFileName(path)}: {ex.Message}"); continue; }
            if (journal.Status != "prepared") continue;
            try
            {
                var destination = ResolveForWrite(stateRoot, NormalizeRelative(journal.DestinationPath, "transaction destination"), "transaction destination");
                var temp = ResolveForWrite(stateRoot, NormalizeRelative(journal.TempPath, "transaction temp"), "transaction temp");
                if (File.Exists(destination) && HashBytes(File.ReadAllBytes(destination)) == journal.PayloadHash)
                {
                    if (File.Exists(temp)) File.Delete(temp);
                }
                else if (File.Exists(temp) && HashBytes(File.ReadAllBytes(temp)) == journal.PayloadHash)
                {
                    Directory.CreateDirectory(Path.GetDirectoryName(destination)!);
                    File.Move(temp, destination, true);
                }
                else
                {
                    WriteJournal(stateRoot, journal with { Status = "incomplete" });
                    failures.Add($"transaction {journal.Id} payload is missing or has hash drift");
                    continue;
                }
                WriteJournal(stateRoot, journal with { Status = "applied" });
                recovered++;
            }
            catch (StateException ex)
            {
                WriteJournal(stateRoot, journal with { Status = "incomplete" });
                failures.Add($"transaction {journal.Id}: {ex.Message}");
            }
        }
        if (failures.Count > 0) throw new StateException(17, "state-conflict", string.Join("; ", failures));
        return recovered;
    }

    private sealed record StateRoots(string PackageRoot, string? TargetRoot, string StateRoot, string EvidenceRoot);
    private sealed record StateDocument(int FormatVersion, List<ProjectInstance> ProjectInstances, List<TransactionSummary> Transactions, List<ResetReceipt> ResetReceipts);
    private sealed record ProjectInstance(string Id, string TargetCanonicalPath, string TargetIdentityHash, string ProfileId, string[] ClaimedStatePaths, string[] ClaimedEvidencePaths);
    private sealed record TransactionSummary(string Id, string Kind, string Status, string ManifestHash, string? ProjectId);
    private sealed record ResetReceipt(string Id, string Mode, string AcceptedManifestHash, string BeforeHash, string AfterHash);
    private sealed record TransactionJournal(int FormatVersion, string Id, string Kind, string Status, string? ProjectId, string DestinationPath, string TempPath, string PayloadHash);
    private sealed class StateException(int code, string category, string message) : Exception(message)
    {
        public int Code { get; } = code;
        public string Category { get; } = category;
    }
}
