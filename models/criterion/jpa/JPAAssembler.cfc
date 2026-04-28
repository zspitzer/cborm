/**
 * Walks descriptor trees produced by cborm.models.criterion.jpa.Restrictions
 * and emits jakarta.persistence.criteria.Predicate instances bound to a given
 * Root + CriteriaBuilder pair.
 *
 * This is the only file in the criterion/jpa/ stack that touches Hibernate APIs.
 * Restrictions/PathResolver/CriteriaBuilder produce + manipulate pure CFML data;
 * the assembler is the bridge to JPA at execution time.
 *
 * Lifecycle: instantiate per query assembly with a fresh Root and PathResolver,
 * call toPredicate( descriptor ) for each accumulated criterion, hand the
 * resulting Predicate(s) to CriteriaQuery.where(...), discard.
 */
component {

	JPAAssembler function init( required cb, required root, required pathResolver ) {
		variables.cb           = arguments.cb;            // jakarta.persistence.criteria.CriteriaBuilder
		variables.root         = arguments.root;          // jakarta.persistence.criteria.Root
		variables.pathResolver = arguments.pathResolver;
		return this;
	}

	/**
	 * Convert a single descriptor (or descriptor tree) into a JPA Predicate.
	 */
	function toPredicate( required struct d ) {
		switch ( arguments.d.type ) {

			case "eq":          return variables.cb.equal(              path( arguments.d.path ), arguments.d.value );
			case "ne":          return variables.cb.notEqual(           path( arguments.d.path ), arguments.d.value );
			case "gt":          return variables.cb.greaterThan(        path( arguments.d.path ), arguments.d.value );
			case "ge":          return variables.cb.greaterThanOrEqualTo( path( arguments.d.path ), arguments.d.value );
			case "lt":          return variables.cb.lessThan(           path( arguments.d.path ), arguments.d.value );
			case "le":          return variables.cb.lessThanOrEqualTo(  path( arguments.d.path ), arguments.d.value );
			case "between":     return variables.cb.between(            path( arguments.d.path ), arguments.d.lo, arguments.d.hi );
			case "like":        return variables.cb.like(               path( arguments.d.path ), arguments.d.value );
			case "ilike":       return variables.cb.like( variables.cb.lower( path( arguments.d.path ) ), lcase( arguments.d.value ) );
			case "isNull":      return variables.cb.isNull(             path( arguments.d.path ) );
			case "isNotNull":   return variables.cb.isNotNull(          path( arguments.d.path ) );
			case "eqProperty":  return variables.cb.equal(              path( arguments.d.left ), path( arguments.d.right ) );

			case "in":
				var inExpr = variables.cb.in( path( arguments.d.path ) );
				for ( var v in arguments.d.values ) {
					inExpr = inExpr.value( v );
				}
				return inExpr;

			case "and":
				return variables.cb.and( predicateArray( arguments.d.parts ) );

			case "or":
				return variables.cb.or( predicateArray( arguments.d.parts ) );

			case "not":
				return variables.cb.not( toPredicate( arguments.d.inner ) );

		}

		throw(
			type    = "cborm.UnsupportedDescriptor",
			message = "Descriptor type [#arguments.d.type#] is not handled by JPAAssembler",
			detail  = "Add a case to JPAAssembler.toPredicate or check the descriptor producer in jpa/Restrictions.cfc"
		);
	}

	/**
	 * Build a Java Predicate[] from a CFML array of descriptors. JPA's and()/or()
	 * accept varargs but `cb.and(predicateArray)` works because Lucee unwraps
	 * arrays into Object[] for varargs targets.
	 */
	private function predicateArray( required array descriptors ) {
		return arguments.descriptors.map( function( d ) { return toPredicate( arguments.d ); } );
	}

	private function path( required string p ) {
		return variables.pathResolver.resolve( arguments.p );
	}

	/**
	 * Convert an order descriptor { path, dir, ignoreCase? } into a JPA Order.
	 * Dir is "asc" or "desc" (case-insensitive). ignoreCase wraps the path in cb.lower
	 * so "abc" and "ABC" sort together — matches the legacy Restrictions.order(...) third arg.
	 */
	function toOrder( required struct o ) {
		var p = path( arguments.o.path );
		if ( structKeyExists( arguments.o, "ignoreCase" ) && arguments.o.ignoreCase ) {
			p = variables.cb.lower( p );
		}
		return lcase( arguments.o.dir ) eq "desc"
			? variables.cb.desc( p )
			: variables.cb.asc(  p );
	}

	/**
	 * Convert a projection descriptor { type, path, alias } into a JPA Selection.
	 * Aggregate types (count/sum/avg/min/max/countDistinct) wrap the path expression;
	 * "property" returns the raw Path; "rowCount" counts the root entity.
	 *
	 * Alias is applied via Selection.alias() so it can be looked up on the Tuple by name.
	 */
	function toSelection( required struct p ) {
		var expr = "";
		switch ( arguments.p.type ) {
			case "property":      expr = path( arguments.p.path );                              break;
			case "count":         expr = variables.cb.count(         path( arguments.p.path ) ); break;
			case "countDistinct": expr = variables.cb.countDistinct( path( arguments.p.path ) ); break;
			case "sum":           expr = variables.cb.sum(           path( arguments.p.path ) ); break;
			case "avg":           expr = variables.cb.avg(           path( arguments.p.path ) ); break;
			case "min":           expr = variables.cb.min(           path( arguments.p.path ) ); break;
			case "max":           expr = variables.cb.max(           path( arguments.p.path ) ); break;
			case "rowCount":      expr = variables.cb.count(         variables.root );           break;
			default:
				throw(
					type    = "cborm.UnsupportedProjection",
					message = "Projection type [#arguments.p.type#] is not handled by JPAAssembler"
				);
		}
		if ( arguments.p.alias.len() ) expr = expr.alias( arguments.p.alias );
		return expr;
	}

	/**
	 * Resolve a dotted path to a JPA Path expression (for use by callers building groupBy etc.).
	 */
	function pathFor( required string p ) {
		return path( arguments.p );
	}

}
