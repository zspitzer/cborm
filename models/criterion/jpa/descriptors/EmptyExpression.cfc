/**
 * Descriptor for collection IS EMPTY / IS NOT EMPTY.
 * Simple name mirrors org.hibernate.criterion.EmptyExpression.
 */
component {
	function init( required string type, required string path ) {
		this.type = arguments.type;     // "isEmpty" | "isNotEmpty"
		this.path = arguments.path;
		return this;
	}
}
