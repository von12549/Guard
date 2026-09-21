using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace V4.Guards.Host;

internal static class Program
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true
    };

    public static int Main(string[] args)
    {
        if (args.Length > 0 && args[0] == "state") return StateRuntime.Execute(args);

        RootSet? roots = null;
        string? adapterHash = null;
        try
        {
            var options = ParseArguments(args);
            roots = ResolveRoots(options);
            ValidateRootBoundaries(roots);
            var result = RunSyntheticModule(options.ModuleId, roots, out adapterHash);
            WriteResult(roots.EvidenceRoot, result);
            Console.WriteLine(JsonSerializer.Serialize(result, JsonOptions));
            return 0;
        }
        catch (SpikeException ex)
        {
            var result = StageResult.Error(ex.Category, ex.Message, adapterHash, roots);
            if (roots is not null)
            {
                try { WriteResult(roots.EvidenceRoot, result); }
                catch { /* The original fail-closed category remains authoritative. */ }
            }
            Console.Error.WriteLine(JsonSerializer.Serialize(result, JsonOptions));
            return (int)ex.Code;
        }
        catch (Exception ex)
        {
            var result = StageResult.Error("adapter-failure", ex.Message, adapterHash, roots);
            if (roots is not null)
            {
                try { WriteResult(roots.EvidenceRoot, result); }
                catch { }
            }
            Console.Error.WriteLine(JsonSerializer.Serialize(result, JsonOptions));
            return (int)ExitCode.AdapterFailure;
        }
    }

    private static Options ParseArguments(string[] args)
    {
        if (args.Length < 2 || args[0] != "spike" || args[1] != "run")
            throw new SpikeException(ExitCode.InvalidInput, "invalid-input", "Expected 'spike run'.");

        var values = new Dictionary<string, string>(StringComparer.Ordinal);
        for (var index = 2; index < args.Length; index += 2)
        {
            if (index + 1 >= args.Length || !args[index].StartsWith("--", StringComparison.Ordinal))
                throw new SpikeException(ExitCode.InvalidInput, "invalid-input", "Arguments must be --name value pairs.");
            if (!values.TryAdd(args[index][2..], args[index + 1]))
                throw new SpikeException(ExitCode.InvalidInput, "invalid-input", $"Duplicate argument: {args[index]}");
        }

        string Required(string name) => values.TryGetValue(name, out var value) && !string.IsNullOrWhiteSpace(value)
            ? value
            : throw new SpikeException(ExitCode.InvalidInput, "invalid-input", $"Missing --{name}.");

        var known = new[] { "package-root", "target-root", "state-root", "evidence-root", "module" };
        var unknown = values.Keys.Where(key => !known.Contains(key, StringComparer.Ordinal)).ToArray();
        if (unknown.Length > 0)
            throw new SpikeException(ExitCode.InvalidInput, "invalid-input", $"Unknown argument: --{unknown[0]}");

        return new Options(Required("package-root"), Required("target-root"), Required("state-root"),
            Required("evidence-root"), Required("module"));
    }

    private static RootSet ResolveRoots(Options options) => new(
        ResolveDirectory("PackageRoot", options.PackageRoot),
        ResolveDirectory("TargetRoot", options.TargetRoot),
        ResolveDirectory("StateRoot", options.StateRoot),
        ResolveDirectory("EvidenceRoot", options.EvidenceRoot));

    private static string ResolveDirectory(string label, string value)
    {
        string full;
        try { full = Path.GetFullPath(value); }
        catch (Exception ex) { throw new SpikeException(ExitCode.UnsafePath, "unsafe-path", $"{label} is invalid: {ex.Message}"); }
        if (!Directory.Exists(full))
            throw new SpikeException(ExitCode.InvalidInput, "invalid-input", $"{label} does not exist: {full}");
        EnsureNoLinks(full, label);
        return Path.TrimEndingDirectorySeparator(full);
    }

    private static void ValidateRootBoundaries(RootSet roots)
    {
        foreach (var mutable in new[] { ("StateRoot", roots.StateRoot), ("EvidenceRoot", roots.EvidenceRoot) })
        {
            foreach (var authority in new[] { ("PackageRoot", roots.PackageRoot), ("TargetRoot", roots.TargetRoot) })
            {
                if (Overlaps(mutable.Item2, authority.Item2))
                    throw new SpikeException(ExitCode.UnsafePath, "unsafe-path", $"{mutable.Item1} overlaps {authority.Item1}.");
            }
        }
        if (Overlaps(roots.StateRoot, roots.EvidenceRoot))
            throw new SpikeException(ExitCode.UnsafePath, "unsafe-path", "StateRoot and EvidenceRoot overlap.");
    }

    private static bool Overlaps(string left, string right) => IsUnder(left, right) || IsUnder(right, left);

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
                throw new SpikeException(ExitCode.UnsafePath, "unsafe-path", $"{label} crosses a link or reparse point: {current.FullName}");
            current = current.Parent;
        }
    }

    private static StageResult RunSyntheticModule(string moduleId, RootSet roots, out string? adapterHash)
    {
        adapterHash = null;
        if (!Regex.IsMatch(moduleId, "^[a-z0-9-]+$", RegexOptions.CultureInvariant))
            throw new SpikeException(ExitCode.InvalidInput, "invalid-input", "Module ID is invalid.");

        var manifestPath = ResolveFileUnder(roots.PackageRoot, Path.Combine("modules", moduleId, "module.json"), "module manifest");
        ModuleManifest manifest;
        try
        {
            manifest = JsonSerializer.Deserialize<ModuleManifest>(File.ReadAllText(manifestPath), JsonOptions)
                ?? throw new JsonException("Manifest is empty.");
        }
        catch (Exception ex) when (ex is JsonException or IOException)
        {
            throw new SpikeException(ExitCode.InvalidInput, "invalid-input", $"Module manifest is invalid: {ex.Message}");
        }

        var adapter = manifest.Adapter;
        if (manifest.FormatVersion != 1 || manifest.Id != moduleId || adapter?.Kind != "powershell" ||
            string.IsNullOrWhiteSpace(adapter.Path) || string.IsNullOrWhiteSpace(adapter.Sha256) ||
            manifest.Stages is null || !manifest.Stages.SequenceEqual(new[] { "analysis" }, StringComparer.Ordinal))
            throw new SpikeException(ExitCode.InvalidInput, "invalid-input", "Module identity, adapter kind or stage is invalid.");

        var capabilities = manifest.Capabilities;
        if (capabilities is null || capabilities.Network ||
            !(capabilities.ReadRoots ?? []).SequenceEqual(new[] { "TargetRoot" }, StringComparer.Ordinal) ||
            (capabilities.WriteRoots ?? []).Length != 0 ||
            !(capabilities.Processes ?? []).SequenceEqual(new[] { "pwsh" }, StringComparer.Ordinal))
            throw new SpikeException(ExitCode.CapabilityDenied, "capability-denied", "The module requests a capability outside the P0 spike grant.");

        if (manifest.ResultSchema != "core/contracts/stage-result-spike.schema.json")
            throw new SpikeException(ExitCode.InvalidInput, "invalid-input", "The module result schema is not registered.");

        var adapterPath = ResolveFileUnder(roots.PackageRoot, adapter.Path, "adapter");
        adapterHash = Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(adapterPath))).ToLowerInvariant();
        if (!string.Equals(adapterHash, adapter.Sha256, StringComparison.Ordinal))
            throw new SpikeException(ExitCode.IntegrityFailure, "integrity-failure", "Adapter SHA-256 does not match the module manifest.");

        var executable = FindPowerShell();
        var input = JsonSerializer.Serialize(new { formatVersion = 1, stage = "analysis", targetRoot = roots.TargetRoot });
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
        start.ArgumentList.Add(adapterPath);
        start.Environment.Clear();
        start.Environment["V4_SPIKE_INPUT_JSON"] = input;
        start.Environment["POWERSHELL_TELEMETRY_OPTOUT"] = "1";
        foreach (var name in new[] { "SystemRoot", "WINDIR", "TEMP", "TMP", "HOME" })
        {
            var value = Environment.GetEnvironmentVariable(name);
            if (!string.IsNullOrWhiteSpace(value)) start.Environment[name] = value;
        }

        using var process = Process.Start(start) ?? throw new SpikeException(ExitCode.AdapterFailure, "adapter-failure", "PowerShell did not start.");
        var stdout = process.StandardOutput.ReadToEndAsync();
        var stderr = process.StandardError.ReadToEndAsync();
        if (!process.WaitForExit(30_000))
        {
            process.Kill(true);
            throw new SpikeException(ExitCode.AdapterFailure, "adapter-failure", "Adapter timed out.");
        }
        Task.WaitAll(stdout, stderr);
        if (process.ExitCode != 0)
            throw new SpikeException(ExitCode.AdapterFailure, "adapter-failure", $"Adapter exited {process.ExitCode}: {stderr.Result.Trim()}");

        AdapterResult adapterResult;
        try
        {
            adapterResult = JsonSerializer.Deserialize<AdapterResult>(stdout.Result, JsonOptions)
                ?? throw new JsonException("Adapter result is empty.");
        }
        catch (JsonException ex)
        {
            throw new SpikeException(ExitCode.AdapterFailure, "adapter-failure", $"Adapter output is invalid: {ex.Message}");
        }
        if (adapterResult.FormatVersion != 1 || adapterResult.Status is not ("pass" or "fail") || adapterResult.Findings is null)
            throw new SpikeException(ExitCode.AdapterFailure, "adapter-failure", "Adapter output does not satisfy the spike result contract.");

        return new StageResult(1, "analysis", moduleId, adapterResult.Status, "success", adapterResult.Findings,
            adapterHash, roots);
    }

    private static string ResolveFileUnder(string root, string relative, string label)
    {
        if (string.IsNullOrWhiteSpace(relative) || Path.IsPathRooted(relative))
            throw new SpikeException(ExitCode.UnsafePath, "unsafe-path", $"The {label} path must be relative.");
        var full = Path.GetFullPath(Path.Combine(root, relative));
        if (!IsUnder(full, root) || !File.Exists(full))
            throw new SpikeException(ExitCode.UnsafePath, "unsafe-path", $"The {label} path escapes PackageRoot or is missing.");
        var file = new FileInfo(full);
        if ((file.Attributes & FileAttributes.ReparsePoint) != 0 || file.LinkTarget is not null)
            throw new SpikeException(ExitCode.UnsafePath, "unsafe-path", $"The {label} is a link or reparse point.");
        EnsureNoLinks(file.DirectoryName!, label);
        return full;
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
        throw new SpikeException(ExitCode.AdapterFailure, "adapter-failure", "PowerShell 7 is not available.");
    }

    private static void WriteResult(string evidenceRoot, StageResult result)
    {
        var destination = Path.Combine(evidenceRoot, "stage-result.json");
        var temporary = Path.Combine(evidenceRoot, $".stage-result-{Guid.NewGuid():N}.tmp");
        File.WriteAllText(temporary, JsonSerializer.Serialize(result, JsonOptions) + Environment.NewLine, new UTF8Encoding(false));
        File.Move(temporary, destination, true);
    }

    private sealed record Options(string PackageRoot, string TargetRoot, string StateRoot, string EvidenceRoot, string ModuleId);
    private sealed record RootSet(string PackageRoot, string TargetRoot, string StateRoot, string EvidenceRoot);
    private sealed record StageResult(int FormatVersion, string Stage, string ModuleId, string Status, string ExitCategory,
        string[] Findings, string? AdapterSha256, RootSet? Roots)
    {
        public static StageResult Error(string category, string message, string? hash, RootSet? roots) =>
            new(1, "analysis", "synthetic-probe", "error", category, [message], hash, roots);
    }
    private sealed record ModuleManifest(int FormatVersion, string? Id, string? Version, AdapterManifest? Adapter,
        string[]? Stages, CapabilityManifest? Capabilities, string? ResultSchema);
    private sealed record AdapterManifest(string? Kind, string? Path, string? Sha256);
    private sealed record CapabilityManifest(string[]? ReadRoots, string[]? WriteRoots, string[]? Processes, bool Network);
    private sealed record AdapterResult(int FormatVersion, string? Status, string[]? Findings);

    private enum ExitCode { InvalidInput = 10, UnsafePath = 11, IntegrityFailure = 12, CapabilityDenied = 13, AdapterFailure = 14 }
    private sealed class SpikeException(ExitCode code, string category, string message) : Exception(message)
    {
        public ExitCode Code { get; } = code;
        public string Category { get; } = category;
    }
}
