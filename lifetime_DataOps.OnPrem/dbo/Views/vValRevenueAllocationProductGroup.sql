
CREATE VIEW [dbo].[vValRevenueAllocationProductGroup]
AS 
SELECT ValRevenueAllocationProductGroupID,
	   Description,
	   SortOrder
FROM ValRevenueAllocationProductGroup WITH (NOLOCK)
