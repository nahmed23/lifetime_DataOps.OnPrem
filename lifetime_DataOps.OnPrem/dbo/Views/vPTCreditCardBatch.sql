﻿CREATE VIEW dbo.vPTCreditCardBatch AS 
SELECT PTCreditCardBatchID,PTCreditCardTerminalID,BatchNumber,TransactionCount,NetAmount,ActionCode,ResponseCode,ResponseMessage,OpenDateTime,UTCOpenDateTime,OpenDateTimeZone,CloseDateTime,UTCCloseDateTime,CloseDateTimeZone,SubmitDateTime,UTCSubmitDateTime,SubmitDateTimeZone,ValCreditCardBatchStatusID,InsertedDateTime,UpdatedDateTime,DrawerActivityID,SubmittedEmployeeID
FROM MMS_Archive.dbo.PTCreditCardBatch WITH(NOLOCK)
