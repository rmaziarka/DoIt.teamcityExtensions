DoIt.teamcityExtensions is a set of TeamCity [metarunners](http://blog.jetbrains.com/teamcity/2013/07/the-power-of-meta-runner-custom-runners-with-ease/) written in Powershell.

They require whole DoIt library installed at TeamCity agent and the agent needs to have Windows OS and Powershell >= 3. See [[Installation]] for details.

Since the metarunners are just wrappers for Powershell functions, this library can also be used in different Continuous Integration servers like Jenkins.

## Examples

Test Trend Report:
![Test Trend](https://github.com/ObjectivityBSS/DoIt.teamcityExtensions/wiki/images/TestTrendReport_output.png)

JMeter Aggregate Report:
![JMeter Aggregate Report](https://github.com/ObjectivityBSS/DoIt.teamcityExtensions/wiki/images/JMeterAggregateReport_output.png)

For a list of available metarunners, see [project wiki](https://github.com/ObjectivityBSS/DoIt.teamcityExtensions/wiki).
