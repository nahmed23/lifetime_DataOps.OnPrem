

create PROC [dbo].[procCognos_PaymentTypes]
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

SELECT vValPaymentType.Description,vValEFTAccountType.ValEFTAccountTypeID, vValEFTAccountType.Description EFTAccountTypeDescription
  FROM dbo.vValPaymentType
  JOIN dbo.vValEFTAccountType ON vValPaymentType.ValEFTAccountTypeID = vValEFTAccountType.ValEFTAccountTypeID
 WHERE vValPaymentType.ViewBankAccountTypeFlag = 1
 ORDER BY vValPaymentType.Description

END

