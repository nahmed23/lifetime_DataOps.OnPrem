


-- Procedure returns monthly statements for members at Minneapolis Athletic club
-- currently no other clubs are planned to be like this, so the club is hardcoded

CREATE  PROC dbo.mmsMonthly_Statement
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  SELECT VPT.Description AS EFTPmtMethodDescription, 
         M.FirstName AS FirstName, 
         M.LastName AS LastName,
         UPPER(SA.FirstName) AS BillingFirstName, 
         UPPER(SA.LastName) AS BillingLastName, 
         UPPER(SA.AddressLine1)AS AddressLine1,
         UPPER(SA.AddressLine2) AS AddressLine2, 
         UPPER(SA.City) AS City, 
         UPPER(VS.Abbreviation) AS State,
         SA.Zip, MMST.TranAmount, MMST.PostDateTime,
         MS.MembershipID,
         VTT.Description AS TranTypeDescription,
         MMST.TranDate, TI.ItemAmount, TI.ItemSalesTax,
         MMST.MemberID AS TranMemberid,
         -- Added next line to obtain MembershipTypeDescription
         PMST.Description AS MembershiptypeDescription,
         P.Description AS ProductDescription,
         MMST.POSAmount, MS.ValMembershipStatusID,
         M.MemberID AS PrimaryMemberid,
         SA.CompanyName AS StatementAddressCompanyname, 
         MSB.StatementBalance,
         MSB.StatementDateTime, MSB.PreviousStatementBalance,
         MSB.AssessedDateTime,
         VC.Abbreviation AS CountryAbbreviation,
         C.ClubName, MS.ValEFTOptionID
    FROM dbo.vMembership MS
    JOIN dbo.vMMSTran MMST
         ON MS.MembershipID = MMST.MembershipID
    JOIN dbo.vClub C
         ON MS.ClubID = C.ClubID
    JOIN dbo.vMember M
         ON MS.MembershipID = M.MembershipID
    JOIN dbo.vValTranType VTT
         ON MMST.ValTranTypeID = VTT.ValTranTypeID
    JOIN dbo.vStatementAddress SA
         ON SA.MembershipID = MS.MembershipID
    JOIN dbo.vMembershipBalance MSB
         ON MMST.MembershipID = MSB.MembershipID
    JOIN dbo.vValMembershipStatus VMSS
         ON VMSS.ValMembershipStatusID = MS.ValMembershipStatusID
    JOIN dbo.vDrawerActivity DA
         ON MMST.DrawerActivityID = DA.DrawerActivityID 
    JOIN dbo.vValCountry VC
         ON VC.ValCountryID = SA.ValCountryID
    JOIN dbo.vValState VS
         ON VS.ValStateID = SA.ValStateID
         -- Added two Joins to obtain MembershipTypeDescription
    JOIN dbo.vMembershipType MST
         ON MS.MembershipTypeID = MST.MembershipTypeID
    JOIN dbo.vProduct PMST
         ON MST.ProductID = PMST.ProductID
         -- End of added Joins
    LEFT JOIN dbo.vTranItem TI
         ON (MMST.MMSTranID = TI.MMSTranID)
    LEFT JOIN dbo.vProduct P
         ON (TI.ProductID = P.ProductID)
    LEFT JOIN dbo.vEFTPaymentAccount EPA
         ON (EPA.MembershipID = MMST.MembershipID)
    LEFT JOIN dbo.vValPaymentType VPT
         ON (EPA.ValPaymentTypeID = VPT.ValPaymentTypeID) 
   WHERE C.ClubID = 11  AND       --Minneapolis Athletic Club
         M.ValMemberTypeID = 1 AND
         MMST.TranVoidedID IS NULL AND
         VMSS. ValMembershipStatusID IN (4,2,3) AND  ---- Active,Pending Termination,Suspended
         (MSB.PreviousStatementDateTime IS NULL OR 
         (DA.CloseDateTime > MSB.PreviousStatementDateTime AND
         DA.CloseDateTime <= MSB.StatementDateTime))

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



