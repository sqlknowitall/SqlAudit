/*********************************************************************************************
PURPOSE:    Sample script that sets up objects to capture Server level configuration changes
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
IF EXISTS
(
	SELECT *
	FROM sys.server_event_sessions
	WHERE server_event_sessions.name = 'Configuration_Changes'
    )
DROP EVENT SESSION Configuration_Changes ON SERVER;
GO

--XE to track server level configuration changes
CREATE EVENT SESSION Configuration_Changes
ON SERVER
ADD EVENT sqlserver.error_reported
    (
	ACTION
        (
		sqlserver.client_app_name
		, sqlserver.client_connection_id
		, sqlserver.database_name
		, sqlserver.nt_username
		, sqlserver.sql_text, sqlserver.username 
		)
	WHERE [error_number]=(15457) OR [error_number]=(5084)
	)
,ADD EVENT sqlserver.database_attached
	(
	ACTION
        (
		sqlserver.client_app_name
		, sqlserver.client_connection_id
		, sqlserver.database_name
		, sqlserver.nt_username
		, sqlserver.sql_text, sqlserver.username 
		)
	)
,ADD EVENT sqlserver.database_detached
	(
	ACTION
        (
		sqlserver.client_app_name
		, sqlserver.client_connection_id
		, sqlserver.database_name
		, sqlserver.nt_username
		, sqlserver.sql_text, sqlserver.username 
		)
	)
ADD TARGET package0.ring_buffer(SET max_memory = (4096))
WITH
(
	MAX_MEMORY = 4096KB
	, EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS
	, MAX_DISPATCH_LATENCY = 30 SECONDS
	, MAX_EVENT_SIZE = 0KB
	, MEMORY_PARTITION_MODE = NONE
	, TRACK_CAUSALITY = OFF
	, STARTUP_STATE = on
);
GO

ALTER EVENT SESSION Configuration_Changes ON SERVER STATE = START;
GO


USE TestSecAudit
GO

--Procedure to load configuration changes into tha Audit_Record table
CREATE OR ALTER PROCEDURE [dbo].[usp_LoadServerConfigChanges]
AS
    BEGIN
        SET NOCOUNT ON;
				
		DECLARE @saved INT;
		DECLARE @target_data XML =
        (
        SELECT TOP 1 Cast(xet.target_data AS XML) AS targetdata
            FROM sys.dm_xe_session_targets AS xet
            INNER JOIN sys.dm_xe_sessions AS xes
                ON xes.address = xet.event_session_address
            WHERE xes.name = 'Configuration_Changes'
            AND xet.target_name = 'ring_buffer'
        );

        INSERT INTO [dbo].[Audit_Record]
           ([audit_name]
           ,[event_time]
           ,[action_id]
           ,[server_principal_name]
           ,[database_principal_name]
           ,[database_name]
           ,[statement]
           ,[additional_information]
           )
		SELECT xep.audit_name, xep.event_time, CAST(xep.action_id AS VARCHAR(4)), xep.server_principal_name, xep.database_principal_name,
			xep.database_name, xep.statement, xep.additional_information
		FROM (SELECT 'Configuration_Changes' AS audit_name,
		CONVERT(datetime2,
				SwitchOffset(CONVERT(datetimeoffset,xed.event_data.value('(@timestamp)[1]', 'datetime2')),
				DateName(TzOffset, SYSDATETIMEOFFSET()))) AS event_time,
		xed.event_data.value('(data[@name="error_number"]/value)[1]', 'int') AS action_id,
		xed.event_data.value('(action[@name="nt_username"]/value)[1]', 'varchar(255)') AS [server_principal_name],
		xed.event_data.value('(action[@name="username"]/value)[1]', 'varchar(255)') AS [database_principal_name],
		xed.event_data.value('(action[@name="database_name"]/value)[1]', 'varchar(255)') AS [database_name],
		xed.event_data.value('(action[@name="sql_text"]/value)[1]', 'nvarchar(max)') AS [statement],
		xed.event_data.value('(data[@name="message"]/value)[1]', 'varchar(255)') AS additional_information
		FROM @Target_Data.nodes('//RingBufferTarget/event') AS xed (event_data)) xep
		LEFT JOIN dbo.Audit_Record ar
			ON xep.audit_name = ar.audit_name
			AND xep.event_time = ar.event_time
			AND xep.action_id = ar.action_id
			AND xep.[statement] = ar.[statement]
			AND xep.server_principal_name = ar.server_principal_name
		WHERE ar.[statement] IS NULL
		

		SET @saved = @@rowcount;

        INSERT  INTO Audit_LoadLog
                ( audit_name ,
                    staged_count ,
                    saved_count
                )
        VALUES  ( 'Configuration_Changes' ,
                    0 ,
                    @saved
                );
	END

GO
