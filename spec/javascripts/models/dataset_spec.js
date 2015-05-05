describe("chorus.models.Dataset", function() {
    beforeEach(function() {
        this.dataset = backboneFixtures.dataset({
            id: 45,
            schema: {
                id: 1,
                name: "ipa",
                database: {
                    "name": "beers",
                    dataSource: {
                        id: 12
                    }
                }
            },
            objectType: "TABLE"
        });
    });

    it("has the right urls", function() {
        expect(this.dataset.url()).toMatchUrl("/datasets/45");
        expect(this.dataset.showUrl()).toMatchUrl("#/datasets/45");
    });

    it("has the correct entityType", function() {
        expect(this.dataset.entityType).toBe("dataset");
    });

    describe("when the 'invalidated' event is triggered", function() {
        describe("when the dataset belongs to a collection", function() {
            beforeEach(function() {
                this.collection = new chorus.collections.SchemaDatasetSet();
                this.collection.add(this.dataset);
            });

            it("re-fetches itself, because the last comment might have changed", function() {
                this.dataset.trigger("invalidated");
                expect(this.dataset).toHaveBeenFetched();
            });
        });

        describe("when the dataset has no collection", function() {
            it("does not fetch anything", function() {
                this.dataset.trigger("invalidated");
                expect(this.dataset).not.toHaveBeenFetched();
            });
        });
    });

    describe("#isChorusView", function() {
        it("is always false", function() {
            expect(this.dataset.isChorusView()).toBeFalsy();
        });
    });

    describe('#isOracle', function(){
        beforeEach(function() {
            this.oracleDataset = backboneFixtures.oracleDataset();
            this.jdbcDataset = backboneFixtures.jdbcDataset();
            this.gpdbDataset = backboneFixtures.dataset();
            this.pgDataset = backboneFixtures.pgDataset();
        });

        it('returns whether the parent data source is an oracle data source', function(){
            expect(this.oracleDataset.isOracle()).toBeTruthy();
            expect(this.gpdbDataset.isOracle()).toBeFalsy();
            expect(this.jdbcDataset.isOracle()).toBeFalsy();
            expect(this.pgDataset.isOracle()).toBeFalsy();
        });
        
         afterEach(function() {
            this.oracleDataset.destroy();
            this.jdbcDataset.destroy();
            this.gpdbDataset.destroy();
            this.pgDataset.destroy();
        });       
    });

    describe('#isJdbc', function(){
        beforeEach(function() {
            this.oracleDataset = backboneFixtures.oracleDataset();
            this.jdbcDataset = backboneFixtures.jdbcDataset();
            this.gpdbDataset = backboneFixtures.dataset();
            this.pgDataset = backboneFixtures.pgDataset();
        });

        it('returns whether the parent data source is a jdbc data source', function(){
            expect(this.oracleDataset.isJdbc()).toBeFalsy();
            expect(this.gpdbDataset.isJdbc()).toBeFalsy();
            expect(this.jdbcDataset.isJdbc()).toBeTruthy();
            expect(this.pgDataset.isJdbc()).toBeFalsy();
        });

        afterEach(function() {
            this.oracleDataset.destroy();
            this.jdbcDataset.destroy();
            this.gpdbDataset.destroy();
            this.pgDataset.destroy();
        });   

    });

    describe('#isGreenplum', function(){
        beforeEach(function() {
            this.gpdbDataset = backboneFixtures.dataset();
            this.jdbcDataset = backboneFixtures.jdbcDataset();
            this.oracleDataset = backboneFixtures.oracleDataset();
            this.pgDataset = backboneFixtures.pgDataset();
        });

        it('returns whether the parent data source is greenplum', function(){
            expect(this.gpdbDataset.isGreenplum()).toBeTruthy();
            expect(this.oracleDataset.isGreenplum()).toBeFalsy();
            expect(this.jdbcDataset.isGreenplum()).toBeFalsy();
            expect(this.pgDataset.isGreenplum()).toBeFalsy();
        });
        afterEach(function() {
            this.oracleDataset.destroy();
            this.jdbcDataset.destroy();
            this.gpdbDataset.destroy();
            this.pgDataset.destroy();
        });   
        
    });

    describe('#isPostgres', function(){
        beforeEach(function() {
            this.gpdbDataset = backboneFixtures.dataset();
            this.jdbcDataset = backboneFixtures.jdbcDataset();
            this.oracleDataset = backboneFixtures.oracleDataset();
            this.pgDataset = backboneFixtures.pgDataset();
        });

        it('returns whether the parent data source is greenplum', function(){
            expect(this.gpdbDataset.isPostgres()).toBeFalsy();
            expect(this.oracleDataset.isPostgres()).toBeFalsy();
            expect(this.jdbcDataset.isPostgres()).toBeFalsy();
            expect(this.pgDataset.isPostgres()).toBeTruthy();
        });
        
        afterEach(function() {
            this.oracleDataset.destroy();
            this.jdbcDataset.destroy();
            this.gpdbDataset.destroy();
            this.pgDataset.destroy();
        });   
        
    });

    it("includes the DataSourceCredentials mixin", function() {
        expect(this.dataset.dataSourceRequiringCredentials).toBe(chorus.Mixins.DataSourceCredentials.model.dataSourceRequiringCredentials);
    });

    describe("#initialize", function() {
        it("doesn't override type when entitySubtype already exists", function() {
            var model = new chorus.models.DynamicDataset({ entitySubtype: "foo"});
            expect(model.get("entitySubtype")).toBe("foo");
        });

        it("sets entitySubtype to datasetType if datasetType exists", function() {
            var model = new chorus.models.DynamicDataset({ datasetType: "foo"});
            expect(model.get("entitySubtype")).toBe("foo");
        });

        it("sets entitySubtype to SOURCE_TABLE if neither entitySubtype nor datasetType exists", function() {
            var model = new chorus.models.DynamicDataset({});
            expect(model.get("entitySubtype")).toBe("SOURCE_TABLE");
        });
    });

    describe("#statistics", function() {
        beforeEach(function() {
            this.statistics = this.dataset.statistics();
        });

        it("returns a data source of DatasetStatistics", function() {
            expect(this.statistics).toBeA(chorus.models.DatasetStatistics);
        });

        it("should memoize the result", function() {
            expect(this.statistics).toBe(this.dataset.statistics());
        });

        it("sets the properties correctly", function() {
            expect(this.statistics.get("datasetId")).toBe(this.dataset.id);
        });
    });

    describe("iconFor", function() {
        var largeIconMap = {
            "CHORUS_VIEW": {
                "CHORUS_VIEW": "chorus_view_large.png"
            },

            "SOURCE_TABLE": {
                "TABLE": "source_table_large.png",
                "EXTERNAL_TABLE": "source_table_large.png",
                "MASTER_TABLE": "source_table_large.png",
                "VIEW": "source_view_large.png"
            },

            "SANDBOX_TABLE": {
                "TABLE": "sandbox_table_large.png",
                "EXTERNAL_TABLE": "sandbox_table_large.png",
                "MASTER_TABLE": "sandbox_table_large.png",
                "VIEW": "sandbox_view_large.png",
                "HDFS_EXTERNAL_TABLE": "sandbox_table_large.png"
            },

            "HDFS": {
                "MASK": "hdfs_dataset_large.png"
            }
        };

        var mediumIconMap = {
            "CHORUS_VIEW": {
                "CHORUS_VIEW": "chorus_view_medium.png"
            },

            "SOURCE_TABLE": {
                "TABLE": "source_table_medium.png",
                "EXTERNAL_TABLE": "source_table_medium.png",
                "MASTER_TABLE": "source_table_medium.png",
                "VIEW": "source_view_medium.png"
            },

            "SANDBOX_TABLE": {
                "TABLE": "sandbox_table_medium.png",
                "EXTERNAL_TABLE": "sandbox_table_medium.png",
                "MASTER_TABLE": "sandbox_table_medium.png",
                "VIEW": "sandbox_view_medium.png",
                "HDFS_EXTERNAL_TABLE": "sandbox_table_medium.png"
            }
        };

        describe("when the 'size' option is set to 'medium'", function() {
            it("returns the medium version of the icon of the appropriate type", function() {
                _.each(mediumIconMap, function(subMap, type) {
                    _.each(subMap, function(filename, objectType) {

                        var model = backboneFixtures.dataset({ entitySubtype: type, objectType: objectType});
                        expect(model.iconUrl({ size: "medium" })).toBe("/images/data_sets/" + filename);

                    });
                });
            });
        });

        describe("when the 'size' option is set to 'large'", function() {
            it("returns the large version of the icon of the appropriate type", function() {
                _.each(largeIconMap, function(subMap, type) {
                    _.each(subMap, function(filename, objectType) {

                        var model = backboneFixtures.dataset({ entitySubtype: type, objectType: objectType});
                        expect(model.iconUrl({ size: "large" })).toBe("/images/data_sets/" + filename);

                    });
                });
            });
        });

        describe("when no 'size' option is given", function() {
            it("returns the large version of the icon of the appropriate type", function() {
                _.each(largeIconMap, function(subMap, type) {
                    _.each(subMap, function(filename, objectType) {

                        var model = backboneFixtures.dataset({ entitySubtype: type, objectType: objectType});
                        expect(model.iconUrl()).toBe("/images/data_sets/" + filename);

                    });
                });
            });
        });
    });

    describe("#canBeImportSource", function() {
        it("returns true if the object is a Dataset (with a workspace id) but not a Sandbox Dataset", function() {
            var table = backboneFixtures.dataset();
            expect(table.canBeImportSource()).toBeFalsy();

            var dataset = backboneFixtures.workspaceDataset.datasetTable();
            expect(dataset.canBeImportSource()).toBeFalsy();

            dataset = backboneFixtures.workspaceDataset.datasetView();
            expect(dataset.canBeImportSource()).toBeFalsy();

            dataset = backboneFixtures.workspaceDataset.sourceTable();
            expect(dataset.canBeImportSource()).toBeTruthy();

            dataset = backboneFixtures.workspaceDataset.chorusView();
            expect(dataset.canBeImportSource()).toBeTruthy();

            dataset = backboneFixtures.workspaceDataset.jdbcTable();
            expect(dataset.canBeImportSource()).toBeFalsy();
        });
    });

    describe("#canBeImportDestination", function() {
        it("returns true if the object is a Dataset (with a workspace id) but not a JDBC dataset", function() {
            var table = backboneFixtures.dataset();
            expect(table.canBeImportDestination()).toBeFalsy();

            var dataset = backboneFixtures.workspaceDataset.datasetTable();
            expect(dataset.canBeImportDestination()).toBeTruthy();

            dataset = backboneFixtures.workspaceDataset.datasetView();
            expect(dataset.canBeImportDestination()).toBeTruthy();

            dataset = backboneFixtures.workspaceDataset.datasetTable();
            expect(dataset.canBeImportDestination()).toBeTruthy();

            dataset = backboneFixtures.workspaceDataset.chorusView();
            expect(dataset.canBeImportDestination()).toBeTruthy();

            dataset = backboneFixtures.workspaceDataset.jdbcTable();
            expect(dataset.canBeImportDestination()).toBeFalsy();
        });
    });

    describe("#dataSource", function() {
        beforeEach(function() {
            this.dataSource = this.dataset.dataSource();
        });

        it("returns a data source with the right id and name", function() {
            expect(this.dataSource).toBeA(chorus.models.GpdbDataSource);
            expect(this.dataSource.id).toBe(this.dataset.get("schema").database.dataSource.id);
            expect(this.dataSource.name()).toBe(this.dataset.get("schema").database.dataSource.name);
        });
    });

    describe("#database", function() {
        it("returns a new database with the right attributes", function() {
            expect(this.dataset.database().name()).toBe(this.dataset.get("schema").database.name);
        });
    });

    describe("#schema", function() {
        it("returns a new schema with the right attributes", function() {
            expect(this.dataset.schema().name()).toBe(this.dataset.get("schema").name);
        });

        it("memoizes", function() {
            expect(this.dataset.schema()).toBe(this.dataset.schema());
        });

    });

    describe("#setSchema", function() {
        it("sets the schema", function() {
            var newSchema = backboneFixtures.schema();
            this.dataset.setSchema(newSchema);
            expect(this.dataset.schema().attributes).toEqual(newSchema.attributes);
        });
    });

    describe("#lastComment", function() {
        beforeEach(function() {
            this.model = backboneFixtures.dataset({
                recentComments: [
                    {
                        author: {
                            id: 1234,
                            firstName: "anything",
                            lastName: "something"
                        },
                        body: "some text"
                    },
                    {
                        author: {
                            id: 5678,
                            firstName: "nothing",
                            lastName: "nothing"
                        },
                        body: "some text"
                    }
                ]
            });
            this.comment = this.model.lastComment();
            this.lastCommentJson = this.model.get('recentComments')[0];
        });

        it("has the right body", function() {
            expect(this.comment.get("body")).toBe("some text");
        });

        it("has the right creator", function() {
            var creator = this.comment.author();
            expect(creator.get("id")).toBe(1234);
            expect(creator.get("firstName")).toBe("anything");
            expect(creator.get("lastName")).toBe("something");
        });

        it("is loaded", function() {
            expect(this.comment.loaded).toBeTruthy();
        });

        context("when the data doesn't have any comments", function() {
            it("returns null", function() {
                expect(backboneFixtures.dataset({recentComments: null}).lastComment()).toBeUndefined();
            });
        });
    });

    describe("#metaType", function() {
        var expectedTypeMap = chorus.models.Dataset.metaTypeMap;

        _.each(expectedTypeMap, function(str, type) {
            it("works for " + type, function() {
                expect(backboneFixtures.dataset({ objectType: type }).metaType()).toBe(str);
            });
        });
    });

    describe("#preview", function() {
        function checkPreview() {
            it("should return a Task", function() {
                expect(this.preview).toBeA(chorus.models.Task);
                expect(this.preview.get("checkId")).not.toBeUndefined();
            });

            it("should not memoize the database preview", function() {
                expect(this.preview).not.toBe(this.dataset.preview());
            });
        }

        context("with a table", function() {
            beforeEach(function() {
                this.dataset.set({objectType: "TABLE", objectName: "foo"});
                this.preview = this.dataset.preview();
            });

            checkPreview();

            it("should return a database preview", function() {
                expect(this.preview).toBeA(chorus.models.DataPreviewTask);
                expect(this.preview.get("dataset").id).toBe(this.dataset.id);
            });
        });

        context("with a view", function() {
            beforeEach(function() {
                this.dataset.set({objectType: "VIEW", objectName: "bar"});
                this.preview = this.dataset.preview();
            });

            checkPreview();

            it("should return a database preview", function() {
                expect(this.preview).toBeA(chorus.models.DataPreviewTask);
                expect(this.preview.get("dataset").id).toBe(this.dataset.id);
            });
        });

        context("with a saved chorus view", function() {
            beforeEach(function() {
                this.dataset = backboneFixtures.workspaceDataset.chorusView();
                this.preview = this.dataset.preview();
            });

            checkPreview();

            it("should return a dataset preview", function() {
                expect(this.preview).toBeA(chorus.models.DataPreviewTask);
                expect(this.preview.get("dataset").id).toBe(this.dataset.id);
            });

            context("when the query has been modified", function() {
                beforeEach(function() {
                    this.dataset.set({query: 'select bananas'});
                    this.preview = this.dataset.preview();
                });

                checkPreview();

                it("should return a chorus view preview", function() {
                    expect(this.preview).toBeA(chorus.models.ChorusViewPreviewTask);
                    expect(this.preview.get("objectName")).toBe(this.dataset.get("objectName"));
                    expect(this.preview.get("schemaId")).toBe(this.dataset.schema().get("id"));
                    expect(this.preview.get("query")).toBe("select bananas");
                });
            });
        });

        context("with a new chorus view", function() {
            beforeEach(function() {
                var sourceDataset = backboneFixtures.workspaceDataset.datasetTable();
                this.dataset = backboneFixtures.workspaceDataset.chorusView({
                    query: "select * from hello_world",
                    objectName: "my_chorusview"
                });
                this.dataset.sourceObject = sourceDataset;

                this.preview = this.dataset.preview();
            });

            checkPreview();

            it("should return a chorus view preview", function() {
                expect(this.preview).toBeA(chorus.models.ChorusViewPreviewTask);
                expect(this.preview.get("objectName")).toBe("my_chorusview");
                expect(this.preview.get("schemaId")).toBe(this.dataset.schema().get("id"));
                expect(this.preview.get("query")).toBe("select * from hello_world");
            });

        });
    });

    describe("#download", function() {
        beforeEach(function() {
            spyOn(chorus, "fileDownload");
        });

        context("when no number of rows is passed", function() {
            it("includes the number of rows", function() {
                this.dataset.download();
                expect(chorus.fileDownload).toHaveBeenCalledWith("/datasets/" + this.dataset.id + "/download.csv", {data: {}});
            });
        });

        context("when a number of rows is passed", function() {
            it("makes a request to the tabular data download api", function() {
                this.dataset.download({ rowLimit: "345" });
                expect(chorus.fileDownload).toHaveBeenCalledWith("/datasets/" + this.dataset.id + "/download.csv", { data: {row_limit: "345"} });
            });
        });
    });

    describe("#columns", function() {
        it("should memoize the result", function() {
            expect(this.dataset.columns()).toBe(this.dataset.columns());
        });

        it("should return a DatabaseColumnSet", function() {
            expect(this.dataset.columns()).toBeA(chorus.collections.DatabaseColumnSet);
        });

        it("should pass the correct parameters to the DatabaseColumnSet", function() {
            var columns = this.dataset.columns();
            expect(columns.attributes.id).toBe(this.dataset.id);
        });

        it("has a reference back to the dataset", function() {
            var columns = this.dataset.columns();
            expect(columns.dataset).toBe(this.dataset);
        });

        context("when the object has a metaType of 'query'", function() {
            beforeEach(function() {
                spyOn(this.dataset, 'metaType').andReturn('query');
                this.dataset.set({ id: "ID" });
            });

            it("has a queryName of the dataset id", function() {
                var columns = this.dataset.columns();
                expect(columns.attributes.queryName).toBe(this.dataset.get('id'));
            });
        });

        context("when the object is a table", function() {
            beforeEach(function() {
                this.dataset.set({ objectType: "SOURCE_TABLE" });
            });

            it("passes its name to the column set as 'tableName'", function() {
                var columns = this.dataset.columns();
                expect(columns.attributes.tableName).toBe(this.dataset.name());
                expect(columns.attributes.viewName).toBeFalsy();
            });
        });

        context("when the object is a view", function() {
            beforeEach(function() {
                this.dataset.set({ objectType: "VIEW" });
            });

            it("passes its name to the column set as 'viewName'", function() {
                var columns = this.dataset.columns();
                expect(columns.attributes.viewName).toBe(this.dataset.name());
                expect(columns.attributes.tableName).toBeFalsy();
            });
        });
    });

    describe("#quotedName", function() {
        beforeEach(function() {
            this.dataset.set({objectName: "My_Object"});
        });

        it("uses the ensureDoubleQuoted helper", function() {
            expect(this.dataset.quotedName()).toBe(chorus.Mixins.dbHelpers.ensureDoubleQuoted(this.dataset.name()));
        });
    });

    describe("#quotedSchemaName", function() {
        beforeEach(function() {
            this.dataset.set({objectName: "My_Object"});
        });

        it("uses the ensureDoubleQuoted helper", function() {
            expect(this.dataset.quotedSchemaName()).toBe(chorus.Mixins.dbHelpers.ensureDoubleQuoted(this.dataset.get("schema").name));
        });
    });

    describe("#toText", function() {
        context("with lowercase names", function() {
            beforeEach(function() {
                this.dataset.set({objectName: "tabler",
                                  schema: {
                                      name: "party_schema",
                                      dataSource: {
                                            entityType: 'data_source'
                                      }
                                  }});
            });

            it("formats the string to put into the sql editor", function() {
                expect(this.dataset.toText()).toBe('"party_schema"."tabler"');
            });
        });

        context("with uppercase names", function() {
            beforeEach(function() {
                this.dataset.set({objectName: "Tabler",
                    schema: {
                        name: "PartyMAN",
                        dataSource: {
                            entityType: 'data_source'
                        }
                    }});
            });

            it("puts quotes around the uppercase names", function() {
                expect(this.dataset.toText()).toBe('"PartyMAN"."Tabler"');
            });
        });

        context("with chorus view", function() {
            beforeEach(function() {
                this.dataset = backboneFixtures.workspaceDataset.chorusView({objectName: "ChorusView", query: "SELECT a,b FROM xyz;"});
            });

            it("creates an appropriate string (trimmed, remove semicolon, and alias to pg-quoted CV name)", function() {
                expect(this.dataset.toText()).toBe('(SELECT a,b FROM xyz) AS "ChorusView"');
            });
        });

        context("when a dataset doesn't want quotes (e.g. hive)", function() {
            beforeEach(function() {
                this.dataset.set({objectName: "can",
                    schema: {
                        name: "trash",
                        dataSource: {
                            // Hive hates quotes.
                            entityType: 'jdbc_hive_data_source'
                        }
                    }});
            });

            it("uses the ensureNotDoubleQuoted helper", function() {
                expect(this.dataset.quotedName()).toBe(chorus.Mixins.dbHelpers.ensureNotDoubleQuoted(this.dataset.name()));
            });

            it("formats the string to put into the sql editor", function() {
                expect(this.dataset.toText()).toBe('trash.can');
            });
        });
    });

    describe("#selectName", function() {
        context("when a datasetNumber is not set", function() {
            it("returns the quotedName", function() {
                expect(this.dataset.selectName()).toBe(this.dataset.quotedName());
            });
        });

        context("when a datasetNumber is set", function() {
            beforeEach(function() {
                this.dataset.setDatasetNumber(1);
            });

            it("returns the alias", function() {
                expect(this.dataset.selectName()).toBe("a");
            });
        });
    });

    describe("#fromClause", function() {
        context("when a datasetNumber is not set", function() {
            it("returns the quoted schema name and table name", function() {
                expect(this.dataset.fromClause()).toBe('"' + this.dataset.schema().name() + '".' + this.dataset.quotedName());
            });
        });

        context("when a datasetNumber is set", function() {
            beforeEach(function() {
                this.dataset.setDatasetNumber(1);
            });

            it("returns the aliased from clause", function() {
                expect(this.dataset.fromClause()).toBe('"' + this.dataset.schema().name() + '".' + this.dataset.quotedName() + ' AS "a"');
            });
        });

        context("when the model has a 'query'", function() {
            beforeEach(function() {
                this.dataset = backboneFixtures.workspaceDataset.chorusView();
            });

            context("when a datasetNumber is not set", function() {
                it("returns the query aliased as the objectName", function() {
                    var expectedFrom = "(" + this.dataset.get('query') + ') AS ' + this.dataset.quotedName();
                    expect(this.dataset.fromClause()).toBe(expectedFrom);
                });
            });

            context("when a datasetNumber is set", function() {
                beforeEach(function() {
                    this.dataset.setDatasetNumber(1);
                });

                it("returns the query aliased as the aliasedName", function() {
                    var expectedFrom = "(" + this.dataset.get('query') + ') AS "' + this.dataset.aliasedName + '"';
                    expect(this.dataset.fromClause()).toBe(expectedFrom);
                });
            });
        });
    });

    describe("#workspace", function() {
        it("is a chorus.models.Workspace when it has a workspace", function() {
            this.dataset.set({workspace: backboneFixtures.workspaceJson()});
            expect(this.dataset.workspace()).toBeA(chorus.models.Workspace);
        });

        it("memoizes", function() {
            this.dataset.set({workspace: backboneFixtures.workspaceJson()});
            expect(this.dataset.workspace()).toEqual(this.dataset.workspace());
        });

        it("is undefined when there is no workspace", function() {
            expect(this.dataset.workspace()).toBeUndefined();
        });
    });

    describe("#workspacesAssociated", function() {
        context("when there are workspaces associated", function() {
            beforeEach(function() {
                this.dataset = backboneFixtures.dataset({associatedWorkspaces: [
                    {id: "43", name: "working_hard"},
                    {id: "54", name: "hardly_working"}
                ]
                });

            });
            it("returns a workspace set with the right data", function() {
                var workspaces = this.dataset.workspacesAssociated();
                expect(workspaces).toBeA(chorus.collections.WorkspaceSet);
                expect(workspaces.length).toBe(2);
                expect(workspaces.at(0).get("id")).toBe("43");
                expect(workspaces.at(1).get("id")).toBe("54");
                expect(workspaces.at(0).get("name")).toBe("working_hard");
                expect(workspaces.at(1).get("name")).toBe("hardly_working");
            });
        });

        context("when there are NOT workspaces associated", function() {
            beforeEach(function() {
                this.dataset.unset("associatedWorkspaces");
                delete this.dataset._workspaceAssociated;
            });
            it("returns an empty workspaceSet", function() {
                var workspaces = this.dataset.workspacesAssociated();
                expect(workspaces.length).toBe(0);
            });
        });

        describe("when the associatedWorkspaces attribute is changed", function() {
            beforeEach(function() {
                this.dataset.unset("associatedWorkspaces");
                delete this.dataset._workspaceAssociated;
                this.oldWorkspaces = this.dataset.workspacesAssociated();
                expect(this.oldWorkspaces.length).toBe(0);

                this.dataset.set({associatedWorkspaces: [
                    {id: "43", name: "working_hard"},
                    {id: "54", name: "hardly_working"}
                ]
                });
            });

            it("is invalidated", function() {
                expect(this.dataset.workspacesAssociated()).not.toEqual(this.oldWorkspaces);
                expect(this.dataset.workspacesAssociated().length).toBe(2);
            });
        });
    });

    describe("#tableauWorkbooks", function() {
        beforeEach(function() {
            this.dataset = backboneFixtures.dataset({tableauWorkbooks: [
                {id: "100000", name: "first" },
                {id: "100001", name: "second" }
            ]
            });
        });
        context("when there are workbooks associated", function() {
            it("returns a workspace set with the right data", function() {
                var workbooks = this.dataset.tableauWorkbooks();
                expect(workbooks).toBeA(chorus.collections.TableauWorkbookSet);
                expect(workbooks.length).toBe(2);
                expect(workbooks.at(0).get("id")).toBe("100000");
                expect(workbooks.at(1).get("id")).toBe("100001");
                expect(workbooks.at(0).get("name")).toBe("first");
                expect(workbooks.at(1).get("name")).toBe("second");
            });
        });

        context("when there are no workbooks associated", function () {
            beforeEach(function () {
                this.dataset.unset("tableauWorkbooks");
                delete this.dataset._tableauWorkbooks;
            });
            it("returns an empty workspace set", function() {
                var workbooks = this.dataset.tableauWorkbooks();
                expect(workbooks.length).toBe(0);
            });
        });
        describe("when the tableauWorkbooks attribute is changed", function() {
            beforeEach(function() {
                this.dataset.unset("tableauWorkbooks");
                delete this.dataset._tableauWorkbooks;
                this.oldWorkbooks = this.dataset.tableauWorkbooks();
                expect(this.oldWorkbooks.length).toBe(0);

                this.dataset.set({tableauWorkbooks: [
                    {id: "43", name: "working_hard"},
                    {id: "54", name: "hardly_working"}
                ]
                });
            });

            it("is invalidated", function() {
                expect(this.dataset.tableauWorkbooks()).not.toEqual(this.oldWorkbooks);
                expect(this.dataset.tableauWorkbooks().length).toBe(2);
            });
        });
    });

    describe("#setDatasetNumber", function() {
        beforeEach(function() {
            this.dataset.setDatasetNumber(4);
        });

        it("sets the datasetNumber", function() {
            expect(this.dataset.datasetNumber).toBe(4);
        });

        it("sets the aliasedName", function() {
            expect(this.dataset.aliasedName).toBe('d');
        });
    });

    describe("#clearDatasetNumber", function() {
        beforeEach(function() {
            this.dataset.setDatasetNumber(4);
            this.dataset.clearDatasetNumber();
        });

        it("unsets the datasetNumber", function() {
            expect(this.dataset.datasetNumber).toBeUndefined();
        });

        it("unsets the aliasedName", function() {
            expect(this.dataset.aliasedName).toBeUndefined();
        });
    });

    describe("#isDeleteable", function() {
        it("is true when the tabular data is a source table", function() {
            expect(backboneFixtures.workspaceDataset.sourceTable().isDeleteable()).toBeTruthy();
        });

        it("is true when the tabular data is a source view", function() {
            expect(backboneFixtures.workspaceDataset.sourceView().isDeleteable()).toBeTruthy();
        });

        it("is true when the tabular data is a chorus view", function() {
            expect(backboneFixtures.workspaceDataset.chorusView().isDeleteable()).toBeTruthy();
        });

        it("is false otherwise", function() {
            expect(backboneFixtures.workspaceDataset.datasetTable().isDeleteable()).toBeFalsy();
        });
    });

    describe("#makeBoxplotTask", function() {
        beforeEach(function() {
            this.task = this.dataset.makeBoxplotTask({
                xAxis: "dog_breed",
                yAxis: "blindness_rate"
            });
        });

        it("returns a BoxplotTask model", function() {
            expect(this.task).toBeA(chorus.models.BoxplotTask);
        });

        it("has the dataset", function() {
            expect(this.task.dataset).toBe(this.dataset);
        });
    });

    describe("#makeHistogramTask", function() {
        beforeEach(function() {
            this.task = this.dataset.makeHistogramTask({
                bins: 5,
                xAxis: "blindness_rate"
            });
        });

        it("returns a HistogramTask model", function() {
            expect(this.task).toBeA(chorus.models.HistogramTask);
        });

        it("has the given number of bins and y axis", function() {
            expect(this.task.get("bins")).toBe(5);
            expect(this.task.get("xAxis")).toBe("blindness_rate");
        });

        it("has the dataset", function() {
            expect(this.task.dataset).toBe(this.dataset);
        });
    });

    describe("#makeHeatmapTask", function() {
        beforeEach(function() {
            this.task = this.dataset.makeHeatmapTask({
                xBins: 5,
                yBins: 6,
                xAxis: "dog_breed",
                yAxis: "blindness_rate"
            });
        });

        it("returns a HeatmapTask model", function() {
            expect(this.task).toBeA(chorus.models.HeatmapTask);
        });

        it("has the given number of bins and y axis", function() {
            expect(this.task.get("xBins")).toBe(5);
            expect(this.task.get("yBins")).toBe(6);
            expect(this.task.get("xAxis")).toBe("dog_breed");
            expect(this.task.get("yAxis")).toBe("blindness_rate");
        });

        it("has the dataset", function() {
            expect(this.task.dataset).toBe(this.dataset);
        });
    });

    describe("#makeFrequencyTask", function() {
        beforeEach(function() {
            this.task = this.dataset.makeFrequencyTask({
                yAxis: "blindness_rate",
                bins: "12"
            });
        });

        it("returns a FrequencyTask model", function() {
            expect(this.task).toBeA(chorus.models.FrequencyTask);
        });

        it("has the given y axis", function() {
            expect(this.task.get("yAxis")).toBe("blindness_rate");
        });

        it("has the dataset and bins", function() {
            expect(this.task.dataset).toBe(this.dataset);
            expect(this.task.get("bins")).toBe("12");
        });
    });

    describe("#makeTimeseriesTask", function() {
        beforeEach(function() {
            this.task = this.dataset.makeTimeseriesTask({
                xAxis: "years",
                yAxis: "height_in_inches",
                aggregation: "sum",
                timeInterval: "minute",
                timeType: "datetime"
            });
        });

        it("returns a TimeseriesTask model", function() {
            expect(this.task).toBeA(chorus.models.TimeseriesTask);
        });

        it("has the given x axis", function() {
            expect(this.task.get("xAxis")).toBe("years");
            expect(this.task.get("aggregation")).toBe("sum");
            expect(this.task.get("timeInterval")).toBe("minute");
        });

        it("has the given y axis", function() {
            expect(this.task.get("yAxis")).toBe("height_in_inches");
        });

        it("has the dataset", function() {
            expect(this.task.dataset).toBe(this.dataset);
        });

        it("has the right timeType", function() {
            expect(this.task.get("timeType")).toBe('datetime');
        });
    });

    describe("#deriveTableauWorkbook", function() {
        it("Creates a TableauWorkbook from the dataset", function() {
            var workbook = this.dataset.deriveTableauWorkbook();
            expect(workbook).toBeA(chorus.models.TableauWorkbook);
            expect(workbook.get('dataset')).toEqual(this.dataset);
        });
    });

    describe("#asDataset", function() {
        it("converts the object to a dataset", function() {
            var dataset = this.dataset.asWorkspaceDataset();
            expect(dataset).toBeA(chorus.models.WorkspaceDataset);
            expect(dataset.attributes).toEqual(this.dataset.attributes);
        });
    });

    describe("#supportsAnalyze", function() {
        var dataset;
        
        it("returns true for a sandbox table", function() {
            dataset = backboneFixtures.workspaceDataset.datasetTable();
            expect(dataset.supportsAnalyze()).toBeTruthy();
        });

        it("returns true for a source table", function() {
            dataset = backboneFixtures.dataset();
            expect(dataset.supportsAnalyze()).toBeTruthy();
        });

        it("returns true for a pg table", function () {
            dataset = backboneFixtures.pgDataset();
            expect(dataset.supportsAnalyze()).toBeTruthy();
        });


        it("returns false for views", function() {
            dataset = backboneFixtures.workspaceDataset.datasetView();
            expect(dataset.supportsAnalyze()).toBeFalsy();
        });

        it("returns false for chorus views", function() {
            dataset = backboneFixtures.workspaceDataset.chorusView();
            expect(dataset.supportsAnalyze()).toBeFalsy();
        });

        it('returns false when the dataset is not pg or gp', function(){
            dataset = backboneFixtures.oracleDataset();
            expect(dataset.supportsAnalyze()).toBeFalsy();
        });
    });

    describe("#hasImport", function() {
        it("is false if there are no loaded imports", function() {
            expect(this.dataset.getImports()).toBeFalsy();
            expect(this.dataset.hasImport()).toBeFalsy();
        });

        it("is true if there are imports", function() {
            var importDataset = backboneFixtures.workspaceDataset.datasetTable();
            importDataset.getImports().add(backboneFixtures.workspaceImportSet().models);
            expect(importDataset.hasImport()).toBeTruthy();
        });
    });

    describe("#canExport", function() {
        var inheritedModelClass = chorus.models.Dataset.extend({
            canBeImportSource: function() {
                return true;
            }
        });

        var dataset;
        beforeEach(function() {
            dataset = new inheritedModelClass();
            dataset.set({
                workspace: backboneFixtures.workspace(),
                schema: backboneFixtures.schema(),
                hasCredentials: true
            });
            dataset.importConfiguration = false;
        });

        it("shouldn't export when workspace cannot be updated", function() {
            spyOn(dataset.workspace(), "canUpdate").andReturn(false);
            expect(dataset.canExport()).toBeFalsy();
        });

        it("shouldn't export when no credentials", function() {
            dataset.set({ hasCredentials: false });
            expect(dataset.canExport()).toBeFalsy();
        });

        it("shouldn't export when it can't be import source", function() {
            spyOn(dataset, 'canBeImportSource').andReturn(false);
            expect(dataset.canExport()).toBeFalsy();
        });

        it("exports when all are ok", function() {
            spyOn(dataset.workspace(), "canUpdate").andReturn(true);
            expect(dataset.canExport()).toBeTruthy();
        });
    });

    describe("#workspaceArchived", function() {
        beforeEach(function() {
            this.dataset._workspace = backboneFixtures.workspace();
        });

        it("returns false for no workspace", function() {
            this.dataset._workspace = undefined;
            expect(this.dataset.workspaceArchived()).toBeFalsy();
        });

        it("returns false for active workspace", function() {
            expect(this.dataset.workspaceArchived()).toBeFalsy();
        });

        it("returns true for archived workspace", function() {
            this.dataset.workspace().set({ archivedAt: "2012-12-12" });
            expect(this.dataset.workspaceArchived()).toBeTruthy();
        });
    });

    describe("#canAnalyze", function() {
        describe("for a gpdb table", function () {
            it("returns true when user has credentials, object type is table, the workspace is not archived", function() {
                this.dataset.set({ hasCredentials: true, objectType: "TABLE" });
                expect(this.dataset.canAnalyze()).toBeTruthy();
            });

            it("returns false when the user has no credentials", function() {
                this.dataset.set({ hasCredentials: false, objectType: "TABLE" });
                expect(this.dataset.canAnalyze()).toBeFalsy();
            });

            it("returns false when the workspace is archived", function() {
                this.dataset.set({ hasCredentials: true, objectType: "TABLE" });
                this.dataset._workspace = backboneFixtures.workspace({ archivedAt: "2012-12-12"});
                expect(this.dataset.canAnalyze()).toBeFalsy();
            });

            it("returns false when the dataset is an external table", function(){
                spyOn(this.dataset, "isExternal").andReturn(true);
                expect(this.dataset.canAnalyze()).toBeFalsy();
            });
        });

        describe("for a pg table", function () {
            beforeEach(function () {
                this.dataset = backboneFixtures.pgDataset();
            });

            it("returns true when user has credentials, object type is table, the workspace is not archived", function() {
                this.dataset.set({ hasCredentials: true, objectType: "TABLE" });
                expect(this.dataset.canAnalyze()).toBeTruthy();
            });
        });


        it("returns false for dataset that is not a gpdb/pg table", function() {
            this.dataset.set({ hasCredentials: true, objectType: "RUBBISH" });
            expect(this.dataset.canAnalyze()).toBeFalsy();
        });


    });

    describe("#isExternal", function() {
        beforeEach(function() {
            this.dataset.statistics().fetch();
            this.dataset.statistics().set("datasetId", this.dataset.id);
            this.server.completeFetchFor(this.dataset.statistics());
        });

        it('returns true if the table is external', function() {
            this.dataset.statistics().set("objectType", "EXT_TABLE");
            expect(this.dataset.isExternal()).toBe(true);
        });

        it('returns true it the table is some other kind of external table', function(){
            this.dataset.statistics().set("objectType", "JOES_EXT_TABLE");
            expect(this.dataset.isExternal()).toBe(true);
        });

        it('returns false if the table is any other kind of table', function(){
            expect(this.dataset.isExternal()).toBe(false);
        });
    });

    describe("Analyze", function() {
        beforeEach(function() {
            this.dataset = backboneFixtures.dataset({
                id: 543
            });
        });

        it("returns a DatasetAnalyze model", function() {
            expect(this.dataset.analyze()).toBeA(chorus.models.DatasetAnalyze);
        });

        it("memoizes", function() {
            expect(this.dataset.analyze()).toBe(this.dataset.analyze());
        });

        it("returns an analyze model with the right url", function() {
            expect(this.dataset.analyze().url()).toBe("/tables/543/analyze");
        });
    });

    afterEach(function() {
        this.dataset.destroy();
    });
    
});
