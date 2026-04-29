<cfscript>
// Probe verifying the lazy NotImplemented stubs we just added to
// cborm.models.criterion.jpa.Subqueries.cfc.
//
// Constructs the legacy cborm.models.criterion.Subqueries — on H7+ the init()
// version-dispatch returns the JPA Subqueries facade. Then exercises:
//   1) Methods that ARE implemented (propertyIn etc.) — must succeed.
//   2) Stubbed legacy methods (subEq, propertyEqAll, setDetachedCriteria, etc.)
//      — must throw cborm.JPA.NotImplemented (catchable typed exception),
//      not "method not found".

systemOutput( "", true );
systemOutput( "===== legacy Subqueries -> JPA stub probe =====", true );
systemOutput( "Hibernate version : " & createObject( "java", "org.hibernate.Version" ).getVersionString(), true );
systemOutput( "", true );

passes  = 0;
fails   = 0;

function check( required string label, required boolean condition, string detail = "" ) {
	if ( arguments.condition ) {
		systemOutput( "  PASS  " & arguments.label, true );
		variables.passes++;
	} else {
		systemOutput( "  FAIL  " & arguments.label & ( arguments.detail.len() ? " — " & arguments.detail : "" ), true );
		variables.fails++;
	}
}

function expectStub( required string label, required any callable ) {
	try {
		arguments.callable();
		check( arguments.label, false, "no exception thrown — stub missing?" );
	} catch ( cborm.JPA.NotImplemented e ) {
		check( arguments.label, true );
	} catch ( any e ) {
		check( arguments.label, false, "wrong type: [#e.type#] #e.message#" );
	}
}

// 1) Construct legacy Subqueries — version dispatch returns jpa.Subqueries on H7
sq = new cborm.models.criterion.Subqueries(
	new cborm.models.util.JavaProxyBuilder()
);

// Sanity: confirm we got the JPA facade, not the legacy Java wrapper
className = getMetadata( sq ).name;
check( "legacy ctor returns JPA facade on H7", className contains "criterion.jpa.Subqueries", "got [#className#]" );

// 2) Implemented methods still work
detached = "fake-detached-builder-stub";
ok = sq.propertyIn( "role.id", detached );
check( "propertyIn returns descriptor", !isNull( ok ) );

// 3) sub*( value ) family — all stubbed
expectStub( "subEq stubbed",     () => sq.subEq( "foo" ) );
expectStub( "subEqAll stubbed",  () => sq.subEqAll( 500 ) );
expectStub( "subGe stubbed",     () => sq.subGe( 500 ) );
expectStub( "subGeAll stubbed",  () => sq.subGeAll( 500 ) );
expectStub( "subGeSome stubbed", () => sq.subGeSome( 500 ) );
expectStub( "subGt stubbed",     () => sq.subGt( 500 ) );
expectStub( "subGtAll stubbed",  () => sq.subGtAll( 500 ) );
expectStub( "subGtSome stubbed", () => sq.subGtSome( 500 ) );
expectStub( "subIn stubbed",     () => sq.subIn( 500 ) );
expectStub( "subLe stubbed",     () => sq.subLe( 500 ) );
expectStub( "subLeAll stubbed",  () => sq.subLeAll( 500 ) );
expectStub( "subLeSome stubbed", () => sq.subLeSome( 500 ) );
expectStub( "subLt stubbed",     () => sq.subLt( 500 ) );
expectStub( "subLtAll stubbed",  () => sq.subLtAll( 500 ) );
expectStub( "subLtSome stubbed", () => sq.subLtSome( 500 ) );
expectStub( "subNe stubbed",     () => sq.subNe( 500 ) );
expectStub( "subNotIn stubbed",  () => sq.subNotIn( 500 ) );

// 4) property*All / property*Some — all stubbed
expectStub( "propertyEqAll stubbed",  () => sq.propertyEqAll(  "views" ) );
expectStub( "propertyGeAll stubbed",  () => sq.propertyGeAll(  "views" ) );
expectStub( "propertyGeSome stubbed", () => sq.propertyGeSome( "views" ) );
expectStub( "propertyGtAll stubbed",  () => sq.propertyGtAll(  "views" ) );
expectStub( "propertyGtSome stubbed", () => sq.propertyGtSome( "views" ) );
expectStub( "propertyLeAll stubbed",  () => sq.propertyLeAll(  "views" ) );
expectStub( "propertyLeSome stubbed", () => sq.propertyLeSome( "views" ) );
expectStub( "propertyLtAll stubbed",  () => sq.propertyLtAll(  "views" ) );
expectStub( "propertyLtSome stubbed", () => sq.propertyLtSome( "views" ) );

// 5) Instance-state methods — stubbed
expectStub( "setDetachedCriteria stubbed", () => sq.setDetachedCriteria( "stub" ) );
expectStub( "getDetachedCriteria stubbed", () => sq.getDetachedCriteria() );
expectStub( "getNativeClass stubbed",      () => sq.getNativeClass() );

// 6) isInstanceOf simple-name match against descriptor CFC
ext = sq.exists( detached );
check( "exists returns ExistsSubqueryExpression descriptor", isInstanceOf( ext, "ExistsSubqueryExpression" ) );

// 7) Restrictions polyfill checks — sql/sqlRestriction stubbed (existing),
//    getNativeClass and buildHibernateType stubbed (just added).
r = new cborm.models.criterion.Restrictions(
	new cborm.models.util.JavaProxyBuilder()
);
check( "legacy Restrictions ctor returns JPA facade on H7", getMetadata( r ).name contains "criterion.jpa.Restrictions" );

// Real predicates produce descriptors with simple-name match
eqExpr = r.isEq( "name", "luis" );
check( "Restrictions.isEq returns SimpleExpression descriptor", isInstanceOf( eqExpr, "SimpleExpression" ) );
notExpr = r.isNot( eqExpr );
check( "Restrictions.isNot returns NotExpression descriptor", isInstanceOf( notExpr, "NotExpression" ) );

expectStub( "Restrictions.sql stubbed",                () => r.sql( "x" ) );
expectStub( "Restrictions.sqlRestriction stubbed",     () => r.sqlRestriction( "x" ) );
expectStub( "Restrictions.getNativeClass stubbed",     () => r.getNativeClass() );
expectStub( "Restrictions.buildHibernateType stubbed", () => r.buildHibernateType( "string" ) );

systemOutput( "", true );
systemOutput( "===== summary =====", true );
systemOutput( "Passes  : " & passes, true );
systemOutput( "Failures: " & fails, true );
systemOutput( fails == 0 ? "ALL GREEN" : "FAILED", true );
</cfscript>
