
CREATE VIEW dbo.vEFTChargeBack
AS
SELECT     EFTChargeBackID, EFTReturnCodeID, MemberID, MembershipID, MMSTranID, Amount, MaskedAccountNumber, ChargeBackFileName,MaskedAccountNumber64
FROM       MMS_Archive.dbo.EFTChargeBack  WITH (NoLock)




