;(function($, ns) {
    var breadcrumbsView = ns.views.ModelBoundBreadcrumbsView.extend({
        getLoadedCrumbs : function(){
            return [
                    {label: t("breadcrumbs.home"), url: "#/"},
                    {label: this.options.workspace.get("name"), url: this.options.workspace.showUrl()},
                    {label: t("breadcrumbs.workfiles.all"), url: this.options.workspace.showUrl() + "/workfiles"},
                    {label: this.model.get("fileName") }
                ];
        }
    });

    ns.pages.WorkfileShowPage = ns.pages.Base.extend({
        setup : function(workspaceId, workfileId, versionNum) {
            this.workspace = new ns.models.Workspace({id: workspaceId});
            this.workspace.fetch();

            if (versionNum) {
                this.model = new ns.models.WorkfileVersion({workfileId: workfileId, workspaceId: workspaceId, versionNum: versionNum})
                this.isOldVersion = true;
            } else {
                this.model = new ns.models.Workfile({id: workfileId, workspaceId: workspaceId});
                this.isOldVersion = false;
            }

            this.model.bind("change", this.modelChanged, this);
            this.model.fetch();

            this.breadcrumbs = new breadcrumbsView({workspace: this.workspace, model: this.model});

            this.sidebar = new chorus.views.WorkfileShowSidebar({model : this.model});

            this.subNav = new ns.views.SubNav({workspace: this.workspace, tab: "workfiles"});

            this.mainContent = new ns.views.MainContentView({
                model : this.model,
                contentHeader : new ns.views.WorkfileHeader({model : this.model})
            });
        },

        modelChanged : function() {
            if (this.model.get("hasDraft") && !this.model.isDraft) {
                alert = new chorus.alerts.WorkfileDraft({model : this.model});
                alert.launchModal();
            }

            if (!this.mainContent.contentDetails) {
                this.mainContent.contentDetails = ns.views.WorkfileContentDetails.buildFor(this.model);
                this.mainContent.content = ns.views.WorkfileContent.buildFor(this.model);
                this.mainContent.content.forwardEvent("autosaved", this.mainContent.contentDetails);
                this.mainContent.content.bind("autosaved", function() {this.model.trigger("invalidated");}, this);
                this.mainContent.contentDetails.forwardEvent("file:saveCurrent", this.mainContent.content);
                this.mainContent.contentDetails.forwardEvent("file:createWorkfileNewVersion", this.mainContent.content);
            }

            this.render();
        }
    });

    ns.views.WorkfileHeader = ns.views.Base.extend({
        className : "workfile_header",
        additionalContext : function() {
            return {
                iconUrl : this.model.get("fileType") && chorus.urlHelpers.fileIconUrl(this.model.get("fileType"))
            };
        }
    });
})(jQuery, chorus);
