/**
 * Hibernate 7+ replacement for cborm.models.criterion.Restrictions.
 *
 * Returns *descriptor structs*, not Hibernate Criterion objects. A descriptor
 * is plain CFML data describing the user's intent ({ type: "eq", path: ..., value: ... });
 * the JPAAssembler converts the tree into jakarta.persistence.criteria.Predicate
 * at execution time, by which point the active Session/Root are known.
 *
 * Public method signatures match the legacy Restrictions.cfc surface so this
 * is a drop-in replacement when getHibernateVersion() >= 7.
 *
 * Path strings (e.g. "role.name") are kept verbatim — PathResolver auto-promotes
 * dotted paths into JPA join chains at assemble time.
 */
component singleton {

	Restrictions function init() {
		return this;
	}

	// ----- comparison -----

	function isEq( required string property, required any propertyValue ) {
		return { "type": "eq", "path": arguments.property, "value": arguments.propertyValue };
	}

	function ne( required string property, required any propertyValue ) {
		return { "type": "ne", "path": arguments.property, "value": arguments.propertyValue };
	}

	function isGt( required string property, required any propertyValue ) {
		return { "type": "gt", "path": arguments.property, "value": arguments.propertyValue };
	}

	function isGe( required string property, required any propertyValue ) {
		return { "type": "ge", "path": arguments.property, "value": arguments.propertyValue };
	}

	function isLt( required string property, required any propertyValue ) {
		return { "type": "lt", "path": arguments.property, "value": arguments.propertyValue };
	}

	function isLe( required string property, required any propertyValue ) {
		return { "type": "le", "path": arguments.property, "value": arguments.propertyValue };
	}

	function between( required string property, required any minValue, required any maxValue ) {
		return { "type": "between", "path": arguments.property, "lo": arguments.minValue, "hi": arguments.maxValue };
	}

	// ----- string -----

	function like( required string property, required string propertyValue ) {
		return { "type": "like", "path": arguments.property, "value": arguments.propertyValue };
	}

	function ilike( required string property, required string propertyValue ) {
		return { "type": "ilike", "path": arguments.property, "value": arguments.propertyValue };
	}

	// ----- collections / null / membership -----

	function isIn( required string property, required any propertyValue ) {
		if ( isSimpleValue( arguments.propertyValue ) ) {
			arguments.propertyValue = listToArray( arguments.propertyValue );
		}
		return { "type": "in", "path": arguments.property, "values": arguments.propertyValue };
	}

	function isNull( required string property ) {
		return { "type": "isNull", "path": arguments.property };
	}

	function isNotNull( required string property ) {
		return { "type": "isNotNull", "path": arguments.property };
	}

	function isTrue( required string property ) {
		return { "type": "eq", "path": arguments.property, "value": javacast( "boolean", true ) };
	}

	function isFalse( required string property ) {
		return { "type": "eq", "path": arguments.property, "value": javacast( "boolean", false ) };
	}

	// ----- property comparisons -----

	function eqProperty( required string property, required string otherProperty ) {
		return { "type": "eqProperty", "left": arguments.property, "right": arguments.otherProperty };
	}

	// ----- composition -----

	function conjunction( required array restrictionValues ) {
		return { "type": "and", "parts": arguments.restrictionValues };
	}

	function disjunction( required array restrictionValues ) {
		return { "type": "or", "parts": arguments.restrictionValues };
	}

	function isNot( required any criterion ) {
		return { "type": "not", "inner": arguments.criterion };
	}

	function $and() {
		var parts = [];
		for ( var k in arguments ) {
			arrayAppend( parts, arguments[ k ] );
		}
		return conjunction( parts );
	}

	function $or() {
		var parts = [];
		for ( var k in arguments ) {
			arrayAppend( parts, arguments[ k ] );
		}
		return disjunction( parts );
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
