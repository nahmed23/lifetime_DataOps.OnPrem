﻿
CREATE VIEW [dbo].[vPTCreditCardRejectedTransaction] AS 
SELECT PTCreditCardRejectedTransactionID,EntryDataSource,AccountNumber,ExpirationDate,TranAmount,ReferenceCode,TipAmount,EmployeeID,MemberID,CardHolderStreetAddress,
CardHolderZipCode,TransactionDateTime,UTCTransactionDateTime,TransactionDateTimeZone,IndustryCode,AuthorizationNetWorkID,AuthorizationSource,ErrorCode,ErrorMessage,
CardType,PTCreditCardTerminalID,CardOnFileFlag,InsertedDateTime,MaskedAccountNumber,UpdatedDateTime,MaskedAccountNumber64,CardHolderName,TypeIndicator,
ThirdPartyPOSPaymentID,HbcPaymentFlag,Token
FROM MMS_Archive.dbo.PTCreditCardRejectedTransaction WITH(NOLOCK)

