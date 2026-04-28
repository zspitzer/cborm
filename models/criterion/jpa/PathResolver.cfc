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
 * If the builder registered explicit aliases via createAlias() / joinTo() they
 * are pre-created at init time with their declared JoinType (INNER/LEFT/RIGHT).
 * Both the alias name AND the original association path then resolve to the same
 * physical Join node, so `eq("r.name", x)` and `eq("role.name", x)` cooperate
 * after `joinTo("role", "r", LEFT_JOIN)`.
 *
 * Bound to a single Root for the lifetime of one query assembly. Discard after
 * .list()/.uniqueResult().
 */
component {

	PathResolver function init( required root, struct aliases = {} ) {
		variables.root  = arguments.root;
		variables.joins = {};

		for ( var aliasName in arguments.aliases ) {
			var spec      = arguments.aliases[ aliasName ];
			var jpaType   = createObject( "java", "jakarta.persistence.criteria.JoinType" )[ spec.joinType ];
			var joinNode  = arguments.root.join( spec.path, jpaType );
			variables.joins[ aliasName ] = joinNode;   // alias-prefixed lookup
			variables.joins[ spec.path ] = joinNode;   // path-prefixed lookup hits the same node
		}

		return this;
	}

	/**
	 * Resolve a dotted path to a JPA Path expression.
	 *
	 * @path Property path, e.g. "name" or "role.org.id" or (with alias) "r.name"
	 */
	function resolve( required string path ) {
		var parts = listToArray( arguments.path, "." );

		if ( parts.len() eq 1 ) {
			return variables.root.get( parts[ 1 ] );
		}

		var current = variables.root;
		var prefix  = "";

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
