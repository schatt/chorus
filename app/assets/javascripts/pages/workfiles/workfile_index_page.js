chorus.pages.WorkfileIndexPage = chorus.pages.Base.include(
    chorus.Mixins.FetchingListSearch
).extend({
    constructorName: 'WorkfileIndexPage',
    helpId: "workfiles",

    setup: function(workspaceId) {
        this.collection = new chorus.collections.WorkfileSet([], {workspaceId: workspaceId});
        this.collection.fileType = "";
        this.collection.sortAsc("fileName");
        this.collection.fetch();


        this.subNav = new chorus.views.SubNav({workspace: this.workspace, tab: "workfiles"});
        this.mainContent = new chorus.views.MainContentList({
            modelClass: "Workfile",
            collection: this.collection,
            model: this.workspace,
            title: t("workfiles.title"),
            contentDetailsOptions: { multiSelect: true },
            contentOptions: {listItemOptions: {workspaceIdForTagLink: this.workspace.id} },
            linkMenus: {
                type: {
                    title: t("header.menu.filter.title"),
                    options: this.linkMenuOptions(),
                    event: "filter"
                },
                sort: {
                    title: t("workfiles.header.menu.sort.title"),
                    options: [
                        {data: "alpha", text: t("workfiles.header.menu.sort.alphabetically")},
                        {data: "date", text: t("workfiles.header.menu.sort.by_date")}
                    ],
                    event: "sort"
                }
            },
            search: {
                placeholder: t("workfile.search_placeholder"),
                onTextChange: this.debouncedCollectionSearch()
            }
        });

        this.subscribePageEvent("workfiles:fetch", function() {
           this.collection.fetch();
        });

        this.subscribePageEvent("workfile:search", function() {
            chorus.PageEvents.trigger('selectNone');
        });

        this.subscribePageEvent("workfile:selected", this.setModel);

        this.multiSelectSidebarMenu = new chorus.views.MultipleSelectionSidebarMenu({
            selectEvent: "workfile:checked",
            actionProvider: [{name: "edit_tags", target: chorus.dialogs.EditTags},
                             {name: "delete", target: chorus.alerts.WorkfileDeleteMultiple}]
        });

        this.mainContent.contentHeader.bind("choice:filter", function(choice) {
            this.collection.attributes.fileType = choice;
            this.collection.fetch();
        }, this);

        this.mainContent.contentHeader.bind("choice:sort", function(choice) {
            var field = choice === "alpha" ? "fileName" : "userModifiedAt";
            this.collection.sortAsc(field);
            this.collection.fetch();
        }, this);

        this.requiredResources.add(this.workspace);
    },

    makeModel: function(workspaceId) {
        this.loadWorkspace(workspaceId);
    },

    setModel: function(workfile) {
        this.model = workfile;
        if(this.sidebar) {
            this.sidebar.teardown(true);
        }
        this.sidebar = chorus.views.WorkfileSidebar.buildFor({model: this.model});
        this.renderSubview('sidebar');
    },

    linkMenuOptions: function () {
        var items = [
            {data: "", text: t("workfiles.header.menu.filter.all")},
            {data: "SQL", text: t("workfiles.header.menu.filter.sql")},
            {data: "CODE", text: t("workfiles.header.menu.filter.code")},
            {data: "TEXT", text: t("workfiles.header.menu.filter.text")},
            {data: "IMAGE", text: t("workfiles.header.menu.filter.image")},
            {data: "OTHER", text: t("workfiles.header.menu.filter.other")}
        ];

        if (chorus.models.Config.instance().license().workflowEnabled()) {
            var workFlowsOption = {data: "WORK_FLOW", text: t("workfiles.header.menu.filter.work_flow")};
            items.splice(2, 0, workFlowsOption);
        }

        return items;
    },

    preRender: function () {
        this.buildPrimaryActionPanel();
    },

    buildPrimaryActionPanel: function () {
        var actions = [];

        var updateActions = [
            {name: 'import_workfile', target: chorus.dialogs.WorkfilesImport},
            {name: 'create_sql_workfile', target: chorus.dialogs.WorkfilesSqlNew}
        ];

        this.workspace.canUpdate() && _.each(updateActions, function (action) { actions.push(action); });
        var createWorkflow = {name: 'create_workflow', target: chorus.dialogs.WorkFlowNew};
        this.workspace.currentUserCanCreateWorkFlows() && actions.push(createWorkflow);

        this.primaryActionPanel = new chorus.views.PrimaryActionPanel({pageModel: this.workspace, actions: actions});
    }
});
