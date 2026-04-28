/**
 * Translates cborm-style dotted property paths into jakarta.persistence.criteria.Path
 * expressions, auto-promoting intermediate association steps into JPA Joins.
 *
 * "name"           -> root.get("name")
 * "role.name"      -> root.join("role").get("name")
 * "role.org.id"    -> root.join("role").join("org").get("id")
 *
 * Joins are cached per dotted prefix so repeated references to "role.*" share a
 * single Join("role") on the underlying CriteriaQuery — avoiding the cartesian
 * product you'd get if every restriction added its own join.
 *
 * Bound to a single Root for the lifetime of one query assembly. Discard after
 * .list()/.uniqueResult().
 */
component {

	PathResolver function init( required root ) {
		variables.root  = arguments.root;
		variables.joins = {};
		return this;
	}

	/**
	 * Resolve a dotted path to a JPA Path expression.
	 *
	 * @path Property path, e.g. "name" or "role.org.id"
	 */
	function resolve( required string path ) {
		var parts = listToArray( arguments.path, "." );

		if ( parts.len() eq 1 ) {
			return variables.root.get( parts[ 1 ] );
		}

		var current = variables.root;
		var prefix  = "";

		// every segment except the last is an association step → promote to Join
		for ( var i = 1; i lt parts.len(); i++ ) {
			prefix = prefix.len() ? prefix & "." & parts[ i ] : parts[ i ];
			if ( !structKeyExists( variables.joins, prefix ) ) {
				variables.joins[ prefix ] = current.join( parts[ i ] );
			}
			current = variables.joins[ prefix ];
		}

		return current.get( parts[ parts.len() ] );
	}

	function getRoot()  { return variables.root; }
	function getJoins() { return variables.joins; }

}
