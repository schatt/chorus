;(function() {
    var CLASS_MAP = {
        "actor": "User",
        "dataset": "WorkspaceDataset",
        "greenplumInstance": "GreenplumInstance",
        "newOwner": "User",
        "hadoopInstance": "HadoopInstance",
        "workfile": "Workfile",
        "workspace": "Workspace",
        "newUser" : "User",
        "noteObject" : "NoteObject",
        "hdfsEntry" : "HdfsEntry",
        "member": "User",
        "sourceDataset": "WorkspaceDataset"
    };

    chorus.models.Activity = chorus.models.Base.extend({
        constructorName: "Activity",
        urlTemplate: "activities/{{id}}",

        author: function() {
            if (!this._author && this.has("author")) {
                this._author = new chorus.models.User(this.get("author"))
            }

            return this._author;
        },

        newOwner: makeAssociationMethod("newOwner"),
        workspace: makeAssociationMethod("workspace"),
        actor: makeAssociationMethod("actor"),
        greenplumInstance: makeAssociationMethod("greenplumInstance"),
        hadoopInstance: makeAssociationMethod("hadoopInstance"),
        workfile: makeAssociationMethod("workfile"),
        newUser: makeAssociationMethod("newUser"),
        member: makeAssociationMethod("member"),

        dataset: makeAssociationMethod("dataset", function(model) {
            model.set({workspace: this.get("workspace")}, {silent: true});
        }),

        importSource: makeAssociationMethod("sourceDataset", function(model) {
            model.set({workspace: this.get("workspace")}, {silent: true});
        }),

        hdfsEntry: makeAssociationMethod("hdfsEntry", function(model) {
            var hdfsFile = this.get("hdfsFile");
            var pathArray = hdfsFile.path.split("/");
            var path = _.first(pathArray, pathArray.length - 1).join('/');
            var name = _.last(pathArray);
            model.set({
                hadoopInstance: { id : hdfsFile.hadoopInstanceId},
                path : path,
                name : name
            })
        }),

        noteObject: function() {
            var model;

            switch (this.get("actionType")) {
                case "NoteOnHadoopInstance":
                    model = new chorus.models.HadoopInstance();
                    model.set(this.get("hadoopInstance"));
                    break;
                case "NoteOnGreenplumInstance":
                    model = new chorus.models.GreenplumInstance();
                    model.set(this.get("greenplumInstance"));
                    break;
                case "NoteOnHdfsFile":
                    model = new chorus.models.HdfsFile();
                    model.set({
                        hadoopInstance: new chorus.models.HadoopInstance({ id: this.get("hdfsFile").hadoopInstanceId }),
                        path: this.get("hdfsFile").path
                    });
                    break;
                case "NoteOnWorkspace":
                    model = new chorus.models.Workspace();
                    model.set(this.get("workspace"));
                    break;
                case "NoteOnDataset":
                    model = new chorus.models.Dataset();
                    model.set(this.get("dataset"));
                    break;
                case "NoteOnWorkspaceDataset":
                    model = new chorus.models.WorkspaceDataset();
                    model.set(this.get("dataset"));
                    break;
                case "NoteOnWorkfile":
                    model = new chorus.models.Workfile();
                    model.set(this.get("workfile"));
                    break;
            }
            return model;
        },

        comments: function() {
            this._comments || (this._comments = new chorus.collections.CommentSet(
                this.get("comments"), {
                    entityType: this.collection && this.collection.attributes.entityType,
                    entityId: this.collection && this.collection.attributes.entityId
                }
            ));
            return this._comments;
        },

        parentComment: function() {
            if (this.get("parentComment")) {
                this._parentComment || (this._parentComment = new chorus.models.Activity(this.get("parentComment")));
            }

            return this._parentComment;
        },

        promoteToInsight: function(options) {
            var insight = new chorus.models.CommentInsight({
                id: this.get("id"),
                action: "promote"
            });
            insight.bind("saved", function() {
                this.collection.fetch();
                if (options && options.success) {
                    options.success(this);
                }
            }, this);

            insight.save(null, { method: "create" });
        },

        publish: function() {
            var insight = new chorus.models.CommentInsight({
                id: this.get("id"),
                action: "publish"
            });

            insight.bind("saved", function() {
                this.collection.fetch();
            }, this);

            insight.save(null, { method: "create" });
        },

        unpublish: function() {
            var insight = new chorus.models.CommentInsight({
                id: this.get("id"),
                action: "unpublish"
            });

            insight.bind("saved", function() {
                this.collection.fetch();
            }, this);

            insight.save(null, { method: "create" });
        },

        toNote: function() {
            var comment = new chorus.models.Note({
                id: this.id,
                body: this.get("body")
            });

            comment.bind("destroy", function() {
                this.collection.fetch();
            }, this);

            comment.bind("saved", function() {
                this.collection.fetch();
            }, this)

            return comment;
        },

        attachments: function() {
            if (!this._attachments) {
                this._attachments = _.map(this.get("attachments"), function(artifactJson) {
                    var klass;
                    switch (artifactJson.entityType) {
                        case 'workfile':
                            klass = chorus.models.Workfile;
                            break;
                        case 'chorusView':
                        case 'dataset':
                            klass = chorus.models.WorkspaceDataset;
                            break;
                        default:
                            klass = chorus.models.Attachment;
                            break;
                    }
                    return new klass(artifactJson);
                });
            }
            return this._attachments;
        },

        isNote: function() {
            return this.get("action") === "NOTE";
        },

        isInsight: function() {
            return this.get("type") === "INSIGHT_CREATED";
        },

        isSubComment: function() {
            return this.get("type") === "SUB_COMMENT";
        },

        hasCommitMessage: function() {
            return this.get("action") === "WorkfileUpgradedVersion"  && this.get("commitMessage")
        },

        isUserGenerated: function () {
            return this.isNote() || this.isInsight() || this.isSubComment();
        },

        isPublished: function() {
            return this.get("isPublished") === true;
        },

        isOwner: function() {
            return (this.actor().id === chorus.session.user().id);
        },

        isFailure: function() {
            return this.get("action") === "FileImportFailed" ||  this.get("action") === "DatasetImportFailed" ;
        },

        isSuccessfulImport: function() {
            return this.get("action") === "FileImportSuccess" ||  this.get("action") === "DatasetImportSuccess" ;
        }
    });

    function makeAssociationMethod(name, setupFunction) {
        return function() {
            var className = CLASS_MAP[name];
            var modelClass = chorus.models[className];
            var model = new modelClass(this.get(name));
            if (setupFunction) setupFunction.call(this, model);
            return model;
        };
    }
})();
