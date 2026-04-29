/**
 * Descriptor for EXISTS / NOT EXISTS subquery.
 * Simple name mirrors org.hibernate.criterion.ExistsSubqueryExpression.
 */
component {
	function init( required any subquery, boolean negate = false ) {
		this.type     = "subqueryExists";
		this.subquery = arguments.subquery;
		this.negate   = arguments.negate;
		return this;
	}
}
