﻿CREATE VIEW dbo.vLTFKeyAcquisition AS 
SELECT LTFKeyAcquisitionID,LTFKeyID,ValAcquisitionTypeID,ValOwnershipTypeID,DefaultKeyPriority,ClubID,ProductID,ReimbursementProgramID,FromTime,ThruTime,DurationType,DurationLength,EffectiveFromDateTime,EffectiveThruDateTime,InsertedDateTime,UpdatedDateTime,DisplayName,ClubAccess
FROM MMS.dbo.LTFKeyAcquisition WITH(NOLOCK)
