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

function ConvertTo-EnhancedHTMLFragmentRickshawChart {

    <#
    .SYNOPSIS
    Creates a HTML fragment containing a Rickshaw chart (based on Javascript data generated by ConvertTo-EnhancedHTMLFragmentRickshawJavascriptData).

    .PARAMETER JavascriptDataVariableName
    Name of Javascript variable created by ConvertTo-EnhancedHTMLFragmentRickshawJavascriptData.

    .PARAMETER JavascriptTestTimeThresholdDataVariableName
    Name of Javascript variable with hashtable containing test time thresholds.

    .PARAMETER Width
    Chart width.

    .PARAMETER Height
    Chart height.

    .LINK
    ConvertTo-EnhancedHTMLFragmentRickshawJavascriptData

    .EXAMPLE
    $htmlChart = ConvertTo-EnhancedHTMLFragmentRickshawChart -JavascriptDataVariableName 'TestData'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $JavascriptDataVariableName,

        [Parameter(Mandatory=$true)]
        [string]
        $JavascriptTestTimeThresholdDataVariableName,

        [Parameter(Mandatory=$false)]
        [int]
        $Width = 900,

        [Parameter(Mandatory=$false)]
        [int]
        $Height = 500
    )

    $javascriptFiles = Get-ChildItem -Path "$PSScriptRoot\TestTrendJavascript\*.js" | Get-Content -ReadCount 0 | Out-String
   
    $result = @"

    <div id="mainContent">
        <div class="sectionToggle"><span class="sectionVisible"></span><span class="sectionHeader"> Options</span></div>
        <div id="options">
            <form id="chartFilterForm">
                <table>
                    <tr>
                        <td class="formLabel">
                            <label for="testHistoryNumber" title="Number of last builds.">Num of last builds:</label>
                        </td>
                        <td class="formInput">
                            <input id="testHistoryNumber" type="number" min="0" value="0" />
                        </td>
                        <td class="formLabel">
                            <label for="testNameRegex" title="Filter test names with a regex.">Test name regex:</label>
                        </td>
                        <td class="formInput">
                            <input id="testNameRegex" type="text" placeholder="Test name regex"/>
                        </td>
                        <td class="formLabel">
                            <label for="relativeToBuild" title="Calculate times relative to specific build number. If negative, it will be relative to previous build (-1 -&gt; preceding build, -2 -&gt; current-2 etc.).">Relative to build:</label>
                        </td>
                        <td class="formInput">
                            <input id="relativeToBuild" type="text" placeholder="Relative to build" />
                        </td>
                        <td class="formLabel">
                            <label for="chartRenderer">Chart type:</label>
                        </td>
                        <td class="formInput">
                            <select id="chartRenderer">
                                <option value="line">Line</option>
                                <option value="scatterplot">Scatter</option>
                                <option value="area">Area</option>
                                <option value="bar">Bar</option>
                            </select>
                        </td>
                    </tr>
                    <tr>
                        <td class="formLabel">
                            <label for="includeBuild" title="List of build numbers to include. Can use , and - (e.g. 1,5-7).">Include builds:</label>
                        </td>
                        <td class="formInput">
                            <input id="includeBuilds" type="text" placeholder="Include build numbers" />
                        </td>
                        <td class="formLabel">
                            <label for="minimalValue" title="Minimal time - tests below this value will be excluded.">Minimal value:</label>
                        </td>
                        <td class="formInput">
                            <input id="minimalValue" type="text" placeholder="Minimal value" />
                        </td>
                        <td class="formLabel">
                            <label for="relativeToBuildPercent" title="If checked and relative build is set, the difference will be expressed in percents.">Relative percent:</label>
                        </td>
                        <td class="formInput">
                            <input id="relativeToBuildPercent" type="checkbox"></input>
                        </td>
                        <td class="formLabel">
                            <label for="showFailedBuilds" title="If unchecked, failed builds will be excluded.">Show failed:</label>
                        </td>
                        <td class="formInput">
                            <input id="showFailedBuilds" type="checkbox" checked></input>
                        </td>
                     
                    </tr>
                    <tr>
                        <td class="formLabel">
                            <label for="excludeBuilds" title="List of build numbers to exclude. Can use , and - (e.g. 1,5-7).">Exclude builds:</label>
                        </td>
                        <td class="formInput" colspan="7">
                            <input id="excludeBuilds" type="text" placeholder="Exclude build numbers"/>
                        </td class="formInput">
                    </tr>
                    <tr>
                        <td colspan="8" class="formSubmit">
                            <input type="submit" value="Update" action="javascript:void(0)" />
                        </td>
                    </tr>
                </table>
            </form>
        </div>

        <div class="sectionToggle"><span class="sectionVisible"></span><span class="sectionHeader"> Chart</span></div>
        <div id="contentChart">
            <div id="legend"></div>
            <div id="chartContainer">
                <div id="preview"></div>
                <div id="y_axis"></div>
                <div id="chart"></div>
                <div id="x_axis"></div>
            </div>
        </div>

        <div class="sectionToggle"><span class="sectionVisible"></span><span class="sectionHeader"> Table</span></div>
        <div id="tableContainer">
        </div>
    </div>

</div>

<script type="text/javascript">

var dataModel = function() {
    var self = {
        originalChartData: ${JavascriptDataVariableName}.reverse(),
        chartData: null,
        testTimeThresholdData: ${JavascriptTestTimeThresholdDataVariableName},
        width: $Width,
        height: $Height,

        hasTestTimeThresholdData: function() {
            return (self.testTimeThresholdData != null && Object.getOwnPropertyNames(self.testTimeThresholdData).length > 0);
        }
    };

    return self;
}();
"@ + $javascriptFiles + @"
jQuery('#chartFilterForm').submit(function (event) {
    event.preventDefault();
    mainController.showGraphAndTable();
});

jQuery('.sectionToggle').click(mainController.toggleSection);

jQuery(document).ready(function() {
    mainController.init(dataModel, inputModel, graphModel, tableModel);
    mainController.showGraphAndTable();
});

</script>
"@

    return $result
}