<#
.Synopsis
   Imports Visual Studio environment variables using a fallback method.
.DESCRIPTION
   Looks at the VSPREFERRED variable to require a particular VS version;
   otherwise falls back from latest VS through 2010 to invoke the developer
   command prompt settings.
.EXAMPLE
   Invoke-VisualStudioDevPrompt
#>
function Invoke-VisualStudioDevPrompt {
    [CmdletBinding()]
    Param
    (
    )
    Begin {
        $fallbackReleases = @("2015", "2013", "2012", "2010")
    }
    Process {
        $origErrorAction = $ErrorActionPreference
        try {
            $ErrorActionPreference = "SilentlyContinue"

            if ($NULL -eq $env:VSPREFERRED -or (-not $fallbackReleases.Contains($env:VSPREFERRED))) {
                $vs = Select-VsInstall -Year "$($env:VSPREFERRED)"
                if ($NULL -ne $vs) {
                    Write-Verbose "Attempting VS load..."
                    Invoke-BatchFile -Path "$($vs.InstallationPath)\Common7\Tools\VsDevCmd.bat"
                    $vsYear = $vs.DisplayName -replace '.*\s+(\d\d\d\d).*', '${1}'
                    $global:PromptEnvironment = " ⌂ vs$vsYear "
                    return
                }
            }

            foreach ($rel in $fallbackReleases) {
                if ($NULL -eq $env:VSPREFERRED -or $env:VSPREFERRED -eq $rel) {
                    try {
                        Write-Verbose "Attempting VS $rel load..."
                        Import-VisualStudioVars $rel
                        $global:PromptEnvironment = " ⌂ vs$rel "
                        break;
                    }
                    catch { }
                }
            }
        }
        catch [Exception] {
            Write-Warning "Unable to initialize VS command settings."
        }
        finally {
            $ErrorActionPreference = $origErrorAction
        }
    }
}

<#
.Synopsis
   Locates the VS standard install with the most features.
.DESCRIPTION
   Looks at the standard install locations for the various VS SKUs and
   returns the first found. Iterates through the SKUs from most to least
   featured. Requires the VSSetup module for the "Get-VsSetupInstance" command.
.EXAMPLE
   Select-VsInstall
.EXAMPLE
   Select-VsInstall -Prerelease
#>
function Select-VsInstall {
    [CmdletBinding()]
    Param
    (
        [string] $Year,
        [switch] $Prerelease
    )
    Begin {
        $vsReleases = @("Microsoft.VisualStudio.Product.Enterprise", "Microsoft.VisualStudio.Product.Professional", "Microsoft.VisualStudio.Product.Community")
        $vsInstalls = Get-VsSetupInstance -All -Prerelease:$Prerelease | Sort-Object -Property @{ Expression = { $_.Product.Version } } -Descending
    }
    Process {
        $availableInstalls = $vsInstalls
        if (-not [System.String]::IsNullOrEmpty($Year)) {
            Write-Verbose "Filtering list of VS installs by year [$Year]."
            $availableInstalls = $availableInstalls | Where-Object { ($_.DisplayName -replace '.*\s+(\d\d\d\d).*', '${1}') -eq $Year }
        }
        foreach ($rel in $vsReleases) {
            $found = $availableInstalls | Where-Object { $_.Product.Id -eq $rel } | Select-Object -First 1
            if ($NULL -ne $found) {
                Write-Verbose "Found $($found.DisplayName)."
                return $found
            }
        }

        Write-Verbose "No matching VS installs selected."
        return $NULL
    }
}