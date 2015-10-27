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

function Start-ZapAScan {
    <#
    .SYNOPSIS
    Starts ZAP Active Scan for specified url.
    
    .PARAMETER Url
    Url for which Active Scan should be run.
    
    .PARAMETER ApiKey
    Api key which it was run with ZAP.

    .PARAMETER Interval
    Time in seconds for which Active Scan status should be checked.

    .EXAMPLE
    Start-ZapAScan -Url 'http://localhost:8080' -ApiKey 12345 -Interval 1
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $Url,

        [Parameter(Mandatory=$false)]
        [int]
        $ApiKey = 12345,

        [Parameter(Mandatory=$false)]
        [int]
        $Interval = 1
    )

    $scanUrl = "http://zap/JSON/ascan/action/scan/?zapapiformat=JSON&apikey=" + $ApiKey + "&url=" + $Url + "&recurse=&inScopeOnly=&scanPolicyName=&method=&postData="
    $responseScan = Invoke-WebRequestWrapper -Uri $scanUrl -Method "Get" -ContentType "JSON"
    $json = $responseScan.Content | ConvertFrom-Json
    $scanId = $json.scan

    $status = 0
    while($status -lt 100) {
        $urlGetStatusUrl = "http://zap/JSON/ascan/view/status/?zapapiformat=JSON&scanId=" + $scanId
        $responseStatus = Invoke-WebRequestWrapper -Uri $urlGetStatusUrl -Method "Get" -ContentType "JSON"
        $json = $responseStatus.Content | ConvertFrom-Json
        $status = $json.status
        Start-Sleep -s $Interval
    }
}