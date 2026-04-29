/**
 * Descriptor for collection size comparisons (sizeEq / sizeNe / sizeGt / sizeGe / sizeLt / sizeLe).
 * Simple name mirrors org.hibernate.criterion.SizeExpression.
 */
component {
	function init( required string op, required string path, required numeric size ) {
		this.type = "sizeCmp";
		this.op   = arguments.op;       // "eq" | "ne" | "gt" | "ge" | "lt" | "le"
		this.path = arguments.path;
		this.size = arguments.size;
		return this;
	}
}
