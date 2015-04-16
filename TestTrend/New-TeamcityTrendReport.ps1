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

function New-TeamcityTrendReport {
    <#
    .SYNOPSIS
    Generates Teamcity tests trend reports (CSV / HTML) basing on data available in TeamCity database.

    .DESCRIPTION
    It runs a sql command directly in TeamCity database and generates csv / html reports basing on that.

    .PARAMETER TeamcityBuildId
    Id of currently running Teamcity build (%teamcity.build.id%).

    .PARAMETER TeamcityDbConnectionString
    Connection string that will be used to connect to TeamCity database.

    .PARAMETER TeamcityCurrentBuildNumber
    Current Teamcity build number (%build.number%) - required for reporting test results for current build.

    .PARAMETER OutputDir
    Output directory where .html / .png / .csv files will be generated.

    .PARAMETER TestNameRegex
    Regex for shortening test names, e.g. if test is named 'Category: LongName-TestName', and you provide
    regex 'Category: LongName-(.*)', only 'TestName' will be displayed.

    .PARAMETER NumberOfLastBuilds
    Number of builds that will be trended - all earlier builds will be ignored.

    .PARAMETER GenerateCsvFile
    If true, CSV file will be generated.

    .EXAMPLE
    New-TeamcityTrendReport TestNames @('test1','test2') -TeamcityBuildTypeId 'Client_Project_ConfName' -TeamcityDbServer 'Teamcity' -TeamcityDbUser 'TeamCityExtensions' -TeamcityDbPassword 'XXX' -OutputCsvPath 'c:\output\jmeter-trend.csv' -OutputHtmlPath 'c:\output\jmeter-trend.html'
    #>

    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $TeamcityBuildId,

        [Parameter(Mandatory=$true)]
        [string]
        $TeamcityDbConnectionString,

        [Parameter(Mandatory=$false)]
        [string]
        $OutputDir,

        [Parameter(Mandatory=$false)]
        [string]
        $TestNameRegex,

        [Parameter(Mandatory=$false)]
        [int]
        $NumberOfLastBuilds = 30,

        [Parameter(Mandatory=$false)]
        [switch]
        $GenerateCsvFile

    )

    if (!(Test-Path -Path $OutputDir)) {
        Write-Log -Info "Creating directory '$OutputDir'"
        [void](New-Item -Path $OutputDir -ItemType Directory)
    }
    $csvOutputPath = Join-Path -Path $OutputDir -ChildPath 'TestTrendReport.csv'
    $htmlOutputPath = Join-Path -Path $OutputDir -ChildPath 'TestTrendReport.html'

    $sql = Get-TeamCityTrendReportSql
    $sql = $sql -f $TeamcityBuildId, $NumberOfLastBuilds

    Write-Log -Info "Getting trend data from TeamCity database, BuildId: '$TeamcityBuildId', NumberOfLastBuilds: $NumberOfLastBuilds"
    $sqlResult = Invoke-Sql -ConnectionString $TeamcityDbConnectionString -Query $sql
    if (!$sqlResult -or !$sqlResult.Tables -or $sqlResult.Tables.Count -lt 2) {
        Write-Log -Warn "No trend data returned from TeamCity database. Please ensure parameters are correct. Sql: $sql"
        return
    }
    $sqlResult = $sqlResult.Tables

    # there are two tables returned from sql - buildIdData (containing build id - build name - success) and trendData (containing pivoted build_id / test_name -> duration table)
    $buildIdData = $sqlResult[0]
    $trendData = $sqlResult[1]

    $buildIdMap = @{}
    foreach ($row in $buildIdData) { 
        $buildIdMap[[string]($row.build_id)] = $row 
    }
    if ($TestNameRegex) {
        foreach ($entry in $trendData) {
            if ($entry.test_name -imatch $TestNameRegex -and $matches[1]) {
                $entry.test_name = $matches[1]
            }
        }
    }

    Write-Log -Info "Generating html report"
    if ($GenerateCsvFile) {
        ConvertTo-CsvInBuildNameOrder -BuildIdMap $buildIdMap -TrendData $trendData -CsvOutputPath $csvOutputPath
    }

    $htmlChartData = $trendData | ConvertTo-EnhancedHTMLFragmentJavascriptData -JavascriptVariableName 'TestData' -PropertySeriesName 'test_name' -BuildIdMap $buildIdMap `
        -PrefixCode "var palette = new Rickshaw.Color.Palette({ scheme: 'munin' } );"

    $htmlChart = ConvertTo-EnhancedHTMLFragmentRickshawChart -JavascriptDataVariableName 'TestData'

    $javascriptUri= @('http://code.jquery.com/jquery-1.10.2.min.js', 'http://cdn.datatables.net/1.10.0/js/jquery.dataTables.min.js', `
        'http://cdnjs.cloudflare.com/ajax/libs/d3/3.4.11/d3.min.js', 'https://code.jquery.com/ui/1.11.0/jquery-ui.min.js', 
        'http://cdnjs.cloudflare.com/ajax/libs/rickshaw/1.4.6/rickshaw.min.js')

    Write-Log -Info "Generating Test Trend HTML report at '$htmlOutputPath'."

    $params = @{'HTMLFragments' = @($htmlChartData, $htmlChart);
                'JavascriptUri' = $javascriptUri;
                'CssStyleSheet' = @((Get-DefaultJqueryDataTableCss), (Get-DefaultRickshawCss));
                'CssUri' = @('http://cdn.datatables.net/1.10.0/css/jquery.dataTables.css', 'http://ajax.googleapis.com/ajax/libs/jqueryui/1.8/themes/base/jquery-ui.css')
               }

    ConvertTo-EnhancedHTML @params | Out-File -FilePath $htmlOutputPath -Encoding UTF8

}

