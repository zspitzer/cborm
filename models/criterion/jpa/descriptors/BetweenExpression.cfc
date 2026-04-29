/**
 * Descriptor for BETWEEN.
 * Simple name mirrors org.hibernate.criterion.BetweenExpression.
 */
component {
	function init( required string path, required any lo, required any hi ) {
		this.type = "between";
		this.path = arguments.path;
		this.lo   = arguments.lo;
		this.hi   = arguments.hi;
		return this;
	}
}
