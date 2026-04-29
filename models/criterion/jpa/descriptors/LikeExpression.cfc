/**
 * Descriptor for LIKE / ILIKE comparisons.
 * Simple name mirrors org.hibernate.criterion.LikeExpression.
 */
component {
	function init( required string type, required string path, required string value ) {
		this.type  = arguments.type;
		this.path  = arguments.path;
		this.value = arguments.value;
		return this;
	}
}
