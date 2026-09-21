using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace V4.Guards.Host;

internal static class StateRuntime
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true
    };

    public static int Execute(string[] args)
    {
        try
        {
            if (args.Length < 2 || args[0] is not ("state" or "reset"))
                throw new StateException(10, "invalid-input", "Expected a state or reset command.");
            var values = ParsePairs(args, 2);
            var result = args[0] == "reset" ? Reset(args[1], values) : args[1] switch
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

    private static object Reset(string scope, Dictionary<string, string> values)
    {
        if (scope is not ("project" or "factory")) throw new StateException(10, "invalid-input", "Reset scope must be project or factory.");
        RejectUnknown(values, "mode", "package-root", "state-root", "evidence-root", "project", "accept-manifest-hash");
        var mode = Required(values, "mode");
        if (mode is not ("preview" or "apply")) throw new StateException(10, "invalid-input", "Reset mode must be preview or apply.");
        var roots = ResolveRoots(values, false);
        RecoverPrepared(roots.StateRoot);
        var state = LoadState(roots.StateRoot);
        var projectId = scope == "project" ? Required(values, "project") : null;
        if (projectId is not null && !Regex.IsMatch(projectId, "^[a-f0-9]{32}$", RegexOptions.CultureInvariant))
            throw new StateException(10, "invalid-input", "Project ID is invalid.");

        if (mode == "preview")
        {
            if (values.ContainsKey("accept-manifest-hash")) throw new StateException(10, "invalid-input", "Preview does not accept a manifest hash.");
            var manifest = BuildResetManifest(scope, projectId, roots, state);
            var previewPath = Path.Combine(roots.EvidenceRoot, ".reset", "previews", $"{manifest.ManifestHash}.json");
            WriteEvidenceAtomic(roots.EvidenceRoot, previewPath, JsonSerializer.Serialize(manifest, JsonOptions) + Environment.NewLine);
            return new { formatVersion = 1, status = "pass", command = $"reset.{scope}.preview", manifestHash = manifest.ManifestHash, manifestPath = previewPath, entries = manifest.Entries.Count, beforeHash = manifest.BeforeHash, expectedAfterHash = manifest.ExpectedAfterHash };
        }

        var acceptedHash = Required(values, "accept-manifest-hash");
        if (!Regex.IsMatch(acceptedHash, "^[a-f0-9]{64}$", RegexOptions.CultureInvariant))
            throw new StateException(10, "invalid-input", "Accepted manifest hash is invalid.");
        var existingReceipt = state.ResetReceipts.SingleOrDefault(receipt => receipt.AcceptedManifestHash == acceptedHash && receipt.Mode == scope);
        if (existingReceipt is not null)
            return new { formatVersion = 1, status = "pass", command = $"reset.{scope}.apply", manifestHash = acceptedHash, receiptId = existingReceipt.Id, idempotent = true };

        var previewFile = Path.Combine(roots.EvidenceRoot, ".reset", "previews", $"{acceptedHash}.json");
        if (!File.Exists(previewFile)) throw new StateException(18, "reset-refused", "Accepted reset preview does not exist.");
        EnsureNoLinks(roots.EvidenceRoot, previewFile, "reset preview");
        ResetManifest accepted;
        try { accepted = JsonSerializer.Deserialize<ResetManifest>(File.ReadAllText(previewFile), JsonOptions) ?? throw new JsonException("Preview is empty."); }
        catch (Exception ex) { throw new StateException(18, "reset-refused", $"Reset preview is invalid: {ex.Message}"); }
        if (accepted.ManifestHash != acceptedHash || accepted.Mode != scope || accepted.ProjectId != projectId)
            throw new StateException(18, "reset-refused", "Reset preview identity does not match the apply request.");

        var current = BuildResetManifest(scope, projectId, roots, state);
        if (current.ManifestHash != acceptedHash)
            throw new StateException(18, "reset-refused", "Reset claims changed after preview; create and accept a new preview.");
        DeleteResetEntries(current, roots);

        var affectedIds = scope == "project" ? [projectId!] : state.ProjectInstances.Select(item => item.Id).ToArray();
        state.ProjectInstances.RemoveAll(item => affectedIds.Contains(item.Id, StringComparer.Ordinal));
        var receiptId = acceptedHash[..32];
        state.Transactions.Add(new TransactionSummary(receiptId, scope == "project" ? "project-reset" : "factory-reset", "applied", acceptedHash, projectId));
        state.ResetReceipts.Add(new ResetReceipt(receiptId, scope, acceptedHash, current.BeforeHash, current.ExpectedAfterHash));
        SaveState(roots.StateRoot, state);

        var receiptPath = Path.Combine(roots.EvidenceRoot, ".reset", "receipts", $"{acceptedHash}.json");
        var receiptDocument = new { formatVersion = 1, id = receiptId, mode = scope, projectId, acceptedManifestHash = acceptedHash, beforeHash = current.BeforeHash, afterHash = current.ExpectedAfterHash, deletedEntries = current.Entries.Count };
        WriteEvidenceAtomic(roots.EvidenceRoot, receiptPath, JsonSerializer.Serialize(receiptDocument, JsonOptions) + Environment.NewLine);
        return new { formatVersion = 1, status = "pass", command = $"reset.{scope}.apply", manifestHash = acceptedHash, receiptId, receiptPath, idempotent = false, deletedEntries = current.Entries.Count };
    }

    private static ResetManifest BuildResetManifest(string mode, string? projectId, StateRoots roots, StateDocument state)
    {
        var instances = mode == "project"
            ? state.ProjectInstances.Where(item => item.Id == projectId).ToArray()
            : state.ProjectInstances.ToArray();
        if (mode == "project" && instances.Length != 1) throw new StateException(18, "reset-refused", "Project is not bound.");
        var entries = new List<ResetEntry>();
        foreach (var instance in instances)
        {
            foreach (var claim in instance.ClaimedStatePaths) CollectClaim(entries, "state", roots.StateRoot, claim, instance.Id);
            foreach (var claim in instance.ClaimedEvidencePaths) CollectClaim(entries, "evidence", roots.EvidenceRoot, claim, instance.Id);
        }
        entries = entries.OrderBy(entry => entry.Root, StringComparer.Ordinal).ThenBy(entry => entry.Path, StringComparer.Ordinal).ThenBy(entry => entry.Type, StringComparer.Ordinal).ToList();
        var identity = string.Join("\n", entries.Select(entry => $"{entry.Root}|{entry.Path}|{entry.Type}|{entry.Sha256}"));
        var beforeHash = HashText(identity);
        var expectedAfterHash = HashText(string.Empty);
        var core = new ResetManifestCore(1, mode, projectId, entries, beforeHash, expectedAfterHash);
        var manifestHash = HashText(JsonSerializer.Serialize(core, JsonOptions));
        return new ResetManifest(core.FormatVersion, core.Mode, core.ProjectId, core.Entries, core.BeforeHash, core.ExpectedAfterHash, manifestHash);
    }

    private static void CollectClaim(List<ResetEntry> entries, string rootName, string root, string claim, string projectId)
    {
        var normalized = NormalizeRelative(claim, "reset claim");
        if (normalized != $"projects/{projectId}") throw new StateException(18, "reset-refused", $"Reset claim is not the canonical project claim: {claim}");
        var full = ResolveForWrite(root, normalized, "reset claim");
        if (!Directory.Exists(full)) throw new StateException(18, "reset-refused", $"Claimed reset root is missing: {rootName}:{normalized}");
        CollectDirectory(entries, rootName, root, new DirectoryInfo(full));
    }

    private static void CollectDirectory(List<ResetEntry> entries, string rootName, string root, DirectoryInfo directory)
    {
        RejectResetLinkOrGit(directory);
        var relative = Path.GetRelativePath(root, directory.FullName).Replace('\\', '/');
        entries.Add(new ResetEntry(rootName, relative, "directory", null));
        foreach (var item in directory.EnumerateFileSystemInfos().OrderBy(item => item.Name, StringComparer.Ordinal))
        {
            RejectResetLinkOrGit(item);
            if (item is DirectoryInfo child) CollectDirectory(entries, rootName, root, child);
            else
            {
                var file = (FileInfo)item;
                entries.Add(new ResetEntry(rootName, Path.GetRelativePath(root, file.FullName).Replace('\\', '/'), "file", HashBytes(File.ReadAllBytes(file.FullName))));
            }
        }
    }

    private static void RejectResetLinkOrGit(FileSystemInfo item)
    {
        if ((item.Attributes & FileAttributes.ReparsePoint) != 0 || item.LinkTarget is not null)
            throw new StateException(11, "unsafe-path", $"Reset refuses a link or reparse point: {item.FullName}");
        if (item.Name.Equals(".git", StringComparison.OrdinalIgnoreCase))
            throw new StateException(18, "reset-refused", $"Reset refuses a worktree or gitlink marker: {item.FullName}");
    }

    private static void DeleteResetEntries(ResetManifest manifest, StateRoots roots)
    {
        foreach (var entry in manifest.Entries.Where(entry => entry.Type == "file"))
        {
            var root = entry.Root == "state" ? roots.StateRoot : roots.EvidenceRoot;
            var full = ResolveForWrite(root, NormalizeRelative(entry.Path, "reset entry"), "reset entry");
            if (!File.Exists(full) || HashBytes(File.ReadAllBytes(full)) != entry.Sha256) throw new StateException(18, "reset-refused", $"Reset file changed: {entry.Root}:{entry.Path}");
            RejectResetLinkOrGit(new FileInfo(full));
            File.Delete(full);
        }
        foreach (var entry in manifest.Entries.Where(entry => entry.Type == "directory").OrderByDescending(entry => entry.Path.Length))
        {
            var root = entry.Root == "state" ? roots.StateRoot : roots.EvidenceRoot;
            var full = ResolveForWrite(root, NormalizeRelative(entry.Path, "reset entry"), "reset entry");
            if (!Directory.Exists(full)) throw new StateException(18, "reset-refused", $"Reset directory changed: {entry.Root}:{entry.Path}");
            RejectResetLinkOrGit(new DirectoryInfo(full));
            if (Directory.EnumerateFileSystemEntries(full).Any()) throw new StateException(18, "reset-refused", $"Reset directory contains an unmanifested path: {entry.Root}:{entry.Path}");
            Directory.Delete(full);
        }
    }

    private static void WriteEvidenceAtomic(string evidenceRoot, string destination, string content)
    {
        if (!IsUnder(destination, evidenceRoot)) throw new StateException(11, "unsafe-path", "Evidence destination escapes EvidenceRoot.");
        Directory.CreateDirectory(Path.GetDirectoryName(destination)!);
        EnsureNoLinks(evidenceRoot, Path.GetDirectoryName(destination)!, "reset evidence");
        var temp = Path.Combine(Path.GetDirectoryName(destination)!, $".{Guid.NewGuid():N}.tmp");
        File.WriteAllText(temp, content, new UTF8Encoding(false));
        File.Move(temp, destination, true);
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

    private static void RejectUnknown(Dictionary<string, string> values, params string[] names)
    {
        var known = new HashSet<string>(names, StringComparer.Ordinal);
        var unknown = values.Keys.FirstOrDefault(key => !known.Contains(key));
        if (unknown is not null) throw new StateException(10, "invalid-input", $"Unknown argument: --{unknown}");
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
    private sealed record ResetEntry(string Root, string Path, string Type, string? Sha256);
    private sealed record ResetManifestCore(int FormatVersion, string Mode, string? ProjectId, List<ResetEntry> Entries, string BeforeHash, string ExpectedAfterHash);
    private sealed record ResetManifest(int FormatVersion, string Mode, string? ProjectId, List<ResetEntry> Entries, string BeforeHash, string ExpectedAfterHash, string ManifestHash);
    private sealed record TransactionJournal(int FormatVersion, string Id, string Kind, string Status, string? ProjectId, string DestinationPath, string TempPath, string PayloadHash);
    private sealed class StateException(int code, string category, string message) : Exception(message)
    {
        public int Code { get; } = code;
        public string Category { get; } = category;
    }
}
