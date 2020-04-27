



--
-- returns member information for the Medica Processing Brio document
--
-- Parameters: list of corporate codes, expiration date, and
--             the reimbursement type (either 'Full' or 'Flat')
--

CREATE    PROC dbo.mmsMedicaProcessing_MemberRecord (
  @CorpCodeList VARCHAR(2000),
  @ExpirationDate SMALLDATETIME,
  @ReimbursementType VARCHAR(10)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  CREATE TABLE #tmpList (StringField VARCHAR(50))
  CREATE TABLE #Corps (CorpCode VARCHAR(50))
  EXEC procParseStringList @CorpCodeList
  INSERT INTO #Corps (CorpCode) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList
  
  CREATE TABLE #PriceTax (
    ClubID INTEGER,
    ClubName VARCHAR(100),
    Price MONEY,
    SalesTaxPercentage REAL)

  INSERT INTO #PriceTax 
  SELECT C.ClubID, C.ClubName, CP.Price, SUM(TR.TaxPercentage)
    FROM dbo.vClub C
    JOIN dbo.vClubProduct CP
      ON CP.ClubID = C.ClubID
    JOIN dbo.vProduct P
      ON CP.ProductID = P.ProductID
    JOIN dbo.vClubProductTaxRate CPTR
      ON C.ClubID = CPTR.ClubID AND P.ProductID = CPTR.ProductID
    JOIN dbo.vTaxRate TR
      ON CPTR.TaxRateID = TR.TaxRateID
   WHERE P.ProductID = 168 AND --- IN ('Fitness Single')
         C.ClubID != 13   ----- NOT IN ('Corporate INTERNAL')
   GROUP BY C.ClubID, C.ClubName, CP.Price
  
  SELECT R.Description RegionDescription, M.EmailAddress MemberEmailAddress,
         UPPER(M.FirstName) FirstName, UPPER(M.LastName) LastName,
         MSA.AddressLine1, MSA.AddressLine2,
         UPPER(MSA.City) City, MSA.Zip, MS.ExpirationDate,
         CO.CorporateCode, M.JoinDate, MSS.Description MembershipStatusDescription,
         CO.AccountRepInitials, P.Description MembershipTypeDescription,
         PH.HomePhoneNumber, PH.BusinessPhoneNumber, CO.CompanyName,
         M.MemberID, C.ClubName,
         -- M.SSN, 
         S.Abbreviation StateAbbreviation, C.ClubID,
         CTRY.Abbreviation CountryAbbreviation, M.CWMedicaNumber,
         @ReimbursementType as ReimbType, #PriceTax.Price, #PriceTax.SalesTaxPercentage,
         MS.MembershipID
    FROM dbo.vCompany CO
    JOIN #Corps CS
      ON CO.CorporateCode = CS.CorpCode
    JOIN dbo.vMembership MS
      ON CO.CompanyID = MS.CompanyID
    JOIN dbo.vMembershipAddress MSA
      ON MSA.MembershipID = MS.MembershipID
    JOIN dbo.vClub C
      ON C.ClubID = MS.ClubID
    JOIN dbo.vValRegion R
      ON C.ValRegionID = R.ValRegionID
    JOIN dbo.vMember M
      ON MS.MembershipID = M.MembershipID
    ------JOIN dbo.vValMemberType MT
     ----- ON M.ValMemberTypeID = MT.ValMemberTypeID
   ------ JOIN dbo.vValAddressType VAT
   -----   ON MSA.ValAddressTypeID = VAT.ValAddressTypeID
    JOIN dbo.vValMembershipStatus MSS
      ON MS.ValMembershipStatusID = MSS.ValMembershipStatusID
    JOIN dbo.vMembershipType MST
      ON MS.MembershipTypeID = MST.MembershipTypeID
    JOIN dbo.vProduct P
      ON MST.ProductID = P.ProductID
    JOIN dbo.vMemberPhoneNumbers PH
      ON MS.MembershipID = PH.MembershipID
    JOIN dbo.vValCountry CTRY
      ON MSA.ValCountryID = CTRY.ValCountryID
    JOIN dbo.vValState S
      ON MSA.ValStateID = S.ValStateID
    JOIN #PriceTax
      ON #PriceTax.ClubID = C.ClubID
   WHERE (MS.ExpirationDate > @ExpirationDate OR
         MS.ExpirationDate IS NULL) AND
         MSA.ValAddressTypeID = 1 AND   -----'Membership Address' 
         M.ValMemberTypeID = 1  ---- 'Primary'
  
  DROP TABLE #PriceTax
  DROP TABLE #Corps
  DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END





