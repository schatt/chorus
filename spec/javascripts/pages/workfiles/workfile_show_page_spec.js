describe("chorus.pages.WorkfileShowPage", function() {
    beforeEach(function() {
        spyOn(chorus.pages.WorkfileShowPage.prototype, "reload");
        chorus.page = { workspace: backboneFixtures.workspace() };
        this.workspaceId = 4;
        this.workfileId = 5;
        this.workspace = backboneFixtures.workspace({id: this.workspaceId});
        this.model = backboneFixtures.workfile.sql({id: this.workfileId, workspace: {id: this.workspaceId}});
    });

    describe("#setup", function() {
        beforeEach(function() {
            spyOn(chorus.views.WorkfileContentDetails, 'buildFor').andCallThrough();
            spyOn(chorus.views.WorkfileContent, 'buildFor').andCallThrough();
            spyOn(chorus.views.WorkfileSidebar, 'buildFor').andCallThrough();
            this.page = new chorus.pages.WorkfileShowPage(this.workspaceId, this.workfileId);
        });

        it("has a helpId", function() {
            expect(this.page.helpId).toBe("workfile");
        });

        it("sets the workspace id, for prioritizing search", function() {
            expect(this.page.workspaceId).toBe(4);
        });

        it("instantiates and fetches a workfile with the given id", function() {
            var workfile = this.page.model;
            expect(workfile.get("id")).toBe(this.workfileId);
            expect(this.server.lastFetchFor(this.page.model)).toBeDefined();
        });

        it("does not configure a version number into the workfile model", function() {
            expect(this.page.model.isLatestVersion()).toBeTruthy();
        });

        it("displays a loading spinner when rendered before fetches complete", function() {
            this.page.render();
            expect(this.page.$(".loading_section")).toExist();
        });

        it("should save the workspace ID as an integer", function() {
            var workspaceIdString = "4";
            this.page = new chorus.pages.WorkfileShowPage(workspaceIdString, this.workfileId);
            expect(this.page.workspaceId).toEqual(4);
        });

        context("with a version number", function() {
            beforeEach(function() {
                this.page = new chorus.pages.WorkfileShowPage(this.workspaceId, this.workfileId, '16');
            });

            it("configures the version number into the workfile model", function() {
                expect(this.page.model.isLatestVersion()).toBeFalsy();
            });
        });

        context("when the specified workspace ID doesn't match the workfile's workspace ID", function() {
            beforeEach(function() {
                spyOn(Backbone.history, "loadUrl");
                this.page = new chorus.pages.WorkfileShowPage(3, this.workfileId);
            });

            it("renders a 404", function() {
                this.server.completeFetchFor(this.model);
                expect(Backbone.history.loadUrl).toHaveBeenCalledWith("/invalidRoute");
            });
        });

        describe("fetch failure", function() {
            beforeEach(function() {
                spyOn(Backbone.history, "loadUrl");
            });

            it("navigates to the 404 page for the model", function() {
                this.page.model.trigger('resourceNotFound', this.page.model);
                expect(Backbone.history.loadUrl).toHaveBeenCalledWith("/invalidRoute");
            });
        });

        describe("when the workfile is fetched", function() {
            beforeEach(function() {
                spyOn(chorus.views.Base.prototype, "render").andCallThrough();
            });

            context("and the workfile does not have a draft", function() {
                beforeEach(function() {
                    chorus.views.Base.prototype.render.reset();
                    this.server.completeFetchFor(this.model);
                });

                it("loads sidebar, subnavigation, and mainContent", function() {
                    expect(this.page.sidebar).toBeDefined();
                    expect(this.page.subNav).toBeDefined();
                    expect(this.page.mainContent).toBeDefined();
                });

                it("instantiates the content details view", function() {
                    expect(chorus.views.WorkfileContentDetails.buildFor).toHaveBeenCalledWith(this.page.model, this.page.mainContent.content);
                });

                it("instantiates the content view", function() {
                    expect(chorus.views.WorkfileContent.buildFor).toHaveBeenCalledWith(this.page.model);
                });

                it('instantiates the sidebar view', function() {
                    expect(this.page.sidebar).toBeDefined();
                    var sidebar_options = {model: this.page.model, showVersions: true, showSchemaTabs: true, inWorkfile: true};
                    expect(chorus.views.WorkfileSidebar.buildFor).toHaveBeenCalledWith(sidebar_options);
                });

                it("renders again", function() {
                    expect(chorus.views.Base.prototype.render).toHaveBeenCalled();
                });
            });

            context('and the workfile has a draft', function() {
                beforeEach(function() {
                    this.model.set({'draftInfo': backboneFixtures.draftJson().response, hasDraft: true});
                    this.modalSpy = stubModals();
                    this.server.completeFetchFor(this.model);
                });

                it("shows a workfile draft alert", function() {
                    expect(this.modalSpy).toHaveModal(chorus.alerts.WorkfileDraft);
                });

                context("and the user chooses the draft", function() {
                    beforeEach(function() {
                        this.modalSpy.reset();
                        spyOn(this.page, "render");
                        this.page.model.isDraft = true;
                        this.page.model.trigger('change');
                    });

                    it("does not show an alert", function() {
                        expect(this.modalSpy).not.toHaveModal(chorus.alerts.WorkfileDraft);
                    });
                });
            });
        });

        describe("workfile is renamed", function() {
            beforeEach(function() {
                chorus.PageEvents.trigger("workfile:rename");
            });

            it("reloads the page", function() {
                expect(this.page.reload).toHaveBeenCalled();
            });
        });
    });

    describe("#render", function() {
        beforeEach(function() {
            this.model = backboneFixtures.workfile.sql({id: this.workfileId,
                workspace: {
                    id: this.workspaceId,
                    name: "Cool Workspace"
                }});

            this.page = new chorus.pages.WorkfileShowPage(this.workspaceId, this.workfileId);
            this.server.completeFetchFor(this.model);
        });

        it("has a titlebar", function() {
            this.server.completeFetchFor(this.workspace);

            this.page.render();
            expect(this.page.$(".page_sub_header")).toContainText(this.workspace.name());
        });

        it("it displays the workfile name in the content header", function() {
            expect(this.page.mainContent.contentHeader.$("h1").text()).toBe(this.model.get('fileName'));
            expect(this.page.mainContent.contentHeader.$("h1").attr("title")).toBe(this.model.get('fileName'));
        });

        it("displays the file icon in the content header", function() {
            spyOn(this.page.model, "isImage").andReturn(false);
            this.page.render();
            expect(this.page.mainContent.contentHeader.$("img").attr("src")).toBe(chorus.urlHelpers.fileIconUrl('sql'));
        });
    });

    describe("changing the workfile version", function() {
        var oldVersion = 1;
        var defaultSchemaId = 3;

        function changeWorkfileVersion(version, model, server) {
            chorus.PageEvents.trigger("workfileVersion:changed", version);
            model.set({ versionInfo : { id: version, versionNum: version } });
            server.completeFetchFor(model);
        }

        beforeEach(function() {
            this.schema = backboneFixtures.schema({id: defaultSchemaId});
            this.model = backboneFixtures.workfile.sql({
                id: this.workfileId,
                workspace: {
                    id: this.workspaceId,
                    name: "Cool Workspace"
                },
                versionInfo: {
                    id: oldVersion,
                    versionNum: oldVersion
                }
            });
            this.model.attributes.execution_schema = this.schema.attributes;
        });

        context("regardless of whether the new version id is the same as the latest version id", function() {
            beforeEach(function() {
                this.page = new chorus.pages.WorkfileShowPage(this.workspaceId, this.workfileId, oldVersion);
                this.server.completeFetchFor(this.model);
            });

            it("triggers rendering of the page", function() {
                expect(this.page.$(".version_list .chosen")).toContainText("Version 1");
                changeWorkfileVersion(2, this.page.model, this.server);
                expect(this.page.$(".version_list .chosen")).toContainText("Version 2");
            });

            it("changes the versionId and fetches the model", function() {
                spyOn(this.page.model, "fetch").andCallThrough();
                changeWorkfileVersion(2, this.model, this.server);
                expect(this.page.model.get("versionInfo").id).toEqual(2);
                expect(this.page.model.fetch).toHaveBeenCalled();
            });

            it("does not change the sidebar dataset list", function() {
                this.page.sidebar.tabs.data.schema = backboneFixtures.schema({id: 4});
                changeWorkfileVersion(2, this.model, this.server);
                expect(this.page.sidebar.tabs.data.schema.id).toEqual(4);
            });
        });

        context("when the new version id is not the latest version id", function() {
            beforeEach(function() {
                this.model.set("latestVersionId", 123);
                this.page = new chorus.pages.WorkfileShowPage(this.workspaceId, this.workfileId, oldVersion);
                this.server.completeFetchFor(this.model);
            });

            it("calls navigate with the new version's url and {trigger: false}", function() {
                spyOn(chorus.router, "navigate");
                changeWorkfileVersion(2, this.model, this.server);
                expect(chorus.router.navigate).toHaveBeenCalledWith("#/workspaces/4/workfiles/5/versions/2", {trigger: false});
            });
        });

        context("when the new version id is the latest version id", function() {
            beforeEach(function(){
                this.model.set("latestVersionId", 2);
                this.page = new chorus.pages.WorkfileShowPage(this.workspaceId, this.workfileId, oldVersion);
                this.server.completeFetchFor(this.model);
            });

            it("calls navigate with workfile url and {trigger: false}", function() {
                spyOn(chorus.router, "navigate");
                changeWorkfileVersion(2, this.model, this.server);
                expect(chorus.router.navigate).toHaveBeenCalledWith("#/workspaces/4/workfiles/5", {trigger: false});
            });
        });
    });
});
