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
		variables.root               = arguments.root;
		variables.joins              = {};
		variables.projectionAliases  = {};   // populated post-init by CriteriaBuilder

		var jpaJoinTypes = createObject( "java", "jakarta.persistence.criteria.JoinType" );

		for ( var aliasName in arguments.aliases ) {
			var spec      = arguments.aliases[ aliasName ];
			var jpaType   = jpaJoinTypes[ spec.joinType ];
			var pathParts = listToArray( spec.path, "." );

			// Walk dotted association paths step by step. Each intermediate step uses the
			// same JoinType as the alias spec — matches legacy cborm createAlias("a.b.c", ...)
			// where the JoinType cascades through every link in the chain.
			var current = arguments.root;
			var prefix  = "";
			for ( var part in pathParts ) {
				prefix = prefix.len() ? prefix & "." & part : part;
				if ( !structKeyExists( variables.joins, prefix ) ) {
					variables.joins[ prefix ] = current.join( part, jpaType );
				}
				current = variables.joins[ prefix ];
			}

			// Alias resolves to the FINAL join node in the chain
			variables.joins[ aliasName ] = current;
		}

		return this;
	}

	/**
	 * Register a projection-alias → Selection expression mapping. Once registered,
	 * resolve() will short-circuit a single-segment path matching the alias and
	 * return the projection expression — so HAVING / ORDER on aggregate aliases
	 * (`Restrictions.gt("userCount", 5)` after `count="id:userCount"`) works.
	 */
	void function registerProjectionAlias( required string alias, required expression ) {
		variables.projectionAliases[ arguments.alias ] = arguments.expression;
	}

	/**
	 * Resolve a dotted path to a JPA Path expression.
	 *
	 * @path Property path, e.g. "name" or "role.org.id" or (with alias) "r.name"
	 */
	function resolve( required string path ) {
		var parts = listToArray( arguments.path, "." );

		// projection alias takes precedence over property lookup for single-segment paths
		if ( parts.len() eq 1 && structKeyExists( variables.projectionAliases, parts[ 1 ] ) ) {
			return variables.projectionAliases[ parts[ 1 ] ];
		}

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
