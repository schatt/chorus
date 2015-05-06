chorus.Mixins.dbHelpers = {
    ensureDoubleQuoted: function() {
        function encode(name) {
            var doubleQuoted = name.match(chorus.ValidationRegexes.DoubleQuoted());
            return doubleQuoted ? name : '"' + name + '"';
        }

        return _.map(arguments, function(arg) {
            return encode(arg);
        }).join('.');
    },

    ensureNotDoubleQuoted: function() {
        function unencode(name) {
            var doubleQuoted = name.match(chorus.ValidationRegexes.DoubleQuoted());
            return doubleQuoted ? name.substring(1, name.length - 1) : name;
        }

        return _.map(arguments, function(arg) {
            return unencode(arg);
        }).join('.');
    },

    sqlEscapeString: function(string) {
        return string.replace(/'/g, "''");
    }
};
