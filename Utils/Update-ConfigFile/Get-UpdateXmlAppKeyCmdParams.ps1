<#
The MIT License (MIT)

Copyright (c) 2015 Objectivity Bespoke Software Specialists

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
#>

function Get-UpdateXmlAppKeyCmdParams {

 <#
    .SYNOPSIS
    A helper for Update-ConfigFile function that returns scriptblock for ConfigType = XmlAppKey.
    
    .PARAMETER ConfigFiles
    List of configuration file names to update.

    .PARAMETER ConfigValues
    Values to replace, needs to be in format key=value.

    .PARAMETER FailIfCannotMatch
    If false and key not found, it will be added to the file.
    If true and key not found, exception will be thrown.

    .EXAMPLE
    Get-UpdateXmlAppKeyCmdParams -ConfigFiles 'web.config' -ConfigValues 'serviceMode=true'
#>

    [CmdletBinding()]
    [OutputType([scriptblock])]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]
        $ConfigFiles,

        [Parameter(Mandatory=$true)]
        [string[]]
        $ConfigValues,

        [Parameter(Mandatory=$false)]
        [switch]
        $FailIfCannotMatch
    )

    $configValuesMatches = Get-KeyValueMatches -ConfigValues $ConfigValues

    $result = @{}

    $result.ScriptBlock = {
        
        param($ConfigFiles, $ConfigValuesMatches, $FailIfCannotMatch)

        $Global:ErrorActionPreference = 'Stop'
        foreach ($configFileName in $ConfigFiles) {
            if (!(Test-Path -Path $configFileName)) {
                throw "File $configFileName does not exist (server $([system.environment]::MachineName))."
            }

            $configFileName = (Resolve-Path -Path $configFileName).ProviderPath

            [xml]$config = Get-Content -Path $configFileName -ReadCount -0
    
            $needSaving = $false
            foreach ($match in $configValuesMatches) {
                $node = $config.SelectSingleNode("/configuration/appSettings/add[@key=`"$($match.Key)`"]")
                if (!$node) {
                    if ($FailIfCannotMatch) {
                        throw "Key '$($match.Key)' not found under configuration/appSettings/add (file '$configFileName')."
                    } else {
                        Write-Output -InputObject "Key '$($match.key)' not found - adding with value '$($match.Value)'."
                        $appSettings = $config.SelectSingleNode("/configuration/appSettings")
                        if (!$appSettings) {
                            throw "/configuration/appSettings node not found in file '$configFileName' - please ensure it exists."
                        }
                        $node = $config.CreateElement("add")
                        $node.SetAttribute('key', $match.Key)
                        $node.SetAttribute('value', $match.Value)
                        [void]$appSettings.appendChild($node)
                        $needSaving = $true
                    }
                } else {
                    if ($node.value -eq $match.Value) {
                        Write-Output -InputObject "Key '$($match.Key)' - value is already '$($match.Value)'."
                    } else { 
                        $node.value = $match.Value
                        $needSaving = $true
                        Write-Output -InputObject "Key '$($match.Key)' - value set to '$($match.Value)'."
                    }
                }
            }

            if ($needSaving) {
                $config.Save($configFileName)
                Write-Output -InputObject "File '$configFileName' saved."
            }
        }  
    }

    $result.ArgumentList = @($ConfigFiles, $ConfigValuesMatches, $FailIfCannotMatch)

    return $result
}