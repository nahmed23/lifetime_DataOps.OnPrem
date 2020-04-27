CREATE VIEW dbo.vLTFAcquisitionType AS 
SELECT LTFAcquisitionTypeID,AcquisitionType,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.LTFAcquisitionType WITH(NOLOCK)
