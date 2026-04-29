/**
 * AND junction over multiple criteria.
 * Simple name mirrors org.hibernate.criterion.Conjunction.
 */
component {
	function init( required array parts ) {
		this.type  = "and";
		this.parts = arguments.parts;
		return this;
	}
}
