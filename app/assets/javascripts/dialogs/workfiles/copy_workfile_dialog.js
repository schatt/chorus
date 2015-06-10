chorus.dialogs.CopyWorkfile = chorus.dialogs.PickWorkspace.extend({
    constructorName: "CopyWorkfile",

    title: t("workfile.copy_dialog.title"),
    submitButtonTranslationKey: "workfile.copy_dialog.copy_file",

    setup: function() {
        this.workfile = new chorus.models.Workfile ({
            id: this.options.workfileId,
            workspace: {id: this.options.workspaceId}
        });
        this.requiredResources.add(this.workfile);
        this.requiredResources.add(this.collection);
        this.workfile.fetch();
        this._super("setup", arguments);
    },

    resourcesLoaded: function() {
        this.render();
    },

    submit: function() {
        var self = this;
        var workfile = this.workfile;
        var params = {
            workspace_id: this.selectedItem().get("id")
        };
        var description = workfile.get("description");
        if (description) {
            params.description = description;
        }

        $.ajax({
            url: "/workfiles/" + this.workfile.get("id") + "/copy",
            type: "POST",
            dataType: "json",
            data: params,
            success: function(data) {
                self.closeModal(true);
                
                // construct message to user                

                // A. construct link to file copy
                var copiedWorkfile = new chorus.models.Workfile(workfile.parse(data));
                var copiedFileLink = copiedWorkfile.showLink();
                
                // B. construct info to destination workspace
                var workspaceTarget;
                var workspaceTargetName = self.selectedItem().get("name");
                var workspaceTargetID   = self.selectedItem().get("id");
                var workspaceCurrentID  = workfile.workspace().get("id");

                // if file is copied to a different workspace, then the workspace name should be a link to that workspace
                // else if same workspace just workspace name
                if (workspaceTargetID !== workspaceCurrentID) {
                    workspaceTarget = self.selectedItem().showLink();
                } else {
                    workspaceTarget = workspaceTargetName;
                }

                chorus.PageEvents.trigger("workfiles:fetch");
                chorus.toast("workfile.copy_success.toast", {workfileLink: copiedFileLink, workspaceTarget: workspaceTarget, toastOpts: {type: "success"}});
            },

            error: function(xhr) {
                var data = JSON.parse(xhr.responseText);
                self.resource.serverErrors = data.errors;
                self.showErrors();
            }
        });
        
    }
});