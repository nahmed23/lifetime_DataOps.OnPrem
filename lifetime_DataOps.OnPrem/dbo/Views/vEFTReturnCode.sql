--MSSQL-4489B.sql

--BEGIN CODE

CREATE VIEW [dbo].[vEFTReturnCode]
AS
SELECT     EFTReturnCodeID
, ReasonCodeID
, ValMembershipMessageTypeID
, StopEFTFlag
, ReturnCode
, Description
, EFTDeclinedFlag
, EFTChargeBackFlag
, ValCurrencyCodeID
FROM         MMS.dbo.EFTReturnCode  WITH (NoLock)
