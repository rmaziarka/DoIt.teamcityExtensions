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

Import-Module -Name "$PSScriptRoot\..\..\..\..\PSCI.psm1"

Describe -Tag "PSCI.unit" "Get-UpdateXmlAppKeyCmdParams" {
    InModuleScope PSCI.teamcityExtensions {

        $testFileName = 'Get-UpdateXmlAppKeyCmdParams.test'

        function New-TestFile {
            Set-Content -Path $testFileName -Value @'
<?xml version="1.0"?>
<configuration>
  <appSettings>
    <add key="key1" value="value1" />
    <add key="key2" value="&amp;" />
    <add key="key3" value="" />
    <add key="key4" value="value4" />
    <add key="key5" value="value5" />
  </appSettings>
</configuration>
'@
        }

        Context "when supplied a file with multiple keys" {
            It "should properly update the file" {

                try { 
                    New-TestFile
                    $configValues = @('key1=newValue1', 'key2=c:\x\z', 'key3=&', 'key4=value4', 'keyNew=newValue')

                    $params = Get-UpdateXmlAppKeyCmdParams -ConfigFiles $testFileName -ConfigValues $configValues
                    $result = Invoke-Command @params
                    Write-Host $result

                    $content = [IO.File]::ReadAllText($testFileName)
                        $content | Should Be @'
<?xml version="1.0"?>
<configuration>
  <appSettings>
    <add key="key1" value="newValue1" />
    <add key="key2" value="c:\x\z" />
    <add key="key3" value="&amp;" />
    <add key="key4" value="value4" />
    <add key="key5" value="value5" />
    <add key="keyNew" value="newValue" />
  </appSettings>
</configuration>
'@

                    $result | Should Not Be $null
                    $result.Count | Should Be 6
                    $result[0] | Should Match "Key 'key1' - value set to 'newValue1'"
                    $result[1] | Should Match "Key 'key2' - value set to 'c:\\x\\z'"
                    $result[2] | Should Match "Key 'key3' - value set to '&'"
                    $result[3] | Should Match "Key 'key4' - value is already 'value4'"
                    $result[4] | Should Match "Key 'keyNew' not found - adding with value 'newValue'"

                } finally {
                    Remove-Item -Path $testFileName -Force -ErrorAction SilentlyContinue
                }

            }
        }

        Context "when FailIfCannotMatch=true and cannot match" {

            It "should fail" {
                try {
                    New-TestFile
                    $params = Get-UpdateXmlAppKeyCmdParams -ConfigFiles $testFileName -ConfigValues 'keyNotFound=test' -FailIfCannotMatch
                    try { 
                        Invoke-Command @params 
                    } catch {
                        Write-Host $_
                        return
                    }
                    0 | Should Be 1
                } finally {
                    Remove-Item -Path $testFileName -Force -ErrorAction SilentlyContinue
                }
            }
        }

       
    }
}
