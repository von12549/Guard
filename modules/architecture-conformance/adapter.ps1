Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($env:V4_STAGE_INPUT_JSON)) { throw 'V4_STAGE_INPUT_JSON is required.' }
$inputData = $env:V4_STAGE_INPUT_JSON | ConvertFrom-Json
if ($inputData.formatVersion -ne 1 -or $inputData.stage -notin @('pre','post')) { throw 'Architecture Conformance supports only Pre and Post.' }

$targetRoot = [IO.Path]::GetFullPath([string]$inputData.targetRoot)
$config = $inputData.config
$enabled = @($config.enabledClaims)
$coverage = [Collections.Generic.List[object]]::new()
$findings = [Collections.Generic.List[object]]::new()
$findingKeys = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)

$projectClaims = @('ARCH.PROJECT_REFERENCE','ARCH.PACKAGE_REFERENCE','ARCH.TARGET_FRAMEWORK','ARCH.GRAPH_COMPLETENESS')
$syntaxClaims = @('ARCH.SOURCE_IMPORT','ARCH.DISABLED_BRANCH','ARCH.DECLARATION_PLACEMENT')
$semanticClaims = @('ARCH.FORBIDDEN_SYMBOL','ARCH.MEMBER_PAYLOAD')
$compiledClaims = @('ARCH.TYPE_DEPENDENCY','ARCH.IMPLEMENTATION_LOCATION','ARCH.ASSEMBLY_PLACEMENT')
$activeClaims = if ($inputData.stage -eq 'pre') {
    @($enabled | Where-Object { $_ -in ($projectClaims + $syntaxClaims) })
} else {
    @($enabled | Where-Object { $_ -in ($semanticClaims + $compiledClaims) })
}

