chorus.dialogs.DatasetDownload = chorus.dialogs.Base.extend({
    constructorName: "DatasetDownload",
    templateName: "dataset_download",
    submitKey: "actions.download",
    title: t("dataset.download.title"),

    events: {
        "click button.submit": "submitDownload"
    },

    setup: function() {
        this._super("setup", arguments);
        this.dataset = this.options.pageModel;
        this.model = this.resource = new chorus.models.DatasetDownloadConfiguration();
    },

    additionalContext: function() {
        return {
            submitKey: this.submitKey
        };
    },

    submitDownload: function(e) {
        e.preventDefault();

        if (this.specifyAll()) {
            this.downloadAll();
        } else {
            if(this.validateInput()) {
                this.downloadSome();
            }
        }
    },

    validateInput: function() {
        this.model.set({ rowLimit: this.rowLimit() }, { silent: true });
        if (this.model.performValidation()) {
            return true;
        }
        this.showErrors();
    },

    downloadAll: function() {
        this.dataset.download();
        this.closeModal();
    },

    downloadSome: function() {
        this.dataset.download({ rowLimit: this.rowLimit() });
        this.closeModal();
    },

    rowLimit: function() {
        return this.$("input[name=rowLimit]").val();
    },

    specifyAll: function() {
        return !this.$("input[type=radio][id=specify_rows]").prop("checked");
    }
});

