chorus.dialogs.HdfsConnectionParameters = chorus.dialogs.Base.extend({
    constructorName: 'HdfsConnectionParametersDialog',
    templateName: 'hdfs_connection_parameters',
    title: t('hdfs_connection_parameters.dialog.title'),
    additionalClass: "dialog_wide",

    events: {
        'click a.add_pair': 'addPair',
        'click a.remove_pair': 'removePair',
        'click button.submit': 'save',
        'click a.external_config': 'showExternalConfig',
        'click a.fetch_external_config': 'fetchExternalConfig',
        'click a.cancel_external_config': 'cancelExternalConfig'
    },

    setup: function () {
        this.pairs = this.model.get('connectionParameters') || [{key: '', value: ''}];
        this.host_info = { host: '', port: 8088 };
    },

    save: function (e) {
        e && e.preventDefault();

        this.preservePairs();
        this.model.set('connectionParameters', this.pairs);
        this.closeModal();
    },

    addPair: function (e) {
        e && e.preventDefault();

        this.preservePairs();
        this.pairs.push({key: '', value: ''});
        this.render();
    },

    removePair: function (e) {
        e && e.preventDefault();
        var pair = $(e.target).closest('.pair');
        pair.remove();
    },

    preservePairs: function () {
        this.pairs = _.map(this.$('.pair'), function (input) {
            return {
                key: $(input).find('.key').val(),
                value: $(input).find('.value').val()
            };
        });
    },

    showExternalConfig: function(event) {
        event && event.preventDefault();
        this.$(".load_configuration_area").removeClass("hidden");
    },

    fetchExternalConfig: function(event) {
        event && event.preventDefault();

        this.host_info = {
            host: this.$("#configuration_host").val().trim(),
            port: this.$("#configuration_port").val().trim()
        };
        this.fetchedParams = new chorus.collections.HadoopConfigurationParamSet(this.host_info);

        // Perform manual validation
        var validation_errors = {};

        if (!this.host_info.host || this.host_info.host.length === 0) {
            validation_errors['configuration_host'] = t('validation.required', {fieldName: "Host"});
        }

        if (!this.host_info.port || this.host_info.port.length === 0) {
            validation_errors['configuration_port'] = t('validation.required', {fieldName: "Port"});
        }

        if (!_.isEmpty(validation_errors)) {
            this.fetchedParams.models[0]['errors'] = validation_errors;
            this.showErrors(this.fetchedParams.models[0]);

            return;
        }

        // If validates, fetch params
        this.listenTo(this.fetchedParams, "reset", this.populateFetchedParams);
        this.listenTo(this.fetchedParams, "fetchFailed", this.configFetchFailed);

        this.fetchedParams.fetch();
    },

    configFetchFailed: function(e) {
        this.resource = this.fetchedParams;
        //this.showErrors(this.fetchedParams);

        chorus.toast("hdfs_connection_parameters.dialog.load_configuration.failure.toast", {
            error_msg: this.fetchedParams.serverErrors.params,
            toastOpts: { type: "error" }
        });
    },

    populateFetchedParams: function() {
        // Make an hash lookup for existing keys
        this.preservePairs();
        var existing_params = {};
        _.each(this.pairs, function(pair, index) { this[pair.key] = index; }, existing_params);

        // For each fetched param, either overwrite if it already is defined
        // or append it to the list.
        var param_set = this.fetchedParams.models[0].attributes.params;
        for (var i = 0; i < param_set.length; i++) {
            if (existing_params.hasOwnProperty(param_set[i].name)) {
                this.pairs[existing_params[param_set[i].name]].value = param_set[i].value;
            } else {
                this.pairs.push({key: param_set[i].name, value: param_set[i].value});
            }
        }

        this.render();
    },

    cancelExternalConfig: function(event) {
        event && event.preventDefault();
        this.$(".load_configuration_area").addClass("hidden");
    },

    additionalContext: function () {
        return {
            connectionParameters: this.pairs,
            configuration_host: this.host_info.host,
            configuration_port: this.host_info.port
        };
    }
});