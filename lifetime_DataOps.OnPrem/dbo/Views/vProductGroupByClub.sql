
CREATE VIEW [dbo].[vProductGroupByClub]
AS
SELECT ProductGroupByClubID, 
	   ProductID,  
	   MMSClubID, 
	   ValProductGroupID,  
	   GLRevenueAccount,
       GLRevenueSubAccount,  
	   ValRevenueAllocationProductGroupID
FROM   dbo.ProductGroupByClub WITH (NOLOCK)
