chorus.handlebarsHelpers.template = {
    renderTemplate: function(templateName, context) {
        return new Handlebars.SafeString(window.HandlebarsTemplates[templateName](context));
    },

    // generalized fragment for some interface actions
    // addWidget = icon (+) for adding an item in a list
    // removeWidget = icon (x) for removing an item from a list

    addWidget: function(t) {
        return Handlebars.helpers.renderTemplate("components/widget_add", {text: t});
    },
    removeWidget: function(t) {
        return Handlebars.helpers.renderTemplate("components/widget_remove", {text: t});
    },


    formControls:function(submitText, cancelText) {
        if(cancelText && cancelText.hash) {
            cancelText = "actions.cancel";
        }
        return Handlebars.helpers.renderTemplate("components/form_controls", { submitText: submitText, cancelText: cancelText});
    },

    formControlsWithDisabledSubmit: function(submitText, cancelText) {
        if(cancelText && cancelText.hash) {
            cancelText = "actions.cancel";
        }
        return Handlebars.helpers.renderTemplate("components/form_controls", { submitText: submitText, cancelText: cancelText, disabled: true});
    },

    formInfoBlock: function(t) {
        return Handlebars.helpers.renderTemplate("components/form_info_block", {text: t});
    },

    renderTemplateIf: function(conditional, templateName, context) {
        if (conditional) {
            return Handlebars.helpers.renderTemplate(templateName, context);
        } else {
            return "";
        }
    },

    renderErrors: function(serverErrors) {
        var output = ["<ul>"];
        var errorMessages = chorus.Mixins.ServerErrors.serverErrorMessages.call({serverErrors: serverErrors});

        _.each(errorMessages, function(message) {
            output.push("<li>" + Handlebars.Utils.escapeExpression(message) + "</li>");
        });

        output.push("</ul>");
        return new Handlebars.SafeString(output.join(""));
    },

    spanFor: function(text, attributes) {
        return new Handlebars.SafeString($("<span></span>").text(text).attr(attributes || {}).outerHtml());
    },

    timeZonesSelect: function () {
        return Handlebars.helpers.renderTemplate('time_zone_selector', {
            zones: chorus.models.Config.instance().get("timeZones")
        });
    },
    
    uploadWidgetFor: function(propertyName) {
        return Handlebars.helpers.renderTemplate("components/upload_widget", { propertyName: propertyName });
    },

    hdfsDataSourceFields: function(context) {
        return Handlebars.helpers.renderTemplate("data_sources/hdfs_data_source_fields", context || {});
    },

    hdfsVersionsSelect: function(selectOne, hive) {
        selectOne = selectOne === undefined ? true : selectOne;
        hive = hive === undefined ? false : hive;
        return Handlebars.helpers.renderTemplate("data_sources/hdfs_versions_select", {
            hdfsVersions: hive ? chorus.models.Config.instance().get("hiveHdfsVersions") : chorus.models.Config.instance().get("hdfsVersions"),
            selectOne: selectOne
        });
    },

    generalDataSourceFields: function (values) {
        return Handlebars.helpers.renderTemplate("data_sources/general_data_source_fields", values || {});
    },

    generaldBAccountFields: function (values) {
        return Handlebars.helpers.renderTemplate("data_sources/general_dB_account_fields", values || {});
    },

   
    dbDataSourceFields: function(context) {
        return Handlebars.helpers.renderTemplate("data_sources/db_data_source_fields", context || {});
    },

    jdbcDataSourceFields: function(context) {
        return Handlebars.helpers.renderTemplate("data_sources/jdbc_data_source_fields", context || {});
    },

    jdbcHiveDataSourceFields: function(context) {
        return Handlebars.helpers.renderTemplate("data_sources/jdbc_hive_data_source_fields", context || {});
    },

    workflowResultLink: function (jobTaskResult) {
        var result = new chorus.models.WorkFlowResult({workfileId: jobTaskResult.payloadId, id: jobTaskResult.payloadResultId});
        return Handlebars.helpers.renderTemplate("workflow_result_link", { link: result.showUrl(), name: result.name() });
    },

    modelNamesList: function(collection) {
        function appendLast(name) { return ", and " + name; }

        var list = "";
        var comma = ", ";
        var names = collection.map(function(m) { return _.result(m, "name"); });
        var length = names.length;

        switch (length) {
            case 0:
                list = "";
                break;
            case 1:
                list = names[0];
                break;
            case 2:
                list = names.join(" and ");
                break;
            case 3:
                var last = names.pop();
                list = names.join(comma) + appendLast(last);
                break;
            default:
                list = names.slice(0,2).join(comma) + appendLast(length - 2 + " others");
                break;
        }

        return new Handlebars.SafeString(list);
    },

    dashboardModuleList: function(modules, className, translationKey, footnoteKey) {
        var ctx = {
            modules: modules,
            className: className,
            translationKey: translationKey,
            footnoteKey: footnoteKey
        };
        return Handlebars.helpers.renderTemplate("user/dashboard_edit_list", ctx);
    }
};

_.each(chorus.handlebarsHelpers.template, function(helper, name) {
    Handlebars.registerHelper(name, helper);
});
