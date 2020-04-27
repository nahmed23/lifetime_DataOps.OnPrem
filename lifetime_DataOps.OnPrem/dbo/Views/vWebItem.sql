CREATE VIEW dbo.vWebItem AS 
SELECT WebItemID,ProductID,ClubID,UnitPrice,ProratedPrice,Quantity,ValProductSalesChannelID,ItemTotal,DiscountTotal,TaxTotal,MasterProductID,InsertedDateTime,UpdatedDateTime,QualifiedSalesPromotionID,TranIndex
FROM MMS_Archive.dbo.WebItem WITH(NOLOCK)
