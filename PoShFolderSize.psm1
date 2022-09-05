function Get-FolderSize
{
    <#
    .SYNOPSIS
        Gets amount of Folders & Files within a Folder and its total size in Byte

    .DESCRIPTION
        Uses Robocopy to get Total Size, Files and Folders within a given Folder recursiv.
        No 260 char Path limitation. Only works with GER and EN OS.

    .PARAMETER Path
        Path to the Folder that will be checked

    .PARAMETER Threads
        Number of Threads robocopy should use, using the /MT Parameter.
        Allowed Values 1-128.
        default = 8

    .INPUTS
        System.String
        System.IO.DirectoryInfo

    .OUTPUTS
        System.Management.Automation.PSCustomObject

    .EXAMPLE
        Get-FolderSize -Path 'C:\Windows\temp'

    .EXAMPLE
        Get-ChildItem 'C:\LHG-IT' | Get-FolderSize
    #>

    [CmdLetBinding()]
    [OutputType([System.Object])]
    Param(
        [Parameter(
            Position=0,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName)
        ]
        [Alias('FullName')]
        [string[]]$Path = (Get-Location).Path,

        [ValidateRange(1,128)]
        [ValidateNotNullOrEmpty()]
        [int]$Threads = 8,

        [switch]$IgnoreLanguage
    )

    Begin
    {
        if($IgnoreLanguage) { Write-Warning "Parameter -IgnoreLanguage can cause inacurate results. Only use this Parameter as Last resort."}
        ### GET PARSER WHITCH IS USED TO PARSE THE ROBOCOPY OUTPUT ###
        ### BASED ON DETECTED ROBOCOPY LANGUAGE ###
        ### IF -IgnoreLanguage IS SET, NO ERROR IS THROWN AND ENGLISCH PARSER IS RETURN ###
        $parser = Get-RobocopyOutputParser -IgnoreLanguage:$IgnoreLanguage
    }

    Process
    {
        foreach ($p in $Path)
        {
            $p = (Resolve-Path $p).ProviderPath
            $inputItem = Get-Item $p -Force

            ### CHECK IF INPUT IS A FILE & SKIP IF APPLICABLE ###
            if(-Not $inputItem.PSIsContainer) {
                Write-Verbose "Input `"$p`" is a File. Skipping"
                continue
            }

            ### EXECUTING ROBOCOPY DOING THE HEAVY LIFTING ###
            $robocopyResult = @(robocopy.exe "$p" "." /L /E /BYTES /NFL /NDL /NJH /XJ /R:0 /W:0 /MT:$Threads)

            ### IF ROBOCOPY RESULT IS LESS THAN 11 LINES, SOMETHING HAS GONNE WRONG
            if($robocopyResult.Count -lt 11) {
                Write-Error "Error while checking Filezize of Folder '$p'.`n$robocopyResult"
                continue
            }

            $obj = [pscustomobject]@{
                PSTypeName='Robocopy.Result'
                Path =   $p
                Files =   0
                Folders = 0
                Size =    0
            }

            ### PARSE ROBOCOPYRESULT LINE BY LINE USING PARSER FROM BEGIN BLOCK ###
            foreach ($line in $robocopyResult) {
                foreach ($prop in @("Folders","Files","Size")) {
                    if($line -like $parser.$prop) {

                        ### EXTRACT NUMBERS ONLY ###
                        $obj.$prop = [Regex]::Match($line,"\d+").Value
                        break
                    }
                }
            }

            ### REDUCE FOLDER AMOUNT bY 1 SINCE IT IS ALWAYS OFF BY 1 ###
            $obj.Folders = [int]$obj.Folders -1
            $obj | Add-Member -MemberType ScriptProperty -Name 'Size(GB)' -Value {[Math]::Round(($this.Size/1GB),2)}
            $obj | Write-Output
        }
    }
}

function Get-RobocopyOutputParser
{
    [CmdLetBinding()]
    Param(
        [switch]$IgnoreLanguage
    )

    ### EXECUTE ROBOCOPY TO DETERMAN THE ROBOCOPY LANGUAGE ###
    Try { $out = robocopy.exe -ErrorAction Stop }
    catch [System.Management.Automation.CommandNotFoundException] {
        throw "Failed to execute robocopy.exe - Command not found. Make sure robocopy.exe ist reachable from PATH"
    } catch { throw $_ }

    ### LOAD JSON CONTAINING A LANGUAGE MAPPING FROM MODULE FOLDER ###
    Try { $jsonPath = "$PSScriptRoot\languageMap.json"
        $languageMapping = Get-Content $jsonPath -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    } catch { throw "Couldn't load JSON `"$jsonPath`". Make sure File exists and is not corrupted" }

    ### CHECK EVERY LANGUAGEMAPPING IF HELPMSG MATCHES WITH ROBOCOPY OUTPUT ###
    foreach ($prop in $languageMapping.PSOBject.Properties.Name) {
        if(($out | Select-String -Pattern $languageMapping.$prop.HelpMsg)) {
            return $languageMapping.$prop
        }
    }

    ### LANGUAGE NOT SUPPORTED ###
    if($IgnoreLanguage) { return $languageMapping.EN }
    throw "Language of Robocopy CLI could not be detected and is not supported."
}

New-Alias -Name gfs -Value Get-FolderSize -Force