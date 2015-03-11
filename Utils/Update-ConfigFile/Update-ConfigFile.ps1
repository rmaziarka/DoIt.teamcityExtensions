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

function Update-ConfigFile {

    <#
    .SYNOPSIS
    A helper for TeamCity MetaRunnes that updates config files.

    .DESCRIPTION
    It can update following types of config files, locally or remotely:
    1) XmlAppKey - XML with <app key='x' value='y'> (web.config properties)
    2) KeyValue - key = value (.ini-like)
    3) Regex - custom regex with replace string.
    4) XSLT - XML using provided XSLT stylesheet
    5) XDT - XML using provided XDT transform
    
    .PARAMETER ConfigFiles
    List of configuration file names to update.

    .PARAMETER ConfigType
    Type of configuration file - see .DESCRIPTION for details.

    .PARAMETER ConfigValues
    Values to replace (only used for FileType = XmlAppKey or KeyValue). 

    .PARAMETER RegexSearch
    Regex for searching in files (only used for FileType = Regex).

    .PARAMETER ReplaceString
    Replace string for matches (only used for FileType = Regex).

    .PARAMETER TransformFileName
    Path to the XSLT/XDT transform file (only used for FileType = XSLT or XDT). If not provided, $TransformBody will be used.

    .PARAMETER TransformBody
    String containing XSLT/XDT transform (only used for FileType = XSLT or XDT). If not provided, $TransformFileName will be used

    .PARAMETER ConnectionParameters
    Connection parameters created by New-ConnectionParameters function. If not provided, function will run locally.

    .EXAMPLE
    Update-ConfigFile -ConfigFiles 'application.properties' -ConfigValues 'service.mode=true' -ConfigType 'XmlAppKey'
"@
    #>
    
    [CmdletBinding(DefaultParametersetName='XmlAppKeyOrKeyValue')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]
        $ConfigFiles,

        [Parameter(Mandatory=$true)]
        [string]
        [ValidateSet('XmlAppKey', 'KeyValue', 'Regex', 'XSLT', 'XDT')]
        $ConfigType,

        [Parameter(Mandatory=$true,ParameterSetName='XmlAppKeyOrKeyValue')]
        [string[]]
        $ConfigValues,

        [Parameter(Mandatory=$true,ParameterSetName='Regex')]
        [string]
        $RegexSearch,

        [Parameter(Mandatory=$true,ParameterSetName='Regex')]
        [string]
        $ReplaceString,

        [Parameter(Mandatory=$false,ParameterSetName='XSLTOrXDT')]
        [string]
        $TransformFilename,

        [Parameter(Mandatory=$false,ParameterSetName='XSLTOrXDT')]
        [string]
        $TransformBody,

        [Parameter(Mandatory=$false)]
        [hashtable]
        $ConnectionParameters
    )

    if ($ConfigType -eq 'XmlAppKey') {
        $cmdParams = Get-UpdateXmlAppKeyCmdParams -ConfigFiles $ConfigFiles -ConfigValues $ConfigValues
    } elseif ($ConfigType -eq 'KeyValue') {
        $cmdParams = Get-UpdateKeyValueCmdParams -ConfigFiles $ConfigFiles -ConfigValues $ConfigValues
    } elseif ($ConfigType -eq 'Regex') {
        $cmdParams = Get-UpdateRegexCmdParams -ConfigFiles $ConfigFiles -RegexSearch $RegexSearch -ReplaceString $ReplaceString
    } elseif ($ConfigType -eq 'XSLT') {
        $cmdParams = Get-UpdateXSLTCmdParams -ConfigFiles $ConfigFiles -XsltFilename $TransformFilename -XsltBody $TransformBody
    } elseif ($ConfigType -eq 'XDT') {
        $cmdParams = Get-UpdateXDTCmdParams -ConfigFiles $ConfigFiles -XdtFilename $TransformFilename -XdtBody $TransformBody
        if ($ConnectionParameters -and $ConnectionParameters.Nodes) {
            # for remote run, we need to copy Carbon files
            Copy-CarbonFilesToRemoteServer -ConnectionParameters $ConnectionParameters -DestinationPath 'C:\XDTTransform'
        }
    }

    if ($ConnectionParameters.Nodes) {
        $computerNamesLog = $ConnectionParameters.Nodes
    } else {
        $computerNamesLog = ([system.environment]::MachineName)
    }

    if ($ConnectionParameters) {
        $cmdParams += $ConnectionParameters.PSSessionParams
    }

    Write-Log -Info ('Updating file(s) {0} on server(s) {1}' -f ($ConfigFiles -join ', '), ($ComputerNamesLog -join ', ')) 
    Invoke-Command @cmdParams
    if ($LASTEXITCODE) {
        Write-Log -Critical "Failed to update files $WebConfigFiles"
    }

}