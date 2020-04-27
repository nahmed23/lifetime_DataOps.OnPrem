
--Update view
CREATE VIEW [dbo].[vProductGroup] AS
SELECT ProductGroupID,
       ProductID,
       ValProductGroupID,
       GLRevenueAccount,
       GLRevenueSubAccount,
       ValRevenueAllocationProductGroupID,
       Old_vs_NewBusiness_TrackingFlag,
       AvgDeliveredSessionPriceTrackingFlag
FROM ProductGroup WITH(NOLOCK)
