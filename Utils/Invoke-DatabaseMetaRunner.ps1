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

function Invoke-DatabaseMetaRunner {

    <#
    .SYNOPSIS
    A helper for TeamCity MetaRunner that drops/creates/restores SQL Server database.
    
    .PARAMETER DatabaseServer
    Name of database server.

    .PARAMETER DatabaseName
    Name of database.

    .PARAMETER Action
    Action to do - Drop, DropAndCreate, DropAndRestore.

    .PARAMETER IntegratedSecurity
    If true, Windows Authentication will be used. SQL Server Authentication otherwise.

    .PARAMETER Username
    Username - leave empty for domain agent credentials.

    .PARAMETER Password
    Password - leave empty for domain agent credentials.

    .PARAMETER TimeoutInSeconds
    Timeout for command execution.

    .PARAMETER BackupLocation
    Path to backup required if Action = DropAndRestore.

    .EXAMPLE
      $params = @{
        'DatabaseServer' = '%sqlRun.databaseServer%';
        'DatabaseName' = '%sqlRun.databaseName%';
        'Action' = '%sqlRun.action%';
        'IntegratedSecurity' = %sqlRun.integratedSecurity%;
        'Username' = '%sqlRun.username%';
        'Password' = '%sqlRun.password%';
        'TimeoutInSeconds' = '%sqlRun.timeout%';
      }

      Invoke-DatabaseMetaRunner @params
    #>

    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $DatabaseServer,

        [Parameter(Mandatory=$true)]
        [string]
        $DatabaseName,

        [Parameter(Mandatory=$true)]
        [ValidateSet('Drop', 'DropAndCreate', 'DropAndRestore')]
        [string]
        $Action,

        [Parameter(Mandatory=$false)]
        [switch]
        $IntegratedSecurity,

        [Parameter(Mandatory=$false)]
        [string]
        $Username,

        [Parameter(Mandatory=$false)]
        [string]
        $Password,

        [Parameter(Mandatory=$false)]
        [string]
        $TimeoutInSeconds,

        [Parameter(Mandatory=$false)]
        [string]
        $BackupLocation
    )

    if ($Action -eq 'DropAndRestore' -and !$BackupLocation) {
        Write-Log -Critical 'Please specify path to the database backup.'
    }

    $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
    $builder['Data Source'] = $DatabaseServer

    $credential = $null
    if ($IntegratedSecurity) {
        $builder['Integrated Security'] = $true
        if ($Username) {
            $credential = ConvertTo-PSCredential -User $Username -Password $Password
        }
    } else {
        $builder['User ID'] = $Username
        $builder['Password'] = $Password
    }

    $params = @{
        ConnectionString = $builder.ConnectionString
        DatabaseName = $DatabaseName
    }
    if ($credential) {
       $params['Credential'] = $credential
    }
    if ($TimeoutInSeconds) {
       $params['TimeoutInSeconds'] = $TimeoutInSeconds
    }

    Remove-SqlDatabase @params

    if ($Action -eq 'DropAndRestore') {
        $params['Path'] = $BackupLocation
        Restore-SqlDatabase @params
    } elseif ($Action -eq 'DropAndCreate') {
        New-SqlDatabase @params
    }
}