function Relative([string] $Path) { [IO.Path]::GetRelativePath($targetRoot, $Path).Replace('\','/') }
function Enabled([string] $Claim) { return $activeClaims -contains $Claim }
function Config-Array([string] $Name) {
    if ($config.PSObject.Properties.Name -contains $Name) { return @($config.$Name) }
    return @()
}
function Matches-Policy([string] $Candidate, [string[]] $Policies) {
    foreach ($policy in $Policies) {
        if ($Candidate -ceq $policy -or $Candidate.StartsWith("$policy.", [StringComparison]::Ordinal)) { return $true }
    }
    return $false
}
function Add-Finding([string] $RuleId, [string] $Subject, [string] $EvidenceKind, [string] $DetectorId) {
    $key = "$RuleId`n$Subject`n$EvidenceKind`n$DetectorId"
    if ($findingKeys.Add($key)) {
        $findings.Add([ordered]@{ ruleId=$RuleId; subject=$Subject; evidenceKind=$EvidenceKind; detectorId=$DetectorId; severity='blocking' })
    }
}
function Add-Coverage([string[]] $Claims, [int] $Matched) {
    foreach ($claim in $Claims) { $coverage.Add([ordered]@{ claimId=$claim; matched=$Matched; minimum=1 }) }
}
function Write-Result([string] $Status, [string] $Category, [string] $Message = '') {
    $result = [ordered]@{ formatVersion=1; status=$Status; exitCategory=$Category }
    if (-not [string]::IsNullOrWhiteSpace($Message)) { $result.message = $Message }
    $result.findings = @($findings)
    $result.coverage = @($coverage)
    $result | ConvertTo-Json -Depth 20 -Compress
}
function Is-Under([string] $Path, [string] $Root) {
    $relative = [IO.Path]::GetRelativePath($Root, $Path)
    return $relative -eq '.' -or (-not [IO.Path]::IsPathRooted($relative) -and $relative -ne '..' -and
        -not $relative.StartsWith("..$([IO.Path]::DirectorySeparatorChar)", [StringComparison]::Ordinal))
}
function Resolve-ScanRoots {
    $declared = @(if ($inputData.PSObject.Properties.Name -contains 'relativeRoots') { $inputData.relativeRoots })
    if ($declared.Count -eq 0 -or ($declared.Count -eq 1 -and $declared[0] -ceq '.')) { return @($targetRoot) }
    $resolved = [Collections.Generic.List[string]]::new()
    $names = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($value in $declared) {
        if ($value -isnot [string] -or [string]::IsNullOrWhiteSpace($value)) { throw 'Relative scan root is missing or not a string.' }
        $relative = $value.Replace('\','/')
        $parts = $relative.Split('/')
        if ([IO.Path]::IsPathRooted($value) -or $relative -match '^[A-Za-z]:' -or
            @($parts | Where-Object { $_ -in @('', '.', '..') }).Count -gt 0) {
            throw "Unsafe relative scan root: $value"
        }
        if (-not $names.Add($relative)) { throw "Duplicate or case-colliding scan root: $value" }
        $path = $targetRoot
        foreach ($part in $parts) {
            $path = Join-Path $path $part
            if (-not [IO.Directory]::Exists($path)) { throw "Scan root is missing: $value" }
            $item = Get-Item -LiteralPath $path -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) {
                throw "Scan root crosses a link: $value"
            }
        }
        $full = [IO.Path]::GetFullPath($path)
        if ($full -ceq $targetRoot -or -not (Is-Under $full $targetRoot)) { throw "Scan root escapes TargetRoot: $value" }
        foreach ($prior in $resolved) {
            if ((Is-Under $full $prior) -or (Is-Under $prior $full)) { throw "Overlapping scan roots: $value" }
        }
        $resolved.Add($full)
    }
    $resolved.Sort([StringComparer]::Ordinal)
    return $resolved.ToArray()
}
function Scoped-Files([string] $Filter) {
    $files = [Collections.Generic.List[IO.FileInfo]]::new()
    foreach ($scanRoot in $scanRoots) {
        foreach ($file in Get-ChildItem -LiteralPath $scanRoot -Recurse -File -Filter $Filter) {
            $relative = Relative $file.FullName
            if (@($relative.Split('/') | Where-Object { $_ -in @('bin','obj') }).Count -gt 0) { continue }
            if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $file.LinkTarget) {
                throw "Scan input is a link: $relative"
            }
            $files.Add($file)
        }
    }
    $files.Sort([Comparison[IO.FileInfo]]{ param($left,$right) [StringComparer]::Ordinal.Compare($left.FullName,$right.FullName) })
    return $files.ToArray()
}
try { $scanRoots = @(Resolve-ScanRoots) }
catch {
    Write-Result 'error' 'unsafe-path' $_.Exception.Message
    exit 0
}
function Source-Location($Node, [string] $Path) {
    $position = $Node.GetLocation().GetLineSpan().StartLinePosition
    return "$(Relative $Path):$($position.Line + 1):$($position.Character + 1)"
}
function Find-RoslynRoots {
    if ($null -eq (Get-Command dotnet -ErrorAction SilentlyContinue)) { return @() }
    $candidates = [Collections.Generic.List[object]]::new()
    foreach ($line in @(& dotnet --list-sdks 2>&1)) {
        if ([string]$line -match '^([^\s]+)\s+\[(.+)\]$') {
            $version = $null
            if ([version]::TryParse($Matches[1].Split('-')[0], [ref]$version)) {
                $root = Join-Path (Join-Path $Matches[2] $Matches[1]) 'Roslyn/bincore'
                if ([IO.File]::Exists((Join-Path $root 'Microsoft.CodeAnalysis.dll')) -and [IO.File]::Exists((Join-Path $root 'Microsoft.CodeAnalysis.CSharp.dll'))) {
                    $candidates.Add([pscustomobject]@{ Version=$version; Root=$root })
                }
            }
        }
    }
    return @($candidates | Sort-Object Version -Descending | ForEach-Object Root)
}
function Load-Roslyn {
    foreach ($roslynRoot in @(Find-RoslynRoots)) {
        try {
            [void][Reflection.Assembly]::LoadFrom((Join-Path $roslynRoot 'Microsoft.CodeAnalysis.dll'))
            [void][Reflection.Assembly]::LoadFrom((Join-Path $roslynRoot 'Microsoft.CodeAnalysis.CSharp.dll'))
            return $true
        } catch {
            continue
        }
    }
    $hostCommon = Join-Path $PSHOME 'Microsoft.CodeAnalysis.dll'
    $hostCSharp = Join-Path $PSHOME 'Microsoft.CodeAnalysis.CSharp.dll'
    if ([IO.File]::Exists($hostCommon) -and [IO.File]::Exists($hostCSharp)) {
        [void][Reflection.Assembly]::LoadFrom($hostCommon)
        [void][Reflection.Assembly]::LoadFrom($hostCSharp)
        return $true
    }
    return $false
}
function Resolve-EvidencePath([string] $EvidenceRoot, [string] $Relative, [string] $Label) {
    if ([string]::IsNullOrWhiteSpace($Relative) -or [IO.Path]::IsPathRooted($Relative)) { throw "$Label must be a relative path beneath EvidenceRoot." }
    $segments = $Relative.Replace('\','/').Split('/', [StringSplitOptions]::RemoveEmptyEntries)
    if ($segments.Count -eq 0 -or $segments -contains '..' -or $segments -contains '.') { throw "$Label contains an unsafe path segment: $Relative" }
    $resolved = [IO.Path]::GetFullPath((Join-Path $EvidenceRoot ($segments -join [IO.Path]::DirectorySeparatorChar)))
    $prefix = $EvidenceRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw "$Label escapes EvidenceRoot: $Relative" }
    $probe = $resolved
    while (-not (Test-Path -LiteralPath $probe) -and -not $probe.Equals($EvidenceRoot,[StringComparison]::OrdinalIgnoreCase)) { $probe = [IO.Path]::GetDirectoryName($probe) }
    while (-not [string]::IsNullOrWhiteSpace($probe) -and ($probe.Equals($EvidenceRoot,[StringComparison]::OrdinalIgnoreCase) -or $probe.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase))) {
        $item = Get-Item -LiteralPath $probe -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $item.LinkTarget) { throw "$Label crosses a link or reparse point: $probe" }
        if ($probe.Equals($EvidenceRoot,[StringComparison]::OrdinalIgnoreCase)) { break }
        $probe = [IO.Path]::GetDirectoryName($probe)
    }
    return $resolved
}
function Get-NuGetPackageRoot {
    if (-not [string]::IsNullOrWhiteSpace($env:NUGET_PACKAGES)) { return [IO.Path]::GetFullPath($env:NUGET_PACKAGES) }
    $userProfile = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
    if (-not [string]::IsNullOrWhiteSpace($userProfile)) {
        $defaultRoot = Join-Path $userProfile '.nuget/packages'
        if ([IO.Directory]::Exists($defaultRoot)) { return [IO.Path]::GetFullPath($defaultRoot) }
    }
    if ($null -eq (Get-Command dotnet -ErrorAction SilentlyContinue)) { return $null }
    foreach ($line in @(& dotnet nuget locals global-packages --list 2>&1)) {
        if ([string]$line -match '^[^:]+:\s*(.+)$') { return [IO.Path]::GetFullPath($Matches[1].Trim()) }
    }
    return $null
}
function Load-ArchUnitNet {
    $packagesRoot = Get-NuGetPackageRoot
    if ([string]::IsNullOrWhiteSpace($packagesRoot)) { return $false }
    $packages = @(
        [ordered]@{ Id='cycledetection'; Version='2.0.0'; Sha512='B17MeeByzaoz26WWgV/UnFgmkPhV1AS9bjV0OE7XS2mccAFbkUt0RTxbKBtiN/CsbHwxQFBpGwpdxm6W2KuvEQ=='; Dlls=@('lib/netcoreapp2.0/StronglyConnectedComponents.dll') },
        [ordered]@{ Id='jetbrains.annotations'; Version='2026.2.0'; Sha512='s1XOfrJmIZOk12oYmy89zIXwotbgI7gO+oq43M74xIJkssTy16fJe3fz5IurxqPsRl6P4Of/7iBx0y/ltMu9oQ=='; Dlls=@('lib/netstandard2.0/JetBrains.Annotations.dll') },
        [ordered]@{ Id='mono.cecil'; Version='0.11.6'; Sha512='HFkyJGsjyfMXaQolzj4UFtFo2IWHEGPS9gTPmX7Z6Z1BvM3Q4i1L5uSl6nKdBr2SzFQ2htu9dasBmdtg4JEvtA=='; Dlls=@('lib/netstandard2.0/Mono.Cecil.dll','lib/netstandard2.0/Mono.Cecil.Rocks.dll','lib/netstandard2.0/Mono.Cecil.Pdb.dll','lib/netstandard2.0/Mono.Cecil.Mdb.dll') },
        [ordered]@{ Id='newtonsoft.json'; Version='13.0.4'; Sha512='bR+v+E/yJ6g7GV2uXw2OrUSjYYfjLkOLC8JD4kCS23msLapnKtdJPBJA75fwHH++ErIffeIqzYITLxAur4KAXA=='; Dlls=@('lib/net6.0/Newtonsoft.Json.dll') },
        [ordered]@{ Id='tngtech.archunitnet'; Version='0.13.4'; Sha512='2XXCci6X7VpgVrfv4Ugjkmzvm/OUx0fPBiniXehL7iAM4E56z3MvfmIiOU8RCxDnG6PX7OJG65nm6YbW0fJyHg=='; Dlls=@('lib/netstandard2.0/ArchUnitNET.dll') }
    )
    foreach ($package in $packages) {
        $packageRoot = Join-Path (Join-Path $packagesRoot $package.Id) $package.Version
        $hashPath = Join-Path $packageRoot "$($package.Id).$($package.Version).nupkg.sha512"
        if (-not [IO.File]::Exists($hashPath) -or [IO.File]::ReadAllText($hashPath).Trim() -cne $package.Sha512) { return $false }
        foreach ($relativeDll in $package.Dlls) {
            $dllPath = Join-Path $packageRoot $relativeDll
            if (-not [IO.File]::Exists($dllPath)) { return $false }
            try { [void][Reflection.Assembly]::LoadFrom($dllPath) } catch { return $false }
        }
    }
    return $true
}
function Target-Snapshot([string] $Root) {
    $lines = [Collections.Generic.List[string]]::new()
    foreach ($file in Get-ChildItem -LiteralPath $Root -Recurse -File -Force | Sort-Object FullName) {
        $relative = Relative $file.FullName
        $parts = $relative.Split('/', [StringSplitOptions]::RemoveEmptyEntries)
        if (@($parts | Where-Object { $_ -in @('.git','bin','obj','artifacts') }).Count -gt 0) { continue }
        if (($file.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0 -or $null -ne $file.LinkTarget) { throw "Target snapshot crosses a link: $relative" }
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $file.FullName).Hash.ToLowerInvariant()
        $lines.Add("$relative`:$hash")
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes(($lines -join "`n"))
    return [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}

$requestedProjectClaims = @($activeClaims | Where-Object { $_ -in $projectClaims })
if ($requestedProjectClaims.Count -gt 0) {
    $projects = @(Scoped-Files '*.csproj')
    if ($projects.Count -eq 0) {
        Add-Coverage $activeClaims 0
        Write-Result 'error' 'prerequisite-missing' 'No declared project files were found.'
        exit 0
    }
    foreach ($project in $projects) {
        try { $xml = [xml][IO.File]::ReadAllText($project.FullName) }
        catch { throw "Project XML is invalid: $(Relative $project.FullName): $($_.Exception.Message)" }
        $projectSubject = Relative $project.FullName
        if (Enabled 'ARCH.PROJECT_REFERENCE') {
            foreach ($reference in @($xml.SelectNodes("//*[local-name()='ProjectReference']"))) {
                $include = [string]$reference.Include
                foreach ($forbidden in @(Config-Array 'forbiddenProjectReferences')) {
                    if ($include -like $forbidden) { Add-Finding 'ARCH.PROJECT_REFERENCE' "$projectSubject -> $include" 'project-model-raw' 'project-model' }
                }
            }
        }
        if (Enabled 'ARCH.PACKAGE_REFERENCE') {
            foreach ($reference in @($xml.SelectNodes("//*[local-name()='PackageReference']"))) {
                $identity = if ($reference.Include) { [string]$reference.Include } else { [string]$reference.Update }
                if (@(Config-Array 'forbiddenPackages') -contains $identity) { Add-Finding 'ARCH.PACKAGE_REFERENCE' "$projectSubject -> $identity" 'project-model-raw' 'project-model' }
            }
        }
        if (Enabled 'ARCH.TARGET_FRAMEWORK') {
            $frameworks = @($xml.SelectNodes("//*[local-name()='TargetFramework' or local-name()='TargetFrameworks']") | ForEach-Object { ([string]$_.InnerText).Split(';',[StringSplitOptions]::RemoveEmptyEntries) } | ForEach-Object { $_.Trim() })
            if ($frameworks.Count -eq 0) { Add-Finding 'ARCH.TARGET_FRAMEWORK' "$projectSubject -> <missing>" 'project-model-raw' 'project-model' }
            foreach ($framework in $frameworks) {
                if (@(Config-Array 'allowedTargetFrameworks') -notcontains $framework) { Add-Finding 'ARCH.TARGET_FRAMEWORK' "$projectSubject -> $framework" 'project-model-raw' 'project-model' }
            }
        }
        if ((Enabled 'ARCH.GRAPH_COMPLETENESS') -and ($config.PSObject.Properties.Name -contains 'requireResolvedProjectReferences') -and $config.requireResolvedProjectReferences) {
            foreach ($reference in @($xml.SelectNodes("//*[local-name()='ProjectReference']"))) {
                $resolved = [IO.Path]::GetFullPath((Join-Path $project.DirectoryName ([string]$reference.Include)))
                $prefix = $targetRoot.TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
                if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or
                    -not [IO.File]::Exists($resolved) -or
                    @($scanRoots | Where-Object { Is-Under $resolved $_ }).Count -eq 0) {
                    Add-Finding 'ARCH.GRAPH_COMPLETENESS' "$projectSubject -> $([string]$reference.Include)" 'project-model-raw' 'project-model'
                }
            }
        }
    }
    Add-Coverage $requestedProjectClaims $projects.Count
}

$requestedSourceClaims = @($activeClaims | Where-Object { $_ -in ($syntaxClaims + $semanticClaims) })
if ($requestedSourceClaims.Count -gt 0) {
    $sources = @(Scoped-Files '*.cs')
    if ($sources.Count -eq 0) {
        Add-Coverage $requestedSourceClaims 0
        Write-Result 'error' 'prerequisite-missing' 'No C# source files were found.'
        exit 0
    }
    if (-not (Load-Roslyn)) {
        Add-Coverage $requestedSourceClaims 0
        Write-Result 'error' 'prerequisite-missing' 'An installed .NET SDK with Roslyn compiler assemblies is required.'
        exit 0
    }
    $trees = [Collections.Generic.List[Microsoft.CodeAnalysis.SyntaxTree]]::new()
    foreach ($source in $sources) {
        $tree = [Microsoft.CodeAnalysis.CSharp.CSharpSyntaxTree]::ParseText([IO.File]::ReadAllText($source.FullName), $null, $source.FullName)
        $trees.Add($tree)
        $root = $tree.GetRoot()
        if (Enabled 'ARCH.SOURCE_IMPORT') {
            foreach ($node in $root.DescendantNodes()) {
                if ($node.Kind().ToString() -eq 'UsingDirective') {
                    $identity = [string]$node.Name.ToString()
                    if (Matches-Policy $identity @(Config-Array 'forbiddenImports')) {
                        Add-Finding 'ARCH.SOURCE_IMPORT' "$(Source-Location $node $source.FullName) -> $identity" 'source-syntax' 'roslyn-syntax'
                    }
                }
            }
        }
        if (Enabled 'ARCH.DISABLED_BRANCH') {
            foreach ($trivia in $root.DescendantTrivia($null, $true)) {
                if ($trivia.RawKind -eq [int][Microsoft.CodeAnalysis.CSharp.SyntaxKind]::DisabledTextTrivia) {
                    Add-Finding 'ARCH.DISABLED_BRANCH' "$(Source-Location $trivia $source.FullName) -> disabled-text" 'source-syntax' 'roslyn-syntax'
                }
            }
        }
        if (Enabled 'ARCH.DECLARATION_PLACEMENT') {
            foreach ($node in $root.DescendantNodes()) {
                if ($node.Kind().ToString() -in @('ClassDeclaration','StructDeclaration','InterfaceDeclaration','EnumDeclaration','RecordDeclaration','RecordStructDeclaration')) {
                    $namespaceParts = @($node.Ancestors() | Where-Object { $_.Kind().ToString() -in @('NamespaceDeclaration','FileScopedNamespaceDeclaration') } | ForEach-Object { [string]$_.Name.ToString() })
                    [array]::Reverse($namespaceParts)
                    $namespace = if ($namespaceParts.Count -eq 0) { '<global>' } else { $namespaceParts -join '.' }
                    if (Matches-Policy $namespace @(Config-Array 'forbiddenDeclarationNamespaces')) {
                        Add-Finding 'ARCH.DECLARATION_PLACEMENT' "$(Source-Location $node $source.FullName) -> $namespace.$($node.Identifier.Text)" 'source-syntax' 'roslyn-syntax'
                    }
                }
            }
        }
    }

    if ($inputData.stage -eq 'post') {
        $references = [Collections.Generic.List[Microsoft.CodeAnalysis.MetadataReference]]::new()
        $trustedAssemblies = [string][AppContext]::GetData('TRUSTED_PLATFORM_ASSEMBLIES')
        if ([string]::IsNullOrWhiteSpace($trustedAssemblies)) {
            Add-Coverage $requestedSourceClaims 0
            Write-Result 'error' 'prerequisite-missing' 'Trusted platform assemblies are unavailable for semantic inspection.'
            exit 0
        }
        foreach ($assemblyPath in $trustedAssemblies.Split([IO.Path]::PathSeparator, [StringSplitOptions]::RemoveEmptyEntries)) {
            $references.Add([Microsoft.CodeAnalysis.MetadataReference]::CreateFromFile($assemblyPath))
        }
        $options = [Microsoft.CodeAnalysis.CSharp.CSharpCompilationOptions]::new([Microsoft.CodeAnalysis.OutputKind]::DynamicallyLinkedLibrary)
        $compilation = [Microsoft.CodeAnalysis.CSharp.CSharpCompilation]::Create('V4ArchitectureInspection', $trees.ToArray(), $references.ToArray(), $options)
        foreach ($tree in $trees) {
            $root = $tree.GetRoot()
            $model = $compilation.GetSemanticModel($tree)
            if (Enabled 'ARCH.FORBIDDEN_SYMBOL') {
                foreach ($node in $root.DescendantNodes()) {
                    if ($node.Kind().ToString() -in @('IdentifierName','GenericName')) {
                        $symbol = $model.GetSymbolInfo($node).Symbol
                        if ($null -ne $symbol) {
                            $identity = [Microsoft.CodeAnalysis.CSharp.SymbolDisplay]::ToDisplayString([Microsoft.CodeAnalysis.ISymbol]$symbol, [Microsoft.CodeAnalysis.SymbolDisplayFormat]::CSharpErrorMessageFormat)
                            if (Matches-Policy $identity @(Config-Array 'forbiddenSymbols')) {
                                Add-Finding 'ARCH.FORBIDDEN_SYMBOL' "$(Source-Location $node $tree.FilePath) -> $identity" 'source-semantic' 'roslyn-semantic'
                            }
                        }
                    }
                }
            }
            if (Enabled 'ARCH.MEMBER_PAYLOAD') {
                foreach ($node in $root.DescendantNodes()) {
                    if ($node.Kind().ToString() -notin @('MethodDeclaration','ConstructorDeclaration','PropertyDeclaration','IndexerDeclaration','FieldDeclaration','EventDeclaration','EventFieldDeclaration','DelegateDeclaration','OperatorDeclaration','ConversionOperatorDeclaration')) { continue }
                    $isPublic = @($node.Modifiers | Where-Object { $_.RawKind -eq [int][Microsoft.CodeAnalysis.CSharp.SyntaxKind]::PublicKeyword }).Count -gt 0
                    if (-not $isPublic) {
                        $isPublic = @($node.Ancestors() | Where-Object { $_.Kind().ToString() -eq 'InterfaceDeclaration' } | Select-Object -First 1).Count -gt 0
                    }
                    if (-not $isPublic) { continue }
                    $typeNodes = [Collections.Generic.List[object]]::new()
                    if ($node.PSObject.Properties.Name -contains 'ReturnType') { $typeNodes.Add($node.ReturnType) }
                    if ($node.PSObject.Properties.Name -contains 'Type') { $typeNodes.Add($node.Type) }
                    if (($node.PSObject.Properties.Name -contains 'Declaration') -and $null -ne $node.Declaration) { $typeNodes.Add($node.Declaration.Type) }
                    if ($node.PSObject.Properties.Name -contains 'ParameterList') {
                        foreach ($parameter in $node.ParameterList.Parameters) { if ($null -ne $parameter.Type) { $typeNodes.Add($parameter.Type) } }
                    }
                    foreach ($typeNode in $typeNodes) {
                        if ($null -eq $typeNode) { continue }
                        foreach ($candidateTypeNode in $typeNode.DescendantNodesAndSelf()) {
                            $type = $model.GetTypeInfo($candidateTypeNode).Type
                            if ($null -ne $type) {
                                $identity = [Microsoft.CodeAnalysis.CSharp.SymbolDisplay]::ToDisplayString([Microsoft.CodeAnalysis.ISymbol]$type, [Microsoft.CodeAnalysis.SymbolDisplayFormat]::CSharpErrorMessageFormat)
                                if (Matches-Policy $identity @(Config-Array 'forbiddenPayloadNamespaces')) {
                                    Add-Finding 'ARCH.MEMBER_PAYLOAD' "$(Source-Location $candidateTypeNode $tree.FilePath) -> $identity" 'source-semantic' 'roslyn-semantic'
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    Add-Coverage $requestedSourceClaims $sources.Count
}

$requestedCompiledClaims = @($activeClaims | Where-Object { $_ -in $compiledClaims })
if ($requestedCompiledClaims.Count -gt 0) {
    if (-not ($inputData.PSObject.Properties.Name -contains 'evidenceRoot') -or [string]::IsNullOrWhiteSpace([string]$inputData.evidenceRoot)) {
        Add-Coverage $requestedCompiledClaims 0
        Write-Result 'error' 'prerequisite-missing' 'EvidenceRoot is required for compiled architecture inspection.'
        exit 0
    }
    $evidenceRoot = [IO.Path]::GetFullPath([string]$inputData.evidenceRoot)
    if (-not [IO.Directory]::Exists($evidenceRoot)) {
        Add-Coverage $requestedCompiledClaims 0
        Write-Result 'error' 'prerequisite-missing' 'EvidenceRoot does not exist.'
        exit 0
    }
    if (-not ($config.PSObject.Properties.Name -contains 'assemblyManifestPath')) {
        Add-Coverage $requestedCompiledClaims 0
        Write-Result 'error' 'prerequisite-missing' 'assemblyManifestPath is required for compiled architecture inspection.'
        exit 0
    }
    $manifestRelative = ([string]$config.assemblyManifestPath)
    if ($inputData.PSObject.Properties.Name -contains 'projectId') { $manifestRelative = $manifestRelative.Replace('{projectId}',[string]$inputData.projectId) }
    if ($inputData.PSObject.Properties.Name -contains 'runId') { $manifestRelative = $manifestRelative.Replace('{runId}',[string]$inputData.runId) }
    try { $manifestPath = Resolve-EvidencePath $evidenceRoot $manifestRelative 'assemblyManifestPath' }
    catch {
        Add-Coverage $requestedCompiledClaims 0
        Write-Result 'error' 'unsafe-path' $_.Exception.Message
        exit 0
    }
    if (-not [IO.File]::Exists($manifestPath)) {
        Add-Coverage $requestedCompiledClaims 0
        Write-Result 'error' 'prerequisite-missing' 'The explicit assembly manifest is missing.'
        exit 0
    }
    try { $assemblyManifest = [IO.File]::ReadAllText($manifestPath) | ConvertFrom-Json }
    catch {
        Add-Coverage $requestedCompiledClaims 0
        Write-Result 'error' 'invalid-input' "The assembly manifest is invalid JSON: $($_.Exception.Message)"
        exit 0
    }
    if ($assemblyManifest.formatVersion -ne 1 -or @($assemblyManifest.assemblies).Count -eq 0) {
        Add-Coverage $requestedCompiledClaims 0
        Write-Result 'error' 'invalid-input' 'The assembly manifest must declare formatVersion 1 and at least one assembly.'
        exit 0
    }
    $requireFresh = ($config.PSObject.Properties.Name -contains 'requireFreshBuildEvidence') -and [bool]$config.requireFreshBuildEvidence
    if ($requireFresh) {
        if (-not ($inputData.PSObject.Properties.Name -contains 'stateRoot') -or -not ($inputData.PSObject.Properties.Name -contains 'projectId') -or -not ($inputData.PSObject.Properties.Name -contains 'runId')) {
            Add-Coverage $requestedCompiledClaims 0
            Write-Result 'error' 'prerequisite-missing' 'Fresh build evidence requires StateRoot, projectId and runId.'
            exit 0
        }
        $requiredManifestFields = @('runId','projectId','createdUtc','configuration','targetFramework','targetSnapshotSha256')
        if (@($requiredManifestFields | Where-Object { $assemblyManifest.PSObject.Properties.Name -notcontains $_ }).Count -gt 0) {
            Add-Coverage $requestedCompiledClaims 0
            Write-Result 'error' 'integrity-failure' 'The build manifest is missing freshness bindings.'
            exit 0
        }
        try { $created = [DateTimeOffset]::Parse([string]$assemblyManifest.createdUtc,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind) }
        catch {
            Add-Coverage $requestedCompiledClaims 0
            Write-Result 'error' 'integrity-failure' 'The build manifest timestamp is not a valid round-trip timestamp.'
            exit 0
        }
        $maximumAge = if ($config.PSObject.Properties.Name -contains 'maximumEvidenceAgeSeconds') { [int]$config.maximumEvidenceAgeSeconds } else { 600 }
        if ($assemblyManifest.runId -cne [string]$inputData.runId -or $assemblyManifest.projectId -cne [string]$inputData.projectId -or
            $created -gt [DateTimeOffset]::UtcNow.AddMinutes(1) -or
            ([DateTimeOffset]::UtcNow - $created).TotalSeconds -gt $maximumAge -or
            (($config.PSObject.Properties.Name -contains 'expectedBuildConfiguration') -and $assemblyManifest.configuration -cne [string]$config.expectedBuildConfiguration) -or
            (($config.PSObject.Properties.Name -contains 'expectedTargetFramework') -and $assemblyManifest.targetFramework -cne [string]$config.expectedTargetFramework)) {
            Add-Coverage $requestedCompiledClaims 0
            Write-Result 'error' 'integrity-failure' 'The build manifest run, project, time, configuration or target-framework binding is stale.'
            exit 0
        }
        try { $currentSnapshot = Target-Snapshot $targetRoot }
        catch {
            Add-Coverage $requestedCompiledClaims 0
            Write-Result 'error' 'unsafe-path' $_.Exception.Message
            exit 0
        }
        if ($assemblyManifest.targetSnapshotSha256 -cne $currentSnapshot) {
            Add-Coverage $requestedCompiledClaims 0
            Write-Result 'error' 'integrity-failure' 'TargetRoot changed after build evidence was produced.'
            exit 0
        }
        foreach ($expected in @(Config-Array 'expectedAssemblySources')) {
            $entry = @($assemblyManifest.assemblies | Where-Object { $_.assemblyName -ceq [string]$expected.assemblyName -and $_.sourceProject -ceq [string]$expected.sourceProject })
            if ($entry.Count -ne 1) {
                Add-Coverage $requestedCompiledClaims 0
                Write-Result 'error' 'integrity-failure' "Expected assembly/source binding is missing: $($expected.assemblyName) -> $($expected.sourceProject)"
                exit 0
            }
        }
    }
    if (-not (Load-ArchUnitNet)) {
        Add-Coverage $requestedCompiledClaims 0
        Write-Result 'error' 'prerequisite-missing' 'The locked ArchUnitNET 0.13.4 dependency closure is unavailable or failed integrity validation.'
        exit 0
    }

    $loadedAssemblies = [Collections.Generic.Dictionary[string,Reflection.Assembly]]::new([StringComparer]::Ordinal)
    $seenPaths = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in @($assemblyManifest.assemblies)) {
        $name = [string]$entry.assemblyName
        $usesState = $entry.PSObject.Properties.Name -contains 'statePath'
        $relativePath = if ($usesState) { [string]$entry.statePath } else { [string]$entry.path }
        $expectedHash = [string]$entry.sha256
        if ([string]::IsNullOrWhiteSpace($name) -or $expectedHash -cnotmatch '^[a-f0-9]{64}$') {
            Add-Coverage $requestedCompiledClaims 0
            Write-Result 'error' 'invalid-input' 'Every assembly manifest entry requires assemblyName, path and lowercase SHA-256.'
            exit 0
        }
        $assemblyRoot = if ($usesState) {
            if (-not ($inputData.PSObject.Properties.Name -contains 'stateRoot')) { $null } else { [IO.Path]::GetFullPath([string]$inputData.stateRoot) }
        } else { $evidenceRoot }
        if ([string]::IsNullOrWhiteSpace($assemblyRoot)) {
            Add-Coverage $requestedCompiledClaims 0
            Write-Result 'error' 'prerequisite-missing' 'StateRoot is required for state-owned assembly evidence.'
            exit 0
        }
        try { $assemblyPath = Resolve-EvidencePath $assemblyRoot $relativePath "assembly $name" }
        catch {
            Add-Coverage $requestedCompiledClaims 0
            Write-Result 'error' 'unsafe-path' $_.Exception.Message
            exit 0
        }
        if (-not $seenPaths.Add($assemblyPath) -or $loadedAssemblies.ContainsKey($name)) {
            Add-Coverage $requestedCompiledClaims 0
            Write-Result 'error' 'invalid-input' "Duplicate assembly identity or path: $name"
            exit 0
        }
        if (-not [IO.File]::Exists($assemblyPath)) {
            Add-Coverage $requestedCompiledClaims 0
            Write-Result 'error' 'prerequisite-missing' "Expected assembly is missing: $relativePath"
            exit 0
        }
        $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $assemblyPath).Hash.ToLowerInvariant()
        if ($actualHash -cne $expectedHash) {
            Add-Coverage $requestedCompiledClaims 0
            Write-Result 'error' 'integrity-failure' "Assembly hash mismatch: $relativePath"
            exit 0
        }
        if ($requireFresh -and (($entry.PSObject.Properties.Name -notcontains 'configuration') -or ($entry.PSObject.Properties.Name -notcontains 'targetFramework') -or ($entry.PSObject.Properties.Name -notcontains 'sourceProject') -or
            $entry.configuration -cne $assemblyManifest.configuration -or $entry.targetFramework -cne $assemblyManifest.targetFramework)) {
            Add-Coverage $requestedCompiledClaims 0
            Write-Result 'error' 'integrity-failure' "Assembly build binding mismatch: $relativePath"
            exit 0
        }
        try {
            $identity = [Reflection.AssemblyName]::GetAssemblyName($assemblyPath).Name
            if ($identity -cne $name) { throw "expected $name, found $identity" }
            $assembly = [Runtime.Loader.AssemblyLoadContext]::Default.LoadFromAssemblyPath($assemblyPath)
            if (-not [IO.Path]::GetFullPath($assembly.Location).Equals($assemblyPath,[StringComparison]::OrdinalIgnoreCase)) { throw "loaded from $($assembly.Location)" }
            $loadedAssemblies.Add($name,$assembly)
        } catch {
            Add-Coverage $requestedCompiledClaims 0
            Write-Result 'error' 'integrity-failure' "Assembly identity/load failure for ${relativePath}: $($_.Exception.Message)"
            exit 0
        }
    }

    try {
        $architecture = [ArchUnitNET.Loader.ArchLoader]::new().LoadAssemblies([Reflection.Assembly[]]@($loadedAssemblies.Values)).Build()
        foreach ($assembly in $loadedAssemblies.Values) { [void]$assembly.GetTypes() }
    } catch {
        Add-Coverage $requestedCompiledClaims 0
        Write-Result 'error' 'prerequisite-missing' "ArchUnitNET could not load the explicit assembly closure: $($_.Exception.Message)"
        exit 0
    }

    if (Enabled 'ARCH.TYPE_DEPENDENCY') {
        $matched = 0
        $policies = @(Config-Array 'forbiddenTypeDependencies')
        foreach ($policy in $policies) {
            if (-not $loadedAssemblies.ContainsKey([string]$policy.sourceAssembly) -or -not $loadedAssemblies.ContainsKey([string]$policy.forbiddenAssembly)) {
                Add-Finding 'ARCH.TYPE_DEPENDENCY' "missing declared assembly -> $($policy.sourceAssembly) / $($policy.forbiddenAssembly)" 'compiled-assembly' 'archunitnet'
                continue
            }
            $sourceTypes = @($loadedAssemblies[[string]$policy.sourceAssembly].GetTypes() | Where-Object Namespace -ceq ([string]$policy.sourceNamespace))
            $targetTypes = @($loadedAssemblies[[string]$policy.forbiddenAssembly].GetTypes() | Where-Object Namespace -ceq ([string]$policy.forbiddenNamespace))
            $minimum = [int]$policy.minimumMatches
            $pairMatches = [Math]::Min($sourceTypes.Count,$targetTypes.Count)
            $matched += $pairMatches
            if ($sourceTypes.Count -lt $minimum -or $targetTypes.Count -lt $minimum) {
                Add-Finding 'ARCH.TYPE_DEPENDENCY' "$($policy.sourceAssembly):$($policy.sourceNamespace) -> $($policy.forbiddenAssembly):$($policy.forbiddenNamespace) [zero-match]" 'compiled-assembly' 'archunitnet'
                continue
            }
            $sourceIdentity = $loadedAssemblies[[string]$policy.sourceAssembly].FullName
            $targetIdentity = $loadedAssemblies[[string]$policy.forbiddenAssembly].FullName
            $sourceProvider = [ArchUnitNET.Fluent.ArchRuleDefinition]::Types().That().ResideInNamespace([string]$policy.sourceNamespace).And().ResideInAssembly($sourceIdentity)
            $targetProvider = [ArchUnitNET.Fluent.ArchRuleDefinition]::Types().That().ResideInNamespace([string]$policy.forbiddenNamespace).And().ResideInAssembly($targetIdentity)
            $rule = $sourceProvider.Should().NotDependOnAny($targetProvider)
            if (-not $rule.HasNoViolations($architecture)) {
                Add-Finding 'ARCH.TYPE_DEPENDENCY' "$($policy.sourceAssembly):$($policy.sourceNamespace) -> $($policy.forbiddenAssembly):$($policy.forbiddenNamespace)" 'compiled-assembly' 'archunitnet'
            }
        }
        if ($policies.Count -eq 0) { Add-Finding 'ARCH.TYPE_DEPENDENCY' '<zero configured rules>' 'compiled-assembly' 'archunitnet' }
        Add-Coverage @('ARCH.TYPE_DEPENDENCY') $matched
    }

    if (Enabled 'ARCH.IMPLEMENTATION_LOCATION') {
        $matched = 0
        $policies = @(Config-Array 'implementationLocations')
        foreach ($policy in $policies) {
            if (-not $loadedAssemblies.ContainsKey([string]$policy.interfaceAssembly) -or -not $loadedAssemblies.ContainsKey([string]$policy.implementationAssembly)) {
                Add-Finding 'ARCH.IMPLEMENTATION_LOCATION' "missing declared assembly -> $($policy.interfaceAssembly) / $($policy.implementationAssembly)" 'compiled-assembly' 'archunitnet'
                continue
            }
            $interfaceType = $loadedAssemblies[[string]$policy.interfaceAssembly].GetType([string]$policy.interfaceType,$false,$false)
            if ($null -eq $interfaceType -or -not $interfaceType.IsInterface) {
                Add-Finding 'ARCH.IMPLEMENTATION_LOCATION' "$($policy.interfaceAssembly):$($policy.interfaceType) [zero-match]" 'compiled-assembly' 'archunitnet'
                continue
            }
            $implementers = @($loadedAssemblies.Values | ForEach-Object GetTypes | Where-Object { $_.IsClass -and -not $_.IsAbstract -and $interfaceType.IsAssignableFrom($_) })
            $matched += $implementers.Count
            if ($implementers.Count -lt [int]$policy.minimumMatches) {
                Add-Finding 'ARCH.IMPLEMENTATION_LOCATION' "$($policy.interfaceType) -> $($policy.implementationAssembly):$($policy.implementationNamespace) [zero-match]" 'compiled-assembly' 'archunitnet'
                continue
            }
            $rule = [ArchUnitNET.Fluent.ArchRuleDefinition]::Classes().That().AreAssignableTo($interfaceType).Should().ResideInNamespace([string]$policy.implementationNamespace)
            $wrong = @($implementers | Where-Object { $_.Assembly.GetName().Name -cne [string]$policy.implementationAssembly -or $_.Namespace -cne [string]$policy.implementationNamespace })
            if ($wrong.Count -gt 0 -or -not $rule.HasNoViolations($architecture)) {
                $subjects = if ($wrong.Count) { @($wrong.FullName) -join ', ' } else { [string]$policy.interfaceType }
                Add-Finding 'ARCH.IMPLEMENTATION_LOCATION' "$subjects -> $($policy.implementationAssembly):$($policy.implementationNamespace)" 'compiled-assembly' 'archunitnet'
            }
        }
        if ($policies.Count -eq 0) { Add-Finding 'ARCH.IMPLEMENTATION_LOCATION' '<zero configured rules>' 'compiled-assembly' 'archunitnet' }
        Add-Coverage @('ARCH.IMPLEMENTATION_LOCATION') $matched
    }

    if (Enabled 'ARCH.ASSEMBLY_PLACEMENT') {
        $matched = 0
        $policies = @(Config-Array 'assemblyPlacements')
        foreach ($policy in $policies) {
            if (-not $loadedAssemblies.ContainsKey([string]$policy.assemblyName)) {
                Add-Finding 'ARCH.ASSEMBLY_PLACEMENT' "missing declared assembly -> $($policy.assemblyName)" 'compiled-assembly' 'archunitnet'
                continue
            }
            $types = @($loadedAssemblies[[string]$policy.assemblyName].GetTypes() | Where-Object { -not $_.IsNested -and -not [string]::IsNullOrWhiteSpace($_.Namespace) })
            $matched += $types.Count
            if ($types.Count -lt [int]$policy.minimumMatches) {
                Add-Finding 'ARCH.ASSEMBLY_PLACEMENT' "$($policy.assemblyName):$($policy.requiredNamespace) [zero-match]" 'compiled-assembly' 'archunitnet'
                continue
            }
            $assemblyIdentity = $loadedAssemblies[[string]$policy.assemblyName].FullName
            $rule = [ArchUnitNET.Fluent.ArchRuleDefinition]::Types().That().ResideInAssembly($assemblyIdentity).Should().ResideInNamespace([string]$policy.requiredNamespace)
            $wrong = @($types | Where-Object Namespace -cne ([string]$policy.requiredNamespace))
            if ($wrong.Count -gt 0 -or -not $rule.HasNoViolations($architecture)) {
                $subjects = if ($wrong.Count) { @($wrong.FullName) -join ', ' } else { [string]$policy.assemblyName }
                Add-Finding 'ARCH.ASSEMBLY_PLACEMENT' "$subjects -> $($policy.requiredNamespace)" 'compiled-assembly' 'archunitnet'
            }
        }
        if ($policies.Count -eq 0) { Add-Finding 'ARCH.ASSEMBLY_PLACEMENT' '<zero configured rules>' 'compiled-assembly' 'archunitnet' }
        Add-Coverage @('ARCH.ASSEMBLY_PLACEMENT') $matched
    }
}

$status = if ($findings.Count -eq 0) { 'pass' } else { 'fail' }
$category = if ($status -eq 'pass') { 'success' } else { 'findings-blocking' }
Write-Result $status $category
