component {

	this.name              = "cborm-h73-spike";
	this.sessionManagement = false;

	// expose the cborm root as /cborm so `cborm.models.criterion.jpa.*` resolves
	this.mappings[ "/cborm" ] = expandPath( "../.." );

	this.datasources[ "spike" ] = {
		  class            : "org.hsqldb.jdbcDriver"
		, bundleName       : "org.lucee.hsqldb"
		, connectionString : "jdbc:hsqldb:mem:cbormh73spike;shutdown=true"
		, username         : "sa"
		, password         : ""
	};
	this.datasource = "spike";

	this.ormEnabled  = true;
	this.ormSettings = {
		dialect            : "org.hibernate.dialect.HSQLDialect",
		cfclocation        : [ "entities" ],
		dbcreate           : "dropcreate",
		eventhandling      : false,
		flushAtRequestEnd  : false,
		automanageSession  : false,
		secondaryCacheEnabled : false
	};

}
