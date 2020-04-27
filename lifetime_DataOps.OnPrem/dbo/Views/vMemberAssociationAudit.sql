CREATE VIEW dbo.vMemberAssociationAudit AS 
SELECT MemberAssociationAuditID,MemberAssociationID,Operation,ModifiedDateTime,ModifiedUser,ColumnName,OldValue,NewValue
FROM MMS.dbo.MemberAssociationAudit WITH(NOLOCK)
