describe("chorus.dialogs.DataSourcesNew", function() {
    beforeEach(function() {
        loadConfig();
        this.selectMenuStub = stubSelectMenu();
        spyOn(chorus, 'styleSelect').andCallThrough();
        spyOn(chorus.dialogs.DataSourcesNew.prototype, "createDataSource").andCallThrough();
        this.dialog = new chorus.dialogs.DataSourcesNew();
        $('#jasmine_content').append(this.dialog.el);
        this.dialog.render();
    });

    it("styles the select", function() {
        expect(chorus.styleSelect).toHaveBeenCalled();
    });

    it("shows the icon", function() {
        this.dialog.$(".ui-selectmenu-button .ui-button").click();
        expect(this.selectMenuStub.find(".register_existing_greenplum")).toExist();
        expect(this.selectMenuStub.find(".register_existing_hdfs")).toExist();
    });

    it("shows data source 'helpful' information", function() {
        expect(this.dialog.$(".register_existing_greenplum .form_info_block .message").text()).toMatchTranslation("data_sources.new_dialog.register_existing_greenplum_help_text");
        expect(this.dialog.$(".register_existing_hdfs .form_info_block .message").text()).toMatchTranslation("data_sources.new_dialog.register_existing_hdfs_help_text");
    });

    it("does not autocomplete password inputs", function(){
        var passwordFields = this.dialog.$("input[type=password]");
        _.each(passwordFields, function(field) {
            expect($(field)).toHaveAttr("autocomplete", "off");
        });
    });

    describe("immediately", function() {
        beforeEach(function() {
            chorus.models.Config.instance().set({oracleConfigured: false, gnipConfigured: false});
            this.dialog.render();
        });
        it("shows the label", function() {
            expect(this.dialog.$("label[for=data_sources]").text()).toMatchTranslation("datasource.type");
        });

        it("has select box for 'Greenplum Database', 'HDFS Cluster', 'Hawq', and 'JDBC'", function() {
            expect(this.dialog.$("select.data_sources option").length).toBe(7);
            expect(this.dialog.$("select.data_sources option").eq(1).text()).toMatchTranslation("datasource.greenplum");
            expect(this.dialog.$("select.data_sources option").eq(2).text()).toMatchTranslation("datasource.postgres");
            expect(this.dialog.$("select.data_sources option").eq(3).text()).toMatchTranslation("datasource.hdfs");
            expect(this.dialog.$("select.data_sources option").eq(4).text()).toMatchTranslation("datasource.hawq");
            expect(this.dialog.$("select.data_sources option").eq(5).text()).toMatchTranslation("datasource.jdbc");
            expect(this.dialog.$("select.data_sources option").eq(6).text()).toMatchTranslation("datasource.jdbc_hive");

        });

        it("starts with no select box selected", function() {
            expect(this.dialog.$(".data_sources option:selected").text()).toMatchTranslation("selectbox.select_one");
        });

        it("starts with the submit button disabled", function() {
            expect(this.dialog.$("button.submit")).toBeDisabled();
        });

        describe("selecting the 'Greenplum Database' option", function() {
            beforeEach(function() {
                this.dialog.$(".data_sources").val("register_existing_greenplum").change();
            });

            it("un-collapses the 'register an existing data source'", function() {
                expect(this.dialog.$(".data_sources_form").not(".collapsed").length).toBe(1);
                expect(this.dialog.$(".register_existing_greenplum")).not.toHaveClass("collapsed");
            });

            it("enables the submit button", function() {
                expect(this.dialog.$("button.submit")).toBeEnabled();
            });

            it("uses 'postgres' as the default database name", function() {
                expect(this.dialog.$(".register_existing_greenplum input[name=dbName]").val()).toBe("postgres");
            });

            describe("filling out the form", function() {
                beforeEach(function() {
                    this.dialog.$(".register_existing_greenplum input[name=name]").val("DataSource_Name");
                    this.dialog.$(".register_existing_greenplum textarea[name=description]").val("DataSource Description");
                    this.dialog.$(".register_existing_greenplum input[name=host]").val("foo.bar");
                    this.dialog.$(".register_existing_greenplum input[name=port]").val("1234");
                    this.dialog.$(".register_existing_greenplum input[name=dbUsername]").val("user");
                    this.dialog.$(".register_existing_greenplum input[name=dbPassword]").val("my_password");
                    this.dialog.$(".register_existing_greenplum input[name=dbName]").val("foo");
                    this.dialog.$(".register_existing_greenplum input[name=ssl]").prop('checked', true);

                    this.dialog.$(".register_existing_greenplum input[name=name]").trigger("change");
                });

                it("gets the fieldValues", function() {
                    var values = this.dialog.fieldValues();
                    expect(values.name).toBe("DataSource_Name");
                    expect(values.description).toBe("DataSource Description");
                    expect(values.host).toBe("foo.bar");
                    expect(values.port).toBe("1234");
                    expect(values.dbUsername).toBe("user");
                    expect(values.dbPassword).toBe("my_password");
                    expect(values.dbName).toBe("foo");
                    expect(values.isHawq).toBeFalsy();
                    expect(values.ssl).toBeTruthy();
                });
            });

            context("changing to 'Select one' option", function() {
                beforeEach(function() {
                    this.dialog.$("select.data_sources").val("").change();
                });

                it("should hides all forms", function() {
                    expect(this.dialog.$(".data_sources_form")).toHaveClass("collapsed");
                });

                it("should disable the submit button", function() {
                    expect(this.dialog.$("button.submit")).toBeDisabled();
                });

            });
        });

        describe("selecting the 'PostgreSQL Database' option", function() {
            beforeEach(function() {
                this.dialog.$(".data_sources").val("register_existing_postgres").change();
            });

            it("un-collapses the 'register an existing data source'", function() {
                expect(this.dialog.$(".data_sources_form").not(".collapsed").length).toBe(1);
                expect(this.dialog.$(".register_existing_postgres")).not.toHaveClass("collapsed");
            });

            it("enables the submit button", function() {
                expect(this.dialog.$("button.submit")).toBeEnabled();
            });

            it("uses 'postgres' as the default database name", function() {
                expect(this.dialog.$(".register_existing_postgres input[name=dbName]").val()).toBe("postgres");
            });

            describe("filling out the form", function() {
                beforeEach(function() {
                    this.dialog.$(".register_existing_postgres input[name=name]").val("DataSource_Name");
                    this.dialog.$(".register_existing_postgres textarea[name=description]").val("DataSource Description");
                    this.dialog.$(".register_existing_postgres input[name=host]").val("foo.bar");
                    this.dialog.$(".register_existing_postgres input[name=port]").val("1234");
                    this.dialog.$(".register_existing_postgres input[name=dbUsername]").val("user");
                    this.dialog.$(".register_existing_postgres input[name=dbPassword]").val("my_password");
                    this.dialog.$(".register_existing_postgres input[name=dbName]").val("foo");
                    this.dialog.$(".register_existing_postgres input[name=ssl]").prop('checked', true);

                    this.dialog.$(".register_existing_postgres input[name=name]").trigger("change");
                });

                it("gets the fieldValues", function() {
                    var values = this.dialog.fieldValues();
                    expect(values.name).toBe("DataSource_Name");
                    expect(values.description).toBe("DataSource Description");
                    expect(values.host).toBe("foo.bar");
                    expect(values.port).toBe("1234");
                    expect(values.dbUsername).toBe("user");
                    expect(values.dbPassword).toBe("my_password");
                    expect(values.dbName).toBe("foo");
                    expect(values.isHawq).toBeFalsy();
                    expect(values.ssl).toBeTruthy();
                });
            });

            context("changing to 'Select one' option", function() {
                beforeEach(function() {
                    this.dialog.$("select.data_sources").val("").change();
                });

                it("should hides all forms", function() {
                    expect(this.dialog.$(".data_sources_form")).toHaveClass("collapsed");
                });

                it("should disable the submit button", function() {
                    expect(this.dialog.$("button.submit")).toBeDisabled();
                });

            });
        });

        describe("selecting the 'HAWQ' option", function() {
            beforeEach(function() {
                this.dialog.$(".data_sources").val("register_existing_hawq").change();
            });

            it("un-collapses the 'register an existing data source'", function() {
                expect(this.dialog.$(".data_sources_form").not(".collapsed").length).toBe(1);
                expect(this.dialog.$(".register_existing_greenplum")).not.toHaveClass("collapsed");
            });

            it("enables the submit button", function() {
                expect(this.dialog.$("button.submit")).toBeEnabled();
            });

            it("uses 'postgres' as the default database name", function() {
                expect(this.dialog.$(".register_existing_greenplum input[name=dbName]").val()).toBe("postgres");
            });

            describe("filling out the form", function() {
                beforeEach(function() {
                    this.dialog.$(".register_existing_greenplum input[name=name]").val("DataSource_Name");
                    this.dialog.$(".register_existing_greenplum textarea[name=description]").val("DataSource Description");
                    this.dialog.$(".register_existing_greenplum input[name=host]").val("foo.bar");
                    this.dialog.$(".register_existing_greenplum input[name=port]").val("1234");
                    this.dialog.$(".register_existing_greenplum input[name=dbUsername]").val("user");
                    this.dialog.$(".register_existing_greenplum input[name=dbPassword]").val("my_password");
                    this.dialog.$(".register_existing_greenplum input[name=dbName]").val("foo");

                    this.dialog.$(".register_existing_greenplum input[name=name]").trigger("change");
                });

                it("gets the fieldValues", function() {
                    var values = this.dialog.fieldValues();
                    expect(values.name).toBe("DataSource_Name");
                    expect(values.description).toBe("DataSource Description");
                    expect(values.host).toBe("foo.bar");
                    expect(values.port).toBe("1234");
                    expect(values.dbUsername).toBe("user");
                    expect(values.dbPassword).toBe("my_password");
                    expect(values.dbName).toBe("foo");
                    expect(values.isHawq).toBeTruthy();
                });
            });

            context("changing to 'Select one' option", function() {
                beforeEach(function() {
                    this.dialog.$("select.data_sources").val("").change();
                });

                it("should hides all forms", function() {
                    expect(this.dialog.$(".data_sources_form")).toHaveClass("collapsed");
                });

                it("should disable the submit button", function() {
                    expect(this.dialog.$("button.submit")).toBeDisabled();
                });
            });
        });

        describe("selecting the 'HDFS cluster' option", function() {
            beforeEach(function() {
                this.modalSpy = stubModals();
                this.dialog.$("select.data_sources").val("register_existing_hdfs").change();
            });

            itBehavesLike.aDialogLauncher('a.connection_parameters', chorus.dialogs.HdfsConnectionParameters);

            describe("the connection parameters link", function () {
                beforeEach(function () {
                    this.dialog.model.set('connectionParameters', [
                        {key: 'dfs.data.dir', value: '/foo/bar'},
                        {key: 'mapred.queue.names', value: 'thingie, zippity, original'},
                        {key: 'mapred.acls.enabled', value: 'true'}
                    ]);
                    this.dialog.render();
                });

                it("show a count of configured parameters", function () {
                    expect(this.dialog.$('a.connection_parameters')).toContainTranslation('data_sources.dialog.connection_parameters', {count: 3});
                });

                it("updates the count when the model's connectionParameters are updated'", function () {
                    this.dialog.model.set('connectionParameters', []);
                    expect(this.dialog.$('a.connection_parameters')).toContainTranslation('data_sources.dialog.connection_parameters', {count: 0});
                });

            });

            it("un-collapses the 'register a hadoop file system' form", function() {
                expect(this.dialog.$("div.data_sources_form").not(".collapsed").length).toBe(1);
                expect(this.dialog.$("div.register_existing_hdfs")).not.toHaveClass("collapsed");
            });

            it("enables the submit button", function() {
                expect(this.dialog.$("button.submit")).toBeEnabled();
            });

            describe("filling out the form", function() {
                beforeEach(function() {
                    this.form = this.dialog.$(".register_existing_hdfs");
                    this.form.find("input[name=name]").val("DataSource_Name");
                    this.form.find("textarea[name=description]").val("DataSource Description");
                    this.form.find("input[name=host]").val("foo.bar");
                    this.form.find("input[name=port]").val("1234");
                    this.form.find("input.username").val("user");
                    this.form.find("input.group_list").val("hadoop");
                    this.form.find("select[name=hdfsVersion]").val("Cloudera CDH4");
                    this.form.find("input[name=high_availability]").prop('checked', false);

                    this.form.find("input[name=name]").trigger("change");
                });

                it("labels 'host' correctly ", function() {
                    expect(this.dialog.$(".register_existing_hdfs label[name=host]").text()).toMatchTranslation("data_sources.dialog.hadoop_host");
                });

                it("#fieldValues returns the values", function() {
                    var values = this.dialog.fieldValues();
                    expect(values.name).toBe("DataSource_Name");
                    expect(values.description).toBe("DataSource Description");
                    expect(values.host).toBe("foo.bar");
                    expect(values.port).toBe("1234");
                    expect(values.username).toBe("user");
                    expect(values.groupList).toBe("hadoop");
                    expect(values.hdfsVersion).toBe("Cloudera CDH4");
                    expect(values.highAvailability).toBe(false);
                });

                it("#fieldValues includes 'shared'", function() {
                    var values = this.dialog.fieldValues();
                    expect(values.shared).toBe(true);
                });

                describe("enabling High Availability", function () {
                    beforeEach(function () {
                        this.form.find("input[name=high_availability]").prop('checked', true).trigger('change');
                    });

                    it("disables the name nome port field", function () {
                        expect(this.form.find("input[name=port]")).toBeDisabled();
                        expect(this.form.find("label[name=port]")).not.toHaveClass('required');
                        expect(this.form.find("input[name=port]").val()).toBe('');
                    });

                    it("#fieldValues returns the values", function() {
                        var values = this.dialog.fieldValues();
                        expect(values.highAvailability).toBe(true);
                    });

                    it("labels 'host' correctly ", function() {
                        expect(this.dialog.$(".register_existing_hdfs label[name=host]").text()).toMatchTranslation("data_sources.dialog.name_service");
                    });
                });
            });
        });

        describe("selecting the 'JDBC' option", function() {
            beforeEach(function() {
                this.dialog.$(".data_sources").val("register_existing_jdbc").change();
            });

            it("un-collapses the 'register an existing data source'", function() {
                expect(this.dialog.$(".data_sources_form").not(".collapsed").length).toBe(1);
                expect(this.dialog.$(".register_existing_jdbc")).not.toHaveClass("collapsed");
            });

            it("enables the submit button", function() {
                expect(this.dialog.$("button.submit")).toBeEnabled();
            });

            it("labels the host field JDBC Url", function() {
                expect(this.dialog.$(".register_existing_jdbc label[name=host]")).toContainTranslation("data_sources.dialog.jdbc_url");
            });

            describe("filling out the form", function() {
                beforeEach(function() {
                    this.dialog.$(".register_existing_jdbc input[name=name]").val("DataSource_Name");
                    this.dialog.$(".register_existing_jdbc textarea[name=description]").val("DataSource Description");
                    this.dialog.$(".register_existing_jdbc input[name=host]").val("foo.bar");
                    this.dialog.$(".register_existing_jdbc input[name=dbUsername]").val("user");
                    this.dialog.$(".register_existing_jdbc input[name=dbPassword]").val("my_password");

                    this.dialog.$(".register_existing_jdbc input[name=name]").trigger("change");
                });

                it("gets the fieldValues", function() {
                    var values = this.dialog.fieldValues();
                    expect(values.name).toBe("DataSource_Name");
                    expect(values.description).toBe("DataSource Description");
                    expect(values.host).toBe("foo.bar");
                    expect(values.dbUsername).toBe("user");
                    expect(values.dbPassword).toBe("my_password");
                });
            });

            context("changing to 'Select one' option", function() {
                beforeEach(function() {
                    this.dialog.$("select.data_sources").val("").change();
                });

                it("should hides all forms", function() {
                    expect(this.dialog.$(".data_sources_form")).toHaveClass("collapsed");
                });

                it("should disable the submit button", function() {
                    expect(this.dialog.$("button.submit")).toBeDisabled();
                });

            });
        });
    });

    context("when oracle is configured", function() {
        beforeEach(function() {
            chorus.models.Config.instance().set({oracleConfigured: true});
        });

        describe("selecting the 'Oracle Database' option", function() {
            beforeEach(function() {
                this.dialog.$(".data_sources").val("register_existing_oracle").change();
            });

            it("un-collapses the 'register an existing data source'", function() {
                expect(this.dialog.$(".data_sources_form").not(".collapsed").length).toBe(1);
                expect(this.dialog.$(".register_existing_oracle")).not.toHaveClass("collapsed");
            });

            it("enables the submit button", function() {
                expect(this.dialog.$("button.submit")).toBeEnabled();
            });

            it("uses a blank name as the default database name", function() {
                expect(this.dialog.$(".register_existing_oracle input[name=dbName]").val()).toBe("");
            });

            describe("filling out the form", function() {
                beforeEach(function() {
                    this.dialog.$(".register_existing_oracle input[name=name]").val("DataSource_Name");
                    this.dialog.$(".register_existing_oracle textarea[name=description]").val("DataSource Description");
                    this.dialog.$(".register_existing_oracle input[name=host]").val("foo.bar");
                    this.dialog.$(".register_existing_oracle input[name=port]").val("1234");
                    this.dialog.$(".register_existing_oracle input[name=dbUsername]").val("user");
                    this.dialog.$(".register_existing_oracle input[name=dbPassword]").val("my_password");
                    this.dialog.$(".register_existing_oracle input[name=dbName]").val("foo");

                    this.dialog.$(".register_existing_oracle input[name=name]").trigger("change");
                });

                it("should return the values in fieldValues", function() {
                    var values = this.dialog.fieldValues();
                    expect(values.name).toBe("DataSource_Name");
                    expect(values.description).toBe("DataSource Description");
                    expect(values.host).toBe("foo.bar");
                    expect(values.port).toBe("1234");
                    expect(values.dbUsername).toBe("user");
                    expect(values.dbPassword).toBe("my_password");
                    expect(values.dbName).toBe("foo");
                });
            });
        });
    });

    context("when gnip is configured", function() {
        beforeEach(function() {
            chorus.models.Config.instance().set({ gnipConfigured: true });
            this.dialog.render();
        });

        it("shows the 'Register an existing GNIP data source' option", function() {
            expect(this.dialog.$("select.data_sources option[name='register_existing_gnip']")).toExist();
        });

        it("shows gnip data source 'helpful' information", function() {
            expect(this.dialog.$(".register_existing_gnip .form_info_block .message").text()).toMatchTranslation("data_sources.new_dialog.register_existing_gnip_help_text");
        });

        it("shows the icon", function() {
            this.dialog.$(".ui-selectmenu-button .ui-button").click();
            expect(this.selectMenuStub.find(".register_existing_gnip")).toExist();
        });

        describe("selecting gnip data source", function() {
            beforeEach(function() {
                this.dialog.$("select.data_sources").val("register_existing_gnip").change();
            });

            it("shows the gnip streamUrl", function() {
                expect(this.dialog.$(".register_existing_gnip input[name=streamUrl]").val()).toBe("");
            });

            it("does not autocomplete password inputs", function(){
                var passwordField = this.dialog.$("input[type=password].gnip_password ");
                expect(passwordField).toHaveAttr("autocomplete", "off");
            });
        });
    });

    context("when gnip is not configured", function() {
        beforeEach(function() {
            chorus.models.Config.instance().set({ gnipConfigured: false });
            this.dialog.render();
        });

        it("does not show the 'Register an existing GNIP data source' option", function() {
            expect(this.dialog.$("select.data_sources option[name='register_existing_gnip']")).not.toExist();
        });
    });

    describe("submitting the form", function() {
        beforeEach(function() {
            this.dialog.$("select.data_sources").val(this.dialog.$("select.data_sources option:last").val());
            chorus.models.Config.instance().set({ gnipConfigured: true, gnipUrl: "www.example.com", gnipPort: 433, oracleConfigured:true });
            this.dialog.render();
        });

        it("hitting enter should submit the form", function() {
            this.dialog.$("form").submit();
            expect(chorus.dialogs.DataSourcesNew.prototype.createDataSource).toHaveBeenCalled();
        });

        function testUpload() {
            context("#upload", function() {
                beforeEach(function() {
                    this.dialog.$("button.submit").click();
                });

                it("puts the button in 'loading' mode", function() {
                    expect(this.dialog.$("button.submit").isLoading()).toBeTruthy();
                });

                it("changes the text on the upload button to 'saving'", function() {
                    expect(this.dialog.$("button.submit").text()).toMatchTranslation("data_sources.new_dialog.saving");
                });

                it("does not disable the cancel button", function() {
                    expect(this.dialog.$("button.cancel")).not.toBeDisabled();
                });

                context("when save completes", function() {
                    beforeEach(function() {
                        spyOn(chorus.PageEvents, 'trigger');
                        spyOn(this.dialog, "closeModal");

                        this.dialog.model.set({id: "123"});
                        this.dialog.model.trigger("saved");
                    });

                    it("closes the dialog", function() {
                        expect(this.dialog.closeModal).toHaveBeenCalled();
                    });

                    it('displays a toast message', function() {
                        spyOn(chorus, 'toast');
                        this.server.lastCreate().succeed();
                        expect(chorus.toast).toHaveBeenCalledWith('data_sources.add.toast',
                            {dataSourceName: this.dialog.model.name(),
                            toastOpts: {type: "success"}
                            });
                    });

                    it("publishes the 'data_source:added' page event with the new data_source's id", function() {
                        expect(chorus.PageEvents.trigger).toHaveBeenCalledWith("data_source:added", this.dialog.model);
                    });
                });

                function itRecoversFromError() {
                    it("takes the button out of 'loading' mode", function() {
                        expect(this.dialog.$("button.submit").isLoading()).toBeFalsy();
                    });

                    it("sets the button text back to 'Uploading'", function() {
                        expect(this.dialog.$("button.submit").text()).toMatchTranslation("data_sources.new_dialog.save");
                    });
                }

                context("when the upload gives a server error", function() {
                    beforeEach(function() {
                        this.dialog.model.set({serverErrors: { fields: { a: { BLANK: {} } } }});
                        this.dialog.model.trigger("saveFailed");
                    });

                    it("display the correct error", function() {
                        expect(this.dialog.$(".errors").text()).toContain("A can't be blank");
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
        }

        context("registering a hadoop data source", function() {
            beforeEach(function() {
                this.dialog.$("select.data_sources").val("register_existing_hdfs").change();

                var hadoopSection = this.dialog.$("div.register_existing_hdfs");
                hadoopSection.find("input[name=name]").val(" DataSource_Name ");
                hadoopSection.find("textarea[name=description]").val(" DataSource Description ");
                hadoopSection.find("input[name=host]").val(" foo.bar ");
                hadoopSection.find("input[name=port]").val("1234");
                hadoopSection.find("input[name=username]").val(" user ");
                hadoopSection.find("input[name=groupList]").val(" hadoop ").change();
                hadoopSection.find("input[name=jobTrackerHost]").val("foooo.baaaar");
                hadoopSection.find("input[name=jobTrackerPort]").val("4321");
                hadoopSection.find("input[name=high_availability]").prop('checked', false);
                this.someConnectionParams = [
                    {key: 'dfs.data.dir', value: '/foo/bar'},
                    {key: 'mapred.queue.names', value: 'thingie, zippity, original'},
                    {key: 'mapred.acls.enabled', value: 'true'}
                ];
                this.dialog.model.set('connectionParameters', this.someConnectionParams);


                spyOn(chorus.models.HdfsDataSource.prototype, "save").andCallThrough();
                this.dialog.$("button.submit").click();
            });

            it("creates a hadoop data source model with the right data and saves it", function() {
                var json = this.server.lastCreate().json()['hdfs_data_source'];

                expect(json['name']).toBe("DataSource_Name");
                expect(json['description']).toBe("DataSource Description");
                expect(json['host']).toBe("foo.bar");
                expect(json['port']).toBe("1234");
                expect(json['username']).toBe("user");
                expect(json['group_list']).toBe("hadoop");
                expect(json['job_tracker_host']).toBe("foooo.baaaar");
                expect(json['job_tracker_port']).toBe("4321");
                expect(json['high_availability']).toBe(false);
                
                var connection_parameters = json['connection_parameters'];
                expect(connection_parameters[0]['key']).toEqual(this.someConnectionParams[0].key);
                expect(connection_parameters[0]['value']).toEqual(this.someConnectionParams[0].value);
                expect(connection_parameters[1]['key']).toEqual(this.someConnectionParams[1].key);
                expect(connection_parameters[1]['value']).toEqual(this.someConnectionParams[1].value);
            });
        });

        context("registering a greenplum database", function() {
            beforeEach(function() {
                this.dialog.$("select.data_sources").val("register_existing_greenplum").change();

                var section = this.dialog.$(".register_existing_greenplum");
                section.find("input[name=name]").val("DataSource_Name");
                section.find("textarea[name=description]").val("DataSource Description");
                section.find("input[name=host]").val("foo.bar");
                section.find("input[name=port]").val("1234");
                section.find("input[name=dbUsername]").val("user");
                section.find("input[name=dbPassword]").val("my_password");
                section.find("input[name=dbName]").val("foo");
                section.find("input[name=name]").trigger("change");
            });

            it("sends the right params", function() {
                this.dialog.$("button.submit").click();
                var json = this.server.lastCreate().json()['data_source'];

                expect(json['entity_type']).toBe('gpdb_data_source');
                expect(json['name']).toBe("DataSource_Name");
                expect(json['description']).toBe("DataSource Description");
                expect(json['db_name']).toBe("foo");
            });

            testUpload();
        });

        context("registering a postgres database", function() {
            beforeEach(function() {
                this.dialog.$("select.data_sources").val("register_existing_postgres").change();

                var section = this.dialog.$(".register_existing_postgres");
                section.find("input[name=name]").val("DataSource_Name");
                section.find("textarea[name=description]").val("DataSource Description");
                section.find("input[name=host]").val("foo.bar");
                section.find("input[name=port]").val("1234");
                section.find("input[name=dbUsername]").val("user");
                section.find("input[name=dbPassword]").val("my_password");
                section.find("input[name=dbName]").val("foo");
                section.find("input[name=name]").trigger("change");
            });

            it("sends the right params", function() {
                this.dialog.$("button.submit").click();
                var json = this.server.lastCreate().json()['data_source'];

                expect(json['entity_type']).toBe('pg_data_source');
                expect(json['name']).toBe("DataSource_Name");
                expect(json['description']).toBe("DataSource Description");
                expect(json['db_name']).toBe("foo");
            });

            testUpload();
        });

        context("registering a hawq database", function() {
            beforeEach(function() {
                this.dialog.$("select.data_sources").val("register_existing_hawq").change();

                var section = this.dialog.$(".register_existing_greenplum");
                section.find("input[name=name]").val("DataSource_Name");
                section.find("textarea[name=description]").val("DataSource Description");
                section.find("input[name=host]").val("foo.bar");
                section.find("input[name=port]").val("1234");
                section.find("input[name=dbUsername]").val("user");
                section.find("input[name=dbPassword]").val("my_password");
                section.find("input[name=dbName]").val("foo");
                section.find("input[name=name]").trigger("change");
            });

            it("sends the right params", function() {
                this.dialog.$("button.submit").click();
                var json = this.server.lastCreate().json()['data_source'];
                expect(json['entity_type']).toBe('gpdb_data_source');
                expect(json["name"]).toBe("DataSource_Name");
                expect(json["description"]).toBe("DataSource Description");
                expect(json["db_name"]).toBe("foo");
            });

            context("when the data source is not actually a hawq data source", function() {
                beforeEach(function() {
                    this.dialog.model.set({serverErrors: { fields: { base: { INVALID_HAWQ_DATA_SOURCE: {} } } }});
                    this.dialog.model.trigger("saveFailed");
                });

                it("display the correct error", function() {
                    expect(this.dialog.$(".errors").text()).toContainTranslation("field_error.INVALID_HAWQ_DATA_SOURCE");
                });
            });

            testUpload();
        });

        context("registering an oracle database", function() {
            beforeEach(function() {
                this.dialog.$("select.data_sources").val("register_existing_oracle").change();

                var section = this.dialog.$(".register_existing_oracle");
                section.find("input[name=name]").val("DataSource_Name");
                section.find("textarea[name=description]").val("DataSource Description");
                section.find("input[name=host]").val("foo.bar");
                section.find("input[name=port]").val("1234");
                section.find("input[name=dbUsername]").val("user");
                section.find("input[name=dbPassword]").val("my_password");
                section.find("input[name=dbName]").val("foo");
                section.find("input[name=name]").trigger("change");

                spyOn(chorus.models.OracleDataSource.prototype, "save").andCallThrough();
            });

            it('sends the right params', function() {
                this.dialog.$("button.submit").click();
                var json = this.server.lastCreate().json()['data_source'];

                expect(json['entity_type']).toBe('oracle_data_source');
                expect(json["db_password"]).toBe("my_password");
                expect(json["name"]).toBe("DataSource_Name");
                expect(json["description"]).toBe("DataSource Description");
                expect(json["db_name"]).toBe("foo");
            });

            testUpload();
        });

        context('registering a gnip data source', function() {
            beforeEach(function() {
                this.dialog.$("select.data_sources").val("register_existing_gnip").change();

                var section = this.dialog.$(".register_existing_gnip");
                section.find("input[name=name]").val("Gnip Name");
                section.find("textarea[name=description]").val("Gnip Description");
                section.find("input[name=streamUrl]").val("gnip.com");
                section.find("input[name=username]").val("gnip_user");
                section.find("input[name=password]").val("my_password");
            });

            it("sends the right params", function() {
                this.dialog.$("button.submit").click();
                var json = this.server.lastCreate().json()["gnip_data_source"];

                expect(json["name"]).toBe("Gnip Name");
                expect(json["description"]).toBe("Gnip Description");
                expect(json["stream_url"]).toBe("gnip.com");
                expect(json["username"]).toBe("gnip_user");
                expect(json["password"]).toBe("my_password");
            });

            testUpload();
        });

        context("registering a jdbc database", function() {
            beforeEach(function() {
                this.dialog.$("select.data_sources").val("register_existing_jdbc").change();

                var section = this.dialog.$(".register_existing_jdbc");
                section.find("input[name=name]").val("DataSource_Name");
                section.find("textarea[name=description]").val("DataSource Description");
                section.find("input[name=host]").val("foo.bar");
                section.find("input[name=dbUsername]").val("user");
                section.find("input[name=dbPassword]").val("my_password");
                section.find("input[name=name]").trigger("change");
            });

            it("sends the right params", function() {
                this.dialog.$("button.submit").click();
                var json = this.server.lastCreate().json()['data_source'];

                expect(json['entity_type']).toBe('jdbc_data_source');
                expect(json['name']).toBe("DataSource_Name");
                expect(json['description']).toBe("DataSource Description");
                expect(json['host']).toBe("foo.bar");
                expect(json['db_username']).toBe("user");
                expect(json['db_password']).toBe("my_password");
            });

            testUpload();
        });
    });
});
