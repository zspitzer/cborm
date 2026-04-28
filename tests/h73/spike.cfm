<cfscript>
// ---------------------------------------------------------------------------
// cborm h73 descriptor pipeline spike.
//
// Boots Lucee 7 + extension-hibernate 7.3.x via script-runner. Verifies the new
// cborm.models.criterion.jpa.* MVP runs end-to-end against H2: descriptor
// production -> JPA Predicate assembly -> SQL execution -> result list.
//
// Run:   spike-h73.bat   (output captured to test-output/spike-h73.txt)
// ---------------------------------------------------------------------------

systemOutput( "", true );
systemOutput( "===== cborm h73 descriptor spike =====", true );
systemOutput( "Hibernate version : " & createObject( "java", "org.hibernate.Version" ).getVersionString(), true );
systemOutput( "Lucee version     : " & server.lucee.version, true );
systemOutput( "", true );

// ---------- seed ----------

oAcme = entityNew( "Org", { name: "acme"   } ); entitySave( oAcme );
oWidg = entityNew( "Org", { name: "widget" } ); entitySave( oWidg );

rAdmin   = entityNew( "Role", { name: "admin",  org: oAcme } ); entitySave( rAdmin );
rEditor  = entityNew( "Role", { name: "editor", org: oAcme } ); entitySave( rEditor );
rViewer  = entityNew( "Role", { name: "viewer", org: oWidg } ); entitySave( rViewer );

seed = [
	{ name: "luis",     age: 42, isActive: true,  role: rAdmin   },
	{ name: "brad",     age: 35, isActive: true,  role: rEditor  },
	{ name: "curt",     age: 28, isActive: true,  role: rEditor  },
	{ name: "joel",     age: 22, isActive: false, role: rViewer  },
	{ name: "lucia",    age: 51, isActive: true,  role: rAdmin   },
	{ name: "luminita", age: 30, isActive: false, role: rViewer  }
];
for ( u in seed ) {
	entitySave( entityNew( "User", u ) );
}
ormFlush();
systemOutput( "Seeded #seed.len()# users across 3 roles.", true );
systemOutput( "", true );

// ---------- helper: fetch entity Java class from session metamodel ----------

hbSession = ormGetSession();
userClass = hbSession.getMetamodel().entity( "User" ).getJavaType();

// ---------- runner ----------

request.failures = [];
request.passes   = 0;

function check( required string label, required boolean ok, string detail = "" ) {
	if ( arguments.ok ) {
		systemOutput( "  PASS  " & arguments.label, true );
		request.passes++;
	} else {
		systemOutput( "  FAIL  " & arguments.label & ( arguments.detail.len() ? "  -- " & arguments.detail : "" ), true );
		arrayAppend( request.failures, arguments.label );
	}
}

// ---------- scenarios ----------

systemOutput( "[scenario 1] simple eq", true );
try {
	cb = new cborm.models.criterion.jpa.CriteriaBuilder(
		entityName = "User",
		ormSession = hbSession
	);
	got = cb.eq( "name", "luis" ).list();
	check( "eq returns 1 user", got.len() eq 1 );
	check( "matched user.name == luis", got.len() ? got[ 1 ].getName() eq "luis" : false );
} catch ( any e ) {
	check( "scenario 1 didn't throw", false, e.message & " :: " & e.detail );
}

systemOutput( "[scenario 2] AND of multiple top-level restrictions", true );
try {
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb
		.eq( "isActive", javacast( "boolean", true ) )
		.gt( "age", 30 )
		.list();
	// luis(42), brad(35), lucia(51) — three actives over 30
	check( "active && age>30 returns 3", got.len() eq 3, "got " & got.len() );
} catch ( any e ) {
	check( "scenario 2 didn't throw", false, e.message );
}

systemOutput( "[scenario 3] like", true );
try {
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb.like( "name", "lu%" ).list();
	// luis, lucia, luminita
	check( "like 'lu%' returns 3", got.len() eq 3, "got " & got.len() );
} catch ( any e ) {
	check( "scenario 3 didn't throw", false, e.message );
}

