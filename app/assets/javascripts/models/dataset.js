chorus.models.Dataset = chorus.models.Base.include(
    chorus.Mixins.DataSourceCredentials.model
).extend({
    nameAttribute: 'objectName',
    constructorName: "Dataset",
    entityType: "dataset",

    showUrlTemplate: "datasets/{{id}}",

    urlTemplate: function(options) {
        if(options && options.download) {
            return "datasets/{{id}}/download.csv";
        } else {
            return "datasets/{{id}}";
        }
    },

    initialize: function() {
        this.bind('invalidated', this.refetchAfterInvalidated, this);
        this.bind("change:associatedWorkspaces", this.invalidateWorkspacesAssociated, this);
        this.bind("change:tableauWorkbooks", this.invalidateTableauWorkbooks, this);

        if (!this.has("entitySubtype")) {
            this.set({entitySubtype: this.get("datasetType") || "SOURCE_TABLE"}, { silent: true });
        }
    },

    metaType: function() {
        return this.constructor.metaTypeMap[this.get("objectType")] || "table";
    },

    isDeleteable: function() {
        var entitySubtype = this.get("entitySubtype");
        return entitySubtype && (entitySubtype === "SOURCE_TABLE" || entitySubtype === "CHORUS_VIEW");
    },

    isHdfsDataset: function () {
        return this.get('entitySubtype') === "HDFS";
    },

    isOracle: function() {
        return this.dataSource() && this.dataSource().isOracle();
    },

    isJdbc: function() {
        return this.dataSource() && this.dataSource().isJdbc();
    },

    isJdbcHive: function() {
        return this.dataSource() && this.dataSource().isJdbcHive();
    },

    isGreenplum: function() {
        return this.dataSource().isGreenplum();
    },

    isPostgres: function() {
        return this.dataSource().isPostgres();
    },

    isExternal: function() {
        var objectType = this.statistics().get("objectType");
        return (/EXT_TABLE$/).test(objectType);
    },

    columns: function(options) {
        if (!this._columns) {
            this._columns = new chorus.collections.DatabaseColumnSet([], {
                id: this.get("id"),
                type: options && options.type
            });

            this._columns.dataset = this;
            var objectNameField = this.metaType() + "Name";
            this._columns.attributes[objectNameField] = (this.metaType() === "query") ? this.get("id") : this.name();
        }
        return this._columns;
    },

    dataSource: function() {
        return this.schema() && this.schema().dataSource();
    },

    database: function() {
        return this.schema().database();
    },

    getImports: $.noop,

    lastImport: $.noop,

    hasImport: function() {
        return this.getImports() && !this.getImports().isEmpty();
    },

    canExport:function () {
        return this.workspace() && this.workspace().canUpdate() &&
            this.hasCredentials() &&
            this.canBeImportSource();
    },

    schema: function() {
        var schema = this._schema || this.get("schema") && new chorus.models.Schema(this.get("schema"));
        if(this.loaded) {
            this._schema = schema;
        }
        return schema;
    },

    setSchema: function(newSchema) {
        this.set('schema', newSchema.attributes);
    },

    workspace: function() {
        if (!this._workspace && this.get("workspace")) {
            this._workspace = new chorus.models.Workspace(this.get("workspace"));
        }
        return this._workspace;
    },

    workspacesAssociated: function() {
        if (!this._workspaceAssociated) {
            var workspaceList = this.get("associatedWorkspaces");
            this._workspaceAssociated = new chorus.collections.WorkspaceSet(workspaceList);
        }
        return this._workspaceAssociated;

    },

    tableauWorkbooks: function() {
        if (!this._tableauWorkbooks) {
            var workbookList = this.get("tableauWorkbooks");
            this._tableauWorkbooks = new chorus.collections.TableauWorkbookSet(workbookList);
        }
        return this._tableauWorkbooks;
    },

    workspaceArchived: function() {
        return this.workspace() && !this.workspace().isActive();
    },

    invalidateWorkspacesAssociated: function() {
        delete this._workspaceAssociated;
    },

    invalidateTableauWorkbooks: function() {
        delete this._tableauWorkbooks;
    },

    statistics: function() {
        if (!this._statistics) {
            this._statistics = new chorus.models.DatasetStatistics({ datasetId: this.id });
        }

        return this._statistics;
    },

    iconUrl: function(options) {
        var size = (options && options.size) || "large";
        var name = this.constructor.iconMap[this.get("entitySubtype")][this.get("objectType")];
        return "/images/data_sets/" + name + "_" + size + ".png";
    },

    lastComment: function() {
        var commentsJson = this.get("recentComments");
        if (commentsJson && commentsJson.length > 0) {
            var comment = new chorus.models.Comment({
                body: commentsJson[0].body,
                author: commentsJson[0].author,
                commentCreatedStamp: commentsJson[0].timestamp
            });

            comment.loaded = true;
            return comment;
        }
    },

    preview: function() {
        return new chorus.models.DataPreviewTask({
            dataset: {id: this.id},
            objectName: this.name()
        });
    },

    download: function(options) {
        var data = { };
        if (options && options.rowLimit) {
            data.row_limit = options.rowLimit;
        }

        chorus.fileDownload(this.url({download: true}), {data: data});
    },

    isChorusView: function() {
        return false;
    },

    refetchAfterInvalidated: function() {
        this.collection && this.fetch();
    },

    useQuotes: function() {
        return !this.isJdbcHive();
    },

    quotedName: function() {
        return (this.useQuotes())? this.ensureDoubleQuoted(this.name()) : this.ensureNotDoubleQuoted(this.name());
    },

    quotedSchemaName: function() {
        return (this.useQuotes())? this.ensureDoubleQuoted(this.schema().name()) : this.ensureNotDoubleQuoted(this.schema().name());
    },

    toText: function() {
        if (this.has("query")) {
            var query = this.get("query").trim().replace(/;$/, "").trim();
            return "(" + query + ") AS " + this.quotedName();
        } else {

            return this.quotedSchemaName() + '.' + this.quotedName();
        }
    },

    selectName: function() {
        if (this.aliasedName) {
            return this.aliasedName;
        }
        return this.quotedName();
    },

    setDatasetNumber: function(number) {
        this.datasetNumber = number;
        this.aliasedName = String.fromCharCode(96 + this.datasetNumber);
    },

    clearDatasetNumber: function() {
        delete this.datasetNumber;
        delete this.aliasedName;
    },

    fromClauseBody: function() {
        if (this.has("query")) {
            return "(" + this.get("query") + ")";
        }
        return this.quotedSchemaName() + "." + this.quotedName();
    },

    alias: function() {
        return this.aliasedName || this.quotedName();
    },

    aliased: function() {
        return this.datasetNumber || this.has("query");
    },

    fromClause: function() {
        if (this.aliased()) {
            return this.fromClauseBody() + " AS " + ((this.useQuotes())? this.ensureDoubleQuoted(this.alias()) :  this.ensureNotDoubleQuoted(this.alias()));
        }
        return this.fromClauseBody();
    },

    canBeImportSource: function() {
        return false;
    },

    canBeImportDestination: function() {
        return false;
    },

    canBeImportSourceOrDestination: function() {
        return this.canBeImportSource() || this.canBeImportDestination();
    },

    asWorkspaceDataset: function() {
        return new chorus.models.WorkspaceDataset(this);
    },

    hasCredentials: function() {
        return this.get('hasCredentials') !== false;
    },

    supportsAnalyze: function() {
        return this.get("objectType") === "TABLE" && (this.isGreenplum() || this.isPostgres());
    },

    canAnalyze: function() {
        return this.hasCredentials() && this.supportsAnalyze() && !this.workspaceArchived() && !this.isExternal();
    },

    analyze: function() {
        if (!this._analyze) {
            this._analyze = new chorus.models.DatasetAnalyze({
                tableId: this.get("id")
            });
        }

        return this._analyze;
    },

    makeBoxplotTask: function(taskAttrs) {
        return new chorus.models.BoxplotTask({
            xAxis: taskAttrs.xAxis,
            yAxis: taskAttrs.yAxis,
            dataset: this,
            bins: taskAttrs.bins
        });
    },

    makeFrequencyTask: function(taskAttrs) {
        return new chorus.models.FrequencyTask({
            yAxis: taskAttrs.yAxis,
            dataset: this,
            bins: taskAttrs.bins
        });
    },

    makeHistogramTask: function(taskAttrs) {
        return new chorus.models.HistogramTask({
            bins: taskAttrs.bins,
            xAxis: taskAttrs.xAxis,
            dataset: this
        });
    },

    makeHeatmapTask: function(taskAttrs) {
        return new chorus.models.HeatmapTask({
            xBins: taskAttrs.xBins,
            yBins: taskAttrs.yBins,
            xAxis: taskAttrs.xAxis,
            yAxis: taskAttrs.yAxis,
            dataset: this
        });
    },

    makeTimeseriesTask: function(taskAttrs) {
        return new chorus.models.TimeseriesTask({
            xAxis: taskAttrs.xAxis,
            yAxis: taskAttrs.yAxis,
            aggregation: taskAttrs.aggregation,
            timeInterval: taskAttrs.timeInterval,
            dataset: this,
            timeType: taskAttrs.timeType
        });
    },

    deriveTableauWorkbook: function() {
        return new chorus.models.TableauWorkbook({
            dataset: this,
            name: this.get('objectName')
        });
    },

    humanType: function() {
        return t(['dataset.entitySubtypes',this.get("entitySubtype"),this.get("objectType")].join("."));
    }
}, {
    metaTypeMap: {
        "TABLE": "table",
        "VIEW": "view",
        "EXTERNAL_TABLE": "table",
        "MASTER_TABLE": "table",
        "CHORUS_VIEW": "query",
        "MASK": "mask"
    },

    iconMap: {
        "CHORUS_VIEW": {
            CHORUS_VIEW: "chorus_view"
        },

        "SOURCE_TABLE": {
            "TABLE": "source_table",
            "EXTERNAL_TABLE": "source_table",
            "MASTER_TABLE": "source_table",
            "VIEW": "source_view",
            "HDFS_EXTERNAL_TABLE": "source_table"
        },

        "SANDBOX_TABLE": {
            "TABLE": "sandbox_table",
            "EXTERNAL_TABLE": "sandbox_table",
            "MASTER_TABLE": "sandbox_table",
            "VIEW": "sandbox_view",
            "HDFS_EXTERNAL_TABLE": "sandbox_table"
        },

        "HDFS": {
            "MASK": "hdfs_dataset"
        }
    }
});
