chorus.dialogs.DataSourcesNew = chorus.dialogs.Base.extend ({
    constructorName: "DataSourcesNew",
    templateName: "data_source_new",
    title: t("data_sources.new_dialog.title"),
    persistent: true,

    events: {
        "change select.data_sources": "showFieldset",
        "click a.close_errors": "clearServerErrors",
        "submit form": "createDataSource",
        "change input[name=high_availability]": 'toggleHighAvailability',
        "change input[name=hiveKerberos]": 'toggleKerberos',
        "click a.connection_parameters": "launchConnectionParametersDialog"
    },

    postRender: function() {
        _.defer(_.bind(function() {
            chorus.styleSelect(this.$("select.data_sources"), { format: function(text, option) {
                var aliasedName = $(option).val();
                return '<span class='+ aliasedName +'></span>' + text;
            } });
            chorus.styleSelect(this.$("select.hdfs_version"), { format: function(text, option) {
                var aliasedName = $(option).attr("name");
                return '<span class='+ aliasedName +'></span>' + text;
            } });
        }, this));
    },

    makeModel: function () {
        this.model = this.model || new chorus.models.GpdbDataSource();
        this.listenTo(this.model, 'change', this.rewriteLink);
    },

    additionalContext: function() {
        var config = chorus.models.Config.instance();
        return {
            gnipConfigured: config.get('gnipConfigured'),
            oracleConfigured: config.get('oracleConfigured'),
            defaultGpdbFields: {dbName: "postgres"},
            parameterCount: {count: this.model.numberOfConnectionParameters()}
        };
    },

    showFieldset: function (e) {
        this.$(".data_source_fields").addClass("collapsed");
        var className = this.$("select.data_sources option:selected").attr("name");

        if(className.length) {
            this.$("." + className).removeClass("collapsed");
        }
        this.$("button.submit").prop("disabled", className === 'select_one');
        this.clearErrors();
    },

    rewriteLink: function () {
        this.$('a.connection_parameters').text(t('data_sources.dialog.connection_parameters', {count: this.model.numberOfConnectionParameters()}));
    },

    toggleHighAvailability: function (e) {
        e && e.preventDefault();

        if (this.$('input[name=high_availability]').prop('checked')) {
            this.$('input[name=port]').val('');
            this.$('[name=port]').prop('disabled', true).removeClass('required');
            this.$('label[name=host]').text(t('data_sources.dialog.name_service'));
        } else {
            this.$('[name=port]').prop('disabled', false).addClass('required');
            this.$('label[name=host]').text(t('data_sources.dialog.hadoop_host'));
        }
    },

    toggleKerberos: function(e) {
        e && e.preventDefault();
        if (this.$('input[name=hiveKerberos]:checked').val() === 'true') {
            this.$('[name=hiveKerberosPrincipal]').removeClass('hidden');
            this.$('[name=hiveKerberosKeytabLocation]').removeClass('hidden');
            this.$('[name=dbUsername]').addClass('hidden');
            this.$('[name=dbPassword]').addClass('hidden');
            this.$('[name=shared]').addClass('hidden');
            this.$('[for=register_jdbc_shared]').addClass('hidden');
        } else {
            this.$('[name=hiveKerberosPrincipal]').addClass('hidden');
            this.$('[name=hiveKerberosKeytabLocation]').addClass('hidden');
            this.$('[name=dbUsername]').removeClass('hidden');
            this.$('[name=dbPassword]').removeClass('hidden');
            this.$('[name=shared]').removeClass('hidden');
            this.$('[for=register_jdbc_shared]').removeClass('hidden');
        }
    },

    launchConnectionParametersDialog: function (e) {
        e && e.preventDefault();

        new chorus.dialogs.HdfsConnectionParameters({model: this.model}).launchModal();
    },

    createDataSource: function (e) {
        e && e.preventDefault();

        var merged_attributes = _.extend({}, this.fieldValues(), this.model.attributes);
        delete merged_attributes['entityType'] // Entity type is chosen by dataSourceClass so we don't want to keep it

        this.resource = this.model = new (this.dataSourceClass())(merged_attributes);
        this.listenTo(this.model, "saved", this.saveSuccess);
        this.listenTo(this.model, "saveFailed", this.saveFailed);
        this.listenTo(this.model, "validationFailed", this.saveFailed);

        this.$("button.submit").startLoading("data_sources.new_dialog.saving");
        this.model.save();
    },

    dataSourceClass: function() {
        var dataSourceType = this.$("select.data_sources option:selected").attr("name");
        if (dataSourceType === "register_existing_hdfs") {
            return chorus.models.HdfsDataSource;
        } else if (dataSourceType === "register_existing_gnip") {
            return chorus.models.GnipDataSource;
        } else if (dataSourceType === "register_existing_oracle") {
            return chorus.models.OracleDataSource;
        } else if (dataSourceType === "register_existing_jdbc") {
            return chorus.models.JdbcDataSource;
        } else if (dataSourceType === "register_existing_postgres") {
            return chorus.models.PgDataSource;
        } else if (dataSourceType === "register_existing_jdbc_hive") {
            return chorus.models.JdbcHiveDataSource;
        } else {
            return chorus.models.GpdbDataSource;
        }
    },

    fieldValues: function() {
        var updates = {};
        var className = this.$("select.data_sources option:selected").attr("name");
        var inputSource = this.$("." + className);
        _.each(inputSource.find("input[type=text], input[type=hidden], input[type=password], textarea, select"), function (i) {
            var input = $(i);
            updates[input.attr("name")] = input.val().trim();
        });
        updates["isHawq"] = this.$("select.data_sources option:selected").attr("hawq");

        updates.ssl = !!inputSource.find("input[name=ssl]").prop("checked");
        updates.shared = !!inputSource.find("input[name=shared]").prop("checked");
        updates.highAvailability = !!inputSource.find("input[name=high_availability]").prop("checked");
        updates.connectionParameters = this.model.get('connectionParameters');
        if(updates.hive) {
            updates.hiveKerberos = inputSource.find("input[name=hiveKerberos]:checked").val() === 'true';
            if (updates.hiveKerberos) {
                updates.dbUsername = 'default';
                updates.dbPassword = 'default';
                updates.shared = true;
            }

            updates.hiveHadoopVersion = updates.hdfsVersion;
            delete updates.hdfsVersion;

        }
        return updates;
    },

    clearServerErrors : function() {
        this.model.serverErrors = {};
    },

    saveSuccess: function () {
        chorus.PageEvents.trigger("data_source:added", this.model);
        chorus.toast('data_sources.add.toast', {dataSourceName: this.model.name(), toastOpts: {type: "success"}});
        this.closeModal();
    }
});