systemOutput( "[scenario 4] in", true );
try {
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb.isIn( "name", [ "luis", "brad", "curt" ] ).list();
	check( "in 3-name list returns 3", got.len() eq 3, "got " & got.len() );
} catch ( any e ) {
	check( "scenario 4 didn't throw", false, e.message );
}

systemOutput( "[scenario 5] dotted-path auto-join (the big one)", true );
try {
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb.eq( "role.name", "admin" ).list();
	// luis + lucia
	check( "role.name = 'admin' returns 2 (PathResolver auto-joined)", got.len() eq 2, "got " & got.len() );
} catch ( any e ) {
	check( "scenario 5 didn't throw", false, e.message & " :: " & e.detail );
}

systemOutput( "[scenario 6] count", true );
try {
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	n = cb.eq( "isActive", javacast( "boolean", true ) ).count();
	check( "count of active users == 4", n eq 4, "got " & n );
} catch ( any e ) {
	check( "scenario 6 didn't throw", false, e.message );
}

systemOutput( "[scenario 7] composition: $or via Restrictions", true );
try {
	r  = new cborm.models.criterion.jpa.Restrictions();
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	cb.add( r.$or( r.isEq( "name", "luis" ), r.isEq( "name", "joel" ) ) );
	got = cb.list();
	check( "or(name=luis, name=joel) returns 2", got.len() eq 2, "got " & got.len() );
} catch ( any e ) {
	check( "scenario 7 didn't throw", false, e.message );
}

systemOutput( "[scenario 8] not", true );
try {
	r  = new cborm.models.criterion.jpa.Restrictions();
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	cb.add( r.isNot( r.isEq( "name", "luis" ) ) );
	got = cb.list();
	check( "not(name=luis) returns 5", got.len() eq 5, "got " & got.len() );
} catch ( any e ) {
	check( "scenario 8 didn't throw", false, e.message );
}

systemOutput( "[scenario 9] order asc + maxResults", true );
try {
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb.order( "age", "asc" ).maxResults( 3 ).list();
	// youngest 3: joel(22), curt(28), luminita(30)
	check( "asc age + max 3 returns 3", got.len() eq 3, "got " & got.len() );
	check( "first is youngest (joel)",  got.len() ? got[ 1 ].getName() eq "joel" : false );
	check( "last is third-youngest (luminita)", got.len() eq 3 ? got[ 3 ].getName() eq "luminita" : false );
} catch ( any e ) {
	check( "scenario 9 didn't throw", false, e.message );
}

systemOutput( "[scenario 10] pagination slice (firstResult + maxResults)", true );
try {
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb.order( "age", "asc" ).firstResult( 2 ).maxResults( 2 ).list();
	// skip youngest 2, take next 2: luminita(30), brad(35)
	check( "page 2 of size 2 returns 2", got.len() eq 2, "got " & got.len() );
	check( "first is luminita", got.len() ? got[ 1 ].getName() eq "luminita" : false );
	check( "second is brad",    got.len() eq 2 ? got[ 2 ].getName() eq "brad" : false );
} catch ( any e ) {
	check( "scenario 10 didn't throw", false, e.message );
}

systemOutput( "[scenario 11] order desc + dotted path", true );
try {
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb.order( "role.name", "desc" ).order( "name", "asc" ).list();
	// roles desc by name: viewer, editor, admin → 6 users grouped by role then by name
	check( "ordered by role desc, name asc returns all 6", got.len() eq 6, "got " & got.len() );
	check( "first user is in 'viewer' role", got.len() ? got[ 1 ].getRole().getName() eq "viewer" : false );
	check( "last user is in 'admin' role",   got.len() eq 6 ? got[ 6 ].getRole().getName() eq "admin" : false );
} catch ( any e ) {
	check( "scenario 11 didn't throw", false, e.message );
}

systemOutput( "[scenario 12] cache flag smoke (no exception, secondary cache off)", true );
try {
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb.eq( "isActive", javacast( "boolean", true ) ).cache( true ).cacheRegion( "spikeUsers" ).list();
	check( "cacheable query still returns 4 active users", got.len() eq 4, "got " & got.len() );
} catch ( any e ) {
	check( "scenario 12 didn't throw", false, e.message );
}

