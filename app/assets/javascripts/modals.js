chorus.Modal = chorus.views.Base.extend({
    constructorName: "Modal",
    focusSelector: "input:eq(0)",
    verticalPosition: 40, // distance of dialog from top of window

    launchModal: function() {
        if (chorus.modal && this !== chorus.modal) {
            chorus.modal.launchSubModal(this);
        } else {
            this.launchNewModal();
        }
    },

    launchNewModal:function () {
        this.render();
        $(document).one('reveal.facebox', _.bind(this.beginReveal, this));
        $.facebox(this.el);
        this.previousModal = chorus.modal;
        this.restore();
        this.showErrors();
    },

    launchSubModal: function(subModal) {
        this.ignoreFacebox();
        this.background();

        $.facebox.settings.inited = false;
        subModal.launchNewModal();
    },

    resize: function(windowWidth, windowHeight) {

    /* jshint ignore:start */
//     console.log ("modals.js RESIZE****** wd:" + windowWidth + " | ht:" + windowHeight);


// BEGIN: move .errors inside of .girdle
// TODO: fix when dialogs are redone

    $(".girdle").prepend($(".errors"));

// END: move the .errors


        var $facebox = $('#facebox');
        var $popup = $("#facebox .popup");

        var $window = $(window);

        var verticalPositionValue = this.verticalPosition;
//          if (typeof verticalPositionValue === "undefined") {
//              console.log ("verticalPositionValue undefined");
//              verticalPositionValue = $(window).verticalPositionValue;
//              console.log ("1 verticalPositionValue " + verticalPositionValue);
//              verticalPositionValue = $(document).verticalPositionValue;
//              console.log ("2 verticalPositionValue " + verticalPositionValue);
//         }


//     console.log ("modals.js > resize: windowHeight A:" + windowHeight);
        if (!windowHeight) windowHeight = $window.height();
//     console.log ("modals.js > resize: windowHeight B:" + windowHeight);
//     console.log ("modals.js > resize: this.verticalPosition 1:" + this.verticalPosition);
//     console.log ("modals.js > resize: this.verticalPosition 2:" + verticalPositionValue);

       
        //position the dialog vertically in the window
        // $facebox.css('top', this.verticalPosition + 'px');
        $facebox.css('top', verticalPositionValue + 'px');

// console.log ("modals.js > resize: top of facebox:" + $facebox.offset().top);


        //calculate max height based on current window
        // var popupHeight = windowHeight - this.verticalPosition * 2;
        var popupHeight = windowHeight - verticalPositionValue * 2;
        $popup.css("max-height", popupHeight + "px");
// console.log ("modals.js > resize: popupHeight:" + popupHeight);

        
        //calculate max height for interior content
        // 1st: find height of the dialog header and footer...
        var headerHeight = $("#dialog_header").height();
        var bottomHeight = $("#dialog_bottom").height();

        // ...if errors are outside of .girdle, then chek if .errors has any height
        // if YES, then that height will need to be added to the overall available height
        var errorHeight = $(".dialog .errors").height();
        errorHeight = isNaN (errorHeight) ? errorHeight : 0;

        // 2nd: figure out height inside .girdle
        // and account for the visual padding
        var girdleHeight = $(".girdle").height();
        var girdleVerticalPadding = $(".girdle").innerHeight() - girdleHeight;
        

// console.log ("modals// .js > resize: girdleVerticalPadding:" + girdleVerticalPadding);
        
        // 3rd: max height will be (total height of popup) - (the sum of the other heights) 
        var maxInteriorHeight = popupHeight - (headerHeight + bottomHeight + errorHeight + girdleVerticalPadding);
// console.log ("modals.js > resize: maxInteriorHeight A:" + maxInteriorHeight);

       //  maxInteriorHeight = maxInteriorHeight- girdleVerticalPadding;
// console.log ("modals.js > resize: maxInteriorHeight B:" + maxInteriorHeight);
        
        var $dialogInteriorContent = $("#dialog_content .girdle");
        $dialogInteriorContent.css("max-height", maxInteriorHeight + "px");
        
//         console.log ("modals.js > resize: max-height:" + maxInteriorHeight);
//         console.log ("modals.js > resize: error-height:" + errorHeight);

/* jshint ignore:end */
    },

    preRender: function() {
        var result = this._super('preRender', arguments);

        $(window).resize(this.resize);

        this.preventScrollingBody();
        return result;
    },

    centerHorizontally: function () {
        $('#facebox').css('left', $(window).width() / 2 - ($('#facebox .popup').width() / 2));
    },

    postRender: function() {
        this._super("postRender");
        this.centerHorizontally();
    },

    makeModel:function (options) {
        if (options && options.pageModel) {
            this.pageModel = options.pageModel;
            this.model = this.model || this.pageModel;
        }
    },

    closeModal:function (success) {
        $(document).trigger("close.facebox");
        if (success === true) {
            $(document).trigger("close.faceboxsuccess");
        }
    },

    keydownHandler:function (e) {
        if (e.keyCode === 27) {
            this.escapePressed();
        }
    },

    escapePressed:function () {
        this.closeModal();
    },

    modalClosed:function () {
        if (this === chorus.modal) {
            this.close();
            $("#facebox").remove();
            $.facebox.settings.inited = false;
            chorus.PageEvents.trigger("modal:closed", this);

            delete chorus.modal;
            this.ignoreFacebox();

            if (this.previousModal) {
                this.previousModal.restore();
            } else {
                this.restoreScrollingBody();
            }
        }
        this.teardown();
    },

    restore: function () {
        chorus.modal = this;
        this.foreground();
        this.listenToFacebox();
        this.recalculateScrolling();
        _.defer(this.resize);
    },

    foreground: function () {
        $("#facebox-" + this.faceboxCacheId).attr("id", "facebox").removeClass("hidden");
        $("#facebox_overlay-" + this.faceboxCacheId).attr("id", "facebox_overlay");
        this.resize();
    },

    background: function () {
        this.faceboxCacheId = Math.floor((Math.random()*1e8)+1).toString();
        $("#facebox").attr("id", "facebox-" + this.faceboxCacheId).addClass("hidden");
        $("#facebox_overlay").attr("id", "facebox_overlay-" + this.faceboxCacheId);
    },

    listenToFacebox: function() {
        this.boundModalClosed = _.bind(this.modalClosed, this);
        this.boundKeyDownHandler = _.bind(this.keydownHandler, this);
        $(document).one("close.facebox", this.boundModalClosed);
        $(document).bind("keydown.facebox", this.boundKeyDownHandler);
    },

    ignoreFacebox: function() {
        $(document).unbind("close.facebox", this.boundModalClosed);
        $(document).unbind("keydown.facebox", this.boundKeyDownHandler);
        delete this.boundModalClosed;
        delete this.boundKeyDownHandler;
    },

    preventScrollingBody: function() {
        $("body").css("overflow", "hidden");
    },

    restoreScrollingBody: function() {
        $("body").css("overflow", "visible");
    },

    close:$.noop,
    revealed: $.noop,

    beginReveal: function() {
        this.revealed();
        if (this.focusSelector) {
            this.$(this.focusSelector).focus();
        }
    },

    saveFailed: function(model) {
        this.$("button.submit").stopLoading();
        this.$("button.cancel").prop("disabled", false);
        if(model) {
            this.showErrors(model);
        } else {
            this.showErrors();
        }
    }
});

if (window.jasmine) {
    chorus.Modal.prototype.preventScrollingBody = $.noop;
    chorus.Modal.prototype.restoreScrollingBody = $.noop;
}
