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

	CriteriaBuilder function init(
		required string entityName,
		required any    ormSession,    // org.hibernate.Session (also a jakarta.persistence.EntityManager)
		any             restrictions
	) {
		variables.entityName   = arguments.entityName;
		variables.ormSession   = arguments.ormSession;
		variables.descriptors  = [];
		variables.orders       = [];
		variables.maxResults   = 0;     // 0 = unbounded
		variables.firstResult  = 0;
		variables.cacheable    = false;
		variables.cacheRegion  = "";
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

	function maxResults(  required numeric n ) { variables.maxResults  = arguments.n; return this; }
	function firstResult( required numeric n ) { variables.firstResult = arguments.n; return this; }
	function cache(       boolean enabled = true ) { variables.cacheable = arguments.enabled; return this; }
	function cacheRegion( required string region ) { variables.cacheRegion = arguments.region; return this; }

	// ----- execution -----

	/**
	 * Build the JPA CriteriaQuery, run it, and return the result list.
	 */
	function list() {
		var ctx   = buildQuery();
		var query = variables.ormSession.createQuery( ctx.cq );
		applyQueryOptions( query );
		return query.getResultList();
	}

	function uniqueResult() {
		var ctx   = buildQuery();
		var query = variables.ormSession.createQuery( ctx.cq );
		applyQueryOptions( query );
		return query.getSingleResult();
	}

	function count() {
		var hbCb         = variables.ormSession.getCriteriaBuilder();
		var cq           = hbCb.createQuery();   // untyped — returns Object on getSingleResult
		var root         = cq.from( variables.entityType );
		var pathResolver = new PathResolver( root = root );
		var assembler    = new JPAAssembler( cb = hbCb, root = root, pathResolver = pathResolver );

		cq.select( hbCb.count( root ) );
		applyWhere( cq, hbCb, assembler );

		return variables.ormSession.createQuery( cq ).getSingleResult();
	}

	// ----- internals -----

	private struct function buildQuery() {
		var hbCb         = variables.ormSession.getCriteriaBuilder();
		var cq           = hbCb.createQuery();   // untyped — Lucee dynamic-map entities aren't Class<T>-typeable
		var root         = cq.from( variables.entityType );
		var pathResolver = new PathResolver( root = root );
		var assembler    = new JPAAssembler( cb = hbCb, root = root, pathResolver = pathResolver );

		cq.select( root );
		applyWhere( cq, hbCb, assembler );
		applyOrders( cq, assembler );

		return { cq: cq, root: root, pathResolver: pathResolver };
	}

	private void function applyWhere( required cq, required hbCb, required assembler ) {
		if ( !variables.descriptors.len() ) return;

		var preds = variables.descriptors.map( function( d ) {
			return assembler.toPredicate( arguments.d );
		} );

		// Multiple top-level descriptors are ANDed (matches H5 Criteria.add() semantics)
		arguments.cq.where( preds.len() eq 1 ? preds[ 1 ] : arguments.hbCb.and( preds ) );
	}

	private void function applyOrders( required cq, required assembler ) {
		if ( !variables.orders.len() ) return;
		var jpaOrders = variables.orders.map( function( o ) {
			return assembler.toOrder( arguments.o );
		} );
		arguments.cq.orderBy( jpaOrders );
	}

	/**
	 * Apply paging + caching to the runtime Query (not the CriteriaQuery — these are
	 * runtime hints, not part of the SQL spec).
	 */
	private void function applyQueryOptions( required query ) {
		if ( variables.firstResult ) arguments.query.setFirstResult( javacast( "int", variables.firstResult ) );
		if ( variables.maxResults  ) arguments.query.setMaxResults(  javacast( "int", variables.maxResults  ) );
		if ( variables.cacheable   ) arguments.query.setCacheable(   javacast( "boolean", true ) );
		if ( variables.cacheRegion.len() ) arguments.query.setCacheRegion( variables.cacheRegion );
	}

}
