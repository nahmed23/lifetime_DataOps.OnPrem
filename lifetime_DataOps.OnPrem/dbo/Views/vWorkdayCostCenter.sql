CREATE VIEW dbo.vWorkdayCostCenter AS 
SELECT WorkdayCostCenterID,WorkdayCostCenter,OfferingsRequiredFlag,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.WorkdayCostCenter WITH(NOLOCK)
