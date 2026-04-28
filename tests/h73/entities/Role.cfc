component persistent="true" table="role" entityName="Role" {

	property name="id"   fieldtype="id" generator="native";
	property name="name" type="string" length="50";

	property
		name      ="org"
		fieldtype ="many-to-one"
		cfc       ="Org"
		fkcolumn  ="org_id";

	property
		name      ="users"
		fieldtype ="one-to-many"
		cfc       ="User"
		fkcolumn  ="role_id"
		inverse   ="true";

}