systemOutput( "[scenario 13] single property projection", true );
try {
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb.eq( "isActive", javacast( "boolean", true ) ).withProjections( property="name" ).list();
	check( "name-only projection returns 4 names", got.len() eq 4, "got " & got.len() );
	check( "first row is a string (not entity)", got.len() ? isSimpleValue( got[ 1 ] ) : false );
} catch ( any e ) {
	check( "scenario 13 didn't throw", false, e.message );
}

systemOutput( "[scenario 14] multi-property projection asStruct", true );
try {
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb
		.eq( "name", "luis" )
		.withProjections( property="name,age" )
		.asStruct()
		.list();
	check( "asStruct with 2 props returns 1 row", got.len() eq 1 );
	check( "row is a struct",                     got.len() ? isStruct( got[ 1 ] ) : false );
	check( "struct has alias 'name' = luis",      got.len() ? got[ 1 ].name eq "luis" : false );
	check( "struct has alias 'age' = 42",         got.len() ? got[ 1 ].age eq 42      : false );
} catch ( any e ) {
	check( "scenario 14 didn't throw", false, e.message & " :: " & e.detail );
}

systemOutput( "[scenario 15] aggregates: count + avg + min + max", true );
try {
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb
		.withProjections( count="id:total", avg="age:avgAge", min="age:minAge", max="age:maxAge" )
		.asStruct()
		.list();
	check( "single result row", got.len() eq 1 );
	check( "total = 6",         got.len() ? got[ 1 ].total  eq 6  : false );
	check( "min age = 22",      got.len() ? got[ 1 ].minAge eq 22 : false );
	check( "max age = 51",      got.len() ? got[ 1 ].maxAge eq 51 : false );
} catch ( any e ) {
	check( "scenario 15 didn't throw", false, e.message );
}

systemOutput( "[scenario 16] groupBy via dotted path: users per role", true );
try {
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb
		.withProjections( count="id:userCount", groupProperty="role.name:roleName" )
		.asStruct()
		.order( "role.name", "asc" )
		.list();
	// 3 roles: admin(2), editor(2), viewer(2)
	check( "groupBy returns 3 rows", got.len() eq 3, "got " & got.len() );
	check( "first row is admin",     got.len() ? got[ 1 ].roleName eq "admin" : false );
	check( "admin has 2 users",      got.len() ? got[ 1 ].userCount eq 2 : false );
} catch ( any e ) {
	check( "scenario 16 didn't throw", false, e.message );
}

systemOutput( "[scenario 17] rowCount projection", true );
try {
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb.eq( "isActive", javacast( "boolean", true ) ).withProjections( rowCount=true ).list();
	check( "rowCount returns 1 row",     got.len() eq 1 );
	check( "rowCount value is 4 actives", got.len() ? got[ 1 ] eq 4 : false );
} catch ( any e ) {
	check( "scenario 17 didn't throw", false, e.message );
}

systemOutput( "[scenario 18] explicit joinTo with INNER join + alias-prefixed path", true );
try {
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb
		.joinTo( associationName="role", alias="r", joinType=cb.INNER_JOIN )
		.eq( "r.name", "admin" )
		.list();
	check( "INNER join + r.name=admin returns 2", got.len() eq 2, "got " & got.len() );
} catch ( any e ) {
	check( "scenario 18 didn't throw", false, e.message & " :: " & e.detail );
}

// add a roleless user so LEFT vs INNER produce different results
nathan = entityNew( "User", { name: "nathan", age: 19, isActive: true } );
entitySave( nathan );
ormFlush();
systemOutput( "  (added nathan with no role for LEFT-join probe)", true );

systemOutput( "[scenario 19] LEFT join keeps roleless rows; INNER drops them", true );
try {
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	innerCount = cb.eq( "role.name", "admin" ).count();   // INNER auto-promote
	check( "INNER auto-join admin = 2", innerCount eq 2, "got " & innerCount );

	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	leftCount = cb
		.joinTo( "role", "r", cb.LEFT_JOIN )
		.list()
		.len();
	// LEFT join role with no predicate = all 7 users (including nathan with null role)
	check( "LEFT join no-predicate returns 7", leftCount eq 7, "got " & leftCount );
} catch ( any e ) {
	check( "scenario 19 didn't throw", false, e.message & " :: " & e.detail );
}

