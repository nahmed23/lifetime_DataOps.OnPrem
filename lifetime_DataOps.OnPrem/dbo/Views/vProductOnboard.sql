CREATE VIEW dbo.vProductOnboard AS 
SELECT ProductOnboardID,ProductOnboardSetID,PurchasedProductID,ProgramStartDate,ProgramEndDate,InsertedDateTime,UpdatedDateTime,EventType
FROM MMS.dbo.ProductOnboard WITH(NOLOCK)
