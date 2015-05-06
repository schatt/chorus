chorus.dialogs.PreviewColumns = chorus.dialogs.Base.extend({
    constructorName: "PreviewColumns",

    templateName: "preview_columns",
    additionalClass: "with_sub_header",
    title: t("dataset.manage_join_tables.title"),
    useLoadingSection: true,

    setup: function() {
        this.resource = this.collection = this.model.columns();
        this.listenTo(this.collection, 'fetchFailed', this.columnFetchFailed);
        this.collection.fetchAll();
    },

    columnFetchFailed: function() {
        this.model.serverErrors = this.collection.serverErrors;
        this.closeModal();
        this.previousModal.showErrors(this.model);
    },

    postRender: function() {
        chorus.search({
            input: this.$("input.search"),
            list: this.$(".list"),
            selector: ".name, .comment"
        });
    },

    additionalContext: function() {
        return {
            objectName: this.model.get("objectName"),
            count: this.collection.models.length
        };
    }
});
