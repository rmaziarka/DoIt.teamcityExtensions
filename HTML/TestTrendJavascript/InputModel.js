var inputModel = function() {
    var self = {
        numLastBuilds: 0,
        testNameRegex: '',
        includeBuilds: '',
        excludeBuilds: '',
        showFailedBuilds: false,
        relativeToBuild: '',
        relativeToBuildInt: null,
        relativeToBuildPercent: false,
        graphUnit: GraphUnitEnum.ms,
        graphRenderer: 'line',

        refreshModel: function() { 
            self.numLastBuilds = jQuery('#testHistoryNumber')[0].value;
            self.testNameRegex = jQuery('#testNameRegex')[0].value;
            if (self.testNameRegex) {
                self.testNameRegex = new RegExp(self.testNameRegex, "i");
            }
            self.includeBuilds = self.parseIncludeExcludeBuilds(jQuery('#includeBuilds')[0].value);
            self.excludeBuilds = self.parseIncludeExcludeBuilds(jQuery('#excludeBuilds')[0].value);
            self.showFailedBuilds = jQuery('#showFailedBuilds').prop('checked');
            self.relativeToBuild = jQuery('#relativeToBuild')[0].value;
            self.relativeToBuildInt = parseInt(self.relativeToBuild, 10);
            self.graphRenderer = jQuery('#chartRenderer option:selected')[0].value;

            var relativeToBuildPercent = jQuery('#relativeToBuildPercent').prop('checked');
            self.graphUnit = (self.relativeToBuild && relativeToBuildPercent) ? GraphUnitEnum.percent : GraphUnitEnum.ms;
        },

        validateRelativeToBuild: function(chartData) {
            if (chartData.length == 0 || !self.relativeToBuild || self.isRelativeToBuildDynamic()) {
                return true;
            }
            var data = chartData[0].data;
            for (i = 0; i < data.length; i++) {
                if (data[i].xLabel == self.relativeToBuild) {
                    return true;
                }
            }
            return false;
        },

        isAnyFilterSet: function() {
            return (self.numLastBuilds > 0 || self.includeBuilds != null || self.excludeBuilds != null || !self.showFailedBuilds || self.relativeToBuild);
        },

        filterTestName: function(testName) {
            return (!self.testNameRegex || self.testNameRegex.test(testName));
        },

        filterNumLastBuilds: function(index, testSeriesDataLength) {
            return (!self.numLastBuilds || self.numLastBuilds <= 0 || index >= testSeriesDataLength - self.numLastBuilds);
        },

        filterIncludeBuilds: function(xLabel) {
            return (!self.includeBuilds || self.includeBuilds.indexOf(xLabel) !== -1);
        },

        filterExcludeBuilds: function(xLabel) {
            return (!self.excludeBuilds || self.excludeBuilds.indexOf(xLabel) === -1);
        },

        filterShowFailedBuilds: function(success) {
            return (self.filterShowFailedBuilds || success);
        },

        filterBuild: function(index, testSeriesDataLength, xLabel, success) {
            return (self.filterNumLastBuilds(index, testSeriesDataLength) &&
                    self.filterIncludeBuilds(xLabel) &&
                    self.filterExcludeBuilds(xLabel) && 
                    self.filterShowFailedBuilds(success)
                   );
        },

        parseIncludeExcludeBuilds: function(input) {
            if (input == null || input === "") {
                return null;
            }
            var inputEntries = input.split(",");
            var output = []
            for (var i = 0; i < inputEntries.length; i++) {
                var rangeEntries = inputEntries[i].split("-")
                if (rangeEntries.length === 1) {
                    output.push(inputEntries[i]);
                } else if (rangeEntries.length === 2) {
                    if (rangeEntries[1] >= rangeEntries[0]) { 
                        for (var j = rangeEntries[0]; j <= rangeEntries[1]; j++) {
                            output.push(j.toString());
                        }
                    } else {
                        for (var j = rangeEntries[0]; j >= rangeEntries[1]; j--) {
                            output.push(j.toString());
                        }
                    }
                }
            }
            return output;
        },

        sortInIncludeBuildsOrder: function(data) {
            if (self.includeBuilds == null) {
                return;
            }

            // sort in includeBuilds order
            data.sort(function(a, b) {
                var indexA = self.includeBuilds.indexOf(a.xLabel);
                var indexB = self.includeBuilds.indexOf(b.xLabel);
                return (indexA == indexB) ? 0 : (indexA > indexB) ? 1 : -1;
            });
            for (var j = 0; j < data.length; j++) {
                data[j].x = j+1;
            }
        },

        isRelativeToBuildDynamic: function() {
            return (self.relativeToBuild && self.relativeToBuildInt && self.relativeToBuildInt < 0);
        },

        getBaseBuildValue: function(testSeriesData) {
            if (!self.relativeToBuild || self.isRelativeToBuildDynamic()) {
                return null;
            }
            var baseBuild = jQuery.grep(testSeriesData, function (element, index) {
                return (element.xLabel == self.relativeToBuild);
            });
            if (baseBuild.length == 0) {
                return;
            }
            return baseBuild[0].y;
        },

        calculateRelativeValue: function (baseValue, value) {
            var result = (baseValue == null || value == null ? null : value - baseValue);
            if (result != null && self.graphUnit == GraphUnitEnum.percent) {
                result = Math.round(result / baseValue * 100);
            }
            return result;
        },

        filterTestSeries: function(testSeries) {
            if (!self.filterTestName(testSeries.name)) {
                return null;
            }
            if (!self.isAnyFilterSet()) {
                return testSeries;
            }

            var testSeriesDataLength = testSeries.data.length;
            var x = 1;
            var hasAtLeastOneValue = false;
            var baseBuildValue = self.getBaseBuildValue(testSeries.data);

            var newData = jQuery.map(testSeries.data, function (element, index) {
                if (!self.filterBuild(index, testSeriesDataLength, element.xLabel, element.success)) {
                    return null;
                }
                var yValue = element.y;
                if (element.y != null) {
                    if (self.relativeToBuild && !self.isRelativeToBuildDynamic()) {
                        yValue = self.calculateRelativeValue(baseBuildValue, yValue);
                    }
                }
                if (yValue != null) {
                    hasAtLeastOneValue = true;
                }
                return { x : x++, y: yValue, xLabel: element.xLabel };
            });

            // if relativeToBuild is dynamic (negative), we need to filter new data once again, in order to prevent using values that have been filtered out
            if (self.isRelativeToBuildDynamic()) {
                hasAtLeastOneValue = false;
                newData = jQuery.map(newData, function (element, index) {
                    var yValue = null;
                    if (index >= -self.relativeToBuildInt) {
                        var baseBuildValue = newData[index + self.relativeToBuildInt].y;
                        yValue = self.calculateRelativeValue(baseBuildValue, element.y);
                        if (yValue != null) {
                            hasAtLeastOneValue = true;
                        }
                        return { x: element.x, y: yValue, xLabel: element.xLabel };
                    } else {
                        return null;
                    }
                    
                });
            }

            if (newData.length > 0 && hasAtLeastOneValue) {
                self.sortInIncludeBuildsOrder(newData);
                return { name : testSeries.name, color: testSeries.color, data: newData };
            } else {
                return null;
            }
        }

    };
    return self;
}();