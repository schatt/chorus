chorus.dialogs.WorkspaceEditMembers = chorus.dialogs.Base.extend({
    constructorName: "WorkspaceEditMembers",
    templateName:"workspace_edit_members",
    title:t("workspace.edit_members_dialog.title"),
    additionalClass: "dialog_wide",
    persistent:true,

    events:{
        "click button.submit":"updateMembers"
    },

    makeModel:function () {
        this._super("makeModel", arguments);
        this.collection = new chorus.collections.UserSet();
        this.members = this.options.pageModel.members();

        this.collection.fetchAllIfNotLoaded();
        this.members.fetchAllIfNotLoaded({per_page: 1e4});

        this.listenTo(this.collection, "reset", this.render);
        this.listenTo(this.members, "saved", this.saved);
    },

    subviews:{
        ".shuttle":"shuttle"
    },

    setup:function () {
        this.shuttle = new chorus.views.ShuttleWidget({
            collection:this.collection,
            selectionSource:this.members,
            nonRemovable:[this.options.pageModel.owner()],
            nonRemovableText:t("workspace.owner"),
            objectName:t("workspace.members")
        });
    },

    updateMembers:function () {
        this.$("button.submit").startLoading("actions.saving");

        var self = this;
        var ids = this.shuttle.getSelectedIDs();
        var users = _.map(ids, function (userId) {
            return self.collection.get(userId);
        });
        self.members.reset(users);
        self.members.save();
    },

    saved:function () {
        this.pageModel.trigger("invalidated");
        this.closeModal();
    }
});
