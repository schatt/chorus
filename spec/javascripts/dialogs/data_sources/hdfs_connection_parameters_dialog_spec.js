describe("chorus.dialogs.HdfsConnectionParameters", function () {
    beforeEach(function () {
        this.hadoop = backboneFixtures.hdfsDataSource();
        this.dialog = new chorus.dialogs.HdfsConnectionParameters({model: this.hadoop});
    });

    it("has a title", function () {
        expect(this.dialog.title).toContainTranslation('hdfs_connection_parameters.dialog.title');
    });

    describe("editing an existing datasource", function () {
        beforeEach(function () {
            this.hadoop = backboneFixtures.hdfsDataSource();
            this.dialog = new chorus.dialogs.HdfsConnectionParameters({model: this.hadoop});
        });

        xit("displays a pair of input fields for every parameter", function () {
            var numberOfFields = this.dialog.$('input.key').length;
            var numberOfParameters = this.hadoop.get('connectionParameters').length;
            expect(numberOfFields).toEqual(numberOfParameters);
        });
    });

    context("on a new model", function () {
        beforeEach(function () {
            this.hadoop = new chorus.models.HdfsDataSource();
            this.dialog = new chorus.dialogs.HdfsConnectionParameters({model: this.hadoop});
            this.dialog.render();
        });

        it("shows an empty pair of input fields", function () {
            expect(this.dialog.$('input.key')).toExist();
            expect(this.dialog.$('input.value')).toExist();
        });

        it("displays a link to add a row", function () {
            expect(this.dialog.$('a.add_pair')).toExist();
            expect(this.dialog.$('a.add_pair')).toContainTranslation('hdfs_connection_parameters.dialog.add_pair');
        });

        describe("clicking add pair", function () {
            beforeEach(function () {
                this.currentPairs = this.dialog.$('.pair').length;
            });

            it('adds another pair', function () {
                this.dialog.$('.add_pair').click();
                expect(this.dialog.$('.pair').length).toBe(this.currentPairs + 1);
            });
        });

        describe("clicking 'remove'", function () {
            beforeEach(function () {
                this.currentPairs = this.dialog.$('.pair').length;
            });

            it('removes the adjacent pair', function () {
                this.dialog.$('.remove_pair').eq(0).click();
                expect(this.dialog.$('.pair').length).toBe(this.currentPairs - 1);
            });
        });

        // TODO: Test the "hadoop_configuration_param_set" fetching dialog.
    });

    describe("submitting", function () {
        beforeEach(function () {
            this.originalPairs = [{key: '1', value: 'v1'}, {key: '2', value: 'v2'}];
            this.hadoop = new chorus.models.HdfsDataSource({connectionParameters: this.originalPairs});
            this.dialog = new chorus.dialogs.HdfsConnectionParameters({model: this.hadoop});
            this.dialog.render();
        });


        it("sets connection parameters on the model based on the field values", function () {
            expect(this.hadoop.get('connectionParameters')).toEqual(this.originalPairs);

            this.dialog.$('.pair .key').eq(0).val('foo');
            this.dialog.$('.pair .value').eq(0).val('bar');
            this.dialog.$('.remove_pair').eq(1).click();

            this.dialog.$('button.submit').click();

            expect(this.hadoop.get('connectionParameters')).toEqual([{key: 'foo', value: 'bar'}]);
        });

    });
});