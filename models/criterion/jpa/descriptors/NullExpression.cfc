/**
 * Descriptor for IS NULL / IS NOT NULL.
 * Simple name mirrors org.hibernate.criterion.NullExpression.
 */
component {
	function init( required string type, required string path ) {
		this.type = arguments.type;     // "isNull" | "isNotNull"
		this.path = arguments.path;
		return this;
	}
}
