CREATE VIEW dbo.vWebCartItem AS 
SELECT WebCartItemID,WebCartID,WebItemID,ItemAddedDateTime
FROM MMS.dbo.WebCartItem WITH(NOLOCK)
