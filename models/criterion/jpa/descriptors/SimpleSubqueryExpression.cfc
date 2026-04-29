/**
 * Descriptor for property IN / NOT IN subquery.
 * Simple name mirrors org.hibernate.criterion.SimpleSubqueryExpression.
 */
component {
	function init( required string path, required any subquery, boolean negate = false ) {
		this.type     = "subqueryIn";
		this.path     = arguments.path;
		this.subquery = arguments.subquery;
		this.negate   = arguments.negate;
		return this;
	}
}
