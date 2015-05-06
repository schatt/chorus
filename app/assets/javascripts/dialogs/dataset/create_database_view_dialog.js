chorus.dialogs.CreateDatabaseView = chorus.dialogs.Base.extend({
    constructorName: "CreateDatabaseView",

    templateName: "create_database_view_dialog",
    title: t("create_database_view.title"),

    events: {
        "submit form": "performValidation",
        "click button.submit": "performValidation"
    },

    makeModel:function (options) {
        this.dataset = this.options.pageModel;
        this.model = new chorus.models.DatabaseViewConverter({workspaceId: this.dataset.get("workspace") && this.dataset.get("workspace").id }, {from: this.dataset});
        this.listenTo(this.model, "saved", this.saved);
        this.listenTo(this.model, "saveFailed", this.saveFailed);
    },

    additionalContext: function() {
        return {
            canonicalName: this.canonicalName()
        };
    },

    performValidation: function(e) {
        e && e.preventDefault();
        this.clearErrors();
        var $name = this.$("#create_database_view_name");

        if ($name.val().match(chorus.ValidationRegexes.ChorusIdentifierLower64())) {
            this.$("button.submit").startLoading("actions.creating");
            this.model.set({objectName: $name.val()}, {silent: true});
            this.model.save();
        } else {
            this.markInputAsInvalid($name, t("validation.chorus64"), true);
        }
    },

    saved: function() {
        chorus.toast("create_database_view.success.toast", {
            canonicalName: this.canonicalName(),
            viewName: this.model.get("objectName"),
            toastOpts: {type: "success"}
        });

        var databaseView = this.model.databaseView();
        if (!databaseView.has("workspace")) {
            databaseView.set({"workspace": this.dataset.get("workspace")});
        }
        chorus.router.navigate(databaseView.showUrl());
    },

    canonicalName: function() {
        return this.dataset.schema().canonicalName();
    }
});
