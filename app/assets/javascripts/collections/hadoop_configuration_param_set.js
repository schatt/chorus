chorus.collections.HadoopConfigurationParamSet = chorus.collections.Base.extend({
    urlTemplate: 'hdfs_params?host={{host}}&port={{port}}',
    urlParams: function() {
        return this.models[0].attributes;
    }
});
