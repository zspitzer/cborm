/**
 * Hibernate 7+ replacement for cborm.models.criterion.Restrictions.
 *
 * Returns *typed descriptor CFCs* under cborm.models.criterion.jpa.descriptors.* —
 * each one's simple name mirrors a legacy org.hibernate.criterion class
 * (SimpleExpression / LikeExpression / NotExpression / SimpleSubqueryExpression / etc.)
 * so legacy test assertions like `isInstanceOf( r, "NotExpression" )` keep working.
 *
 * The descriptor objects are pure data; they hold a `type` field plus payload (path,
 * value, op, etc.). The JPAAssembler dispatches on `descriptor.type` and converts
 * the tree into jakarta.persistence.criteria.Predicate at execution time, by which
 * point the active Session/Root are known.
 */
component singleton {

	import cborm.models.criterion.jpa.descriptors.*;

	Restrictions function init() {
		return this;
	}

	// ----- comparison -----

	function isEq( required string property, required any propertyValue ) { return new SimpleExpression( type="eq", path=arguments.property, value=arguments.propertyValue ); }
	function ne(   required string property, required any propertyValue ) { return new SimpleExpression( type="ne", path=arguments.property, value=arguments.propertyValue ); }
	function isGt( required string property, required any propertyValue ) { return new SimpleExpression( type="gt", path=arguments.property, value=arguments.propertyValue ); }
	function isGe( required string property, required any propertyValue ) { return new SimpleExpression( type="ge", path=arguments.property, value=arguments.propertyValue ); }
	function isLt( required string property, required any propertyValue ) { return new SimpleExpression( type="lt", path=arguments.property, value=arguments.propertyValue ); }
	function isLe( required string property, required any propertyValue ) { return new SimpleExpression( type="le", path=arguments.property, value=arguments.propertyValue ); }

	function between( required string property, required any minValue, required any maxValue ) {
		return new BetweenExpression( path=arguments.property, lo=arguments.minValue, hi=arguments.maxValue );
	}

	// ----- string -----

	function like(  required string property, required string propertyValue ) { return new LikeExpression( type="like",  path=arguments.property, value=arguments.propertyValue ); }
	function ilike( required string property, required string propertyValue ) { return new LikeExpression( type="ilike", path=arguments.property, value=arguments.propertyValue ); }

	// ----- collections / null / membership -----

	function isIn( required string property, required any propertyValue ) {
		if ( isSimpleValue( arguments.propertyValue ) ) {
			arguments.propertyValue = listToArray( arguments.propertyValue );
		}
		return new InExpression( path=arguments.property, values=arguments.propertyValue );
	}

	function isNull(    required string property ) { return new NullExpression( type="isNull",    path=arguments.property ); }
	function isNotNull( required string property ) { return new NullExpression( type="isNotNull", path=arguments.property ); }

	function isTrue(  required string property ) { return new SimpleExpression( type="eq", path=arguments.property, value=javacast( "boolean", true  ) ); }
	function isFalse( required string property ) { return new SimpleExpression( type="eq", path=arguments.property, value=javacast( "boolean", false ) ); }

	// ----- property comparisons -----

	function eqProperty( required string property, required string otherProperty ) { return new PropertyExpression( op="eq", left=arguments.property, right=arguments.otherProperty ); }
	function neProperty( required string property, required string otherProperty ) { return new PropertyExpression( op="ne", left=arguments.property, right=arguments.otherProperty ); }
	function gtProperty( required string property, required string otherProperty ) { return new PropertyExpression( op="gt", left=arguments.property, right=arguments.otherProperty ); }
	function geProperty( required string property, required string otherProperty ) { return new PropertyExpression( op="ge", left=arguments.property, right=arguments.otherProperty ); }
	function ltProperty( required string property, required string otherProperty ) { return new PropertyExpression( op="lt", left=arguments.property, right=arguments.otherProperty ); }
	function leProperty( required string property, required string otherProperty ) { return new PropertyExpression( op="le", left=arguments.property, right=arguments.otherProperty ); }

	// ----- identifier -----

	function idEq( required any propertyValue ) { return new IdentifierEqExpression( value=arguments.propertyValue ); }

	// ----- collection (associations) -----

	function isEmpty(    required string property ) { return new EmptyExpression( type="isEmpty",    path=arguments.property ); }
	function isNotEmpty( required string property ) { return new EmptyExpression( type="isNotEmpty", path=arguments.property ); }

	function sizeEq( required string property, required numeric size ) { return new SizeExpression( op="eq", path=arguments.property, size=arguments.size ); }
	function sizeNe( required string property, required numeric size ) { return new SizeExpression( op="ne", path=arguments.property, size=arguments.size ); }
	function sizeGt( required string property, required numeric size ) { return new SizeExpression( op="gt", path=arguments.property, size=arguments.size ); }
	function sizeGe( required string property, required numeric size ) { return new SizeExpression( op="ge", path=arguments.property, size=arguments.size ); }
	function sizeLt( required string property, required numeric size ) { return new SizeExpression( op="lt", path=arguments.property, size=arguments.size ); }
	function sizeLe( required string property, required numeric size ) { return new SizeExpression( op="le", path=arguments.property, size=arguments.size ); }

	// ----- composition -----

	function conjunction( required array restrictionValues ) { return new Conjunction( parts=arguments.restrictionValues ); }
	function disjunction( required array restrictionValues ) { return new Disjunction( parts=arguments.restrictionValues ); }
	function isNot(       required any   criterion         ) { return new NotExpression( inner=arguments.criterion ); }

	function $and() {
		var parts = [];
		for ( var k in arguments ) arrayAppend( parts, arguments[ k ] );
		return conjunction( parts );
	}

	function $or() {
		var parts = [];
		for ( var k in arguments ) arrayAppend( parts, arguments[ k ] );
		return disjunction( parts );
	}

	// ----- arbitrary SQL fragments (NOT supported on H7) -----

	function sql( required string sql, array params = [] ) {
		throw(
			type    = "cborm.JPA.NotImplemented",
			message = "Restrictions.sql() / sqlRestriction() is not supported on Hibernate 7+",
			detail  = "Arbitrary SQL fragments cannot be expressed via JPA Criteria. Use ormExecuteQuery( ""HQL string"" ) for free-form queries, or add a domain-specific descriptor type if the fragment is reusable."
		);
	}

	function sqlRestriction( required string sql, array params = [] ) {
		// Call via `this.` to disambiguate from the local `sql` argument.
		return this.sql( argumentCollection = arguments );
	}

	// ----- legacy H5 helpers — no JPA equivalent -----

	function getNativeClass() {
		throw(
			type    = "cborm.JPA.NotImplemented",
			message = "Restrictions.getNativeClass() is not supported on Hibernate 7+",
			detail  = "org.hibernate.criterion.Restrictions was removed in H6. The JPA pipeline produces descriptor CFCs (SimpleExpression / NotExpression / etc.) instead of Java Restriction instances; isInstanceOf( descriptor, ""SimpleExpression"" ) matches by simple name."
		);
	}

	function buildHibernateType( required type ) {
		throw(
			type    = "cborm.JPA.NotImplemented",
			message = "Restrictions.buildHibernateType() is not supported on Hibernate 7+",
			detail  = "org.hibernate.type.* was reorganised in H6 — fromStringValue / IntegerType / StringType etc. are gone. JPA performs its own parameter coercion; pass values directly to predicates."
		);
	}

	// ----- aliases (matches legacy onMissingMethod) -----

	function onMissingMethod( required string missingMethodName, required struct missingMethodArguments ) {
		// dynamic negation: "notEq", "notIn", etc.
		if ( left( arguments.missingMethodName, 3 ) eq "not" && len( arguments.missingMethodName ) gt 3 ) {
			var inner = right( arguments.missingMethodName, len( arguments.missingMethodName ) - 3 );
			return isNot( invoke( this, inner, arguments.missingMethodArguments ) );
		}
		switch ( arguments.missingMethodName ) {
			case "eq":  return isEq( argumentCollection = arguments.missingMethodArguments );
			case "in":  return isIn( argumentCollection = arguments.missingMethodArguments );
			case "gt":  return isGt( argumentCollection = arguments.missingMethodArguments );
			case "lt":  return isLt( argumentCollection = arguments.missingMethodArguments );
			case "le":  return isLe( argumentCollection = arguments.missingMethodArguments );
			case "ge":  return isGe( argumentCollection = arguments.missingMethodArguments );
			case "and": return $and( argumentCollection = arguments.missingMethodArguments );
			case "or":  return $or( argumentCollection = arguments.missingMethodArguments );
			case "not": return isNot( argumentCollection = arguments.missingMethodArguments );
		}
		throw(
			type    = "cborm.UnsupportedRestriction",
			message = "Restriction [#arguments.missingMethodName#] is not yet implemented in the JPA Restrictions facade",
			detail  = "Legacy fallback to org.hibernate.criterion.* is not available on Hibernate 7+. Either add a descriptor for this op or open a CBORM ticket."
		);
	}

}
