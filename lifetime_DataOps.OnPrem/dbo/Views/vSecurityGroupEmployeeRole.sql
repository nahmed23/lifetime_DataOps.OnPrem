


CREATE VIEW dbo.vSecurityGroupEmployeeRole
AS
SELECT SecurityGroupEmployeeRoleID, ValSecurityGroupID, 
    ValEmployeeRoleID
FROM MMS.dbo.SecurityGroupEmployeeRole With (NOLOCK)



