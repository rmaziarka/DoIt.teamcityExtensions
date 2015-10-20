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

function Get-PredefinedSqlQuery {
    <#
    .SYNOPSIS
    Returns one of the predefined query. If query with given name does not exists, throws an exception.

    .PARAMETER PredefinedQueryName
    Name of the predefined query.

    .EXAMPLE
    Get-PredefinedSqlQuery -PredefinedQueryName 'LoadTestVisualStudioQuery'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$false)]
        [string]
        $PredefinedQueryName
    )
    
    $resultQuery = $null

    if ($PredefinedQueryName -eq 'LoadTestVisualStudioQuery'){
        $resultQuery = @'
        DECLARE @maxLoadTestRunId int = (SELECT MAX(LoadTestRunId) FROM [dbo].[LoadTestPageResults])

        select 'Request' as Type, 
                  LoadTestRunId,
                  ScenarioName,
                  TestCaseName, 
                  RequestUri as Name,
                  PageCount as Count,
                  Average*1000 as Average,
                  Minimum*1000 as Minimum,
                  Maximum*1000 as Maximum,
                  Percentile90*1000 as Percentile90,
                  Percentile95*1000 as Percentile95
        from  [dbo].[LoadTestPageResults]
        WHERE LoadTestRunId = @maxLoadTestRunId
        union all
        select   'Transaction',
                LoadTestRunId,  
                ScenarioName,
                TransactionName as Name,
                NULL,
                TransactionCount as Count,
                Average*1000 as Average,
                Minimum*1000 as Minimum,
                Maximum*1000 as Maximum,
                Percentile90*1000 as Percentile90,
                Percentile95*1000 as Percentile95
        from  [dbo].[LoadTestTransactionResults2]
        WHERE LoadTestRunId = @maxLoadTestRunId
        union all
        select  'Webtest', 
                LoadTestRunId,  
                ScenarioName,
                TestCaseName as Name,
                NULL,
                TestsRun as Count,
                Average*1000 as Average,
                Minimum*1000 as Minimum,
                Maximum*1000 as Maximum,
                Percentile90*1000 as Percentile90,
                Percentile95*1000 as Percentile95
        from [dbo].[LoadTestTestResults]
        WHERE LoadTestRunId = @maxLoadTestRunId
        ORDER BY LoadTestRunId DESC, Type
'@
    }

    if (!$resultQuery) {
        throw "Given PredefinedQueryName '$PredefinedQueryName' does not have any implementation. Please check given name."
    }
    
    return $resultQuery;
    
}