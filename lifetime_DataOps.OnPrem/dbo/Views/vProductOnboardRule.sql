CREATE VIEW dbo.vProductOnboardRule AS 
SELECT ProductOnboardRuleID,Name,Description,Parameter,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ProductOnboardRule WITH(NOLOCK)
