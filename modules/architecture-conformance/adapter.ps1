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
$activeClaims = if ($inputData.stage -eq 'pre') {
    @($enabled | Where-Object { $_ -in ($projectClaims + $syntaxClaims) })
} else {
    @($enabled | Where-Object { $_ -in $semanticClaims })
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

$requestedProjectClaims = @($activeClaims | Where-Object { $_ -in $projectClaims })
if ($requestedProjectClaims.Count -gt 0) {
    $projects = @(Get-ChildItem -LiteralPath $targetRoot -Recurse -File -Filter '*.csproj' | Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' } | Sort-Object FullName)
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
                if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -or -not [IO.File]::Exists($resolved)) {
                    Add-Finding 'ARCH.GRAPH_COMPLETENESS' "$projectSubject -> $([string]$reference.Include)" 'project-model-raw' 'project-model'
                }
            }
        }
    }
    Add-Coverage $requestedProjectClaims $projects.Count
}

$requestedSourceClaims = @($activeClaims | Where-Object { $_ -in ($syntaxClaims + $semanticClaims) })
if ($requestedSourceClaims.Count -gt 0) {
    $sources = @(Get-ChildItem -LiteralPath $targetRoot -Recurse -File -Filter '*.cs' | Where-Object { $_.FullName -notmatch '[\\/](bin|obj)[\\/]' } | Sort-Object FullName)
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

$status = if ($findings.Count -eq 0) { 'pass' } else { 'fail' }
$category = if ($status -eq 'pass') { 'success' } else { 'findings-blocking' }
Write-Result $status $category
