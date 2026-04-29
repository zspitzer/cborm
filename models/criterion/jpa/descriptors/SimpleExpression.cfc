/**
 * Descriptor for binary comparisons: eq / ne / gt / ge / lt / le.
 * Simple name mirrors org.hibernate.criterion.SimpleExpression so legacy tests
 * asserting `isInstanceOf( r, "SimpleExpression" )` keep working.
 */
component {
	function init( required string type, required string path, required any value ) {
		this.type  = arguments.type;
		this.path  = arguments.path;
		this.value = arguments.value;
		return this;
	}
}
