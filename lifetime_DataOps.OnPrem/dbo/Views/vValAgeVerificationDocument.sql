﻿CREATE VIEW dbo.vValAgeVerificationDocument AS 
SELECT ValAgeVerificationDocumentID,Description,SortOrder,InsertedDateTime,UpdatedDateTime,DisplayUIFlag
FROM MMS.dbo.ValAgeVerificationDocument WITH(NOLOCK)
