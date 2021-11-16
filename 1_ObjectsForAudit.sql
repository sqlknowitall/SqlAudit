/*********************************************************************************************
PURPOSE:    Creates all database objects needed to house Audit/Change History
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



USE master
IF EXISTS(SELECT 1 FROM sys.databases WHERE name = 'TestSecAudit')
DROP DATABASE TestSecAudit
GO

CREATE DATABASE TestSecAudit
GO

USE TestSecAudit
GO

--Records information about last read audit file and location
CREATE TABLE [dbo].[Audit_Locator](
	[audit_name] [varchar](128) NULL,
	[file_name] [nvarchar](260) NOT NULL,
	[audit_file_offset] [bigint] NOT NULL,
	[file_pattern] [nvarchar](260) NULL,
	[locator_id] [int] IDENTITY(1,1) NOT NULL,
	[active] [char](1) NULL
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[Audit_Locator] ADD  DEFAULT ('Y') FOR [active]
GO

--Table for staging audit data for processing before being inserted into Record table
CREATE TABLE [dbo].[Audit_Stage](
	[audit_name] [varchar](128) NOT NULL,
	[event_time] [datetime2](7) NOT NULL,
	[sequence_number] [int] NOT NULL,
	[action_id] [varchar](4) NULL,
	[succeeded] [bit] NOT NULL,
	[permission_bitmask] [bigint] NOT NULL,
	[is_column_permission] [bit] NOT NULL,
	[session_id] [smallint] NOT NULL,
	[server_principal_id] [int] NOT NULL,
	[database_principal_id] [int] NOT NULL,
	[target_server_principal_id] [int] NOT NULL,
	[target_database_principal_id] [int] NOT NULL,
	[object_id] [int] NOT NULL,
	[class_type] [varchar](2) NULL,
	[session_server_principal_name] [nvarchar](128) NULL,
	[server_principal_name] [nvarchar](128) NULL,
	[server_principal_sid] [varbinary](85) NULL,
	[database_principal_name] [nvarchar](128) NULL,
	[target_server_principal_name] [nvarchar](128) NULL,
	[target_server_principal_sid] [varbinary](85) NULL,
	[target_database_principal_name] [nvarchar](128) NULL,
	[server_instance_name] [nvarchar](128) NULL,
	[database_name] [nvarchar](128) NULL,
	[schema_name] [nvarchar](128) NULL,
	[object_name] [nvarchar](128) NULL,
	[statement] [nvarchar](4000) NULL,
	[additional_information] [nvarchar](4000) NULL,
	[file_name] [nvarchar](260) NOT NULL,
	[audit_file_offset] [bigint] NOT NULL
) ON [PRIMARY]
GO

--Table to hold Audit detail for reporting/alerting
CREATE TABLE [dbo].[Audit_Record](
	[audit_name] [varchar](128) NOT NULL,
	[event_time] [datetime2](7) NOT NULL,
	[sequence_number] [int] NULL,
	[action_id] [varchar](4) NULL,
	[succeeded] [bit] NULL,
	[permission_bitmask] [bigint] NULL,
	[is_column_permission] [bit] NULL,
	[session_id] [smallint] NULL,
	[server_principal_id] [int] NULL,
	[database_principal_id] [int] NULL,
	[target_server_principal_id] [int] NULL,
	[target_database_principal_id] [int] NULL,
	[object_id] [int] NULL,
	[class_type] [varchar](2) NULL,
	[session_server_principal_name] [nvarchar](128) NULL,
	[server_principal_name] [nvarchar](128) NULL,
	[server_principal_sid] [varbinary](85) NULL,
	[database_principal_name] [nvarchar](128) NULL,
	[target_server_principal_name] [nvarchar](128) NULL,
	[target_server_principal_sid] [varbinary](85) NULL,
	[target_database_principal_name] [nvarchar](128) NULL,
	[server_instance_name] [nvarchar](128) NULL,
	[database_name] [nvarchar](128) NULL,
	[schema_name] [nvarchar](128) NULL,
	[object_name] [nvarchar](128) NULL,
	[statement] [nvarchar](4000) NULL,
	[additional_information] [nvarchar](4000) NULL,
	[file_name] [nvarchar](260) NULL,
	[audit_file_offset] [bigint] NULL
) ON [PRIMARY]
GO

--Exclusion table to filter explicit objects
CREATE TABLE [dbo].[Audit_Exclude](
	[InstanceName] [nvarchar](128) NULL,
	[DatabaseName] [varchar](50) NULL,
	[SchemaName] [sysname] NOT NULL,
	[ObjectName] [varchar](50) NULL,
	[ObjectType] [varchar](50) NULL,
	[Reason] [varchar](100) NULL
) ON [PRIMARY]
GO

--Record history of Load procedure execution
CREATE TABLE [dbo].[Audit_LoadLog](
	[audit_name] [varchar](128) NULL,
	[staged_count] [int] NOT NULL,
	[saved_count] [int] NOT NULL,
	[run_date] [datetime] NULL
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[Audit_LoadLog] ADD  DEFAULT (getdate()) FOR [run_date]
GO

--Procedure to load audit data
CREATE OR ALTER PROCEDURE [dbo].[usp_LoadAuditData]
AS
    BEGIN
        DECLARE @audit VARCHAR(128) , --name of the audit
            @file NVARCHAR(260) ,
            @offset BIGINT ,
            @pattern NVARCHAR(260) ,
            @staged INT ,
            @saved INT;
 
        SET NOCOUNT ON;
 
        DECLARE cAudits CURSOR
        FOR
            SELECT  audit_name ,
                    file_name ,
                    audit_file_offset ,
                    file_pattern
            FROM    Audit_Locator
            WHERE   active = 'Y' FOR UPDATE;

        OPEN cAudits;

        FETCH cAudits INTO @audit, @file, @offset, @pattern;
        WHILE @@fetch_status = 0
            BEGIN
 
                SET @staged = 0;
                SET @saved = 0;
 
                INSERT  INTO Audit_Stage
                        SELECT  @audit , event_time, sequence_number,action_id, succeeded, permission_bitmask, is_column_permission, session_id, server_principal_id, database_principal_id, target_server_principal_id, target_database_principal_id, object_id, class_type, session_server_principal_name, server_principal_name, server_principal_sid, database_principal_name, target_server_principal_name, target_server_principal_sid, target_database_principal_name, server_instance_name, database_name, schema_name, object_name, statement, additional_information, file_name, audit_file_offset
                                
                        FROM    fn_get_audit_file(@pattern, @file, @offset);
 
                SET @staged = @@rowcount;
 
                INSERT  INTO Audit_Record
                        SELECT  *
                        FROM    Audit_Stage a
                        WHERE   NOT EXISTS ( SELECT 1
                                             FROM   dbo.Audit_Exclude ae
                                             WHERE  a.server_instance_name = ae.InstanceName
                                                    AND a.database_name = ae.DatabaseName
                                                    AND a.schema_name = ae.SchemaName
                                                    AND a.object_name = ae.ObjectName )
						AND Action_ID <> 'VSST';--excluding View Server State
 
                SET @saved = @@rowcount;

                SELECT TOP 1
                        @file = file_name ,
                        @offset = audit_file_offset
                FROM    Audit_Stage
                ORDER BY event_time DESC;
 
                UPDATE  Audit_Locator
                SET     file_name = @file ,
                        audit_file_offset = @offset
                WHERE CURRENT OF cAudits;

                INSERT  INTO Audit_LoadLog
                        ( audit_name ,
                          staged_count ,
                          saved_count
                        )
                VALUES  ( @audit ,
                          @staged ,
                          @saved
                        );
                DELETE  Audit_Stage;
                FETCH cAudits INTO @audit, @file, @offset, @pattern;
            END;
        CLOSE cAudits;
        DEALLOCATE cAudits;
    END;


GO


