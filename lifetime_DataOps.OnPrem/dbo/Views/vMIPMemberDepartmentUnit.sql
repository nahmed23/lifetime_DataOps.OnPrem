CREATE VIEW dbo.vMIPMemberDepartmentUnit AS 
SELECT MIPMemberDepartmentUnitID,DepartmentEmailSentFlag,DepartmentUnitID,MemberID
FROM MMS.dbo.MIPMemberDepartmentUnit WITH(NOLOCK)
