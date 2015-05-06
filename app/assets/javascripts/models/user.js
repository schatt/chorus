chorus.models.User = chorus.models.Base.extend({
    constructorName: "User",

    urlTemplate: "users/{{id}}",
    showUrlTemplate: "users/{{id}}",
    nameFunction: 'displayName',
    entityType: 'user',

    workspaces: function () {
        if (!this._workspaces) {
            this._workspaces = new chorus.collections.WorkspaceSet([], {userId: this.get("id")});
            this._workspaces.bind("reset", function () {
                this.trigger("change");
            }, this);
        }
        return this._workspaces;
    },

    activeWorkspaces: function() {
        if(!this._activeWorkspaces) {
            this._activeWorkspaces = new chorus.collections.WorkspaceSet([], {userId: this.get("id"), active: true});
        }

        return this._activeWorkspaces;
    },

    declareValidations: function (newAttrs) {
        this.require('firstName', newAttrs);
        this.require('lastName', newAttrs);
        this.require('username', newAttrs);
        this.requireValidEmailAddress('email', newAttrs);

        if (!this.ldap){
            this.requireConfirmationForChange('password', newAttrs);
        }
    },

    requireConfirmationForChange: function (name, newAttrs) {
        if (this.isNew() || (newAttrs && newAttrs.hasOwnProperty(name))) {
            this.require(name, newAttrs);
            this.requireConfirmation(name, newAttrs);
        }
    },

    hasImage: function () {
        return true;
    },

    fetchImageUrl: function (options) {
        var size = (options && options.size) || "original";
        var url = this.get("image") && this.get("image")[size];
        return url && new URI(url)
            .addSearch({ iebuster: chorus.cachebuster() })
            .toString();
    },

    createImageUrl: function() {
        var url = new URI(this.url());
        url.path(url.path() + "/image");
        return url.toString();
    },

    currentUserCanEdit: function() {
        var currentUser = chorus.session.user();
        return currentUser.isAdmin() || this.get("username") === currentUser.get("username");
    },

    currentUserCanDelete: function() {
        var currentUser = chorus.session.user();
        return currentUser.isAdmin() && this.get("username") !== currentUser.get("username");
    },

    isAdmin: function() {
        return !!this.get("admin");
    },

    picklistImageUrl: function () {
        return this.fetchImageUrl();
    },

    displayName: function () {
        if (!this.get('firstName') && !this.get('lastName') && this.get('fullName')) {
            return this.get('fullName');
        }
        return [this.get("firstName"), this.get("lastName")].join(' ');
    },

    displayShortName: function (length) {
        length = length || 20;

        var name = this.displayName();
        return (name.length < length) ? name : this.get("firstName") + " " + this.get("lastName")[0] + ".";
    },

    maxImageSize: function () {
        return chorus.models.Config.instance().get("fileSizesMbUserIcon");
    },

    attrToLabel: {
        "email":"users.email",
        "firstName":"users.first_name",
        "lastName":"users.last_name",
        "username":"users.username",
        "password":"users.password",
        "title":"users.title",
        "department":"users.department",
        "admin":"users.administrator"
    }
});
