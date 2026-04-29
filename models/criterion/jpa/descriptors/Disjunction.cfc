/**
 * OR junction over multiple criteria.
 * Simple name mirrors org.hibernate.criterion.Disjunction.
 */
component {
	function init( required array parts ) {
		this.type  = "or";
		this.parts = arguments.parts;
		return this;
	}
}
