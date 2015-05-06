describe("chorus.dialogs.DataSourceEdit", function() {
    beforeEach(function() {
        loadConfig();
        this.dataSource = backboneFixtures.gpdbDataSource({
            name: "pasta",
            host: "greenplum",
            port: "8555",
            description: "it is a food name",
            dbName: "postgres"
        });
        this.dialog = new chorus.dialogs.DataSourceEdit({ model: this.dataSource });
    });

    it("should make a copy of the source model", function() {
        expect(this.dialog.model).not.toBe(this.dataSource);
        expect(this.dialog.model.attributes).toEqual(this.dataSource.attributes);
    });

    describe("#render", function() {
        function itBehavesLikeADbDataSource() {
            it("Field called 'name' should be editable and pre populated", function() {
                expect(this.dialog.$("input[name=name]").val()).toBe(this.dialog.model.name());
                expect(this.dialog.$("input[name=name]").prop("disabled")).toBeFalsy();
            });

            it("Field called 'description' should be editable and pre populated", function() {
                expect(this.dialog.$("textarea[name=description]").val()).toBe(this.dialog.model.get("description"));
                expect(this.dialog.$("textarea[name=description]").prop("disabled")).toBeFalsy();
            });

            it("Field called 'host' should be editable and pre populated", function() {
                expect(this.dialog.$("input[name=host]").val()).toBe(this.dialog.model.get("host"));
                expect(this.dialog.$("input[name=host]").prop("disabled")).toBeFalsy();
            });

            it("Field called 'port' should be editable and pre populated", function() {
                expect(this.dialog.$("input[name=port]").val()).toBe(this.dialog.model.get("port"));
                expect(this.dialog.$("input[name=port]").prop("disabled")).toBeFalsy();
            });

            it("has a 'database' field that is pre-populated", function() {
                expect(this.dialog.$("input[name='dbName']").val()).toBe(this.dialog.model.get("dbName"));
                expect(this.dialog.$("label[name='dbName']").text()).toMatchTranslation("data_sources.dialog.database_name");
                expect(this.dialog.$("input[name='dbName']").prop("disabled")).toBeFalsy();
            });
        }

        describe('when editing a greenplum data source', function() {
            beforeEach(function() {
                this.dialog.model.set({ entityType: "gpdb_data_source", ssl: true });
                this.dialog.render();
            });

            itBehavesLikeADbDataSource();

            it("has a 'ssl' field that is pre-populated", function () {
                expect(this.dialog.$("input[name='ssl']").prop('checked')).toBe(this.dialog.model.get('ssl'));
                expect(this.dialog.$("input[name='ssl']").prop("disabled")).toBeFalsy();
            });
        });

        describe('when editing a postgres data source', function() {
            beforeEach(function() {
                this.dialog.model.set({
                    name: "pgsql",
                    host: "pg-host",
                    entityType: "pg_data_source",
                    ssl: true
                });
                this.dialog.render();
            });

            itBehavesLikeADbDataSource();

            it("has a 'ssl' field that is pre-populated", function () {
                expect(this.dialog.$("input[name='ssl']").prop('checked')).toBe(this.dialog.model.get('ssl'));
                expect(this.dialog.$("input[name='ssl']").prop("disabled")).toBeFalsy();
            });
        });

        describe('when editing a oracle data source', function() {
            beforeEach(function() {
                this.dialog.model.set({
                    entityType: "oracle_data_source",
                    name: "orcl",
                    host: "oracle",
                    port: "1521",
                    description: "it is a foobar",
                    dbName: "oracle-db121"
                });
                this.dialog.render();
            });

            itBehavesLikeADbDataSource();
        });

        describe('when editing a hdfs data source', function() {
            beforeEach(function() {
                this.dataSource = backboneFixtures.hdfsDataSource({
                    username: 'user',
                    groupList: 'hadoop',
                    jobTrackerHost: 'job-tracker-host.emc.com',
                    jobTrackerPort: "5000",
                    hdfsVersion: "Pivotal HD 2",
                    highAvailability: "true"
                });
                this.dialog = new chorus.dialogs.DataSourceEdit({ model: this.dataSource });
                this.dialog.render();
            });

            it("has a pre-populated and enabled 'name' field", function() {
                expect(this.dialog.$("input[name=name]").val()).toBe(this.dataSource.get('name'));
                expect(this.dialog.$("input[name=name]").prop("disabled")).toBeFalsy();
            });

            it("has a pre-populated and enabled 'description' field", function() {
                expect(this.dialog.$("textarea[name=description]").val()).toBe(this.dataSource.get('description'));
                expect(this.dialog.$("textarea[name=description]").prop("disabled")).toBeFalsy();
            });

            it("has a pre-populated and enabled 'host' field", function() {
                expect(this.dialog.$("input[name=host]").val()).toBe(this.dataSource.get('host'));
                expect(this.dialog.$("input[name=host]").prop("disabled")).toBeFalsy();
            });

            it("has a pre-populated and enabled 'port' field", function() {
                expect(this.dialog.$("input[name=port]").val()).toBe(this.dataSource.get('port').toString());
                expect(this.dialog.$("input[name=port]").prop("disabled")).toBeFalsy();
            });

            it("has a pre-populated and enabled 'HDFS account' field", function() {
                expect(this.dialog.$("input[name=username]").val()).toBe("user");
                expect(this.dialog.$("input[name=username]").prop("disabled")).toBeFalsy();
            });

            it("has a pre-populated and enabled 'group list' field", function() {
                expect(this.dialog.$("input[name=groupList]").val()).toBe("hadoop");
                expect(this.dialog.$("input[name=groupList]").prop("disabled")).toBeFalsy();
            });

            it("has a pre-populated and enabled 'job tracker host' field", function() {
                expect(this.dialog.$("input[name=jobTrackerHost]").val()).toBe(this.dataSource.get('jobTrackerHost'));
                expect(this.dialog.$("input[name=jobTrackerHost]").prop("disabled")).toBeFalsy();
            });

            it("has a pre-populated and enabled 'job tracker port' field", function() {
                expect(this.dialog.$("input[name=jobTrackerPort]").val()).toBe(this.dataSource.get('jobTrackerPort'));
                expect(this.dialog.$("input[name=jobTrackerPort]").prop("disabled")).toBeFalsy();
            });

            it("has a pre-populated and enabled 'hdfs version' selector", function() {
                expect(this.dialog.$("select[name=hdfsVersion]").val()).toBe(this.dataSource.get('hdfsVersion'));
                expect(this.dialog.$("select[name=hdfsVersion]").prop("disabled")).toBeFalsy();
            });

            it("has a pre-populated high availability checkbox", function () {
                expect(this.dialog.$("input[name=high_availability]").prop('checked')).toBeTruthy();
            });

            describe("the connection parameters link", function () {
                beforeEach(function () {
                    this.modalSpy = stubModals();
                    this.dialog.model.set('connectionParameters', [
                        {key: 'dfs.data.dir', value: '/foo/bar'},
                        {key: 'mapred.queue.names', value: 'thingie, zippity, original'},
                        {key: 'mapred.acls.enabled', value: 'true'}
                    ]);

                    this.dialog.render();
                });

                itBehavesLike.aDialogLauncher('a.connection_parameters', chorus.dialogs.HdfsConnectionParameters);

                it("show a count of configured parameters", function () {
                    expect(this.dialog.$('a.connection_parameters')).toContainTranslation('data_sources.dialog.connection_parameters', {count: 3});
                });

                it("updates the count when the model's connectionParameters are updated'", function () {
                    this.dialog.model.set('connectionParameters', []);
                    expect(this.dialog.$('a.connection_parameters')).toContainTranslation('data_sources.dialog.connection_parameters', {count: 0});
                });

            });

            describe("enabling High Availability", function () {
                beforeEach(function () {
                    this.dialog.$("input[name=high_availability]").prop('checked', true).trigger('change');
                });

                it("disables the name nome port field", function () {
                    expect(this.dialog.$("input[name=port]")).toBeDisabled();
                    expect(this.dialog.$("label[name=port]")).not.toHaveClass('required');
                    expect(this.dialog.$("input[name=port]").val()).toBe('');
                });

                it("labels 'host' correctly ", function() {
                    expect(this.dialog.$("label[name=host]").text()).toMatchTranslation("data_sources.dialog.name_service");
                });
            });
        });

        describe('when editing a gnip data source', function() {
            beforeEach(function() {
                this.dataSource = backboneFixtures.gnipDataSource({
                    name: "myGnip",
                    username: "me@fun.com",
                    streamUrl: "https://some.thing.com",
                    description: "a gnip data source"
                });
                this.dialog = new chorus.dialogs.DataSourceEdit({ model: this.dataSource });

                this.dialog.model = new chorus.models.GnipDataSource(this.dialog.model.attributes);
                this.dialog.render();
            });

            it("has a pre-populated and enabled 'name' field", function() {
                expect(this.dialog.$("input[name=name]").val()).toBe("myGnip");
                expect(this.dialog.$("input[name=name]").prop("disabled")).toBeFalsy();
            });

            it("has a pre-populated and enabled 'description' field", function() {
                expect(this.dialog.$("textarea[name=description]").val()).toBe("a gnip data source");
                expect(this.dialog.$("textarea[name=description]").prop("disabled")).toBeFalsy();
            });

            it("has a pre-populated and enabled 'streamUrl' field", function() {
                expect(this.dialog.$("input[name=streamUrl]").val()).toBe("https://some.thing.com");
                expect(this.dialog.$("input[name=streamUrl]").prop("disabled")).toBeFalsy();
            });

            it("has a pre-populated and enabled 'username' field", function() {
                expect(this.dialog.$("input[name=username]").val()).toBe("me@fun.com");
                expect(this.dialog.$("input[name=username]").prop("disabled")).toBeFalsy();
            });

            it("shows an empty 'password' field", function() {
                expect(this.dialog.$("input[name=password]").val()).toBe("");
                expect(this.dialog.$("input[name=password]").prop("disabled")).toBeFalsy();
            });

            it("does not autocomplete password inputs", function(){
                expect(this.dialog.$("input[type='password']")).toHaveAttr("autocomplete", "off");
            });
        });

        describe('when editing a jdbc data source', function() {
            beforeEach(function() {
                this.dialog.model.set({
                    entityType: "jdbc_data_source",
                    name: "jdbc source",
                    host: "jdbc:teradata://hostname/dbc",
                    description: "it is a foobar"
                });
                this.dialog.render();
            });

            it("Field called 'name' should be editable and pre populated", function() {
                expect(this.dialog.$("input[name=name]").val()).toBe("jdbc source");
                expect(this.dialog.$("input[name=name]").prop("disabled")).toBeFalsy();
            });

            it("Field called 'description' should be editable and pre populated", function() {
                expect(this.dialog.$("textarea[name=description]").val()).toBe("it is a foobar");
                expect(this.dialog.$("textarea[name=description]").prop("disabled")).toBeFalsy();
            });

            it("Field called 'JDBC Url' should be editable and pre populated", function() {
                expect(this.dialog.$("label[name=host]").text()).toMatchTranslation("data_sources.dialog.jdbc_url");
                expect(this.dialog.$("input[name=host]").val()).toBe("jdbc:teradata://hostname/dbc");
                expect(this.dialog.$("input[name=host]").prop("disabled")).toBeFalsy();
            });
        });
    });

    describe("saving", function() {
        beforeEach(function() {
            this.dialog.model.set({ entity_type: "gpdb_data_source", ssl: true });
            this.dialog.render();

            spyOn(this.dialog, "closeModal");
            spyOn(chorus, "toast");

            this.dialog.$("input[name=name]").val(" test1 ");
            this.dialog.$("input[name=port]").val("8555");
            this.dialog.$("input[name=host]").val(" testhost ");
            this.dialog.$("input[name=dbName]").val(" not_postgres ");
            this.dialog.$("textarea[name=description]").val("  data source   ");
        });

        it("puts the button in 'loading' mode", function() {
            spyOn(this.dialog.model, "save");
            this.dialog.$("button[type=submit]").submit();
            expect(this.dialog.$("button.submit").isLoading()).toBeTruthy();
        });

        it("should call the save method", function() {
            spyOn(this.dialog.model, "save");
            this.dialog.$("button[type=submit]").submit();
            expect(this.dialog.model.save).toHaveBeenCalled();
        });

        it("should call save with the right parameters", function() {
            spyOn(this.dialog.model, "save").andCallThrough();
            this.dialog.$("button[type=submit]").submit();

            var saveParams = this.dialog.model.save.lastCall().args[0];
            expect(saveParams.name).toBe("test1");
            expect(saveParams.port).toBe("8555");
            expect(saveParams.host).toBe("testhost");
            expect(saveParams.description).toBe("data source");
            expect(saveParams.dbName).toBe("not_postgres");
            expect(saveParams.ssl).toBe(true);
        });

        it("changes the text on the upload button to 'saving'", function() {
            spyOn(this.dialog.model, "save");
            this.dialog.$("button[type=submit]").submit();
            expect(this.dialog.$("button.submit").text()).toMatchTranslation("data_sources.new_dialog.saving");
        });

        it("disables the cancel button", function() {
            spyOn(this.dialog.model, "save");
            this.dialog.$("button[type=submit]").submit();
            expect(this.dialog.$("button.cancel")).toBeDisabled();
        });

        context('with a hadoop data source', function() {
            beforeEach(function() {
                this.dialog.model = new chorus.models.HdfsDataSource();
                this.dialog.render();
                this.dialog.$("input[name=name]").val("test3");
                this.dialog.$("input[name=port]").val("8557");
                this.dialog.$("input[name=host]").val("testhost3");
                this.dialog.$("input[name=username]").val("username");
                this.dialog.$("input[name=groupList]").val("groupList");
                this.dialog.$("input[name=jobTrackerHost]").val("whatever");
                this.dialog.$("input[name=jobTrackerPort]").val("3333");
                this.dialog.$("select[name=hdfsVersion]").val("Pivotal HD 2");
                this.dialog.$("input[name=high_availability]").prop("checked", "checked");
                this.dialog.$("button[type=submit]").submit();
            });

            it("updates the model", function() {
                expect(this.dialog.model.get("name")).toBe("test3");
                expect(this.dialog.model.get("port")).toBe("8557");
                expect(this.dialog.model.get("host")).toBe("testhost3");
                expect(this.dialog.model.get("username")).toBe("username");
                expect(this.dialog.model.get("groupList")).toBe("groupList");
                expect(this.dialog.model.has("dbName")).toBeFalsy();
                expect(this.dialog.model.get("jobTrackerHost")).toBe("whatever");
                expect(this.dialog.model.get("jobTrackerPort")).toBe("3333");
                expect(this.dialog.model.get("hdfsVersion")).toBe("Pivotal HD 2");
                expect(this.dialog.model.get("highAvailability")).toBe(true);
            });
        });

        context('with a jdbc data source', function() {
            beforeEach(function() {
                this.dialog.model = backboneFixtures.jdbcDataSource();
                this.dialog.render();
                this.dialog.$("input[name=name]").val("jdbcname");
                this.dialog.$("input[name=host]").val("jdbchost");
                this.dialog.$("button[type=submit]").submit();
            });

            it("updates the model", function() {
                expect(this.dialog.model.get("name")).toBe("jdbcname");
                expect(this.dialog.model.get("host")).toBe("jdbchost");
            });
        });

        context('with a gnip data source', function() {
            beforeEach(function() {
                this.dialog.model = new chorus.models.GnipDataSource();
                this.dialog.render();
                this.dialog.$("input[name=name]").val("test3");
                this.dialog.$("input[name=streamUrl]").val("https://www.test.me");
                this.dialog.$("input[name=username]").val("username");
                this.dialog.$("textarea[name=description]").val("some description");
                this.dialog.$("input[name=password]").val("newpass");
                this.dialog.$("button[type=submit]").submit();
            });

            it("updates the model", function() {
                expect(this.dialog.model.get("name")).toBe("test3");
                expect(this.dialog.model.get("streamUrl")).toBe("https://www.test.me");
                expect(this.dialog.model.get("username")).toBe("username");
                expect(this.dialog.model.get("description")).toBe("some description");
                expect(this.dialog.model.get("password")).toBe("newpass");
            });
        });

        context("when save completes", function() {
            beforeEach(function() {
                this.dialog.$("button.submit").submit();
                spyOnEvent(this.dataSource, "change");
                this.dialog.model.trigger("saved");
            });

            it("displays toast message", function() {
                expect(chorus.toast).toHaveBeenCalled();
            });

            it("closes the dialog", function() {
                expect(this.dialog.closeModal).toHaveBeenCalled();
            });

            it("triggers change on the source model", function() {
                expect("change").toHaveBeenTriggeredOn(this.dataSource);
            });
        });

        function itRecoversFromError() {
            it("takes the button out of 'loading' mode", function() {
                expect(this.dialog.$("button.submit").isLoading()).toBeFalsy();
            });

            it("sets the button text back to 'Uploading'", function() {
                expect(this.dialog.$("button.submit").text()).toMatchTranslation("data_sources.edit_dialog.save");
            });
        }

        context("when the upload gives a server error", function() {
            beforeEach(function() {
                this.dialog.model.set({serverErrors: { fields: { a: { BLANK: {} } } }});
                this.dialog.model.trigger("saveFailed");
            });

            it("display the correct error", function() {
                expect(this.dialog.$(".errors")).toContainText("A can't be blank");
            });

            itRecoversFromError();
        });

        context("when the validation fails", function() {
            beforeEach(function() {
                this.dialog.model.trigger("validationFailed");
            });

            itRecoversFromError();
        });
    });
    
    afterEach(function() {
        this.dataSource= "";
        this.dialog.teardown();
    });
    
});
