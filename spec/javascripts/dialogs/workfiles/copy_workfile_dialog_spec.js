describe("chorus.dialogs.CopyWorkfile", function() {
    beforeEach(function() {
        this.workspaceId = '4';
        this.workfileId = '10';
        this.workfile = backboneFixtures.workfile.text({ id: this.workfileId, workspace: {id: this.workspaceId} });
        this.workspace = backboneFixtures.workspace({ id: this.workspaceId });
        setLoggedInUser({id: 4003});
        chorus.session.trigger("saved");

        this.dialog = new chorus.dialogs.CopyWorkfile({ workspaceId: this.workspaceId, workfileId: this.workfileId });
        this.dialog.render();
    });

    describe("#setup", function() {
        it("fetches the source workfile", function() {
            expect(this.server.lastFetch().url).toBe("/workfiles/10");
        });
    });

    describe("after the workfile and workspaces are fetched", function() {
        beforeEach(function() {
            this.workspace = backboneFixtures.workspace({ name: "me_neither" });

            this.server.completeFetchFor(this.workfile);
            this.server.completeFetchFor(chorus.session.user().workspaces(), [
                backboneFixtures.workspace({ name: "im_not_the_current_one'" }),
                this.workspace,
                backboneFixtures.workspace({ name: "yes_im_the_current_one", id: this.workspaceId })
            ]);
        });

        it("shows all of the user's workspaces", function() {
            expect(this.dialog.$("li").length).toBe(3);
        });

        it("has the right button text", function() {
            expect(this.dialog.$("button.submit")).toContainTranslation("workfile.copy_dialog.copy_file");
        });

        describe("clicking Copy File", function() {
            beforeEach(function() {
                spyOn(chorus, "toast");
                spyOn(chorus.router, "navigate");
                spyOn(chorus.PageEvents, "trigger");
                spyOn(this.dialog, "closeModal");

                this.dialog.workfile = this.workfile;
                this.dialog.render();

                this.dialog.$("li:eq(1)").click();
                this.dialog.$("button.submit").click();
            });

            it("calls the API", function() {
                expect(_.last(this.server.requests).url).toBe("/workfiles/" + this.workfile.get("id") + "/copy");
                expect(_.last(this.server.requests).method).toBe("POST");
            });

            describe("when the workfile contains a description", function() {
                beforeEach(function() {
                    this.workfile.set({ description: "my workfile" });
                    this.dialog.$("button.submit").click();
                });

                it("includes the description in the API call", function() {
                    expect(_.last(this.server.requests).requestBody).toContain("description=my+workfile");
                });
            });

            describe("when the workfile does not contain a description", function() {
                beforeEach(function() {
                    this.workfile.unset("description");
                    this.dialog.$("button.submit").click();
                });

                it("does not include the description in the API call", function() {
                    expect(_.last(this.server.requests).requestBody).not.toContain("description=my+workfile");
                });
            });

            describe("when the API is successful", function() {
                beforeEach(function() {
                    this.workfile.set({"fileName": "copied_filename.sql" });
                    this.server.lastCreate().succeed(this.workfile.attributes);
                });

                it("closes the dialog", function() {
                    expect(this.dialog.closeModal).toHaveBeenCalled();
                });

                it("pops toast", function() {
                    var copiedFileValue = this.workfile.showLink();
                    //this.workfile.get("fileName"),
                    var workspaceTargetValue = this.workspace.showLink();
                    //this.workspace.get("name"),
                    expect(chorus.toast).toHaveBeenCalledWith("workfile.copy_success.toast", {
                        workfileLink: copiedFileValue,
                        workspaceTarget: workspaceTargetValue,
                        toastOpts: {type: "success"}
                    });
                });

                it("does not navigate", function() {
                    expect(chorus.router.navigate).not.toHaveBeenCalled();
                });

                it("triggers the collection fetch event", function(){
                   expect(chorus.PageEvents.trigger).toHaveBeenCalled();
                });
            });

            describe("when the API fails", function() {
                beforeEach(function() {
                    this.dialog.closeModal.reset();
                    this.server.lastCreate().failUnprocessableEntity({ fields: { a: { BLANK: {} } } });
                });

                it("does not close the dialog", function() {
                    expect(this.dialog.closeModal).not.toHaveBeenCalled();
                });

                it("does not pop toast", function() {
                    expect(chorus.toast).not.toHaveBeenCalled();
                });

                it("displays the server error message", function() {
                    expect(this.dialog.$(".errors ul").text().trim()).toBe("A can't be blank");
                });
            });
        });
    });
});
