






-- Retrieves billing information for report for mac
-- not anticipated to be used for other reports so club is hardcoded


CREATE   PROC dbo.mmsBillable_memberships

AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

SELECT MS.MembershipID, SA.Zip,
       UPPER(SA.CompanyName) AS BillingCompanyName, 
       UPPER(SA.FirstName) AS BillingFirstName,
       UPPER(SA.LastName) AS BillingLastName, 
       UPPER(SA.AddressLine1) AS AddressLine1, 
       UPPER(SA.AddressLine2) AS AddressLine2,
       UPPER(SA.City) AS City, 
       UPPER(VS.Abbreviation) AS State, 
       M.MemberID AS PrimaryMemberID, MSB.StatementBalance, MSB.StatementDateTime,
       VMSS.Description AS StatusDescription, MS.ActivationDate, 
       P.Description AS ProductDescription,
       MSB.PreviousStatementBalance, VC.Abbreviation AS CountryAbbreviation
  FROM dbo.vMembership MS
  JOIN dbo.vClub C
       ON C.ClubID = MS.ClubID
  JOIN dbo.vValMembershipStatus VMSS
       ON VMSS.ValMembershipStatusID = MS.ValMembershipStatusID
  JOIN dbo.vStatementAddress SA
       ON SA.MembershipID = MS.MembershipID
  JOIN dbo.vMember M
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vMembershipBalance MSB
       ON MSB.MembershipID = MS.MembershipID
  JOIN dbo.vMembershipType MST
       ON MST.MembershipTypeID = MS.MembershipTypeID
  JOIN dbo.vProduct P
       ON P.ProductID = MST.ProductID
  JOIN dbo.vValCountry VC
       ON SA.ValCountryID = VC.ValCountryID
  JOIN dbo.vValState VS 
       ON SA.ValStateID = VS.ValStateID
 WHERE VMSS.Description IN ('Active', 'Pending Termination', 'Suspended') AND
       C.ClubName = 'Minneapolis Athletic Club' AND
       M.ValMemberTypeID = 1 AND
       C.ValStatementTypeID = 2

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END







