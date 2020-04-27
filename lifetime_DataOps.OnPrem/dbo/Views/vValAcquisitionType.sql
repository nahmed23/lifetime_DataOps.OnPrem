CREATE VIEW dbo.vValAcquisitionType AS 
SELECT ValAcquisitionTypeID,Description,InsertedDateTime,SortOrder,UpdatedDateTime
FROM MMS.dbo.ValAcquisitionType WITH(NOLOCK)
