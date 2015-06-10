chorus.pages.WorkfileShowPage = chorus.pages.Base.extend({
    helpId: "workfile",

    makeModel: function(workspaceId) {
        this.loadWorkspace(workspaceId);
    },

    setup: function(workspaceId, workfileId, versionId) {
        this.model = new chorus.models.Workfile({id:workfileId, workspace: {id: workspaceId}});
        if (versionId) {
            this.model.set({ versionInfo : { id: versionId } }, { silent:true });
        }

        this.handleFetchErrorsFor(this.model);

        this.model.fetch();

        this.workspace = this.model.workspace();
        this.subNav = new chorus.views.SubNav({workspace: this.workspace, tab: "workfiles"});

        this.subscribePageEvent("workfileVersion:changed", this.workfileVersionChanged);

        this.onceLoaded(this.model, this.buildPage);

        this.subscribePageEvent("workfile:rename", this.reload);
    },

    reload: function() {
        window.location.reload();
    },

    buildPage: function() {
        this.model = new chorus.models.DynamicWorkfile(this.model.attributes);
        this.workspace = this.model.workspace();
        if (this.workspace.get("id") !== this.workspaceId) {
            this.dependentResourceNotFound();
            return;
        }

        var contentView = new chorus.views.WorkfileContent.buildFor(this.model);
        this.mainContent = new chorus.views.MainContentView({
            model:this.model,
            content: contentView,
            contentHeader: new chorus.views.WorkfileHeader({model:this.model}),
            contentDetails: chorus.views.WorkfileContentDetails.buildFor(this.model, contentView)
        });

        this.sidebar = chorus.views.WorkfileSidebar.buildFor({model: this.model, showVersions: true, showSchemaTabs: true, inWorkfile: true});
        this.subNav = new chorus.views.SubNav({workspace:this.workspace, tab:"workfiles"});

        if (this.model.isLatestVersion() && this.model.get("hasDraft") && !this.model.isDraft) {
            var alert = new chorus.alerts.WorkfileDraft({model:this.model});
            alert.launchModal();
        }

        this.render();
    },

    workfileVersionChanged: function(versionId) {
        this.model.set({ versionInfo : { id: versionId } }, { silent:true });
        this.model.fetch();
        chorus.router.navigate(this.model.showUrl(), {trigger: false});
    }
});

