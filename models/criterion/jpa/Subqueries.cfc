/**
 * Hibernate 7+ replacement for cborm.models.criterion.Subqueries.
 *
 * Returns typed descriptor CFCs (SimpleSubqueryExpression / ExistsSubqueryExpression /
 * PropertySubqueryExpression) whose simple names match the legacy Hibernate criterion
 * subquery classes. Each descriptor holds a reference to a "detached" CriteriaBuilder
 * (a CriteriaBuilder whose .list() is never called); the JPAAssembler invokes its
 * renderAsSubquery() at execution time to materialise a JPA Subquery inside the
 * parent CriteriaQuery.
 *
 * Common pattern:
 *   detached = new CriteriaBuilder( entityName="Role", ormSession=session )
 *       .eq( "org.name", "acme" )
 *       .withProjections( property="id" );
 *
 *   mainCb.add( subqueries.propertyIn( "role.id", detached ) );
 *
 * Single-column subqueries only — the detached builder must have at most one
 * projection (becomes the SELECT clause of the subquery). When no projection is set
 * the entity itself is selected (suits exists/notExists, where the SELECT is irrelevant).
 */
component singleton {

	import cborm.models.criterion.jpa.descriptors.*;

	Subqueries function init() {
		return this;
	}

	function propertyIn(    required string property, required any detachedBuilder ) { return new SimpleSubqueryExpression( path=arguments.property, subquery=arguments.detachedBuilder, negate=false ); }
	function propertyNotIn( required string property, required any detachedBuilder ) { return new SimpleSubqueryExpression( path=arguments.property, subquery=arguments.detachedBuilder, negate=true  ); }

	function exists(    required any detachedBuilder ) { return new ExistsSubqueryExpression( subquery=arguments.detachedBuilder, negate=false ); }
	function notExists( required any detachedBuilder ) { return new ExistsSubqueryExpression( subquery=arguments.detachedBuilder, negate=true  ); }

	function propertyEq( required string property, required any detachedBuilder ) { return cmp( "eq", arguments.property, arguments.detachedBuilder ); }
	function propertyNe( required string property, required any detachedBuilder ) { return cmp( "ne", arguments.property, arguments.detachedBuilder ); }
	function propertyGt( required string property, required any detachedBuilder ) { return cmp( "gt", arguments.property, arguments.detachedBuilder ); }
	function propertyGe( required string property, required any detachedBuilder ) { return cmp( "ge", arguments.property, arguments.detachedBuilder ); }
	function propertyLt( required string property, required any detachedBuilder ) { return cmp( "lt", arguments.property, arguments.detachedBuilder ); }
	function propertyLe( required string property, required any detachedBuilder ) { return cmp( "le", arguments.property, arguments.detachedBuilder ); }

	private function cmp( required string op, required string property, required any detachedBuilder ) {
		return new PropertySubqueryExpression( op=arguments.op, path=arguments.property, subquery=arguments.detachedBuilder );
	}

}
