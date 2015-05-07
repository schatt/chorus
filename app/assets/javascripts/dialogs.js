chorus.dialogs.Base = chorus.Modal.extend ({
    constructorName: "Dialog",

    render: function() {
        if(this.hasBeenClosed) {
            return this;
        }

        this.preRender();

// TODO replace with an actual template, instead of 'generated' stuff
        var header = $("<div id='dialog_header' class='dialog_header'/></div>");
        var errors = $("<div id='dialog_errors' class='errors hidden'/></div>");
        var content = $("<div id='dialog_content' class='dialog_content'/></div>");

        this.events = this.events || {};

        this.events["click .form_controls button.cancel"] = "closeModal";

        header.html($("<h1/>").text(_.result(this, 'title')));
        content.html(this.template(this.context()));
        content.attr("data-template", this.className);
        
        $(this.el).
            empty().
            append(header).
            append(errors).
            append(content);

        $(this.el).
            addClass(this.className).
            addClass("dialog").
            addClass(this.additionalClass || "");
            
// new
//         $(this.el).
//             empty().
//             append(header).
//             append(content).
//             addClass(this.className).
//             addClass("dialog").
//             addClass(this.additionalClass || "");
// TODO intending to move the errors into the girdle node


        this.delegateEvents();
        this.renderSubviews();
        this.renderHelps();
        this.postRender($(this.el));
        chorus.placeholder(this.$("input[placeholder], textarea[placeholder]"));

        return this;
    },

    modalClosed: function () {
        this._super("modalClosed");
        this.hasBeenClosed = true;
    },

    revealed: function () {
        $("#facebox").removeClass().addClass("dialog_facebox");
    },

    showDialogError : function(errorText) {
        var resource = this.resource || this.model;
        var serverErrors = resource.serverErrors || {};
        serverErrors.message = errorText;
        resource.serverErrors = serverErrors;
        this.displayServerErrors(resource);
    }
});
