CREATE VIEW dbo.vClubProductSecurity AS 
SELECT ClubProductSecurityID,ClubID,ProductID,ValEmployeeRoleID
FROM MMS.dbo.ClubProductSecurity WITH(NOLOCK)