function ConvertTo-CsvInBuildNameOrder {

     <#
    .SYNOPSIS
    Generates a CSV file containing trend data.

    .DESCRIPTION
    The columns in CSV file are ordered by build names.

    .PARAMETER BuildIdMap
    Hashmap mapping build_id to sql row.

    .PARAMETER TrendData
    Raw trend data as taken from sql command.

    .PARAMETER CsvOutputPath
    Path to the output CSV file.

    .EXAMPLE
    ConvertTo-CsvInBuildNameOrder -BuildIdMap $buildIdMap -TrendData $trendData -CsvOutputPath $csvOutputPath
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]
        $BuildIdMap,

        [Parameter(Mandatory=$true)]
        [object[]]
        $TrendData,

        [Parameter(Mandatory=$true)]
        [string]
        $CsvOutputPath
    )
    Write-Log -Info "Generating Test Trend CSV report at '$csvOutputPath'."
    $trendData | Foreach-Object { 
        $newRow = New-Object PSObject
        $row = $_
        Add-Member -InputObject $newRow -Name 'test_name' -Value $_['test_name'] -MemberType NoteProperty
        Get-Member -InputObject $row -MemberType Properties | Where-Object { $_.Name -ne 'test_name' } | `
            Foreach-Object { Add-Member -InputObject $newRow -Name $BuildIdMap[$_.Name].build_number -Value $row[$_.Name] -MemberType NoteProperty }
        $newRow
    } | ConvertTo-Csv -NoTypeInformation | Out-File -FilePath $CsvOutputPath

}


function Get-TeamCityTrendReportSql {

    <#
    .SYNOPSIS
    Returns a sql that returns trend data from Teamcity database.

    .EXAMPLE
    $sql = Get-TeamCityTrendReportSql

    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return @"
    -- Test Trend Report (PSCI / New-TeamcityTrendReport)
    SET QUOTED_IDENTIFIER ON
    SET NOCOUNT ON

    DECLARE @cols AS NVARCHAR(MAX),
        @query  AS NVARCHAR(MAX)

    if object_id('tempdb..#builds') is not null
	    drop table #builds;

    if object_id('tempdb..#tests') is not null
	    drop table #tests;

    select top {1}
        build_id,
        build_number,
        cast(row_number() over (partition by build_number order by build_number) as varchar) as build_row,
		count(build_number) over (partition by build_number order by build_number) non_distinct_build_numbers,
        success
    into
	    #builds
    from (
        select
		    build_id, 
		    build_number,
            cast(1 as bit) as success
	    from
		    dbo.running r
	    where 
		    build_id = {0}
	    union all
	    select
	        h.build_id, 
		    h.build_number,
            cast(case when h.status = 1 then 1 else 0 end as bit) as success
	    from
		    dbo.history h
	    inner join
            (select 
                build_type_id
             from
                dbo.running 
             where
                build_id = {0}
             union
             select
                build_type_id
             from
                dbo.history
             where
                build_id = {0}
	       ) currentBuild
	    on currentBuild.build_type_id = h.build_type_id
        where
            h.status <> 0 -- cancelled
    ) x
    where 
		exists (select 1 from dbo.test_info where build_id = x.build_id)
    order by 
		build_id desc;

    select
		build_id,
		case when non_distinct_build_numbers = 1 then b.build_number else b.build_number + '_' + build_row end build_number,
		success
	from
		#builds b

	select
		b.build_id,
		tn.test_name,
		ti.duration
	into
		#tests
	from
		#builds b
	inner join
	    dbo.test_info ti
	on ti.build_id = b.build_id
	inner join
		dbo.test_names tn
	on tn.id = ti.test_name_id
	/*inner join
		dbo.test_info tiFilter
	on  tiFilter.test_name_id = tn.id
	and tiFilter.build_id = (select top 1 build_id from #builds order by build_id desc)*/
    where
        ti.status <> 0 -- ignored tests

    select @cols = STUFF((SELECT  ',' + QUOTENAME(build_id) 
                        from #tests
                        group by build_id
                        order by build_id
                FOR XML PATH(''), TYPE
                ).value('.', 'NVARCHAR(MAX)') 
            ,1,1,'')

	
    set @query = 'select test_name, ' + @cols + '
                  from 
                 (
                    select test_name, build_id, duration
                    from #tests
                ) x
                pivot 
                (
                    max(duration)
                    for build_id in (' + @cols + ')
                ) p 
                order by test_name'

    execute(@query)
"@

}
