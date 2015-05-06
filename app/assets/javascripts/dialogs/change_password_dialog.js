chorus.dialogs.ChangePassword = chorus.dialogs.Base.extend({
    templateName: "dialogs/change_password",
    title: function() {
        return this.changeSelfPassword() ? t("user.change_password_self.title") : t("user.change_password.title");
    },
    
    events: {
        "submit form":"save"
    },
    persistent: true,

    setup: function() {
        this.listenTo(this.model, "saved", this.saved);
    },

    changeSelfPassword: function () {
        var sessionUserID = chorus.session.user().get("id");
        var passwordUserID = this.model.get("id");
        return (sessionUserID === passwordUserID) ? true : false;
    },

    save:function (e) {
        e && e.preventDefault();

        this.model.save({
            password: this.$("input[name=password]").val(),
            passwordConfirmation: this.$("input[name=passwordConfirmation]").val()
        });
    },

    saved:function () {
        this.model.trigger('invalidated');
        this.showSavedToast();
        this.closeModal();
    },

    showSavedToast: function() {
        // conditionalize the toast: 
        // whether you are changing your own password or another password
        var toastMessage, fullName;
        if (this.changeSelfPassword()) {
            toastMessage = "user.change_password_self.success.toast";
        }
        else {
            toastMessage = "user.change_password.success.toast";
            fullName =  this.model.displayName();
        }
        chorus.toast(toastMessage, {fullName: this.model.displayName(), toastOpts: {type: "success"}});
    }
});