systemOutput( "[scenario 20] aliased path coexists with dotted path on same join", true );
try {
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	// Both `r.name` and `role.name` should reach the SAME join node — not produce two joins
	got = cb
		.joinTo( "role", "r", cb.INNER_JOIN )
		.eq( "r.name", "admin" )
		.eq( "role.name", "admin" )    // redundant but should not double-join
		.list();
	check( "alias + dotted on same join returns 2 admins", got.len() eq 2, "got " & got.len() );
} catch ( any e ) {
	check( "scenario 20 didn't throw", false, e.message );
}

systemOutput( "[scenario 21] join with order through alias", true );
try {
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb
		.joinTo( "role", "r", cb.INNER_JOIN )
		.order( "r.name", "asc" )
		.order( "name",   "asc" )
		.list();
	// 6 users with roles (nathan excluded by INNER), ordered by role then name
	check( "ordered by alias.field returns 6 (INNER excludes nathan)", got.len() eq 6, "got " & got.len() );
	check( "first user is in 'admin'", got.len() ? got[ 1 ].getRole().getName() eq "admin" : false );
} catch ( any e ) {
	check( "scenario 21 didn't throw", false, e.message );
}

systemOutput( "[scenario 22] HAVING references projection alias", true );
try {
	r  = new cborm.models.criterion.jpa.Restrictions();
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb
		.withProjections( count="id:userCount", groupProperty="role.name:roleName" )
		.having( r.isGe( "userCount", 2 ) )
		.asStruct()
		.list();
	// each role has 2 users (luis,lucia / brad,curt / joel,luminita)
	check( "having userCount >= 2 returns 3 roles", got.len() eq 3, "got " & got.len() );
} catch ( any e ) {
	check( "scenario 22 didn't throw", false, e.message & " :: " & e.detail );
}

systemOutput( "[scenario 23] HAVING that excludes everything", true );
try {
	r  = new cborm.models.criterion.jpa.Restrictions();
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb
		.withProjections( count="id:userCount", groupProperty="role.name:roleName" )
		.having( r.isGt( "userCount", 99 ) )
		.asStruct()
		.list();
	check( "having userCount > 99 returns 0", got.len() eq 0, "got " & got.len() );
} catch ( any e ) {
	check( "scenario 23 didn't throw", false, e.message );
}

systemOutput( "[scenario 24] multi-level joinTo (User -> role -> org) with alias", true );
try {
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb
		.joinTo( "role.org", "ro", cb.INNER_JOIN )
		.eq( "ro.name", "acme" )
		.list();
	// admin (luis, lucia) + editor (brad, curt) are in acme org → 4 users
	check( "joinTo role.org with alias returns 4 acme-org users", got.len() eq 4, "got " & got.len() );
} catch ( any e ) {
	check( "scenario 24 didn't throw", false, e.message & " :: " & e.detail );
}

systemOutput( "[scenario 25] multi-level dotted-path auto-promote", true );
try {
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb.eq( "role.org.name", "widget" ).list();
	// viewer (joel, luminita) are in widget org → 2 users
	check( "role.org.name=widget returns 2 viewer-users", got.len() eq 2, "got " & got.len() );
} catch ( any e ) {
	check( "scenario 25 didn't throw", false, e.message );
}

systemOutput( "[scenario 26] subquery propertyIn — users whose role is in acme org", true );
try {
	subq = new cborm.models.criterion.jpa.Subqueries();
	detached = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="Role", ormSession=hbSession )
		.eq( "org.name", "acme" )
		.withProjections( property="id" );

	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb.add( subq.propertyIn( "role.id", detached ) ).list();
	// admin (luis, lucia) + editor (brad, curt) — all in acme = 4 users
	check( "propertyIn returns 4 acme-org users", got.len() eq 4, "got " & got.len() );
} catch ( any e ) {
	check( "scenario 26 didn't throw", false, e.message & " :: " & e.detail );
}

