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

function Invoke-RunJsCoverMetaRunner {
    <#
	.SYNOPSIS
    A helper for TeamCity MetaRunner that runs javascript unit tests with code coverage.

    .DESCRIPTION
    Executes Jasmine tests using PhantomJS. Coverage information is gathered using JsCover.

	.PARAMETER JsCoverPath
	Path to JsCover (typically JsCover-all.jar).

    .PARAMETER DocumentRoot
	Path to the root directory of tested scripts.

    .PARAMETER OutputDir
	Path to the directory where results will be stored. If exists it will be cleared.

    .PARAMETER PhantomJsPath
	Path to PhantomJS executable.

	.PARAMETER RunJasminePath
	Path to Jasmine script.

	.PARAMETER TestRunnerPagePath
	Path to test runner html page. It has to be relative to DocumentRoot

	.PARAMETER NoInstrumentPaths
	URLs not to be instrumented by JsCover.

	.PARAMETER NoInstrumentRegExp
	Regular expressions of URLs not to be instrumented by JsCover.

	.PARAMETER JavaPath
    Optional path to java.exe that will be used by JMeter.

	.EXAMPLE			
    Invoke-RunJsCoverMetaRunner -JsCoverPath 'bin\JSCover-all.jar' -DocumentRoot 'Source' -OutputDir '.jscover' 
        -PhantomJsPath 'bin\phantomjs.exe' -RunJasminePath 'bin\run-jscover-jasmine.js' -TestRunnerPagePath 'Web.Tests\SpecRunner.html' 
        -NoInstrumentPaths @('Web/Scripts', 'Web.Tests') -NoInstrumentRegExp '.*_test.js'

	#>
	[CmdletBinding()]
	[OutputType([void])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $JsCoverPath,

        [Parameter(Mandatory=$true)]
        [string]
        $DocumentRoot,

        [Parameter(Mandatory=$true)]
        [string]
        $OutputDir,
        
        [Parameter(Mandatory=$true)]
        [string]
        $PhantomJsPath,

        [Parameter(Mandatory=$true)]
        [string]
        $RunJasminePath,

        [Parameter(Mandatory=$true)]
        [string]
        $TestRunnerPagePath,

        [Parameter(Mandatory=$false)]
        [string[]]
        $NoInstrumentPaths,

        [Parameter(Mandatory=$false)]
        [string[]]
        $NoInstrumentRegExp,

        [Parameter(Mandatory=$false)]
        [string]
        $JavaPath
    )
    
    if (!(Test-Path -Path $JsCoverPath)) {
        Write-Log -Critical "Cannot find JsCover jar file at '$JsCoverPath'."
    }
        
    if (!(Test-Path -Path $PhantomJsPath)) {
        Write-Log -Critical "Cannot find PhantomJs exe file at '$PhantomJsPath'."
    }
    
    if (!(Test-Path -Path $RunJasminePath)) {
        Write-Log -Critical "Cannot find Jasmine script file at '$RunJasminePath'."
    }

    if (!(Test-Path -Path $DocumentRoot)) {
        Write-Log -Critical "Cannot find documents root directory at '$DocumentRoot'."
    }
    
    $testRunnerAbsPath = Join-Path -Path $DocumentRoot -ChildPath $TestRunnerPagePath
    if (!(Test-Path -Path ($testRunnerAbsPath))) {
        Write-Log -Critical "Cannot find test runner page at '$testRunnerAbsPath'."
    }

    if (Test-Path -Path $OutputDir) {
        Write-Log -Info "Output directory '$OutputDir' exists - deleting."
        Remove-Item -Path $OutputDir -Force -Recurse
    }
    
    $JsCoverPath = (Resolve-Path -Path $JsCoverPath).Path
    $PhantomJsPath = (Resolve-Path -Path $PhantomJsPath).Path
    $RunJasminePath = (Resolve-Path -Path $RunJasminePath).Path
    $DocumentRoot = (Resolve-Path -Path $DocumentRoot).Path
        
    if ($JavaPath) {
       Write-Log -Info "Setting environment variable (process-scoped) JM_LAUNCH to '$JavaPath'"
       [Environment]::SetEnvironmentVariable("JM_LAUNCH", $JavaPath, "Process")
    }
    
    $stdOutFile = Join-Path -Path $OutputDir -ChildPath 'out.log'
    $stdErrFile = Join-Path -Path $OutputDir -ChildPath 'err.log'

    $cmdArgs = "-Dfile.encoding=UTF-8 -jar $JsCoverPath -ws --log=INFO --save-json-only --document-root=$DocumentRoot --report-dir=$OutputDir"
    
    foreach ($path in $NoInstrumentPaths) {
        $cmdArgs += " --no-instrument=$path"
    }
    
    foreach ($regex in $NoInstrumentRegExp) {
        $cmdArgs += " --no-instrument-reg=$regex"
    }

    $params = @{
        'FilePath' = 'java.exe'
        'ArgumentList' = $cmdArgs
        'NoNewWindow' = $true
        'PassThru' = $true
        'RedirectStandardOutput' = $stdOutFile
        'RedirectStandardError' = $stdErrFile
    }

    Write-Log -Info "Running JsCover server in background with following command line: java $cmdArgs."
    Write-Log -Info "JsCover output will be captured in following files: '$stdOutFile', '$stdErrFile'"

    $process = Start-Process @params
    Write-Log -Info "Process started, id = $($process.Id), name = $($process.Name)"
    
    # give time to server start up
    Start-Sleep -Seconds 2

    try{
        $testRunnerUri = $TestRunnerPagePath -replace '\\', '/'
        $phantomJsArgs = "$RunJasminePath http://localhost:8080/$testRunnerUri"
        Write-Log -Info "Running phantomjs with following command line: $PhantomJsPath $phantomJsArgs"
        Write-ProgressExternal -Message 'Running Javascript tests'
        [void](Start-ExternalProcess -Command $PhantomJsPath -ArgumentList $phantomJsArgs -WorkingDirectory (Get-Location))
        Start-Sleep -Seconds 2
    } finally {
        Stop-JsCoverServer -Process $process
    }

    $OutputDir = (Resolve-Path -Path $OutputDir).Path
    $convertArgs = "-cp $JsCoverPath jscover.report.Main --format=LCOV $OutputDir $DocumentRoot"
    Write-ProgressExternal -Message 'Converting coverage reports'
    [void](Start-ExternalProcess -Command 'java.exe' -ArgumentList $convertArgs -WorkingDirectory (Get-Location) -CheckStdErr: $false)
}

function Stop-JsCoverServer {
    <#
    .SYNOPSIS
    Stops JsCover local web server.
    
    .PARAMETER Process
    Process of JsCover server.
    
    .PARAMETER Port
    Port of JsCover server.
    
    .EXAMPLE
    Stop-JsCoverServer -Process $serverProcess -Port 8080
    #>

    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory=$false)]
        [PSCustomObject]
        $Process,

        [Parameter(Mandatory=$false)]
        [int]
        $Port = 8080
    )

    # first try to stop it using web request
    try {
        Invoke-WebRequest -Uri "http://localhost:$Port/stop" -Method 'GET' -UseBasicParsing
    } catch {
        #JsCover response is badly formatted so we need to swallow the exception
    }
    
    if ($Process -and !$Process.WaitForExit(10000)) {
        Stop-ProcessForcefully -Process $Process
        Write-Log -Critical "JsCover process has not finished after 10s and has been killed."
    }
}