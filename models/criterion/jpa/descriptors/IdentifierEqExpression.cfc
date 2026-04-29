/**
 * Descriptor for Restrictions.idEq(value).
 * Mirrors org.hibernate.criterion.IdentifierEqExpression in legacy Hibernate.
 * The assembler resolves the entity's id attribute name from the runtime metamodel
 * at execution time, so this descriptor only carries the comparison value.
 */
component {
	function init( required any value ) {
		this.type  = "idEq";
		this.value = arguments.value;
		return this;
	}
}
