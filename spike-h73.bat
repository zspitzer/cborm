SET "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-21.0.9.10-hotspot"

if not exist test-output mkdir test-output

call ant -buildfile "d:\work\script-runner" ^
    -DluceeJar="D:\work\lucee7\loader\target\lucee-7.0.4.29-SNAPSHOT.jar" ^
    -Dwebroot="d:\work\cborm" ^
    -Dexecute="tests/h73/spike.cfm" ^
    -DextensionDir="d:\work\lucee-extensions\extension-hibernate\target" ^
    -DuniqueWorkingDir="true" > test-output\spike-h73.txt 2>&1

type test-output\spike-h73.txt
