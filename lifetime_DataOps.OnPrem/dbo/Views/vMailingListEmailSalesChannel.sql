﻿CREATE VIEW dbo.vMailingListEmailSalesChannel AS 
SELECT MailingListEmailSalesChannelID,MailingListEmailID,ValProductSalesChannelID,InsertedDateTime,UpdatedDateTime
FROM MMS.dbo.MailingListEmailSalesChannel WITH(NOLOCK)