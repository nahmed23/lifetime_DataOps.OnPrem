﻿CREATE VIEW dbo.vValCommunicationPreferenceSource AS 
SELECT ValCommunicationPreferenceSourceID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValCommunicationPreferenceSource WITH(NOLOCK)