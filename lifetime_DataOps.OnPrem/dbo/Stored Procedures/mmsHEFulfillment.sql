



-- Query returns transactions for health merchandise purchased per club
-- parameters: clubname, startdate, endate

CREATE      PROC dbo.mmsHEFulfillment(
      @StartDate SMALLDATETIME,
      @EndDate SMALLDATETIME,
      @ClubIDList VARCHAR(2000)
      )
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(20))
CREATE TABLE #Clubs (ClubID VARCHAR(20))
   --INSERT INTO #Clubs EXEC procParseStringList @ClubList
EXEC procParseStringList @ClubIDList
INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList

SELECT MMST.TranDate, C.ClubName, MMST.MemberID,
       M.FirstName, M.MiddleName, M.LastName,
       MSA.AddressLine1, MSA.AddressLine2, MSA.City,
       MSA.Zip, MPN.HomePhoneNumber, 
       P.Description AS ProductDescription,
       TI.Quantity, TI.TranItemID, 
       VR.Description AS RegionDescription,
       MMST.PostDateTime, TI.ItemAmount, TI.ItemSalesTax,
       VTT.Description AS TranTypeDescription, 
       VS.Abbreviation AS StateAbbreviation, 
       VC.Abbreviation AS CountryAbbreviation, C.GLClubID,
       @StartDate AS TransactionRangeBeginDate, @EndDate AS TransactionRangeEndDate
  FROM dbo.vClub C
  JOIN #Clubs CS
       ON C.ClubID = CS.ClubID
  JOIN dbo.vMMSTran MMST
       ON MMST.ClubID = C.ClubID
  JOIN dbo.vTranItem TI
       ON MMST.MMSTranID = TI.MMSTranID
  JOIN dbo.vProduct P
       ON TI.ProductID = P.ProductID
  JOIN dbo.vDepartment D
       ON P.DepartmentID = D.DepartmentID
  JOIN dbo.vMember M
       ON MMST.MemberID = M.MemberID
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vValTranType VTT
       ON MMST.ValTranTypeID = VTT.ValTranTypeID
  LEFT JOIN dbo.vMembershipAddress MSA
       ON (MMST.MembershipID = MSA.MembershipID)
  LEFT JOIN dbo.vValState VS
       ON (MSA.ValStateID = VS.ValStateID)
  LEFT JOIN dbo.vValCountry VC
       ON (MSA.ValCountryID = VC.ValCountryID)
  LEFT JOIN dbo.vMemberPhoneNumbers MPN
       ON (MMST.MembershipID = MPN.MembershipID) 
 WHERE MMST.PostDateTime BETWEEN @StartDate AND @EndDate AND
       D.Description = 'Merchandise' AND
       MMST.TranVoidedID IS NULL AND
       C.DisplayUIFlag = 1

DROP TABLE #Clubs
DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END




