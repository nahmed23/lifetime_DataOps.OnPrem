﻿CREATE VIEW dbo.vFICOIntegrationKey AS 
SELECT MemberID,FICOCDIIndividualKey,FICODeliveryPointBarCode,FICOCarrierRoute,FICOLineOfTravel,FICONCOADropFlag,InsertedDateTime,UpdatedDateTime,DoNotMailFlag,NCOAAddressLine1,NCOAAddressLine2,NCOACity,NCOAState,NCOAZip,Title,FirstName,MiddleName,LastName,Suffix,NameChangeFlag,DoNotCallFlag,AreaCode,PhoneNumber
FROM MMS.dbo.FICOIntegrationKey WITH(NOLOCK)
