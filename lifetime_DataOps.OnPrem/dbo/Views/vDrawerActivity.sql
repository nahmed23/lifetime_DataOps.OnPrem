
CREATE VIEW [dbo].[vDrawerActivity] AS 
SELECT DrawerActivityID,DrawerID,OpenDateTime,CloseDateTime,OpenEmployeeID,
       CloseEmployeeID,ValDrawerStatusID,UTCOpenDateTime,OpenDateTimeZone,
       UTCCloseDateTime,CloseDateTimeZone,PendDateTime,PendEmployeeID,
	   PendDateTimeZone,UTCPendDateTime,ClosingComments
FROM MMS.dbo.DrawerActivity With (NOLOCK)
