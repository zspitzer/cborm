/**
 * Hibernate 7+ replacement for cborm.models.criterion.CriteriaBuilder.
 *
 * Accumulates descriptors via the existing fluent API (.eq, .like, .between, etc.)
 * but defers all Hibernate interaction until execution time (.list / .uniqueResult /
 * .count). At execution we open a session, ask it for a CriteriaBuilder + CriteriaQuery,
 * walk the descriptors through JPAAssembler, and run.
 *
 * This MVP proves the descriptor pipeline shape end-to-end. It deliberately
 * implements only the most common surface — eq/ne/gt/ge/lt/le, between, like/ilike,
 * in, isNull/isNotNull, and/or/not, plus list()/uniqueResult()/count(). Joins (joinTo,
 * createAlias, fetchMode), projections, ordering, paging, caching, streams,
 * transformers — TODO.
 *
 * Usage:
 *   var builder = new cborm.models.criterion.jpa.CriteriaBuilder(
 *       entityName  = "User",
 *       entityClass = "models.entities.User",
 *       session     = ormGetSession()
 *   );
 *   var users = builder
 *       .eq( "isActive", javacast( "boolean", true ) )
 *       .like( "name", "luis%" )
 *       .list();
 */
component accessors="true" {

	property name="entityName"  type="string";
	property name="descriptors" type="array";
	property name="orders"      type="array";

	// Join type constants — match cborm's legacy public surface so user code is portable.
	// FULL_JOIN intentionally absent: jakarta.persistence.criteria.JoinType only exposes INNER/LEFT/RIGHT.
	this.INNER_JOIN = "INNER";
	this.LEFT_JOIN  = "LEFT";
	this.RIGHT_JOIN = "RIGHT";

	CriteriaBuilder function init(
		required string entityName,
		required any    ormSession,    // org.hibernate.Session (also a jakarta.persistence.EntityManager)
		any             restrictions
	) {
		variables.entityName   = arguments.entityName;
		variables.ormSession   = arguments.ormSession;
		variables.descriptors  = [];
		variables.havings      = [];
		variables.orders       = [];
		variables.projections  = [];
		variables.groupBys     = [];
		variables.aliases      = {};    // aliasName -> { path, joinType }
		variables.asStruct     = false;
		variables.distinctRoot = false;
		variables.maxResults   = 0;     // 0 = unbounded
		variables.firstResult  = 0;
		variables.cacheable    = false;
		variables.cacheRegion  = "";
		variables.hints        = {};    // arbitrary JPA/Hibernate query hints
		variables.restrictions = isNull( arguments.restrictions )
			? new Restrictions()
			: arguments.restrictions;
		// Lucee CFC entities use dynamic-map tuplization, so getJavaType() returns
		// java.util.Map — not usable with cq.from(Class). Look up the EntityDomainType
		// by name via SessionFactoryImplementor.getJpaMetamodel(). Same pattern our
		// extension uses internally for EntityLoad / EntityLoadByExample.
		variables.entityType = arguments.ormSession.getSessionFactory()
			.getJpaMetamodel().entity( arguments.entityName );
		return this;
	}

	// ----- fluent API: each call appends a descriptor -----

	function eq(        required string property, required any value ) { return add( variables.restrictions.isEq(  argumentCollection = { property: property, propertyValue: value } ) ); }
	function ne(        required string property, required any value ) { return add( variables.restrictions.ne(    argumentCollection = { property: property, propertyValue: value } ) ); }
	function gt(        required string property, required any value ) { return add( variables.restrictions.isGt(  argumentCollection = { property: property, propertyValue: value } ) ); }
	function ge(        required string property, required any value ) { return add( variables.restrictions.isGe(  argumentCollection = { property: property, propertyValue: value } ) ); }
	function lt(        required string property, required any value ) { return add( variables.restrictions.isLt(  argumentCollection = { property: property, propertyValue: value } ) ); }
	function le(        required string property, required any value ) { return add( variables.restrictions.isLe(  argumentCollection = { property: property, propertyValue: value } ) ); }
	function between(   required string property, required any lo, required any hi ) { return add( variables.restrictions.between( property=property, minValue=lo, maxValue=hi ) ); }
	function like(      required string property, required string value ) { return add( variables.restrictions.like(  property=property, propertyValue=value ) ); }
	function ilike(     required string property, required string value ) { return add( variables.restrictions.ilike( property=property, propertyValue=value ) ); }
	function isIn(      required string property, required any values    ) { return add( variables.restrictions.isIn(  property=property, propertyValue=values ) ); }
	function isNull(    required string property ) { return add( variables.restrictions.isNull(    property=property ) ); }
	function isNotNull( required string property ) { return add( variables.restrictions.isNotNull( property=property ) ); }
	function isTrue(    required string property ) { return add( variables.restrictions.isTrue(    property=property ) ); }
	function isFalse(   required string property ) { return add( variables.restrictions.isFalse(   property=property ) ); }

	/**
	 * Append a raw descriptor (advanced / composition output from Restrictions.$and / $or / isNot).
	 */
	function add( required any descriptor ) {
		arrayAppend( variables.descriptors, arguments.descriptor );
		return this;
	}

	/**
	 * Add a HAVING predicate — applied after groupBy. Accepts the same descriptor
	 * shapes as add() / where(): typically aggregates wrapped in comparisons
	 * (e.g. having a count-projection alias gt 5).
	 */
	function having( required any descriptor ) {
		arrayAppend( variables.havings, arguments.descriptor );
		return this;
	}

	// ----- query options -----

	/**
	 * Add an order-by clause. Multiple calls accumulate; resolution order matches call order.
	 *
	 * @path       Property path, dotted paths supported ("role.name")
	 * @dir        "asc" (default) or "desc"
	 * @ignoreCase If true, sorts on lower(path) for case-insensitive ordering
	 */
	function order( required string path, string dir = "asc", boolean ignoreCase = false ) {
		arrayAppend( variables.orders, {
			"path"       : arguments.path,
			"dir"        : arguments.dir,
			"ignoreCase" : arguments.ignoreCase
		} );
		return this;
	}

	// ----- joins -----

	/**
	 * Register an explicit JPA Join with a named alias and a chosen JoinType.
	 * Both `alias.field` and `associationName.field` paths resolve to the same physical join afterwards.
	 *
	 * @associationName Property path on the root entity, e.g. "role" or "role.org"
	 * @alias           Alias name for use in subsequent paths, e.g. "r"
	 * @joinType        One of this.INNER_JOIN | this.LEFT_JOIN | this.RIGHT_JOIN (default INNER)
	 * @withClause      Optional descriptor — additional ON-clause restriction. Distinct from
	 *                  WHERE: an ON-clause filter on a LEFT join keeps the left-side rows but
	 *                  nulls the joined columns; in WHERE the rows would be eliminated.
	 */
	function createAlias(
		required string associationName,
		required string alias,
		string          joinType = this.INNER_JOIN,
		any             withClause
	) {
		var spec = {
			"path"     : arguments.associationName,
			"joinType" : arguments.joinType
		};
		if ( !isNull( arguments.withClause ) ) spec[ "withClause" ] = arguments.withClause;
		variables.aliases[ arguments.alias ] = spec;
		return this;
	}

	/** Alias of createAlias — matches legacy cborm naming. */
	function joinTo(
		required string associationName,
		required string alias,
		string          joinType = this.INNER_JOIN,
		any             withClause
	) {
		return createAlias( argumentCollection = arguments );
	}

	function maxResults(  required numeric n ) { variables.maxResults  = arguments.n; return this; }
	function firstResult( required numeric n ) { variables.firstResult = arguments.n; return this; }
	function cache(       boolean enabled = true ) { variables.cacheable = arguments.enabled; return this; }
	function cacheRegion( required string region ) { variables.cacheRegion = arguments.region; return this; }

	// ----- query hints (passthrough to JPA Query.setHint) -----

	function timeout(   required numeric seconds ) { variables.hints[ "org.hibernate.timeout"   ] = javacast( "int", arguments.seconds ); return this; }
	function fetchSize( required numeric n       ) { variables.hints[ "org.hibernate.fetchSize" ] = javacast( "int", arguments.n );       return this; }
	function readOnly(  boolean enabled = true   ) { variables.hints[ "org.hibernate.readOnly"  ] = javacast( "boolean", arguments.enabled ); return this; }
	function comment(   required string comment  ) { variables.hints[ "org.hibernate.comment"   ] = arguments.comment; return this; }

	/**
	 * Generic hint setter — pass JPA-standard or Hibernate hint names directly.
	 * E.g. queryHint( "jakarta.persistence.fetchgraph", graph ).
	 */
	function queryHint( required string name, required any value ) {
		variables.hints[ arguments.name ] = arguments.value;
		return this;
	}

	// ----- fetch-by-id (terminal) -----

	/**
	 * Load an entity by primary key. Returns the entity instance or null if not found.
	 * Bypasses the descriptor pipeline — uses the standard ORM lookup path.
	 */
	function get( required any id ) {
		return entityLoadByPK( variables.entityName, arguments.id );
	}

	/**
	 * Like get(), but throws cborm.EntityNotFound when the id has no match.
	 */
	function getOrFail( required any id ) {
		var entity = get( arguments.id );
		if ( isNull( entity ) ) {
			throw(
				type    = "cborm.EntityNotFound",
				message = "Entity [#variables.entityName#] with id [#arguments.id#] not found"
			);
		}
		return entity;
	}

	// ----- flow helpers (mirror cborm 4.6+ ActiveEntity additions) -----

	/**
	 * Pass the builder to a closure for inspection / inline mutation. Always returns this.
	 */
	function peek( required target ) {
		arguments.target( this );
		return this;
	}

	/**
	 * Conditional builder mutation — invoke the closure only when test is truthy.
	 * For the inverse, use unless().
	 */
	function when( required boolean test, required target, function failure ) {
		if ( arguments.test ) {
			arguments.target( this );
		} else if ( !isNull( arguments.failure ) ) {
			arguments.failure( this );
		}
		return this;
	}

	function unless( required boolean test, required target, function failure ) {
		return when(
			test    = !arguments.test,
			target  = arguments.target,
			failure = isNull( arguments.failure ) ? javacast( "null", "" ) : arguments.failure
		);
	}

	// ----- projections -----

	/**
	 * Mirrors legacy cborm.models.criterion.BaseBuilder.withProjections. Each argument is a
	 * comma-separated list of `property[:alias]` entries. Multiple kinds of projection can be
	 * combined in one call.
	 *
	 * @property      Plain property selection
	 * @count         COUNT(property)
	 * @countDistinct COUNT(DISTINCT property)
	 * @sum           SUM(property)
	 * @avg           AVG(property)
	 * @min           MIN(property)
	 * @max           MAX(property)
	 * @groupProperty Property to group by — also added to the projection list
	 * @rowCount      Add a count(rootEntity) projection (count of all matching rows)
	 */
	function withProjections(
		string  property              = "",
		string  count                 = "",
		string  countDistinct         = "",
		string  sum                   = "",
		string  avg                   = "",
		string  min                   = "",
		string  max                   = "",
		string  groupProperty         = "",
		boolean rowCount              = false,
		boolean id                    = false,
		any     distinct,
		any     sqlProjection,
		any     sqlGroupProjection,
		any     detachedSQLProjection
	) {
		// Reject arbitrary-SQL projection variants — same JPA limitation as Restrictions.sql().
		if ( !isNull( arguments.sqlProjection ) || !isNull( arguments.sqlGroupProjection ) || !isNull( arguments.detachedSQLProjection ) ) {
			throwNotImplemented(
				"withProjections(sqlProjection / sqlGroupProjection / detachedSQLProjection)",
				"Free-form SQL projections cannot be expressed via JPA Criteria. Use ormExecuteQuery( ""HQL ..."" ) for non-aggregate raw SQL needs."
			);
		}
		// Whole-list DISTINCT wrapping isn't a JPA concept — use asDistinct() for distinct rows
		// or countDistinct=... for distinct counts.
		if ( !isNull( arguments.distinct ) ) {
			throwNotImplemented(
				"withProjections(distinct=...)",
				"JPA Criteria has no per-projection-list distinct wrapper. Use .asDistinct() for whole-row distinct, or withProjections( countDistinct=""prop"" ) for COUNT(DISTINCT prop)."
			);
		}

		addProjections( arguments.property,      "property" );
		addProjections( arguments.count,         "count" );
		addProjections( arguments.countDistinct, "countDistinct" );
		addProjections( arguments.sum,           "sum" );
		addProjections( arguments.avg,           "avg" );
		addProjections( arguments.min,           "min" );
		addProjections( arguments.max,           "max" );

		if ( arguments.groupProperty.len() ) {
			for ( var p in listToArray( arguments.groupProperty ) ) {
				arrayAppend( variables.groupBys, listFirst( p, ":" ) );
			}
			// matches legacy: groupProperty also appears in the SELECT list
			addProjections( arguments.groupProperty, "property" );
		}

		if ( arguments.rowCount ) {
			arrayAppend( variables.projections, { "type": "rowCount", "path": "", "alias": "rowCount" } );
		}

		// `id=true` projects the entity's identifier — resolved from the metamodel at assemble time
		if ( arguments.id ) {
			arrayAppend( variables.projections, { "type": "id", "path": "", "alias": "id" } );
		}

		return this;
	}

	/**
	 * Return result rows as structs keyed by projection alias instead of Tuple/array.
	 * Only meaningful when projections are also configured.
	 */
	function asStruct()   { variables.asStruct     = true; return this; }

	/**
	 * Apply DISTINCT to the result list (whole-row distinct).
	 */
	function asDistinct() { variables.distinctRoot = true; return this; }

	private void function addProjections( required string spec, required string projType ) {
		if ( !arguments.spec.len() ) return;
		for ( var pair in listToArray( arguments.spec ) ) {
			var path  = listFirst( pair, ":" );
			var alias = listLen( pair, ":" ) gt 1 ? listLast( pair, ":" ) : path;
			arrayAppend( variables.projections, { "type": arguments.projType, "path": path, "alias": alias } );
		}
	}

	// ----- execution -----

	/**
	 * Build the JPA CriteriaQuery, run it, and return the result list.
	 *
	 * When projections + asStruct are both set, raw Tuple rows are converted to
	 * { alias: value } structs to match the legacy ALIAS_TO_ENTITY_MAP shape.
	 */
	function list() {
		var ctx     = buildQuery();
		var query   = variables.ormSession.createQuery( ctx.cq );
		applyQueryOptions( query );
		var results = query.getResultList();
		return tuplesToStructs( results );
	}

	function uniqueResult() {
		var ctx     = buildQuery();
		var query   = variables.ormSession.createQuery( ctx.cq );
		applyQueryOptions( query );
		var result  = query.getSingleResult();
		if ( shouldStructify() ) return tupleToStruct( result );
		return result;
	}

	/**
	 * Materialise this builder as a JPA Subquery inside a parent CriteriaQuery.
	 *
	 * Used by Subqueries.propertyIn / exists / etc. — the "detached" cborm pattern
	 * in JPA Criteria terms. JPA Subqueries can't exist independently; they're
	 * created via parentCq.subquery(Class) and own their Root/predicates within
	 * the parent's scope. The descriptor pattern fits this naturally: descriptors
	 * are pure data, materialised on demand against any (cq, root) pair.
	 *
	 * Constraints: only descriptors + projections + aliases + joins are honoured.
	 * Orders / paging / cache / asStruct / groupBy / having are ignored — they
	 * don't have JPA Subquery equivalents at this layer.
	 *
	 * @parentCq The parent CriteriaQuery this subquery attaches into
	 * @hbCb     The Hibernate/JPA CriteriaBuilder
	 */
	function renderAsSubquery( required parentCq, required hbCb, any resultType ) {
		// JPA enforces type compatibility between subquery result type and the LHS of
		// the comparison (in / equal / gt / etc.). Caller passes the LHS Path's
		// Java type so the subquery declares it correctly. Falls back to Object for
		// exists/notExists where the result type is irrelevant.
		var type = isNull( arguments.resultType )
			? createObject( "java", "java.lang.Object" ).getClass()
			: arguments.resultType;
		var sq = arguments.parentCq.subquery( type );
		var subRoot         = sq.from( variables.entityType );
		var subPathResolver = new PathResolver( root = subRoot, aliases = variables.aliases );
		var subAssembler    = new JPAAssembler(
			cb           = arguments.hbCb,
			cq           = sq,
			root         = subRoot,
			pathResolver = subPathResolver
		);

		subPathResolver.applyWithClauses( subAssembler );

		// SELECT clause: subqueries must select exactly one expression. Use the first
		// projection if the user set one (typical: count="id" or property="id"); otherwise
		// fall back to selecting the root entity (ie. `select e from Entity e where ...`).
		if ( variables.projections.len() ) {
			sq.select( subAssembler.toSelection( variables.projections[ 1 ] ) );
		} else {
			sq.select( subRoot );
		}

		// WHERE
		if ( variables.descriptors.len() ) {
			var preds = variables.descriptors.map( function( d ) {
				return subAssembler.toPredicate( arguments.d );
			} );
			sq.where( preds.len() eq 1 ? preds[ 1 ] : arguments.hbCb.and( preds ) );
		}

		return sq;
	}

	function count() {
		var hbCb         = variables.ormSession.getCriteriaBuilder();
		var cq           = hbCb.createQuery();   // untyped — returns Object on getSingleResult
		var root         = cq.from( variables.entityType );
		var pathResolver = new PathResolver( root = root, aliases = variables.aliases );
		var assembler    = new JPAAssembler( cb = hbCb, cq = cq, root = root, pathResolver = pathResolver );

		pathResolver.applyWithClauses( assembler );

		cq.select( hbCb.count( root ) );
		applyWhere( cq, hbCb, assembler );

		return variables.ormSession.createQuery( cq ).getSingleResult();
	}

	// ----- internals -----

	private struct function buildQuery() {
		var hbCb           = variables.ormSession.getCriteriaBuilder();
		var hasProjections = variables.projections.len() gt 0;

		// Tuple-mode query when projections + asStruct so we can look up by alias on the row.
		// Otherwise untyped query — works for both entity-list and Object[]/aggregate results.
		var cq = ( hasProjections && variables.asStruct )
			? hbCb.createTupleQuery()
			: hbCb.createQuery();

		var root         = cq.from( variables.entityType );
		var pathResolver = new PathResolver( root = root, aliases = variables.aliases );
		var assembler    = new JPAAssembler( cb = hbCb, cq = cq, root = root, pathResolver = pathResolver );

		// Resolve aliasable withClause descriptors to JPA predicates and attach them
		// to their joins via Join.on(...). Done before any other descriptor walk so
		// downstream paths can reference these joins safely.
		pathResolver.applyWithClauses( assembler );

		if ( hasProjections ) {
			var selections = variables.projections.map( function( p ) {
				var sel = assembler.toSelection( arguments.p );
				// Register alias so HAVING / ORDER referencing the alias by name
				// resolves to the same expression (matches legacy cborm behaviour).
				if ( arguments.p.alias.len() ) {
					pathResolver.registerProjectionAlias( arguments.p.alias, sel );
				}
				return sel;
			} );
			cq.multiselect( selections );
		} else {
			cq.select( root );
		}

		if ( variables.distinctRoot ) cq.distinct( javacast( "boolean", true ) );

		applyWhere( cq, hbCb, assembler );

		if ( variables.groupBys.len() ) {
			var groupExprs = variables.groupBys.map( function( gb ) {
				return assembler.pathFor( arguments.gb );
			} );
			cq.groupBy( groupExprs );
		}

		applyHaving( cq, hbCb, assembler );
		applyOrders( cq, assembler );

		return { cq: cq, root: root, pathResolver: pathResolver };
	}

	private boolean function shouldStructify() {
		return variables.asStruct && variables.projections.len() gt 0;
	}

	private function tuplesToStructs( required array results ) {
		if ( !shouldStructify() ) return arguments.results;
		return arguments.results.map( function( row ) { return tupleToStruct( arguments.row ); } );
	}

	private struct function tupleToStruct( required tuple ) {
		var s = {};
		for ( var p in variables.projections ) {
			s[ p.alias ] = arguments.tuple.get( p.alias );
		}
		return s;
	}

	private void function applyWhere( required cq, required hbCb, required assembler ) {
		if ( !variables.descriptors.len() ) return;

		var preds = variables.descriptors.map( function( d ) {
			return assembler.toPredicate( arguments.d );
		} );

		// Multiple top-level descriptors are ANDed (matches H5 Criteria.add() semantics)
		arguments.cq.where( preds.len() eq 1 ? preds[ 1 ] : arguments.hbCb.and( preds ) );
	}

	private void function applyHaving( required cq, required hbCb, required assembler ) {
		if ( !variables.havings.len() ) return;
		var preds = variables.havings.map( function( d ) {
			return assembler.toPredicate( arguments.d );
		} );
		arguments.cq.having( preds.len() eq 1 ? preds[ 1 ] : arguments.hbCb.and( preds ) );
	}

	private void function applyOrders( required cq, required assembler ) {
		if ( !variables.orders.len() ) return;
		var jpaOrders = variables.orders.map( function( o ) {
			return assembler.toOrder( arguments.o );
		} );
		arguments.cq.orderBy( jpaOrders );
	}

	/**
	 * Apply paging + caching + arbitrary hints to the runtime Query.
	 */
	private void function applyQueryOptions( required query ) {
		if ( variables.firstResult ) arguments.query.setFirstResult( javacast( "int", variables.firstResult ) );
		if ( variables.maxResults  ) arguments.query.setMaxResults(  javacast( "int", variables.maxResults  ) );
		if ( variables.cacheable   ) arguments.query.setCacheable(   javacast( "boolean", true ) );
		if ( variables.cacheRegion.len() ) arguments.query.setCacheRegion( variables.cacheRegion );

		for ( var hintName in variables.hints ) {
			arguments.query.setHint( hintName, variables.hints[ hintName ] );
		}
	}

	// =====================================================================
	// Legacy-API stubs — TODO: implement or formally retire.
	//
	// These methods exist on the H5 BaseBuilder/CriteriaBuilder surface but have no
	// clean JPA Criteria equivalent. Stubbed so user code calling them gets a clear,
	// catchable cborm.JPA.NotImplemented error instead of "method not found".
	// =====================================================================

	/** TODO: cbStreams integration. Returns a stream wrapping list() results. */
	function asStream() {
		throwNotImplemented( "asStream", "cbStreams integration not wired in the JPA builder yet. Use .list() and feed it into a stream manually if needed." );
	}

	/** TODO: re-rooted criteria at an associated entity. JPA equivalent requires building a fresh CriteriaQuery; deferred. */
	function createSubcriteria( required string entityName, string alias = "" ) {
		throwNotImplemented( "createSubcriteria", "Re-rooting criteria at an associated entity has no direct JPA Criteria translation. Use a separate CriteriaBuilder( entityName=#arguments.entityName# ) and join/correlate as needed, or use Subqueries for IN/EXISTS patterns." );
	}

	/** Manual JPA Selection injection. Use withProjections(...) instead. */
	function setProjection( any projection ) {
		throwNotImplemented( "setProjection", "Pass projection specs via withProjections( property=, count=, ... ). Manual JPA Selection objects bypass the descriptor pipeline." );
	}

	/** Hibernate ResultTransformer — removed in H6. Equivalent: withProjections + asStruct, or write a closure over .list() results. */
	function resultTransformer( any resultTransformer ) {
		throwNotImplemented( "resultTransformer", "Hibernate ResultTransformer was removed in H6. Use .asStruct() (alias-keyed structs) or .asDistinct() (whole-row distinct), or transform .list() results in CFML." );
	}

	// ---- SQL extraction (Hibernate's CriteriaJoinWalker / CriteriaQueryTranslator are gone in H6+) ----

	function getSQL( boolean returnExecutableSql = false, boolean formatSql = true ) {
		throwNotImplemented( "getSQL", "JPA Criteria has no public API to extract the rendered SQL string. Enable Hibernate's logSQL setting on the datasource for SQL logging, or unwrap to org.hibernate.query.Query and call .getQueryString() for the HQL form (not raw SQL)." );
	}

	function getPositionalSQLParameterValues() { throwNotImplemented( "getPositionalSQLParameterValues", "Same as getSQL — internal Hibernate criteria SQL extraction was removed in H6." ); }
	function getPositionalSQLParameterTypes()  { throwNotImplemented( "getPositionalSQLParameterTypes",  "Same as getSQL." ); }
	function getPositionalSQLParameters()      { throwNotImplemented( "getPositionalSQLParameters",      "Same as getSQL." ); }
	function getSQLLog()                       { throwNotImplemented( "getSQLLog",                       "Internal SQL log relied on legacy SQL extraction. Use Hibernate's logSQL setting." ); }
	function startSqlLog( boolean returnExecutableSql = false, boolean formatSql = false ) { throwNotImplemented( "startSqlLog", "Use Hibernate's logSQL setting on the datasource." ); }
	function stopSqlLog()                       { throwNotImplemented( "stopSqlLog",  "Use Hibernate's logSQL setting on the datasource." ); }
	function logSQL( required string label )    { throwNotImplemented( "logSQL",      "Use Hibernate's logSQL setting on the datasource." ); }
	function canLogSql()                        { return false; }   // safe falsey — callers branch on this

	// ---- type-coercion helpers (JPA does its own coercion via parameter binding) ----

	function convertIDValueToJavaType( required id )                         { throwNotImplemented( "convertIDValueToJavaType", "JPA performs its own parameter coercion. Pass values directly to predicates." ); }
	function idCast( required id )                                            { throwNotImplemented( "idCast",                  "JPA performs its own parameter coercion. Pass values directly to predicates." ); }
	function convertValueToJavaType( required propertyName, required value )  { throwNotImplemented( "convertValueToJavaType",  "JPA performs its own parameter coercion. Pass values directly to predicates." ); }
	function autoCast( required propertyName, required value )               { throwNotImplemented( "autoCast",                "JPA performs its own parameter coercion. Pass values directly to predicates." ); }

	// ---- consistent throw helper ----

	private void function throwNotImplemented( required string method, string detail = "" ) {
		throw(
			type    = "cborm.JPA.NotImplemented",
			message = "[#arguments.method#] is not implemented in the H7+ JPA criterion pipeline",
			detail  = arguments.detail
		);
	}

}
