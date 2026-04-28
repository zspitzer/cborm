component persistent="true" table="users" entityName="User" {

	property name="id"       fieldtype="id" generator="native";
	property name="name"     type="string"  length="80";
	property name="age"      type="numeric" ormtype="integer";
	property name="isActive" type="boolean";

	property
		name      ="role"
		fieldtype ="many-to-one"
		cfc       ="Role"
		fkcolumn  ="role_id";

}
