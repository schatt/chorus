chorus.alerts.WorkfileConflict = chorus.alerts.Confirm.extend({
    constructorName: "WorkfileConflict",

    text: t("workfile.conflict.alert.text"),
    ok: t("workfile.conflict.alert.submit"),
    cancel: t("workfile.conflict.alert.cancel"),
    additionalClass: "error",

    setup:function () {
        this.title = this.model.serverErrorMessage();
        delete this.model.serverErrors;
    },

    postRender:function () {
        this._super('postRender');
        this.$("button.cancel").click(_.bind(function () {
            this.discardChanges();
        }, this));
    },

    confirmAlert:function () {
        this.closeModal();
        this.dialog = new chorus.dialogs.WorkfileNewVersion({ pageModel: this.model });
        this.dialog.launchModal();
    },

    discardChanges:function () {
        var draft = new chorus.models.Draft({workspaceId:this.model.workspace().id, workfileId:this.model.get("id")});
        this.listenTo(draft, "change", function (draft) {
            draft.destroy();
        });

        draft.fetch();
        this.model.fetch();
        this.closeModal();
    }
});