systemOutput( "[scenario 27] subquery propertyNotIn — users whose role is NOT in acme org", true );
try {
	subq = new cborm.models.criterion.jpa.Subqueries();
	detached = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="Role", ormSession=hbSession )
		.eq( "org.name", "acme" )
		.withProjections( property="id" );

	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb.add( subq.propertyNotIn( "role.id", detached ) ).list();
	// viewer (joel, luminita) — in widget org, not acme = 2 users
	check( "propertyNotIn returns 2 widget-org users", got.len() eq 2, "got " & got.len() );
} catch ( any e ) {
	check( "scenario 27 didn't throw", false, e.message );
}

systemOutput( "[scenario 28] subquery exists — at least one role in acme exists", true );
try {
	subq = new cborm.models.criterion.jpa.Subqueries();
	detached = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="Role", ormSession=hbSession )
		.eq( "org.name", "acme" );  // no projection — selects entity, fine for exists

	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb.add( subq.exists( detached ) ).list();
	// exists is true for ALL rows (acme roles do exist) → all 7 users
	check( "exists returns all 7 users", got.len() eq 7, "got " & got.len() );
} catch ( any e ) {
	check( "scenario 28 didn't throw", false, e.message );
}

systemOutput( "[scenario 29] subquery notExists — when subquery returns empty", true );
try {
	subq = new cborm.models.criterion.jpa.Subqueries();
	detached = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="Role", ormSession=hbSession )
		.eq( "name", "DefinitelyNotARole" );

	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb.add( subq.notExists( detached ) ).list();
	// notExists of empty subquery → all 7 users
	check( "notExists(empty subquery) returns all 7", got.len() eq 7, "got " & got.len() );
} catch ( any e ) {
	check( "scenario 29 didn't throw", false, e.message );
}

systemOutput( "[scenario 30] subquery comparison — find users older than max viewer age", true );
try {
	subq = new cborm.models.criterion.jpa.Subqueries();
	detached = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession )
		.eq( "role.name", "viewer" )
		.withProjections( max="age" );  // max viewer age = max(joel 22, luminita 30) = 30

	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb.add( subq.propertyGt( "age", detached ) ).list();
	// > 30: brad(35), luis(42), lucia(51) = 3 users
	check( "propertyGt returns 3 users older than max viewer", got.len() eq 3, "got " & got.len() );
} catch ( any e ) {
	check( "scenario 30 didn't throw", false, e.message & " :: " & e.detail );
}

systemOutput( "[scenario 31] withClause on LEFT join — ON-clause keeps all left rows", true );
try {
	r = new cborm.models.criterion.jpa.Restrictions();

	// Sanity: same predicate in WHERE drops to 2 admin users (LEFT becomes effectively INNER).
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	whereCount = cb
		.joinTo( "role", "rw", cb.LEFT_JOIN )
		.eq( "rw.name", "admin" )
		.list().len();
	check( "LEFT join + WHERE name=admin drops to 2", whereCount eq 2, "got " & whereCount );

	// withClause: same predicate in ON keeps all 7 left rows (role null for non-admins).
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	onCount = cb
		.joinTo(
			associationName = "role",
			alias           = "ro",
			joinType        = cb.LEFT_JOIN,
			withClause      = r.isEq( "ro.name", "admin" )
		)
		.list().len();
	check( "LEFT join + ON name=admin keeps all 7 users", onCount eq 7, "got " & onCount );
} catch ( any e ) {
	check( "scenario 31 didn't throw", false, e.message & " :: " & e.detail );
}

systemOutput( "[scenario 32] withClause referencing alias path resolves correctly", true );
try {
	r = new cborm.models.criterion.jpa.Restrictions();
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb
		.joinTo( "role", "r", cb.INNER_JOIN, r.isEq( "r.name", "admin" ) )
		.list();
	// INNER + ON name=admin → only admin matches → 2 users
	check( "INNER + withClause filters to 2 admins", got.len() eq 2, "got " & got.len() );
} catch ( any e ) {
	check( "scenario 32 didn't throw", false, e.message );
}

