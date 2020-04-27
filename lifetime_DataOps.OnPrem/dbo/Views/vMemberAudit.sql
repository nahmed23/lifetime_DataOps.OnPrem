CREATE VIEW dbo.vMemberAudit AS 
SELECT MemberAuditId,RowId,Operation,ModifiedDateTime,ModifiedUser,ColumnName,OldValue,NewValue
FROM MMS.dbo.MemberAudit WITH(NOLOCK)
