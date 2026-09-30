using System.Diagnostics;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

namespace V4.Guards.Host;

internal static class ProfileRuntime
{
    private const int MaximumFiles = 10_000;
    private const long MaximumFileBytes = 1_048_576;
    private const string DetectorId = "v4-profile-discovery";
    private const string DetectorVersion = "1.0.0";
    private const string GeneratorId = "v4-profile-scaffold";
    private const string GeneratorVersion = "1.0.0";
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = false,
        WriteIndented = true
    };
    private static readonly JsonSerializerOptions CompactJsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = false,
        WriteIndented = false
    };
    private static readonly Regex ProfileIdPattern = new("^[a-z][a-z0-9_-]{0,62}$", RegexOptions.CultureInvariant);
    private static readonly Regex HashPattern = new("^[a-f0-9]{64}$", RegexOptions.CultureInvariant);
    private static readonly HashSet<string> ExcludedDirectories = new(StringComparer.OrdinalIgnoreCase)
    {
        ".git", ".guard", ".vs", ".idea", "bin", "obj", "node_modules", "dist", "out", ".venv", "venv"
    };
    private static readonly HashSet<string> ManifestNames = new(StringComparer.OrdinalIgnoreCase)
    {
        "package.json", "package-lock.json", "pnpm-lock.yaml", "yarn.lock", "pyproject.toml",
        "requirements.txt", "go.mod", "Cargo.toml", "pom.xml", "build.gradle", "build.gradle.kts", "global.json"
    };
    private static readonly HashSet<string> ManifestExtensions = new(StringComparer.OrdinalIgnoreCase)
    {
        ".sln", ".slnx", ".csproj", ".fsproj", ".vbproj", ".props", ".targets"
    };
    private static readonly Dictionary<string, string> SourceLanguages = new(StringComparer.OrdinalIgnoreCase)
    {
        [".cs"] = "csharp", [".fs"] = "fsharp", [".vb"] = "visual-basic", [".ts"] = "typescript",
        [".js"] = "javascript", [".py"] = "python", [".go"] = "go", [".rs"] = "rust", [".java"] = "java"
    };

    public static int Execute(string[] args)
    {
        try
        {
            var arguments = Arguments.Parse(args);
            JsonObject output = arguments.Operation switch
            {
                "discover" => DiscoverOperation(arguments),
                "draft" => DraftOperation(arguments),
                "validate" => ValidateOperation(arguments),
                "promote" => PromoteOperation(arguments),
                _ => throw Invalid($"Unknown profile operation: {arguments.Operation}")
            };
            Console.WriteLine(output.ToJsonString(JsonOptions));
            return 0;
        }
        catch (ProfileException ex)
        {
            return Error(ex.Code, ex.Category, ex.Message);
        }
        catch (ContractRuntime.ContractException ex)
        {
            return Error(ex.Code, ex.Category, ex.Message);
        }
        catch (System.ComponentModel.Win32Exception ex)
        {
            return Error(15, "prerequisite-missing", $"A declared validation runtime is unavailable: {ex.Message}");
        }
        catch (Exception ex)
        {
            return Error(19, "internal-error", ex.Message);
        }
    }

    private static JsonObject DiscoverOperation(Arguments arguments)
    {
        arguments.RequireOnly("package-root", "target-root");
        var packageRoot = ResolveExistingDirectory(arguments.Required("package-root"), "PackageRoot");
        var targetRoot = ResolveExistingDirectory(arguments.Required("target-root"), "TargetRoot");
        EnsureDisjoint(packageRoot, targetRoot, "PackageRoot and TargetRoot");
        var discovery = Discover(packageRoot, targetRoot);
        ValidateNode(packageRoot, "profile-discovery", discovery);
        return discovery;
    }

    private static JsonObject DraftOperation(Arguments arguments)
    {
        arguments.RequireOnly("package-root", "target-root", "state-root", "profile");
        var packageRoot = ResolveExistingDirectory(arguments.Required("package-root"), "PackageRoot");
        var targetRoot = ResolveExistingDirectory(arguments.Required("target-root"), "TargetRoot");
        var stateRoot = ResolveExistingDirectory(arguments.Required("state-root"), "StateRoot");
        EnsureDisjoint(packageRoot, targetRoot, "PackageRoot and TargetRoot");
        EnsureDisjoint(stateRoot, targetRoot, "StateRoot and TargetRoot");
        EnsureDisjoint(stateRoot, packageRoot, "StateRoot and PackageRoot");
        var profileId = arguments.Required("profile");
        if (!ProfileIdPattern.IsMatch(profileId)) throw Invalid("Profile ID is invalid.");
        if (InstalledProfileIds(packageRoot).Contains(profileId))
            throw Conflict("The draft Profile ID collides with an installed Profile.");

        var discovery = Discover(packageRoot, targetRoot);
        ValidateNode(packageRoot, "profile-discovery", discovery);
        var discoveryText = Serialize(discovery);
        var discoveryHash = HashText(discoveryText);
        var snapshot = RequiredString(discovery["target"]!.AsObject(), "snapshotSha256");
        var projectId = ProjectId(targetRoot);
        var draftId = HashText($"{projectId}\n{snapshot}\n{profileId}\n{GeneratorId}\n{GeneratorVersion}\n")[..32];
        var draftPath = Path.Combine(stateRoot, "profile-drafts", projectId, draftId, "draft.json");
        var discoveryPath = Path.Combine(Path.GetDirectoryName(draftPath)!, "discovery.json");
        var candidate = ConservativeProfile(profileId);
        ValidateNode(packageRoot, "profile", candidate);
        var candidateHash = HashCanonical(candidate);
        var recommendations = Recommendations(discovery, packageRoot);
        var draft = new JsonObject
        {
            ["formatVersion"] = 1,
            ["status"] = "draft",
            ["authority"] = "state-draft-non-authoritative",
            ["draftId"] = draftId,
            ["storagePath"] = draftPath,
            ["project"] = new JsonObject { ["id"] = projectId, ["targetCanonicalPath"] = targetRoot },
            ["targetSnapshotSha256"] = snapshot,
            ["discoverySha256"] = discoveryHash,
            ["generator"] = new JsonObject { ["id"] = GeneratorId, ["version"] = GeneratorVersion },
            ["candidateProfile"] = candidate.DeepClone(),
            ["candidateProfileSha256"] = candidateHash,
            ["recommendations"] = recommendations,
            ["unresolvedPolicy"] = new JsonArray("gate-selection", "severity", "exceptions", "baselines", "unsupported-coverage", "ambiguous-modules"),
            ["coverage"] = new JsonObject { ["status"] = "unprotected", ["selectedModuleCount"] = 0, ["enabledStageCount"] = 0 }
        };
        ValidateNode(packageRoot, "profile-draft", draft);
        WriteNewOrSame(discoveryPath, discoveryText);
        WriteNewOrSame(draftPath, Serialize(draft));
        var after = Discover(packageRoot, targetRoot);
        if (RequiredString(after["target"]!.AsObject(), "snapshotSha256") != snapshot)
            throw Conflict("Target snapshot changed while the draft was created.");
        return draft;
    }

    private static JsonObject ValidateOperation(Arguments arguments)
    {
        arguments.RequireOnly("package-root", "target-root", "state-root", "draft", "review");
        var context = ResolveReviewContext(arguments);
        var validation = ValidateReview(context);
        ValidateNode(context.PackageRoot, "profile-validation", validation);
        return validation;
    }

    private static JsonObject PromoteOperation(Arguments arguments)
    {
        arguments.RequireOnly("package-root", "target-root", "state-root", "draft", "review", "output-root", "base-archive-sha256");
        var context = ResolveReviewContext(arguments);
        var baseArchiveHash = arguments.Required("base-archive-sha256");
        if (!HashPattern.IsMatch(baseArchiveHash)) throw Invalid("Base archive SHA-256 is invalid.");
        var validation = ValidateReview(context);
        ValidateNode(context.PackageRoot, "profile-validation", validation);

        var output = Path.TrimEndingDirectorySeparator(Path.GetFullPath(arguments.Required("output-root")));
        if (Directory.Exists(output) || File.Exists(output)) throw Conflict("Promotion output already exists.");
        EnsureNotUnder(output, context.TargetRoot, "Promotion output cannot be inside TargetRoot.");
        EnsureNotUnder(output, context.PackageRoot, "Promotion output cannot be inside PackageRoot.");
        var parent = Path.GetDirectoryName(output) ?? throw Unsafe("Promotion output has no parent directory.");
        Directory.CreateDirectory(parent);
        EnsureNoLinks(parent, "promotion output parent");

        var targetSnapshot = RequiredString(context.Draft, "targetSnapshotSha256");
        var profile = context.Draft["candidateProfile"]!.AsObject();
        var profileId = RequiredString(profile, "id");
        var profileVersion = RequiredString(profile, "version");
        var plugin = ReadObject(Path.Combine(context.PackageRoot, "plugin.json"), "plugin manifest");
        var baseVersion = RequiredString(plugin, "version");
        var reviewId = RequiredString(context.Review, "id");
        var reviewer = RequiredString(context.Review["acceptedBy"]!.AsObject(), "authorityId");
        var coverageStatus = RequiredString(context.Review["coverageDecision"]!.AsObject(), "status");
        var draftHash = HashFile(context.DraftPath);
        var reviewHash = HashFile(context.ReviewPath);
        var temporary = Path.Combine(parent, $".v4-profile-promotion-{Guid.NewGuid():N}");
        var marker = Path.Combine(temporary, ".promotion-owner");
        try
        {
            Directory.CreateDirectory(temporary);
            File.WriteAllText(marker, "v4-profile-promotion", new UTF8Encoding(false));
            var bundleRoot = Path.Combine(temporary, "bundle");
            var relativeProfile = $"profiles/catalog/{profileId}/profile.json";
            var profilePath = Path.Combine(bundleRoot, "package", relativeProfile.Replace('/', Path.DirectorySeparatorChar));
            WriteNewOrSame(profilePath, Serialize(profile));
            var profileHash = HashFile(profilePath);
            var profileSize = new FileInfo(profilePath).Length;
            var bundle = new JsonObject
            {
                ["formatVersion"] = 1,
                ["id"] = profileId.Replace('_', '-') + "-profile",
                ["version"] = profileVersion,
                ["compatibleApi"] = "1.x",
                ["baseVersion"] = baseVersion,
                ["profiles"] = new JsonArray(new JsonObject
                {
                    ["id"] = profileId, ["version"] = profileVersion, ["path"] = relativeProfile, ["sha256"] = profileHash
                }),
                ["modules"] = new JsonArray(),
                ["files"] = new JsonArray(new JsonObject
                {
                    ["path"] = relativeProfile, ["sha256"] = profileHash, ["size"] = profileSize
                })
            };
            var bundlePath = Path.Combine(bundleRoot, "bundle-manifest.json");
            WriteNewOrSame(bundlePath, Serialize(bundle));
            ValidateFile(context.PackageRoot, "extension-bundle", bundlePath);
            var bundleHash = HashFile(bundlePath);
            var extensionReview = new JsonObject
            {
                ["formatVersion"] = 1,
                ["id"] = reviewId,
                ["scope"] = "production",
                ["decision"] = "accepted",
                ["acceptedBy"] = new JsonObject
                {
                    ["authorityType"] = "human-review", ["authorityId"] = reviewer, ["candidateHostVerdictAllowed"] = false
                },
                ["bundleManifestSha256"] = bundleHash,
                ["baseArchiveSha256"] = baseArchiveHash,
                ["moduleCeilings"] = new JsonArray()
            };
            var extensionReviewPath = Path.Combine(temporary, "extension-review.json");
            WriteNewOrSame(extensionReviewPath, Serialize(extensionReview));
            ValidateFile(context.PackageRoot, "extension-review", extensionReviewPath);
            File.Copy(context.ReviewPath, Path.Combine(temporary, "profile-review.json"), false);

            var finalBundleRoot = Path.Combine(output, "bundle");
            var finalExtensionReviewPath = Path.Combine(output, "extension-review.json");
            var finalProfilePath = Path.Combine(finalBundleRoot, "package", relativeProfile.Replace('/', Path.DirectorySeparatorChar));
            var receipt = new JsonObject
            {
                ["formatVersion"] = 1,
                ["status"] = "pass",
                ["kind"] = "profile-promotion-candidate",
                ["draftSha256"] = draftHash,
                ["reviewSha256"] = reviewHash,
                ["targetSnapshotSha256"] = targetSnapshot,
                ["bundleRoot"] = finalBundleRoot,
                ["bundleManifestSha256"] = bundleHash,
                ["extensionReviewPath"] = finalExtensionReviewPath,
                ["extensionReviewSha256"] = HashFile(extensionReviewPath),
                ["profilePath"] = finalProfilePath,
                ["profileSha256"] = profileHash,
                ["coverageStatus"] = coverageStatus,
                ["boundaries"] = new JsonObject
                {
                    ["targetChanged"] = false, ["compositionCreated"] = false, ["compositionSelected"] = false,
                    ["ciActivated"] = false, ["targetAdoptionRequired"] = true, ["compositionRequired"] = true,
                    ["ciActivationRequired"] = true
                }
            };
            ValidateNode(context.PackageRoot, "profile-promotion", receipt);
            WriteNewOrSame(Path.Combine(temporary, "promotion-receipt.json"), Serialize(receipt));
            var after = Discover(context.PackageRoot, context.TargetRoot);
            if (RequiredString(after["target"]!.AsObject(), "snapshotSha256") != targetSnapshot)
                throw Conflict("Target snapshot changed while the promotion candidate was created.");
            File.Delete(marker);
            Directory.Move(temporary, output);
            return receipt;
        }
        finally
        {
            if (Directory.Exists(temporary) && File.Exists(marker) && File.ReadAllText(marker) == "v4-profile-promotion")
                Directory.Delete(temporary, true);
        }
    }

    private static ReviewContext ResolveReviewContext(Arguments arguments)
    {
        var packageRoot = ResolveExistingDirectory(arguments.Required("package-root"), "PackageRoot");
        var targetRoot = ResolveExistingDirectory(arguments.Required("target-root"), "TargetRoot");
        var stateRoot = ResolveExistingDirectory(arguments.Required("state-root"), "StateRoot");
        EnsureDisjoint(packageRoot, targetRoot, "PackageRoot and TargetRoot");
        EnsureDisjoint(stateRoot, targetRoot, "StateRoot and TargetRoot");
        EnsureDisjoint(stateRoot, packageRoot, "StateRoot and PackageRoot");
        var draftPath = ResolveExistingFile(arguments.Required("draft"), "draft");
        EnsureUnder(draftPath, stateRoot, "Draft must be below StateRoot.");
        var reviewPath = ResolveExistingFile(arguments.Required("review"), "review");
        var draft = ReadObject(draftPath, "draft");
        var review = ReadObject(reviewPath, "review");
        ValidateFile(packageRoot, "profile-draft", draftPath);
        ValidateFile(packageRoot, "profile-review", reviewPath);
        return new ReviewContext(packageRoot, targetRoot, stateRoot, draftPath, reviewPath, draft, review);
    }

    private static JsonObject ValidateReview(ReviewContext context)
    {
        var currentDiscovery = Discover(context.PackageRoot, context.TargetRoot);
        ValidateNode(context.PackageRoot, "profile-discovery", currentDiscovery);
        var snapshot = RequiredString(currentDiscovery["target"]!.AsObject(), "snapshotSha256");
        var currentDiscoveryHash = HashText(Serialize(currentDiscovery));
        if (RequiredString(context.Draft, "targetSnapshotSha256") != snapshot ||
            RequiredString(context.Draft, "discoverySha256") != currentDiscoveryHash)
            throw Conflict("Draft discovery or Target snapshot is stale.");
        var project = context.Draft["project"]?.AsObject() ?? throw Invalid("Draft project is missing.");
        if (RequiredString(project, "id") != ProjectId(context.TargetRoot) ||
            !PathEquals(RequiredString(project, "targetCanonicalPath"), context.TargetRoot))
            throw Conflict("Draft project binding does not match TargetRoot.");
        if (!PathEquals(RequiredString(context.Draft, "storagePath"), context.DraftPath))
            throw Conflict("Draft storage binding does not match its path.");
        var storedDiscoveryPath = Path.Combine(Path.GetDirectoryName(context.DraftPath)!, "discovery.json");
        if (!File.Exists(storedDiscoveryPath)) throw Invalid("Stored discovery document is missing beside the draft.");
        EnsureNoLinks(storedDiscoveryPath, "stored discovery");
        ValidateFile(context.PackageRoot, "profile-discovery", storedDiscoveryPath);
        if (HashFile(storedDiscoveryPath) != currentDiscoveryHash)
            throw Integrity("Stored discovery document does not match the current discovery identity.");

        var profile = context.Draft["candidateProfile"]?.AsObject() ?? throw Invalid("Draft candidate Profile is missing.");
        ValidateNode(context.PackageRoot, "profile", profile);
        var profileId = RequiredString(profile, "id");
        if (InstalledProfileIds(context.PackageRoot).Contains(profileId))
            throw Conflict("The candidate Profile ID collides with an installed Profile.");
        var expectedDraftId = HashText($"{ProjectId(context.TargetRoot)}\n{snapshot}\n{profileId}\n{GeneratorId}\n{GeneratorVersion}\n")[..32];
        if (RequiredString(context.Draft, "draftId") != expectedDraftId)
            throw Integrity("Draft identity does not match its project, snapshot, Profile and generator bindings.");
        var candidateHash = HashCanonical(profile);
        if (RequiredString(context.Draft, "candidateProfileSha256") != candidateHash)
            throw Integrity("Candidate Profile hash drift.");
        var draftHash = HashFile(context.DraftPath);
        var reviewHash = HashFile(context.ReviewPath);
        foreach (var pair in new[]
        {
            ("draftSha256", draftHash), ("discoverySha256", currentDiscoveryHash),
            ("candidateProfileSha256", candidateHash), ("targetSnapshotSha256", snapshot)
        })
        {
            if (RequiredString(context.Review, pair.Item1) != pair.Item2)
                throw Integrity($"Review {pair.Item1} binding does not match.");
        }

        ValidatePolicyDecisions(context.Review, currentDiscovery);
        var modules = LoadModules(context.PackageRoot);
        var bindings = ValidateProfileModules(context.PackageRoot, profile, modules);
        var reviewedBindings = context.Review["moduleBindings"]?.AsArray() ?? throw Invalid("Review module bindings are missing.");
        if (Canonical(reviewedBindings) != Canonical(bindings)) throw Integrity("Review Module bindings do not match the candidate Profile.");

        var fixtures = context.Review["fixtures"]?.AsArray() ?? throw Invalid("Review fixtures are missing.");
        var positive = 0;
        var negative = 0;
        foreach (var item in fixtures)
        {
            var fixture = item?.AsObject() ?? throw Invalid("Fixture receipt is invalid.");
            var classification = RequiredString(fixture, "classification");
            if (classification == "positive") positive++; else if (classification == "negative") negative++;
            if (RequiredString(fixture, "expected") != RequiredString(fixture, "actual"))
                throw Findings("Fixture expected and actual results differ.");
        }
        if (positive < 1 || negative < 1) throw Findings("At least one positive and one negative fixture receipt are required.");

        var selectedCount = profile["moduleSelections"]!.AsArray().Count;
        var stages = profile["stageConfiguration"]!.AsObject();
        var enabledCount = stages.Count(entry => entry.Value!.AsObject()["enabled"]!.GetValue<bool>());
        var nonVacuous = selectedCount > 0 && enabledCount > 0;
        var coverageStatus = RequiredString(context.Review["coverageDecision"]!.AsObject(), "status");
        if (coverageStatus == "protected" && !nonVacuous)
            throw Findings("Empty or disabled coverage cannot be accepted as protected.");

        return new JsonObject
        {
            ["formatVersion"] = 1,
            ["status"] = "pass",
            ["operation"] = "profile-validate",
            ["draftSha256"] = draftHash,
            ["reviewSha256"] = reviewHash,
            ["targetSnapshotSha256"] = snapshot,
            ["profile"] = new JsonObject
            {
                ["id"] = RequiredString(profile, "id"), ["version"] = RequiredString(profile, "version"),
                ["candidateProfileSha256"] = candidateHash
            },
            ["moduleBindings"] = bindings.DeepClone(),
            ["fixtures"] = new JsonObject { ["positive"] = positive, ["negative"] = negative, ["allMatched"] = true },
            ["coverage"] = new JsonObject
            {
                ["status"] = coverageStatus, ["selectedModuleCount"] = selectedCount,
                ["enabledStageCount"] = enabledCount, ["nonVacuous"] = nonVacuous
            },
            ["readiness"] = new JsonObject
            {
                ["status"] = "ready-for-promotion", ["targetAdoptionRequired"] = true,
                ["compositionRequired"] = true, ["ciActivationRequired"] = true
            }
        };
    }

    private static void ValidatePolicyDecisions(JsonObject review, JsonObject discovery)
    {
        var policy = review["policyDecisions"]?.AsObject() ?? throw Invalid("Review policy decisions are missing.");
        foreach (var name in new[] { "gateSelection", "severity", "exceptions", "baselines", "unsupportedCoverage", "ambiguousModules" })
        {
            var item = policy[name]?.AsObject() ?? throw Invalid($"Review policy decision is missing: {name}");
            _ = RequiredString(item, "decision");
            _ = RequiredString(item, "rationale");
        }
        var requiredQuestions = discovery["questions"]!.AsArray()
            .Where(item => RequiredString(item!.AsObject(), "kind") == "ambiguous-module")
            .Select(item => RequiredString(item!.AsObject(), "id")).Order(StringComparer.Ordinal).ToArray();
        var reviewedQuestions = review["ambiguousModuleChoices"]!.AsArray()
            .Select(item => RequiredString(item!.AsObject(), "questionId")).Order(StringComparer.Ordinal).ToArray();
        if (!requiredQuestions.SequenceEqual(reviewedQuestions, StringComparer.Ordinal))
            throw Findings("Ambiguous Module decisions do not exactly match discovery questions.");
    }

    private static JsonArray ValidateProfileModules(string packageRoot, JsonObject profile, IReadOnlyDictionary<string, ModuleInfo> modules)
    {
        var selections = profile["moduleSelections"]?.AsArray() ?? throw Invalid("Profile module selections are missing.");
        var selected = new HashSet<string>(StringComparer.Ordinal);
        var bindings = new List<JsonObject>();
        foreach (var item in selections)
        {
            var selection = item?.AsObject() ?? throw Invalid("Module selection is invalid.");
            var id = RequiredString(selection, "id");
            if (!selected.Add(id)) throw Invalid($"Duplicate Module selection: {id}");
            if (!modules.TryGetValue(id, out var module)) throw Invalid($"Selected Module is not installed: {id}");
            var config = selection["config"]?.AsObject() ?? throw Invalid($"Module configuration is missing: {id}");
            ValidateArbitrarySchema(config, Path.Combine(packageRoot, module.ConfigSchema), $"Module configuration {id}");
            if (!CapabilitiesWithin(module.Manifest["capabilities"]!.AsObject(), module.AllowedCapabilities))
                throw Capability($"Module capabilities exceed the installed registry ceiling: {id}");
            bindings.Add(new JsonObject
            {
                ["id"] = id,
                ["manifestSha256"] = module.ManifestSha256,
                ["configSha256"] = HashCanonical(config),
                ["allowedCapabilitiesSha256"] = HashCanonical(module.AllowedCapabilities)
            });
        }
        var stageConfiguration = profile["stageConfiguration"]?.AsObject() ?? throw Invalid("Profile stage configuration is missing.");
        foreach (var stageName in new[] { "bootstrap", "analysis", "pre", "post" })
        {
            var stage = stageConfiguration[stageName]?.AsObject() ?? throw Invalid($"Profile stage is missing: {stageName}");
            foreach (var moduleNode in stage["modules"]!.AsArray())
            {
                var id = moduleNode!.GetValue<string>();
                if (!selected.Contains(id)) throw Invalid($"Stage {stageName} uses unselected Module {id}.");
                if (!modules[id].Manifest["stages"]!.AsArray().Any(value => value!.GetValue<string>() == stageName))
                    throw Capability($"Module {id} does not support Stage {stageName}.");
            }
        }
        return new JsonArray(bindings.OrderBy(item => RequiredString(item, "id")).Select(item => (JsonNode)item).ToArray());
    }

    private static bool CapabilitiesWithin(JsonObject actual, JsonObject ceiling)
    {
        foreach (var name in new[] { "readRoots", "writeRoots", "processes" })
        {
            var allowed = ceiling[name]!.AsArray().Select(item => item!.GetValue<string>()).ToHashSet(StringComparer.Ordinal);
            if (actual[name]!.AsArray().Any(item => !allowed.Contains(item!.GetValue<string>()))) return false;
        }
        if (actual["network"]!.GetValue<bool>() && !ceiling["network"]!.GetValue<bool>()) return false;
        return actual["timeoutSeconds"]!.GetValue<int>() <= ceiling["maxTimeoutSeconds"]!.GetValue<int>();
    }

    private static JsonObject Discover(string packageRoot, string targetRoot)
    {
        var observed = ObserveTarget(targetRoot);
        var identity = string.Join("\n", observed.Select(file => $"{file.RelativePath}:{file.Sha256}:{file.Size}")) + "\n";
        var snapshot = HashText(identity);
        var facts = new List<Fact>();
        foreach (var file in observed)
        {
            var extension = Path.GetExtension(file.RelativePath);
            if (ManifestNames.Contains(Path.GetFileName(file.RelativePath)) || ManifestExtensions.Contains(extension))
                facts.Add(new Fact("manifest", file.RelativePath, ManifestValue(file.RelativePath), "inert-manifest", DetectorVersion, snapshot));
        }
        foreach (var language in observed.Select(file => SourceLanguages.TryGetValue(Path.GetExtension(file.RelativePath), out var value) ? value : null)
                     .Where(value => value is not null).Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal))
            facts.Add(new Fact("language", LanguageSource(observed, language!), language!, "source-extension", DetectorVersion, snapshot));
        foreach (var framework in FrameworkFacts(observed, targetRoot, snapshot)) facts.Add(framework);
        foreach (var root in RootFacts(observed, snapshot)) facts.Add(root);

        var modules = LoadModules(packageRoot);
        foreach (var module in modules.Values.OrderBy(item => item.Id, StringComparer.Ordinal))
        {
            var source = $"package:{module.ManifestPath}";
            facts.Add(new Fact("module", source, $"{module.Id}@{RequiredString(module.Manifest, "version")}", "installed-module-catalog", DetectorVersion, snapshot));
            foreach (var prerequisite in module.Manifest["prerequisites"]!.AsArray())
            {
                var value = prerequisite!.AsObject();
                facts.Add(new Fact("prerequisite", source,
                    $"{RequiredString(value, "runtime")}:{RequiredString(value, "versionRange")}", "module-prerequisite", DetectorVersion, snapshot));
            }
        }
        var questions = Questions(observed, facts, modules);
        var factNodes = facts.OrderBy(item => item.Kind, StringComparer.Ordinal)
            .ThenBy(item => item.SourcePath, StringComparer.Ordinal).ThenBy(item => item.NormalizedValue, StringComparer.Ordinal)
            .Select(item => (JsonNode)new JsonObject
            {
                ["kind"] = item.Kind, ["sourcePath"] = item.SourcePath, ["normalizedValue"] = item.NormalizedValue,
                ["detectorId"] = item.DetectorId, ["detectorVersion"] = item.DetectorVersion,
                ["targetSnapshotSha256"] = item.TargetSnapshotSha256
            }).ToArray();
        return new JsonObject
        {
            ["formatVersion"] = 1,
            ["status"] = "pass",
            ["operation"] = "profile-discover",
            ["authority"] = "v4-host-observation-only",
            ["target"] = new JsonObject
            {
                ["canonicalPath"] = targetRoot, ["snapshotSha256"] = snapshot, ["observedFileCount"] = observed.Count
            },
            ["detector"] = new JsonObject { ["id"] = DetectorId, ["version"] = DetectorVersion },
            ["facts"] = new JsonArray(factNodes),
            ["questions"] = questions,
            ["limits"] = new JsonObject { ["maximumFiles"] = MaximumFiles, ["maximumFileBytes"] = MaximumFileBytes },
            ["prohibitions"] = new JsonArray("build", "restore", "download", "execute-target-code", "mutate-target", "infer-policy")
        };
    }

    private static List<ObservedFile> ObserveTarget(string targetRoot)
    {
        var files = new List<ObservedFile>();
        var pending = new Stack<string>();
        pending.Push(targetRoot);
        while (pending.Count > 0)
        {
            var directory = pending.Pop();
            EnsureNoLinks(directory, "Target discovery directory");
            foreach (var childDirectory in Directory.GetDirectories(directory).OrderDescending(StringComparer.Ordinal))
            {
                var info = new DirectoryInfo(childDirectory);
                if ((info.Attributes & FileAttributes.ReparsePoint) != 0 || info.LinkTarget is not null)
                    throw Unsafe($"Target discovery cannot cross a link or reparse point: {childDirectory}");
                if (!ExcludedDirectories.Contains(info.Name)) pending.Push(childDirectory);
            }
            foreach (var filePath in Directory.GetFiles(directory).Order(StringComparer.Ordinal))
            {
                var file = new FileInfo(filePath);
                if ((file.Attributes & FileAttributes.ReparsePoint) != 0 || file.LinkTarget is not null)
                    throw Unsafe($"Target discovery cannot read a link or reparse point: {filePath}");
                var extension = file.Extension;
                if (!ManifestNames.Contains(file.Name) && !ManifestExtensions.Contains(extension) && !SourceLanguages.ContainsKey(extension)) continue;
                if (file.Length > MaximumFileBytes) throw Invalid($"Allowlisted discovery file exceeds {MaximumFileBytes} bytes: {file.FullName}");
                files.Add(new ObservedFile(Path.GetRelativePath(targetRoot, file.FullName).Replace('\\', '/'), HashFile(file.FullName), file.Length));
                if (files.Count > MaximumFiles) throw Invalid($"Target discovery exceeds {MaximumFiles} allowlisted files.");
            }
        }
        return files.OrderBy(file => file.RelativePath, StringComparer.Ordinal).ToList();
    }

    private static IEnumerable<Fact> FrameworkFacts(IEnumerable<ObservedFile> observed, string targetRoot, string snapshot)
    {
        var facts = new List<Fact>();
        foreach (var file in observed.Where(item => ManifestExtensions.Contains(Path.GetExtension(item.RelativePath)) || ManifestNames.Contains(Path.GetFileName(item.RelativePath))))
        {
            var name = Path.GetFileName(file.RelativePath);
            var extension = Path.GetExtension(file.RelativePath);
            if (extension is ".csproj" or ".fsproj" or ".vbproj")
            {
                var text = File.ReadAllText(Path.Combine(targetRoot, file.RelativePath.Replace('/', Path.DirectorySeparatorChar)));
                var matches = Regex.Matches(text, "<TargetFrameworks?>([^<]+)</TargetFrameworks?>", RegexOptions.CultureInvariant);
                foreach (Match match in matches)
                foreach (var framework in match.Groups[1].Value.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
                    facts.Add(new Fact("framework", file.RelativePath, $"dotnet:{framework}", "project-framework", DetectorVersion, snapshot));
            }
            else if (name.Equals("package.json", StringComparison.OrdinalIgnoreCase))
                facts.Add(new Fact("framework", file.RelativePath, "node:declared", "package-manifest", DetectorVersion, snapshot));
            else if (name.Equals("pyproject.toml", StringComparison.OrdinalIgnoreCase) || name.Equals("requirements.txt", StringComparison.OrdinalIgnoreCase))
                facts.Add(new Fact("framework", file.RelativePath, "python:declared", "package-manifest", DetectorVersion, snapshot));
            else if (name.Equals("go.mod", StringComparison.OrdinalIgnoreCase))
                facts.Add(new Fact("framework", file.RelativePath, "go:declared", "package-manifest", DetectorVersion, snapshot));
            else if (name.Equals("Cargo.toml", StringComparison.OrdinalIgnoreCase))
                facts.Add(new Fact("framework", file.RelativePath, "rust:declared", "package-manifest", DetectorVersion, snapshot));
            else if (name.Equals("pom.xml", StringComparison.OrdinalIgnoreCase) || name.StartsWith("build.gradle", StringComparison.OrdinalIgnoreCase))
                facts.Add(new Fact("framework", file.RelativePath, "jvm:declared", "package-manifest", DetectorVersion, snapshot));
        }
        return facts;
    }

    private static IEnumerable<Fact> RootFacts(IEnumerable<ObservedFile> observed, string snapshot)
    {
        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (var file in observed)
        {
            var segments = file.RelativePath.Split('/');
            for (var index = 0; index < segments.Length - 1; index++)
            {
                var name = segments[index];
                var kind = name.Equals("test", StringComparison.OrdinalIgnoreCase) || name.Equals("tests", StringComparison.OrdinalIgnoreCase)
                    ? "test-root"
                    : name.Equals("src", StringComparison.OrdinalIgnoreCase) || name.Equals("source", StringComparison.OrdinalIgnoreCase)
                        ? "source-root" : null;
                if (kind is null) continue;
                var path = string.Join('/', segments.Take(index + 1));
                if (seen.Add($"{kind}:{path}")) yield return new Fact(kind, path, path, "conventional-root", DetectorVersion, snapshot);
            }
        }
    }

    private static JsonArray Questions(IReadOnlyList<ObservedFile> observed, IReadOnlyList<Fact> facts, IReadOnlyDictionary<string, ModuleInfo> modules)
    {
        var questions = new List<JsonObject>();
        var projects = observed.Where(file => new[] { ".sln", ".slnx", ".csproj", ".fsproj", ".vbproj" }
            .Contains(Path.GetExtension(file.RelativePath), StringComparer.OrdinalIgnoreCase)).Select(file => file.RelativePath).ToArray();
        if (projects.Length > 1)
            questions.Add(Question("ambiguous-project-root", "ambiguous-project", projects, "Multiple project or solution manifests require an explicit project-root decision."));
        var frameworks = facts.Where(fact => fact.Kind == "framework").Select(fact => fact.NormalizedValue).Distinct(StringComparer.Ordinal).ToArray();
        if (frameworks.Length > 1)
            questions.Add(Question("ambiguous-framework-set", "ambiguous-framework",
                facts.Where(fact => fact.Kind == "framework").Select(fact => fact.SourcePath).Distinct(StringComparer.Ordinal).ToArray(),
                "Multiple declared framework families require explicit coverage review."));
        var hasDotNet = facts.Any(fact => fact.Kind == "language" && fact.NormalizedValue is "csharp" or "fsharp" or "visual-basic");
        if (hasDotNet && modules.ContainsKey("architecture-conformance") && modules.ContainsKey("build-evidence-provider"))
            questions.Add(Question("ambiguous-module-dotnet-coverage", "ambiguous-module", projects,
                "Installed .NET-related Modules are recommendations only; a human must decide their policy role."));
        return new JsonArray(questions.OrderBy(item => RequiredString(item, "id"), StringComparer.Ordinal).Select(item => (JsonNode)item).ToArray());
    }

    private static JsonObject Question(string id, string kind, IEnumerable<string> sourcePaths, string message) => new()
    {
        ["id"] = id,
        ["kind"] = kind,
        ["sourcePaths"] = new JsonArray(sourcePaths.Distinct(StringComparer.Ordinal).Order(StringComparer.Ordinal).Select(path => (JsonNode)path).ToArray()),
        ["message"] = message
    };

    private static JsonArray Recommendations(JsonObject discovery, string packageRoot)
    {
        var facts = discovery["facts"]!.AsArray().Select(item => item!.AsObject()).ToArray();
        var modules = LoadModules(packageRoot);
        var recommendations = new List<JsonObject>();
        if (facts.Any(fact => RequiredString(fact, "kind") == "language" && RequiredString(fact, "normalizedValue") is "csharp" or "fsharp" or "visual-basic") &&
            modules.ContainsKey("architecture-conformance"))
        {
            recommendations.Add(new JsonObject
            {
                ["id"] = "consider-architecture-conformance", ["kind"] = "consider-module",
                ["moduleId"] = "architecture-conformance",
                ["rationale"] = "The Target declares .NET source; policy and rule selection still require human review.",
                ["confidence"] = "medium"
            });
        }
        if (facts.Any(fact => RequiredString(fact, "kind") == "framework"))
        {
            recommendations.Add(new JsonObject
            {
                ["id"] = "review-declared-frameworks", ["kind"] = "review-framework", ["moduleId"] = null,
                ["rationale"] = "Declared frameworks were observed but do not determine accepted coverage policy.",
                ["confidence"] = "high"
            });
        }
        return new JsonArray(recommendations.OrderBy(item => RequiredString(item, "id"), StringComparer.Ordinal).Select(item => (JsonNode)item).ToArray());
    }

    private static JsonObject ConservativeProfile(string profileId) => new()
    {
        ["formatVersion"] = 1,
        ["id"] = profileId,
        ["version"] = "0.1.0",
        ["projectIdentity"] = new JsonObject { ["id"] = profileId, ["relativeRoots"] = new JsonArray() },
        ["moduleSelections"] = new JsonArray(),
        ["stageConfiguration"] = new JsonObject
        {
            ["bootstrap"] = DisabledStage(), ["analysis"] = DisabledStage(), ["pre"] = DisabledStage(), ["post"] = DisabledStage()
        },
        ["rules"] = new JsonArray(),
        ["baselineRefs"] = new JsonArray()
    };

    private static JsonObject DisabledStage() => new() { ["enabled"] = false, ["modules"] = new JsonArray() };

    private static Dictionary<string, ModuleInfo> LoadModules(string packageRoot)
    {
        var registryPath = Path.Combine(packageRoot, "modules", "registry.json");
        var registry = ReadObject(registryPath, "Module registry");
        var modules = new Dictionary<string, ModuleInfo>(StringComparer.Ordinal);
        foreach (var entryNode in registry["modules"]?.AsArray() ?? throw Invalid("Module registry entries are missing."))
        {
            var entry = entryNode!.AsObject();
            var id = RequiredString(entry, "id");
            var manifestRelative = RequiredString(entry, "manifestPath");
            var manifestPath = ResolveFileUnder(packageRoot, manifestRelative, $"Module manifest {id}");
            var manifestHash = HashFile(manifestPath);
            if (manifestHash != RequiredString(entry, "manifestSha256")) throw Integrity($"Module manifest hash drift: {id}");
            var manifest = ReadObject(manifestPath, $"Module manifest {id}");
            if (RequiredString(manifest, "id") != id) throw Integrity($"Module registry identity drift: {id}");
            var configSchema = RequiredString(manifest, "configSchema");
            _ = ResolveFileUnder(packageRoot, configSchema, $"Module configuration schema {id}");
            var ceiling = entry["allowedCapabilities"]?.AsObject().DeepClone().AsObject()
                ?? throw Invalid($"Module capability ceiling is missing: {id}");
            if (!modules.TryAdd(id, new ModuleInfo(id, manifestRelative, manifestHash, manifest, ceiling, configSchema)))
                throw Invalid($"Duplicate Module registry ID: {id}");
        }
        return modules;
    }

    private static HashSet<string> InstalledProfileIds(string packageRoot)
    {
        var plugin = ReadObject(Path.Combine(packageRoot, "plugin.json"), "plugin manifest");
        var catalog = ResolveDirectoryUnder(packageRoot, RequiredString(plugin, "profilesCatalog"), "Profile catalog");
        return Directory.GetDirectories(catalog).Select(Path.GetFileName).Where(name => name is not null).Cast<string>()
            .ToHashSet(StringComparer.Ordinal);
    }

    private static string ManifestValue(string path)
    {
        var extension = Path.GetExtension(path).ToLowerInvariant();
        return extension switch
        {
            ".sln" or ".slnx" => "dotnet-solution",
            ".csproj" => "dotnet-csharp-project",
            ".fsproj" => "dotnet-fsharp-project",
            ".vbproj" => "dotnet-visual-basic-project",
            _ => Path.GetFileName(path).ToLowerInvariant()
        };
    }

    private static string LanguageSource(IEnumerable<ObservedFile> files, string language) => files
        .Where(file => SourceLanguages.TryGetValue(Path.GetExtension(file.RelativePath), out var value) && value == language)
        .Select(file => file.RelativePath).Order(StringComparer.Ordinal).First();

    private static void ValidateNode(string packageRoot, string schemaId, JsonNode node)
    {
        var path = Path.Combine(Path.GetTempPath(), $"v4-profile-contract-{Guid.NewGuid():N}.json");
        try
        {
            File.WriteAllText(path, Serialize(node), new UTF8Encoding(false));
            ContractRuntime.ValidateRegisteredDocument(packageRoot, schemaId, path);
        }
        finally { if (File.Exists(path)) File.Delete(path); }
    }

    private static void ValidateFile(string packageRoot, string schemaId, string path) =>
        ContractRuntime.ValidateRegisteredDocument(packageRoot, schemaId, path);

    private static void ValidateArbitrarySchema(JsonNode document, string schemaPath, string label)
    {
        var documentPath = Path.Combine(Path.GetTempPath(), $"v4-profile-config-{Guid.NewGuid():N}.json");
        try
        {
            File.WriteAllText(documentPath, Serialize(document), new UTF8Encoding(false));
            const string script = "if(Test-Json -LiteralPath $env:V4_PROFILE_DOCUMENT -SchemaFile $env:V4_PROFILE_SCHEMA -ErrorAction SilentlyContinue){exit 0}else{exit 1}";
            var start = new ProcessStartInfo("pwsh") { UseShellExecute = false, RedirectStandardError = true, RedirectStandardOutput = true, CreateNoWindow = true };
            foreach (var arg in new[] { "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", script }) start.ArgumentList.Add(arg);
            start.Environment["V4_PROFILE_DOCUMENT"] = documentPath;
            start.Environment["V4_PROFILE_SCHEMA"] = schemaPath;
            using var process = Process.Start(start) ?? throw new System.ComponentModel.Win32Exception("PowerShell 7 did not start.");
            process.WaitForExit();
            if (process.ExitCode != 0) throw Findings($"{label} does not satisfy its installed schema.");
        }
        finally { if (File.Exists(documentPath)) File.Delete(documentPath); }
    }

    private static JsonObject ReadObject(string path, string label)
    {
        try { return JsonNode.Parse(File.ReadAllText(path))?.AsObject() ?? throw new JsonException("Document is empty."); }
        catch (Exception ex) when (ex is JsonException or IOException or InvalidOperationException)
        { throw Invalid($"{label} is invalid JSON: {ex.Message}"); }
    }

    private static string ResolveExistingDirectory(string value, string label)
    {
        var path = Path.TrimEndingDirectorySeparator(Path.GetFullPath(value));
        if (!Directory.Exists(path)) throw Invalid($"{label} does not exist.");
        EnsureNoLinks(path, label);
        return path;
    }

    private static string ResolveExistingFile(string value, string label)
    {
        var path = Path.GetFullPath(value);
        if (!File.Exists(path)) throw Invalid($"The {label} does not exist.");
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

    private static string ResolveDirectoryUnder(string root, string relative, string label)
    {
        if (Path.IsPathRooted(relative)) throw Unsafe($"{label} must be relative.");
        var path = Path.GetFullPath(Path.Combine(root, relative));
        EnsureUnder(path, root, $"{label} escapes PackageRoot.");
        if (!Directory.Exists(path)) throw Invalid($"{label} is missing.");
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

    private static void EnsureDisjoint(string left, string right, string label)
    {
        if (IsUnder(left, right) || IsUnder(right, left)) throw Unsafe($"{label} overlap.");
    }

    private static void EnsureUnder(string path, string root, string message)
    {
        if (!IsUnder(path, root)) throw Unsafe(message);
    }

    private static void EnsureNotUnder(string path, string root, string message)
    {
        if (IsUnder(path, root) || IsUnder(root, path)) throw Unsafe(message);
    }

    private static bool IsUnder(string path, string root)
    {
        var relative = Path.GetRelativePath(root, path);
        return relative == "." || (!Path.IsPathRooted(relative) && relative != ".." &&
            !relative.StartsWith($"..{Path.DirectorySeparatorChar}", StringComparison.Ordinal));
    }

    private static bool PathEquals(string left, string right) => string.Equals(Path.TrimEndingDirectorySeparator(Path.GetFullPath(left)),
        Path.TrimEndingDirectorySeparator(Path.GetFullPath(right)), OperatingSystem.IsWindows() ? StringComparison.OrdinalIgnoreCase : StringComparison.Ordinal);

    private static void WriteNewOrSame(string path, string text)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        EnsureNoLinks(Path.GetDirectoryName(path)!, "output directory");
        if (File.Exists(path))
        {
            if (File.ReadAllText(path) != text) throw Conflict($"Existing deterministic output differs: {path}");
            return;
        }
        var temporary = Path.Combine(Path.GetDirectoryName(path)!, $".{Path.GetFileName(path)}.{Guid.NewGuid():N}.tmp");
        try
        {
            File.WriteAllText(temporary, text, new UTF8Encoding(false));
            File.Move(temporary, path);
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }

    private static string Serialize(JsonNode node) => node.ToJsonString(JsonOptions).Replace("\r\n", "\n") + "\n";
    private static string Canonical(JsonNode node) => node.ToJsonString(CompactJsonOptions);
    private static string HashCanonical(JsonNode node) => HashText(Canonical(node));
    private static string HashText(string value) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value))).ToLowerInvariant();
    private static string HashFile(string path) => Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path))).ToLowerInvariant();
    private static string ProjectId(string targetRoot) => HashText(OperatingSystem.IsWindows() ? targetRoot.ToUpperInvariant() : targetRoot)[..32];

    private static string RequiredString(JsonObject value, string property)
    {
        if (value[property] is not JsonValue node || !node.TryGetValue<string>(out var text) || string.IsNullOrWhiteSpace(text))
            throw Invalid($"Required string is missing: {property}");
        return text;
    }

    private static int Error(int code, string category, string message)
    {
        Console.Error.WriteLine(JsonSerializer.Serialize(new
        {
            formatVersion = 1, status = "error", operation = "profile", exitCategory = category, message
        }, JsonOptions));
        return code;
    }

    private static ProfileException Invalid(string message) => new(10, "invalid-input", message);
    private static ProfileException Unsafe(string message) => new(11, "unsafe-path", message);
    private static ProfileException Integrity(string message) => new(12, "integrity-failure", message);
    private static ProfileException Capability(string message) => new(13, "capability-denied", message);
    private static ProfileException Findings(string message) => new(16, "findings-blocking", message);
    private static ProfileException Conflict(string message) => new(17, "state-conflict", message);

    private sealed record ObservedFile(string RelativePath, string Sha256, long Size);
    private sealed record Fact(string Kind, string SourcePath, string NormalizedValue, string DetectorId, string DetectorVersion, string TargetSnapshotSha256);
    private sealed record ModuleInfo(string Id, string ManifestPath, string ManifestSha256, JsonObject Manifest, JsonObject AllowedCapabilities, string ConfigSchema);
    private sealed record ReviewContext(string PackageRoot, string TargetRoot, string StateRoot, string DraftPath, string ReviewPath, JsonObject Draft, JsonObject Review);

    private sealed class Arguments(string operation, Dictionary<string, string> values)
    {
        public string Operation { get; } = operation;

        public static Arguments Parse(string[] args)
        {
            if (args.Length < 2 || args[0] != "profile") throw Invalid("Expected 'profile <discover|draft|validate|promote>'.");
            var values = new Dictionary<string, string>(StringComparer.Ordinal);
            for (var index = 2; index < args.Length; index += 2)
            {
                if (index + 1 >= args.Length || !args[index].StartsWith("--", StringComparison.Ordinal))
                    throw Invalid("Arguments must be --name value pairs.");
                if (!values.TryAdd(args[index][2..], args[index + 1])) throw Invalid($"Duplicate argument: {args[index]}");
            }
            return new Arguments(args[1], values);
        }

        public string Required(string name) => values.TryGetValue(name, out var value) && !string.IsNullOrWhiteSpace(value)
            ? value : throw Invalid($"Missing --{name}.");

        public void RequireOnly(params string[] known)
        {
            var unknown = values.Keys.Where(key => !known.Contains(key, StringComparer.Ordinal)).ToArray();
            if (unknown.Length > 0) throw Invalid($"Unknown argument: --{unknown[0]}");
            foreach (var name in known) _ = Required(name);
        }
    }

    private sealed class ProfileException(int code, string category, string message) : Exception(message)
    {
        public int Code { get; } = code;
        public string Category { get; } = category;
    }
}
