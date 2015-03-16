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

function ConvertTo-TeamcityTest {
    <#
    .SYNOPSIS
    Outputs TeamCity test service messages basing on input CSV file.

    .DESCRIPTION
    If $TestSuiteName is specified, it makes TeamCity to show each row of CSV file as a separate test
    (taking test time from $ColumnTestTime column).
    If $BuildStatisticName is specified, it publishes a row where column $ColumnTestName = $BuildStatiticTestName
    as a TeamCity custom metric named $BuildStatisticName (using service message 'buildStatisticValue').

    .PARAMETER CsvInputFilePath
    Path to the input CSV file.

    .PARAMETER ColumnTestName
    Name of CSV column containing test names.

    .PARAMETER ColumnTestTime
    Name of CSV column containing test times.

    .PARAMETER ColumnTestFailure
    Name of CSV column containing information about test errors (decimal number).
    If greater than FailureThreshold, the test will be marked as failed.

    .PARAMETER FailureThreshold
    Threshold for column $ColumnTestFailure, above which test will be marked as failed.

    .PARAMETER TestSuiteName
    Name of test suite that will be reported to TeamCity.

    .PARAMETER TestNames
    List of test names to report in TeamCity (i.e. rows with column ColumnTestName in TestNames).
    If not specified, all rows will be reported apart from ones specified in $IgnoreTestNames.

    .PARAMETER IgnoreTestNames
    List of test names to ignore in TeamCity. Only used if TestNames is not specified.

    .PARAMETER TestClassNamePrefix
    Prefix that will be added to test name. Can be used to categorize tests (e.g. 'Average.').

    .PARAMETER BuildStatisticName
    Name of TeamCity custom metric where test with name $BuildStatisticTestName will be reported.
    Only used if $BuildStatisticTestName is provided.

    .PARAMETER BuildStatisticTestName
    Name of test which will be reported to TeamCity custom metric.

    .EXAMPLE
    ConvertTo-TeamcityTest -CsvInputFilePath "AggregateReport.csv" -TestSuiteName "JMeter" -FailureThreshold 0 `
        -ColumnTestName "sampler_label" -ColumnTestTime "average" -ColumnTestFailure "aggregate_report_error%" -TestClassNamePrefix "Average." `
        -BuildStatisticTestName "TOTAL" -BuildStatisticName "JMeterAverage"
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $CsvInputFilePath,

        [Parameter(Mandatory=$true)]
        [string]
        $ColumnTestName,

        [Parameter(Mandatory=$true)]
        [string]
        $ColumnTestTime,

        [Parameter(Mandatory=$false)]
        [string]
        $ColumnTestFailure,

        [Parameter(Mandatory=$false)]
        [decimal]
        $FailureThreshold = 0,

        [Parameter(Mandatory=$false)]
        [string]
        $TestSuiteName,

        [Parameter(Mandatory=$false)]
        [string[]]
        $TestNames,

        [Parameter(Mandatory=$false)]
        [string[]]
        $IgnoreTestNames,

        [Parameter(Mandatory=$false)]
        [string]
        $TestClassNamePrefix,

        [Parameter(Mandatory=$false)]
        [string]
        $BuildStatisticName,

        [Parameter(Mandatory=$false)]
        [string]
        $BuildStatisticTestName       
    )

    Write-Log -Info "Converting file '$CsvInputFilePath' to TeamCity tests - column '$ColumnTestTime'..."
    if (!(Test-Path -Path $CsvInputFilePath)) {
        Write-Log -Critical "File '$CsvInputFilePath' does not exist."
    }

    if ($TestSuiteName) {
        Write-Output -InputObject "##teamcity[testSuiteStarted name='$TestSuiteName']"
    }

    if ($TestNames) {
        $testFilter = { $_.$ColumnTestName -in $TestNames }
    } else {
        $testFilter = { $_.$ColumnTestName -notin $IgnoreTestNames }
    }
    $buildStatisticOutput = ""
    Get-Content -Path $CsvInputFilePath -ReadCount 0 | ConvertFrom-CSV | Where-Object $testFilter | ForEach-Object {
        
        if ($TestSuiteName) {
            $testName = ("{0}{1}" -f $TestClassNamePrefix, $_.$ColumnTestName)
            $testInfo = @{}
            $testInfo.TestName = "${TestSuiteName}: $testName"
            $testInfo.Succeeded = $true
            Write-Output -InputObject ("##teamcity[testStarted name='{0}']" -f $testName)
            if ($ColumnTestFailure) { 
                $failureValue = [decimal]$_.$ColumnTestFailure
                if ($failureValue -gt $FailureThreshold) {
                    Write-Output -InputObject ("##teamcity[testFailed name='{0}' message='{1}']" -f $testName, "Failure threshold exceeded (${failureValue} > ${FailureThreshold})")
                    $testInfo.Succeeded = $false
                }
            }
            Write-Output -InputObject ("##teamcity[testFinished name='{0}' duration='{1}']" -f $testName, [decimal]::round($_.$ColumnTestTime))
            $testInfo.Duration = $_.$ColumnTestTime
        }
        if ($BuildStatisticName -and $_.$ColumnTestName -eq $BuildStatisticTestName) {
            $buildStatisticOutput = ("##teamcity[buildStatisticValue key='{0}' value='{1}']" -f $BuildStatisticName, $_.$ColumnTestTime)
        }
    }
    
    if ($TestSuiteName) {
        Write-Output -InputObject "##teamcity[testSuiteFinished name='$TestSuiteName']"
    }
    
    if ($buildStatisticOutput) {
        Write-Output -InputObject $buildStatisticOutput
    }

}