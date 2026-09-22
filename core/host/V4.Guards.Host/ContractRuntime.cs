using System.Diagnostics;
using System.Reflection;
using System.Security.Cryptography;
using System.Text.Json;
using System.Text.RegularExpressions;

namespace V4.Guards.Host;

internal static class ContractRuntime
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true
    };

    public static int Version(string[] args)
    {
        if (args.Length != 1)
            return Error(10, "invalid-input", "The version command does not accept arguments.", "version");

        var assemblyVersion = Assembly.GetExecutingAssembly().GetName().Version
            ?? throw new InvalidOperationException("The host assembly version is unavailable.");
        var version = $"{assemblyVersion.Major}.{assemblyVersion.Minor}.{assemblyVersion.Build}";
        Console.WriteLine(JsonSerializer.Serialize(new
        {
            formatVersion = 1,
            status = "pass",
            command = "version",
            id = "v4-guards",
            version,
            apiVersion = "1.0"
        }, JsonOptions));
        return 0;
    }

    public static int Execute(string[] args)
    {
        try
        {
            if (args.Length < 2 || args[1] != "validate")
                throw new ContractException(10, "invalid-input", "Expected 'contract validate'.");

            var values = ParsePairs(args, 2);
            RejectUnknown(values, "package-root", "schema", "document");
            var packageRoot = ResolvePackageRoot(Required(values, "package-root"));
            var schemaId = Required(values, "schema");
            if (!Regex.IsMatch(schemaId, "^[a-z][a-z0-9-]*$", RegexOptions.CultureInvariant))
                throw new ContractException(10, "invalid-input", "Schema ID is invalid.");

            var documentPath = Path.GetFullPath(Required(values, "document"));
            if (!File.Exists(documentPath))
                throw new ContractException(10, "invalid-input", "Document does not exist.");

            var relativeSchema = $"core/contracts/{schemaId}.schema.json";
            var manifestPath = ResolveFileUnder(packageRoot, "core/contracts/contracts-manifest.json", "contracts manifest");
            using var manifest = JsonDocument.Parse(File.ReadAllText(manifestPath));
            var entries = manifest.RootElement.GetProperty("files").EnumerateArray()
                .Where(entry => entry.GetProperty("path").GetString() == relativeSchema).ToArray();
            if (entries.Length != 1)
                throw new ContractException(10, "invalid-input", $"Schema is not registered: {schemaId}");

            var schemaPath = ResolveFileUnder(packageRoot, relativeSchema, "schema");
            var expectedHash = entries[0].GetProperty("sha256").GetString();
            var actualHash = Hash(schemaPath);
            if (!string.Equals(expectedHash, actualHash, StringComparison.Ordinal))
                throw new ContractException(12, "integrity-failure", $"Registered schema hash drift: {schemaId}");

            var validation = ValidateWithPowerShell(documentPath, schemaPath);
            if (validation.ExitCode == 1)
                throw new ContractException(16, "findings-blocking", $"Document does not satisfy schema {schemaId}.");
            if (validation.ExitCode != 0)
                throw new ContractException(14, "adapter-failure", $"Schema validation failed: {validation.Error}");

            Console.WriteLine(JsonSerializer.Serialize(new
            {
                formatVersion = 1,
                status = "pass",
                command = "contract.validate",
                schema = schemaId,
                schemaSha256 = actualHash,
                document = documentPath
            }, JsonOptions));
            return 0;
        }
        catch (ContractException ex)
        {
            return Error(ex.Code, ex.Category, ex.Message);
        }
        catch (System.ComponentModel.Win32Exception ex)
        {
            return Error(15, "prerequisite-missing", $"PowerShell 7 is unavailable: {ex.Message}");
        }
        catch (Exception ex)
        {
            return Error(19, "internal-error", ex.Message);
        }
    }

    private static (int ExitCode, string Error) ValidateWithPowerShell(string documentPath, string schemaPath)
    {
        const string script = "$ErrorActionPreference='Stop'; try { if (Test-Json -LiteralPath $env:V4_CONTRACT_DOCUMENT -SchemaFile $env:V4_CONTRACT_SCHEMA -ErrorAction SilentlyContinue) { exit 0 }; exit 1 } catch { [Console]::Error.WriteLine($_.Exception.Message); exit 2 }";
        var start = new ProcessStartInfo("pwsh")
        {
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };
        foreach (var argument in new[] { "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", script })
            start.ArgumentList.Add(argument);
        start.Environment["V4_CONTRACT_DOCUMENT"] = documentPath;
        start.Environment["V4_CONTRACT_SCHEMA"] = schemaPath;
        using var process = Process.Start(start) ?? throw new System.ComponentModel.Win32Exception("PowerShell 7 did not start.");
        var output = process.StandardOutput.ReadToEnd();
        var error = process.StandardError.ReadToEnd();
        process.WaitForExit();
        return (process.ExitCode, string.IsNullOrWhiteSpace(error) ? output.Trim() : error.Trim());
    }

    private static Dictionary<string, string> ParsePairs(string[] args, int start)
    {
        var values = new Dictionary<string, string>(StringComparer.Ordinal);
        for (var index = start; index < args.Length; index += 2)
        {
            if (index + 1 >= args.Length || !args[index].StartsWith("--", StringComparison.Ordinal))
                throw new ContractException(10, "invalid-input", "Arguments must be --name value pairs.");
            if (!values.TryAdd(args[index][2..], args[index + 1]))
                throw new ContractException(10, "invalid-input", $"Duplicate argument: {args[index]}");
        }
        return values;
    }

    private static void RejectUnknown(Dictionary<string, string> values, params string[] known)
    {
        var unknown = values.Keys.Where(key => !known.Contains(key, StringComparer.Ordinal)).ToArray();
        if (unknown.Length > 0)
            throw new ContractException(10, "invalid-input", $"Unknown argument: --{unknown[0]}");
    }

    private static string Required(Dictionary<string, string> values, string name) =>
        values.TryGetValue(name, out var value) && !string.IsNullOrWhiteSpace(value)
            ? value
            : throw new ContractException(10, "invalid-input", $"Missing --{name}.");

    private static string ResolvePackageRoot(string value)
    {
        var path = Path.TrimEndingDirectorySeparator(Path.GetFullPath(value));
        if (!Directory.Exists(path))
            throw new ContractException(10, "invalid-input", "PackageRoot does not exist.");
        EnsureNoLinks(path, path);
        return path;
    }

    private static string ResolveFileUnder(string root, string relative, string label)
    {
        var path = Path.GetFullPath(Path.Combine(root, relative));
        var rel = Path.GetRelativePath(root, path);
        if (Path.IsPathRooted(rel) || rel == ".." || rel.StartsWith($"..{Path.DirectorySeparatorChar}", StringComparison.Ordinal) || !File.Exists(path))
            throw new ContractException(11, "unsafe-path", $"The {label} escapes PackageRoot or is missing.");
        EnsureNoLinks(root, path);
        return path;
    }

    private static void EnsureNoLinks(string root, string path)
    {
        var current = new DirectoryInfo(root);
        if ((current.Attributes & FileAttributes.ReparsePoint) != 0)
            throw new ContractException(11, "unsafe-path", "PackageRoot cannot be a link or reparse point.");
        var relative = Path.GetRelativePath(root, path);
        foreach (var segment in relative.Split(new[] { Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar }, StringSplitOptions.RemoveEmptyEntries))
        {
            var candidate = Path.Combine(current.FullName, segment);
            if (Directory.Exists(candidate)) current = new DirectoryInfo(candidate);
            else if (File.Exists(candidate))
            {
                if ((File.GetAttributes(candidate) & FileAttributes.ReparsePoint) != 0)
                    throw new ContractException(11, "unsafe-path", "Package authority cannot traverse a link or reparse point.");
                break;
            }
            else break;
            if ((current.Attributes & FileAttributes.ReparsePoint) != 0)
                throw new ContractException(11, "unsafe-path", "Package authority cannot traverse a link or reparse point.");
        }
    }

    private static string Hash(string path) => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path))).ToLowerInvariant();

    private static int Error(int code, string category, string message, string command = "contract.validate")
    {
        Console.Error.WriteLine(JsonSerializer.Serialize(new
        {
            formatVersion = 1,
            status = "error",
            command,
            exitCategory = category,
            message
        }, JsonOptions));
        return code;
    }

    private sealed class ContractException(int code, string category, string message) : Exception(message)
    {
        public int Code { get; } = code;
        public string Category { get; } = category;
    }
}
