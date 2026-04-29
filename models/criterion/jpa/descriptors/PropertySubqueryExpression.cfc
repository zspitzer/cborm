/**
 * Descriptor for property comparison against a subquery (eq/ne/gt/ge/lt/le).
 * Simple name mirrors org.hibernate.criterion.PropertySubqueryExpression.
 */
component {
	function init( required string op, required string path, required any subquery ) {
		this.type     = "subqueryCompare";
		this.op       = arguments.op;
		this.path     = arguments.path;
		this.subquery = arguments.subquery;
		return this;
	}
}
