/**
 * Descriptor for IN.
 * Simple name mirrors org.hibernate.criterion.InExpression.
 */
component {
	function init( required string path, required array values ) {
		this.type   = "in";
		this.path   = arguments.path;
		this.values = arguments.values;
		return this;
	}
}
