﻿CREATE VIEW dbo.vEmailAddressStatus AS 
SELECT EmailAddressStatusID,EmailAddress,StatusFromDate,StatusThruDate,InsertedDateTime,UpdatedDateTime,ValCommunicationPreferenceSourceID,ValCommunicationPreferenceStatusID
FROM MMS.dbo.EmailAddressStatus WITH(NOLOCK)
