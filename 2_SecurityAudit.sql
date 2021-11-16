/*********************************************************************************************
PURPOSE:    Creates SQL Audits and Specification	
----------------------------------------------------------------------------------------------
REVISION HISTORY:
Date				Developer Name				Change Description                                    
----------			--------------				------------------
10/24/2021			Jared Karney				Original Version
----------------------------------------------------------------------------------------------


This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.  
THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  
We grant You a nonexclusive, royalty-free right to use and modify the 
Sample Code and to reproduce and distribute the object code form of the Sample Code, provided that You agree: (i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded; 
(ii) to include a valid copyright notice on Your software product in which the Sample Code is 
embedded; and 
(iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys’ fees, that arise or result from the use or distribution of the Sample Code.
Please note: None of the conditions outlined in the disclaimer above will supercede the terms and conditions contained within the Premier Customer Services Description.
**********************************************************************************************/

--  View Audit Group Metadata
/*
WITH server_level_groups AS (
    SELECT name
    FROM sys.dm_audit_actions
    WHERE name LIKE '%GROUP' AND class_desc = 'DATABASE'
)
SELECT a.containing_group_name AS group_to_audit, a.class_desc, a.name
FROM sys.dm_audit_actions a
     INNER JOIN server_level_groups g ON g.name = a.containing_group_name
WHERE a.action_in_log = 1 
--AND  containing_group_name = 'LOGIN_CHANGE_PASSWORD_GROUP' 
ORDER BY a.containing_group_name, a.name;
*/


USE master

--Creates Audit
CREATE SERVER AUDIT Security_Object_Change
TO FILE 
(	FILEPATH = N'C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\Log\'
	,MAXSIZE =  200MB
	,MAX_ROLLOVER_FILES = 5
	,RESERVE_DISK_SPACE = OFF
)
WITH
(	QUEUE_DELAY = 1000
	,ON_FAILURE = CONTINUE
)
ALTER SERVER AUDIT Security_Object_Change WITH (STATE = ON)

--Creates audit specification
CREATE SERVER AUDIT SPECIFICATION Security_Object_Change_Spec
FOR SERVER AUDIT Security_Object_Change
		ADD(AUDIT_CHANGE_GROUP),
		ADD(DATABASE_CHANGE_GROUP),
		ADD(DATABASE_OBJECT_CHANGE_GROUP),
		ADD(DATABASE_OBJECT_OWNERSHIP_CHANGE_GROUP),
		ADD(DATABASE_OBJECT_PERMISSION_CHANGE_GROUP),
		ADD(DATABASE_PERMISSION_CHANGE_GROUP),
		ADD(DATABASE_PRINCIPAL_CHANGE_GROUP),
		ADD(DATABASE_ROLE_MEMBER_CHANGE_GROUP),
		ADD(LOGIN_CHANGE_PASSWORD_GROUP),
		ADD(SCHEMA_OBJECT_OWNERSHIP_CHANGE_GROUP),
		ADD(SCHEMA_OBJECT_PERMISSION_CHANGE_GROUP),
		ADD(SERVER_OBJECT_CHANGE_GROUP),
		ADD(SERVER_OBJECT_PERMISSION_CHANGE_GROUP),
		ADD(SERVER_OPERATION_GROUP),
		ADD(SERVER_PERMISSION_CHANGE_GROUP),
		ADD(SERVER_PRINCIPAL_CHANGE_GROUP),
		ADD(SERVER_ROLE_MEMBER_CHANGE_GROUP),
		ADD(SERVER_STATE_CHANGE_GROUP),
		ADD(USER_CHANGE_PASSWORD_GROUP)
WITH(STATE=ON)
