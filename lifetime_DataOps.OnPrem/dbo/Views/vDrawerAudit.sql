
CREATE VIEW [dbo].[vDrawerAudit] AS 
SELECT DrawerAuditID,EmployeeOneID,DrawerActivityID,Amount,AuditDateTime,
	   ValDrawerAuditTypeID,UTCAuditDateTime,AuditDateTimeZone,ValPaymentTypeID 
FROM MMS.dbo.DrawerAudit With (NOLOCK)
