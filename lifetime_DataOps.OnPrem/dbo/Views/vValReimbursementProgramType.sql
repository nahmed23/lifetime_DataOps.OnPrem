﻿CREATE VIEW dbo.vValReimbursementProgramType AS 
SELECT ValReimbursementProgramTypeID,Description,SortOrder,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.ValReimbursementProgramType WITH(NOLOCK)
