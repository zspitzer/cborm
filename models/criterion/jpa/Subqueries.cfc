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

	// ---- Legacy-API stubs ----
	// Mirror the legacy cborm.models.criterion.Subqueries surface so callers and
	// test specs that hit these get a catchable cborm.JPA.NotImplemented instead
	// of "method not found". Each stub names the closest JPA-pipeline alternative
	// in its detail message.

	// sub*( value ) — H5 forms with a pre-set DetachedCriteria. JPA subqueries
	// are inline, so the "value-only" shape doesn't translate cleanly.
	function subEq(      required any value ) { throwNotImplemented( "subEq",      "Use propertyEq( property, detachedBuilder ) — JPA subqueries are inline rather than pre-bound to a DetachedCriteria." ); }
	function subEqAll(   required any value ) { throwNotImplemented( "subEqAll",   "JPA Criteria's cb.all(subquery) quantifier is not yet wired in cborm. Open an issue if this is needed." ); }
	function subGe(      required any value ) { throwNotImplemented( "subGe",      "Use propertyGe( property, detachedBuilder )." ); }
	function subGeAll(   required any value ) { throwNotImplemented( "subGeAll",   "cb.all(subquery) quantifier not yet wired in cborm." ); }
	function subGeSome(  required any value ) { throwNotImplemented( "subGeSome",  "cb.any(subquery) quantifier not yet wired in cborm." ); }
	function subGt(      required any value ) { throwNotImplemented( "subGt",      "Use propertyGt( property, detachedBuilder )." ); }
	function subGtAll(   required any value ) { throwNotImplemented( "subGtAll",   "cb.all(subquery) quantifier not yet wired in cborm." ); }
	function subGtSome(  required any value ) { throwNotImplemented( "subGtSome",  "cb.any(subquery) quantifier not yet wired in cborm." ); }
	function subIn(      required any value ) { throwNotImplemented( "subIn",      "Use propertyIn( property, detachedBuilder )." ); }
	function subLe(      required any value ) { throwNotImplemented( "subLe",      "Use propertyLe( property, detachedBuilder )." ); }
	function subLeAll(   required any value ) { throwNotImplemented( "subLeAll",   "cb.all(subquery) quantifier not yet wired in cborm." ); }
	function subLeSome(  required any value ) { throwNotImplemented( "subLeSome",  "cb.any(subquery) quantifier not yet wired in cborm." ); }
	function subLt(      required any value ) { throwNotImplemented( "subLt",      "Use propertyLt( property, detachedBuilder )." ); }
	function subLtAll(   required any value ) { throwNotImplemented( "subLtAll",   "cb.all(subquery) quantifier not yet wired in cborm." ); }
	function subLtSome(  required any value ) { throwNotImplemented( "subLtSome",  "cb.any(subquery) quantifier not yet wired in cborm." ); }
	function subNe(      required any value ) { throwNotImplemented( "subNe",      "Use propertyNe( property, detachedBuilder )." ); }
	function subNotIn(   required any value ) { throwNotImplemented( "subNotIn",   "Use propertyNotIn( property, detachedBuilder )." ); }

	// property*All / property*Some — JPA all/any quantifiers not yet wired.
	function propertyEqAll(   required string property ) { throwNotImplemented( "propertyEqAll",   "cb.all(subquery) quantifier not yet wired in cborm." ); }
	function propertyGeAll(   required string property ) { throwNotImplemented( "propertyGeAll",   "cb.all(subquery) quantifier not yet wired in cborm." ); }
	function propertyGeSome(  required string property ) { throwNotImplemented( "propertyGeSome",  "cb.any(subquery) quantifier not yet wired in cborm." ); }
	function propertyGtAll(   required string property ) { throwNotImplemented( "propertyGtAll",   "cb.all(subquery) quantifier not yet wired in cborm." ); }
	function propertyGtSome(  required string property ) { throwNotImplemented( "propertyGtSome",  "cb.any(subquery) quantifier not yet wired in cborm." ); }
	function propertyLeAll(   required string property ) { throwNotImplemented( "propertyLeAll",   "cb.all(subquery) quantifier not yet wired in cborm." ); }
	function propertyLeSome(  required string property ) { throwNotImplemented( "propertyLeSome",  "cb.any(subquery) quantifier not yet wired in cborm." ); }
	function propertyLtAll(   required string property ) { throwNotImplemented( "propertyLtAll",   "cb.all(subquery) quantifier not yet wired in cborm." ); }
	function propertyLtSome(  required string property ) { throwNotImplemented( "propertyLtSome",  "cb.any(subquery) quantifier not yet wired in cborm." ); }

	// Instance-state methods — the legacy API stored a shared DetachedCriteria;
	// the JPA pipeline takes the detached builder per call instead.
	function setDetachedCriteria( required any criteria ) { throwNotImplemented( "setDetachedCriteria", "JPA Subqueries are inline. Pass the detachedBuilder argument to propertyIn / exists / etc. directly instead of pre-binding via setDetachedCriteria." ); }
	function getDetachedCriteria()                        { throwNotImplemented( "getDetachedCriteria", "JPA Subqueries are inline; there's no shared DetachedCriteria state to fetch." ); }
	function getNativeClass()                             { throwNotImplemented( "getNativeClass",      "org.hibernate.criterion.Subqueries was removed in H6; the JPA pipeline has no equivalent native-class accessor." ); }

	// ---- consistent throw helper ----

	private void function throwNotImplemented( required string method, string detail = "" ) {
		throw(
			type    = "cborm.JPA.NotImplemented",
			message = "[#arguments.method#] is not implemented in the H7+ JPA criterion pipeline",
			detail  = arguments.detail
		);
	}

}
