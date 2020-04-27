CREATE VIEW dbo.vMembershipAudit AS 
SELECT MembershipAuditId,RowId,Operation,ModifiedDateTime,ModifiedUser,ColumnName,OldValue,NewValue
FROM MMS.dbo.MembershipAudit WITH(NOLOCK)
