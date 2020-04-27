

CREATE VIEW dbo.vDepartmentMembershipMessageType
AS
SELECT DepartmentMembershipMessageTypeID, DepartmentID, ValMembershipMessageTypeID
FROM MMS.dbo.DepartmentMembershipMessageType With (NOLOCK)

