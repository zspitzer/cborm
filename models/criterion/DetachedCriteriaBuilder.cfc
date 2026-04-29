/**
 * Copyright Since 2005 ColdBox Framework by Luis Majano and Ortus Solutions, Corp
 * www.ortussolutions.com
 * ---
 * Based on the general approach of CriteriaBuilder.cfc, DetachedCriteriaBuilder allows you
 * to create a detached criteria query that can be used:
 * - in conjuction with critierion.Subqueries to add a programmatically built subquery as a criterion of another criteria query
 * - as a detachedSQLProjection, which allows you to build a programmatic subquery that is added as a projection to another criteria query
 *
 * @author Luis Majano
 * @see    https://docs.jboss.org/hibernate/stable/orm/javadocs/org/hibernate/criterion/DetachedCriteria.html
 * @see    cborm.models.criterion.CriteriaBuilder
 */
import cborm.models.*;
component accessors="true" extends="cborm.models.criterion.BaseBuilder" {

	/**
	 * Constructor: Usually called by the `createSubcriteria` in the `CriteriaBuilder` object
	 *
	 * @entityName The entity name for the subcriteria
	 * @alias      The entity alias to use in the subcriteria
	 * @ormService A reference back to the calling orm service
	 */
	any function init(
		required string entityName,
		required string alias,
		required any ormService
	){
		// Hibernate 7+ removed org.hibernate.criterion.DetachedCriteria. The JPA descriptor
		// pipeline uses ordinary CriteriaBuilder instances as detached sources — pass them
		// to Subqueries.propertyIn / exists / etc. and they materialise as JPA Subquery
		// nodes inside the parent CriteriaQuery at execution time.
		//
		// Build the jpa CriteriaBuilder as an internal delegate, mirror its legacy public
		// surface to this.*, and return `this`. onMissingMethod forwards method calls to the
		// delegate so callers and test specs that hold the DetachedCriteriaBuilder reference
		// keep working without knowing about the swap.
		if ( useJPACriteria() ) {
			var orm = arguments.ormService.getOrm();
			variables.jpaDelegate = new cborm.models.criterion.jpa.CriteriaBuilder(
				entityName = arguments.entityName,
				ormSession = orm.getSession( orm.getEntityDatasource( arguments.entityName ) ),
				ormService = arguments.ormService
			);
			variables.entityName = arguments.entityName;
			variables.ormService = arguments.ormService;
			this.RESTRICTIONS         = variables.jpaDelegate.getRestrictions();
			this.ENTITYNAME           = arguments.entityName;
			this.ORMSERVICE           = arguments.ormService;
			this.PROJECTIONS          = "";
			this.DISTINCT_ROOT_ENTITY = "";
			this.INNER_JOIN           = variables.jpaDelegate.INNER_JOIN;
			this.LEFT_JOIN            = variables.jpaDelegate.LEFT_JOIN;
			this.RIGHT_JOIN           = variables.jpaDelegate.RIGHT_JOIN;
			return this;
		}

		// create new java DetachedCriteria
		var detachedCriteria = arguments.ormService
			.buildJavaProxy( "org.hibernate.criterion.DetachedCriteria" )
			.forEntityName( arguments.entityName, arguments.alias );

		// We don't use the normal restrictions object, we use the subclass: SubQueries specific to detached criteria queries
		var subQueriesRestrictions = arguments.ormService
			.getWireBox()
			.getInstance( "SubQueries@cborm" )
			.setDetachedCriteria( detachedCriteria );

		// Super size me
		super.init(
			entityName  : arguments.entityName,
			criteria    : detachedCriteria,
			restrictions: subQueriesRestrictions,
			ormService  : arguments.ormService
		);

		return this;
	}

	/**
	 * pass off arguments to higher-level restriction builder, and handle the results
	 *
	 * @missingMethodName     
	 * @missingMethodArguments
	 */
	any function onMissingMethod( required string missingMethodName, required struct missingMethodArguments ){
		// JPA mode: forward to the held delegate. If the delegate returned itself (chain
		// pattern), re-box as `this` so callers chaining off the DetachedCriteriaBuilder
		// reference stay on this object instead of leaking the jpa instance.
		if ( !isNull( variables.jpaDelegate ) ) {
			var result = invoke(
				variables.jpaDelegate,
				arguments.missingMethodName,
				arguments.missingMethodArguments
			);
			if ( isNull( result ) ) return;
			if ( isObject( result ) && result.equals( variables.jpaDelegate ) ) return this;
			return result;
		}

		// get the restriction/new criteria
		var r = createRestriction( argumentCollection = arguments );

		// switch on the object type
		if ( structKeyExists( r, "CFML" ) ) {
			// if it's a builder, just return this
			return this;
		}

		// switch on the object type
		switch ( getMetadata( r ).name ) {
			// if a subquery, we *need* to return the restrictino itself, or bad things happen
			case "org.hibernate.criterion.PropertySubqueryExpression":
			case "org.hibernate.criterion.ExistsSubqueryExpression":
			case "org.hibernate.criterion.SimpleSubqueryExpression":
				return r;

				// otherwise, just a restriction; add it to nativeCriteria, then return this so we can keep chaining
			default:
				nativeCriteria.add( r );
				// process interception
				variables.eventManager.announce(
					"onCriteriaBuilderAddition",
					{
						"type"            : "Subquery Restriction",
						"CriteriaBuilder" : this
					}
				);
				break;
		}

		return this;
	}

	/**
	 * Get a native executable criteria object.
	 *
	 * @see https://docs.jboss.org/hibernate/stable/orm/javadocs/org/hibernate/Criteria.html
	 */
	any function getNativeCriteria(){
		if ( !isNull( variables.jpaDelegate ) ) return variables.jpaDelegate;
		var ormsession = variables.ORMService.getORM().getSession( variables.ormService.getDatasource() );
		return variables.nativeCriteria.getExecutableCriteria( ormsession );
	}

	/**
	 * Create the detached sql projection
	 *
	 * @see https://docs.jboss.org/hibernate/stable/orm/javadocs/org/hibernate/criterion/Projection.html
	 *
	 * @return org.hibernate.criterion.Projection
	 */
	any function createDetachedSQLProjection(){
		if ( !isNull( variables.jpaDelegate ) ) {
			throw(
				type    = "cborm.NotImplemented",
				message = "createDetachedSQLProjection is not yet supported on Hibernate 7+",
				detail  = "Legacy SQL projection extraction relied on org.hibernate.criterion.* internals removed in H7. Track in the cborm h73 polyfill backlog."
			);
		}
		var sqlHelper   = getSqlHelper();
		// get the sql with replaced parameters
		var sql         = sqlHelper.getSql( returnExecutableSql = true );
		var alias       = sqlHelper.getProjectionAlias();
		var uniqueAlias = sqlHelper.generateSQLAlias();
		// by default, alias is this_...convert it to the alias provided
		sql             = replaceNoCase(
			sql,
			"this_",
			sqlHelper.getRootSQLAlias(),
			"all"
		);
		// wrap it up and uniquely alias it
		sql = "( #sql# ) as " & alias;

		// now that we have the sql string, we can create the sqlProjection
		var projection = this.PROJECTIONS.sqlProjection( sql, [ alias ], sqlHelper.getProjectedTypes() );
		// finally, add the alias to the projection list so we can sort on the column if needed
		return this.PROJECTIONS.alias( projection, alias );
	}

	/**
	 * Join an association, assigning an alias to the joined association.
	 *
	 * @associationName The name of the association property
	 * @alias           The alias to use for this association property on restrictions
	 * @joinType        The hibernate join type to use, by default it uses an inner join. Available as properties: criteria.FULL_JOIN, criteria.INNER_JOIN, criteria.LEFT_JOIN
	 */
	any function createAlias(
		required string associationName,
		required string alias,
		numeric joinType = this.INNER_JOIN
	){
		if ( !isNull( variables.jpaDelegate ) ) {
			variables.jpaDelegate.createAlias(
				arguments.associationName,
				arguments.alias,
				arguments.joinType
			);
			return this;
		}
		return super.createAlias(
			arguments.associationName,
			arguments.alias,
			arguments.joinType
		);
	}
	/**
	 * Create a new Criteria, "rooted" at the associated entity and using an Inner Join
	 *
	 * @associationName The name of the association property to root the restrictions with
	 * @alias           The alias to use for this association property on restrictions
	 * @joinType        The hibernate join type to use, by default it uses an inner join. Available as properties: criteria.FULL_JOIN, criteria.INNER_JOIN, criteria.LEFT_JOIN
	 */
	any function createCriteria(
		required string associationName,
		string alias,
		numeric joinType = this.INNER_JOIN
	){
		if ( !isNull( variables.jpaDelegate ) ) {
			invoke( variables.jpaDelegate, "createCriteria", arguments );
			return this;
		}
		if ( structKeyExists( arguments, "alias" ) ) {
			return super.createCriteria(
				associationName = arguments.associationName,
				alias           = arguments.alias,
				joinType        = arguments.joinType
			);
		} else {
			return super.createCriteria(
				associationName = arguments.associationName,
				joinType        = arguments.joinType
			);
		}
	}

	/**
	 * Set a limit upon the number of objects to be retrieved.
	 *
	 * @maxResults The max results to limit by
	 */
	any function maxResults( required numeric maxResults ){
		if ( !isNull( variables.jpaDelegate ) ) {
			variables.jpaDelegate.maxResults( arguments.maxResults );
			return this;
		}
		getNativeCriteria().setMaxResults( javacast( "int", arguments.maxResults ) );
		if ( getSqlHelper().canLogLimitOffset() ) {
			// process interception
			if ( variables.ormService.getEventHandling() ) {
				variables.eventManager.announce(
					"onCriteriaBuilderAddition",
					{ "type" : "Max", "criteriaBuilder" : this }
				);
			}
		}

		return this;
	}

}
