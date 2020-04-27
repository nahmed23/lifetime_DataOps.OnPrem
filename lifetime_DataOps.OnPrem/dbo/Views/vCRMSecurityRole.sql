CREATE VIEW dbo.vCRMSecurityRole AS 
SELECT CRMSecurityRoleID,CRMSecurityRole,ValEmployeeRoleID,InsertedDateTime,UpdatedDateTime,CRMOverrideBusinessUnit
FROM MMS.dbo.CRMSecurityRole WITH(NOLOCK)