systemOutput( "[scenario 33] property comparisons (eqProperty / gtProperty)", true );
try {
	r  = new cborm.models.criterion.jpa.Restrictions();
	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	// trivial truthy: id eq id → matches all 7 users
	got = cb.add( r.eqProperty( "id", "id" ) ).list();
	check( "eqProperty(id,id) matches all 7", got.len() eq 7, "got " & got.len() );

	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	// gtProperty: id > id is always false → 0 rows
	got = cb.add( r.gtProperty( "id", "id" ) ).list();
	check( "gtProperty(id,id) matches 0", got.len() eq 0, "got " & got.len() );
} catch ( any e ) {
	check( "scenario 33 didn't throw", false, e.message );
}

systemOutput( "[scenario 34] idEq via metamodel", true );
try {
	r  = new cborm.models.criterion.jpa.Restrictions();
	// pick any user's id from the seeded data
	allUsers = ormExecuteQuery( "from User" );
	someId   = allUsers[ 1 ].getId();
	someName = allUsers[ 1 ].getName();

	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="User", ormSession=hbSession );
	got = cb.add( r.idEq( someId ) ).list();
	check( "idEq returns exactly 1 user", got.len() eq 1, "got " & got.len() );
	check( "idEq matches the picked user", got.len() ? got[ 1 ].getName() eq someName : false );
} catch ( any e ) {
	check( "scenario 34 didn't throw", false, e.message & " :: " & e.detail );
}

systemOutput( "[scenario 35] collection isNotEmpty / isEmpty", true );
try {
	r  = new cborm.models.criterion.jpa.Restrictions();

	// add a "ghost" role with no users so isEmpty has something to find
	rGhost = entityNew( "Role", { name: "ghost", org: oAcme } );
	entitySave( rGhost );
	ormFlush();

	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="Role", ormSession=hbSession );
	got = cb.add( r.isNotEmpty( "users" ) ).list();
	check( "isNotEmpty(users) returns 3 populated roles", got.len() eq 3, "got " & got.len() );

	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="Role", ormSession=hbSession );
	got = cb.add( r.isEmpty( "users" ) ).list();
	check( "isEmpty(users) returns 1 ghost role", got.len() eq 1, "got " & got.len() );
} catch ( any e ) {
	check( "scenario 35 didn't throw", false, e.message & " :: " & e.detail );
}

systemOutput( "[scenario 36] collection size comparisons", true );
try {
	r  = new cborm.models.criterion.jpa.Restrictions();

	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="Role", ormSession=hbSession );
	got = cb.add( r.sizeEq( "users", 2 ) ).list();
	check( "sizeEq(users,2) returns 3 roles (each has 2 users)", got.len() eq 3, "got " & got.len() );

	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="Role", ormSession=hbSession );
	got = cb.add( r.sizeEq( "users", 0 ) ).list();
	check( "sizeEq(users,0) returns 1 ghost role", got.len() eq 1, "got " & got.len() );

	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="Role", ormSession=hbSession );
	got = cb.add( r.sizeGt( "users", 1 ) ).list();
	check( "sizeGt(users,1) returns 3 roles", got.len() eq 3, "got " & got.len() );

	cb = new cborm.models.criterion.jpa.CriteriaBuilder( entityName="Role", ormSession=hbSession );
	got = cb.add( r.sizeLe( "users", 0 ) ).list();
	check( "sizeLe(users,0) returns 1 ghost role", got.len() eq 1, "got " & got.len() );
} catch ( any e ) {
	check( "scenario 36 didn't throw", false, e.message );
}

// ---------- summary ----------

systemOutput( "", true );
systemOutput( "===== summary =====", true );
systemOutput( "Passes  : " & request.passes, true );
systemOutput( "Failures: " & request.failures.len(), true );

if ( request.failures.len() ) {
	for ( f in request.failures ) systemOutput( "  - " & f, true );
	throw( type="cborm.h73.spike.failed", message="#request.failures.len()# scenario(s) failed" );
}

systemOutput( "ALL GREEN", true );
</cfscript>
