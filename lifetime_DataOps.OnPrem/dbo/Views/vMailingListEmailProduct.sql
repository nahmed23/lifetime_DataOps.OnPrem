﻿CREATE VIEW dbo.vMailingListEmailProduct AS 
SELECT MailingListEmailProductID,MailingListEmailID,ProductID,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.MailingListEmailProduct WITH(NOLOCK)
