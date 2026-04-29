/**
 * Descriptor for property-vs-property comparisons (eqProperty/neProperty/etc.).
 * Simple name mirrors org.hibernate.criterion.PropertyExpression.
 */
component {
	function init( required string op, required string left, required string right ) {
		this.type  = "cmpProperty";
		this.op    = arguments.op;      // "eq" | "ne" | "gt" | "ge" | "lt" | "le"
		this.left  = arguments.left;
		this.right = arguments.right;
		return this;
	}
}
