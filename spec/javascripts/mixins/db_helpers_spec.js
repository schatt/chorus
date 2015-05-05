describe("chorus.Mixins.dbHelpers", function() {
    describe(".ensureDoubleQuoted", function() {
        beforeEach(function() {
            this.originalValidationRegexes = chorus.ValidationRegexes;
        });

        afterEach(function() {
            chorus.ValidationRegexes = this.originalValidationRegexes;
        });

        context("with one argument", function() {
            it("ensures the name starts and ends with a double quote", function () {
                expect(chorus.Mixins.dbHelpers.ensureDoubleQuoted('foo')).toBe('"foo"');
                expect(chorus.Mixins.dbHelpers.ensureDoubleQuoted('Foo')).toBe('"Foo"');
            });
        });

        context("with two arguments", function() {
            it("encodes each argument separately, then concatenates them with '.'", function() {
                expect(chorus.Mixins.dbHelpers.ensureDoubleQuoted("Foo", "bar")).toBe('"Foo"."bar"');
            });
        });
    });

    describe(".ensureNotDoubleQuoted", function() {
        beforeEach(function() {
            this.originalValidationRegexes = chorus.ValidationRegexes;
        });

        afterEach(function() {
            chorus.ValidationRegexes = this.originalValidationRegexes;
        });

        context("with one argument", function() {
            it("ensures the name starts and ends with a double quote", function () {
                expect(chorus.Mixins.dbHelpers.ensureNotDoubleQuoted('"foo"')).toBe('foo');
                expect(chorus.Mixins.dbHelpers.ensureNotDoubleQuoted('"Foo"')).toBe('Foo');
            });
        });

        context("with two arguments", function() {
            it("encodes each argument separately, then concatenates them with '.'", function() {
                expect(chorus.Mixins.dbHelpers.ensureNotDoubleQuoted('"Foo"', '"bar"')).toBe('Foo.bar');
            });
        });
    });

    describe("pgsqlRealEscapeString", function() {
        it("replaces single quotes with two single quotes", function() {
            expect(chorus.Mixins.dbHelpers.sqlEscapeString("John's Father's Boat's Hull")).toBe("John''s Father''s Boat''s Hull");
        });
    });
});
