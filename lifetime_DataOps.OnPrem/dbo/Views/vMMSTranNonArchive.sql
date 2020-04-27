

CREATE VIEW [dbo].[vMMSTranNonArchive]
AS
SELECT MMSTranID, ClubID, MembershipID, MemberID, DrawerActivityID,
       TranVoidedID, ReasonCodeID, ValTranTypeID, DomainName, ReceiptNumber, 
       ReceiptComment, PostDateTime, EmployeeID, TranDate, POSAmount,
       TranAmount, OriginalDrawerActivityID, ChangeRendered, UTCPostDateTime, 
       PostDateTimeZone, OriginalMMSTranID, TranEditedFlag,
       TranEditedEmployeeID, TranEditedDateTime, UTCTranEditedDateTime, 
       TranEditedDateTimeZone, ReverseTranFlag,ComputerName,IPAddress,ValCurrencyCodeID,
       CorporatePartnerID,ConvertedAmount,ConvertedValCurrencyCodeID,ReimbursementProgramID
FROM   MMS_Archive.dbo.MMSTran WITH (NOLOCK)

