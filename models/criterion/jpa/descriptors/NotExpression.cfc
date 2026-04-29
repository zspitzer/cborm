/**
 * Negation wrapper around another descriptor.
 * Simple name mirrors org.hibernate.criterion.NotExpression.
 */
component {
	function init( required any inner ) {
		this.type  = "not";
		this.inner = arguments.inner;
		return this;
	}
}
