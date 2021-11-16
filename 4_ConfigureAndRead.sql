/*********************************************************************************************
PURPOSE:    Sample script that initializes an audit and then loads audit data
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



USE TestSecAudit
GO
--TRUNCATE TABLE dbo.Audit_Locator

--Initialize a particular audit
declare @initfile nvarchar(260)
select @initfile=log_file_path+ log_file_name from sys.server_file_audits where name = 'Security_Object_Change'
set @initfile = STUFF(@initfile,len(@initfile)-charindex('.',reverse(@initfile)), 1, '*')
Insert into dbo.Audit_Locator  (audit_name, file_name, audit_file_offset, file_pattern)
SELECT top 1 'Security_Object_Change', file_name, audit_file_offset, @initfile FROM fn_get_audit_file (@initfile, default,  default) order by event_time asc

--Verify data
SELECT * FROM dbo.Audit_Locator

--Change some settings
USE master
GO
EXEC sp_configure 'advanced',1
RECONFIGURE WITH OVERRIDE
GO
CREATE LOGIN tempsysadmin WITH password = 'csnajk%#89jkjSADSGnm2SADF$#@f'
GO
ALTER SERVER ROLE sysadmin ADD MEMBER tempsysadmin
GO
DROP LOGIN tempsysadmin
GO
USE [TestSecAudit]
GO
ALTER DATABASE SCOPED CONFIGURATION SET MAXDOP = 4;
GO


--Loads data from ALL audits and the configuration XE, in this case there is only 1 audit
--It is these procedures you will want to schedule in a SQL Job or Windows Task.
--The config changes you may want to run separate and more frequently since it uses the ring buffer
EXEC dbo.usp_LoadAuditData
EXEC dbo.usp_LoadServerConfigChanges

--Verify Data
SELECT * FROM Audit_Stage
SELECT * FROM Audit_Record

