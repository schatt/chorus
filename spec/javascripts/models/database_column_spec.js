describe("chorus.models.DatabaseColumn", function() {
    beforeEach(function() {
        this.model = new chorus.models.DatabaseColumn({name: "Col", typeCategory: "WHOLE_NUMBER", type: 'varbit'});
    });

    describe("#initialize", function() {
        context("when there is not dataset", function() {
            beforeEach(function() {
                this.model.initialize();
            });

            it("does not blow up", function() {
                expect(this.model.get('name')).toBe('Col');
            });

            it("sets the typeClass property on the model", function() {
                expect(this.model.get("typeClass")).toBe("numeric");
            });
        });

        context("when there is dataset", function() {
            beforeEach(function() {
                this.dataset = backboneFixtures.workspaceDataset.datasetTable({ id: 45, objectName: 'taaab'});
                this.model.dataset = this.dataset;
                this.model.initialize();
            });

            describe("#url", function() {
                it("is correct", function() {
                    expect(this.model.url()).toMatchUrl("/datasets/45/columns?filter=Col");
                });
            });

            describe("#toText", function() {
                context("with lowercase names", function() {
                    beforeEach(function() {
                        this.model.set({name: "col"});
                    });
                    it("formats the string to put into the sql editor", function() {
                        expect(this.model.toText()).toBe('"col"');
                    });
                });
                context("with uppercase names", function() {
                    beforeEach(function() {
                        this.model.set({name: "Col", schemaName: "PartyMAN", parentName: "TAAAB"});
                    });
                    it("puts quotes around the uppercase names", function() {
                        expect(this.model.toText()).toBe('"Col"');
                    });
                });
                context("when a dataset doesn't want quotes (e.g. hive)", function() {
                    beforeEach(function() {
                        this.model.set({name: "col"});
                        this.model.dataset.set({
                            objectName: "can",
                            schema: {
                                name: "trash",
                                dataSource: {
                                    // Hive hates quotes.
                                    entityType: 'jdbc_hive_data_source'
                                }
                            }
                        });
                    });
                    it("doesn't puts quotes around the uppercase names", function() {
                        expect(this.model.toText()).toBe('col');
                    });
                });
            });

            describe("#typeClass", function() {
                var expectedTypeMap = {
                    "WHOLE_NUMBER" : "numeric",
                    "REAL_NUMBER" : "numeric",
                    "STRING" : "string",
                    "LONG_STRING" : "string",
                    "BINARY" : "binary",
                    "BOOLEAN" : "boolean",
                    "DATE" : "date",
                    "TIME" : "time",
                    "DATETIME" : "date_time",
                    "OTHER" : "other"
                };

                _.each(expectedTypeMap, function(str, type) {
                    it("works for " + type, function() {
                        expect(new chorus.models.DatabaseColumn({ typeCategory : type }).get("typeClass")).toBe(str);
                    });
                });
            });

        });
    });
});
