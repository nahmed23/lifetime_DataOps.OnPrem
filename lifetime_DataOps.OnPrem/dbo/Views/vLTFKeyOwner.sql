CREATE VIEW dbo.vLTFKeyOwner AS 
SELECT LTFKeyOwnerID,PartyID,LTFKeyID,KeyPriority,FromDate,ThruDate,FromTime,ThruTime,UsageCount,UsageLimit,AcquisitionID,ValAcquisitionTypeID,ValOwnershipTypeID,InsertedDateTime,UpdatedDateTime,DisplayName,LTFKeyAcquisitionID
FROM MMS.dbo.LTFKeyOwner WITH(NOLOCK)
