
CREATE PROC [dbo].[mmsDuesAssessment_Detail_ByRegion] (
  @RegionIDList VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

--
--  THIS PROCEDURE RETURNS THE TOTAL NUMBER OF EACH TYPE OF MEMBERSHIP
--  AND THE TOTAL DUES IT SHOULD BRING IN MONTHLY
--
-- Params: A | separated Region ID List 
--
-- EXEC mmsDuesAssessment_Detail_ByRegion '1'


-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY
  
  -- Parse the ClubIDs into a temp table
CREATE TABLE #tmpList (StringField VARCHAR(50))
EXEC procParseStringList @RegionIDList
CREATE TABLE #Clubs (ClubID INT)
INSERT INTO #Clubs (ClubID)
SELECT vClub.ClubID 
  FROM vClub 
  JOIN vValRegion ON vClub.ValRegionID= vValRegion.ValRegionID
 WHERE vValRegion.ValRegionID IN (SELECT StringField FROM #tmpList)

DECLARE @InputStartDate DATETIME,
        @InputEndDate DATETIME,
        @FirstOfMonth DATETIME
SET @FirstOfMonth  =  CONVERT(DATETIME, SUBSTRING(CONVERT(VARCHAR,dateadd(mm,0,GETDATE()),112),1,6) + '01', 112)
SET @InputStartDate = DATEADD(mm,-1,@FirstOfMonth)
SET @InputEndDate = DATEADD(dd,3,@InputStartDate)

--LFF Acquisition changes begin
SELECT ms.MembershipID,
	CASE WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 160 THEN 220 --Cary
		 WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 159 THEN 219 --Dublin
		 WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 40 THEN 218  --Easton
		 WHEN mta.MembershipTypeID IS NOT NULL AND ms.ClubID = 30 THEN 214  --Indianapolis
		 ELSE ms.ClubID END ClubID
INTO #Membership
FROM vMembership ms WITH (NOLOCK)
LEFT JOIN vMembershipTypeAttribute mta WITH (NOLOCK)
  ON mta.MembershipTypeID = ms.MembershipTypeID
 AND mta.ValMembershipTypeAttributeID = 28 --Acquisition

CREATE INDEX IX_ClubID ON #Membership(ClubID)

SELECT 1497 MembershipTypeID
INTO #ProductIDs
UNION
SELECT 3100
UNION
SELECT MembershipTypeID
  FROM vMembershipTypeAttribute
 WHERE ValMembershipTypeAttributeID = 28
 
SELECT DISTINCT MMST.MMSTranID, 
		CASE WHEN TI.TranItemID IS NOT NULL AND MS.ClubID IN (214,218,219,220) AND MMST.ClubID = 160 THEN 220 --Cary
			 WHEN TI.TranItemID IS NOT NULL AND MS.ClubID IN (214,218,219,220) AND MMST.ClubID = 159 THEN 219 --Dublin
			 WHEN TI.TranItemID IS NOT NULL AND MS.ClubID IN (214,218,219,220) AND MMST.ClubID = 40  THEN 218 --Easton
			 WHEN TI.TranItemID IS NOT NULL AND MS.ClubID IN (214,218,219,220) AND MMST.ClubID = 30  THEN 214 --Indianapolis
			 ELSE MMST.ClubID END ClubID,
	   MMST.MembershipID, MMST.MemberID, MMST.DrawerActivityID,
       MMST.TranVoidedID, MMST.ReasonCodeID, MMST.ValTranTypeID, MMST.DomainName, MMST.ReceiptNumber, 
       MMST.ReceiptComment, MMST.PostDateTime, MMST.EmployeeID, MMST.TranDate, MMST.POSAmount,
       MMST.TranAmount, MMST.OriginalDrawerActivityID, MMST.ChangeRendered, MMST.UTCPostDateTime, 
       MMST.PostDateTimeZone, MMST.OriginalMMSTranID, MMST.TranEditedFlag,
       MMST.TranEditedEmployeeID, MMST.TranEditedDateTime, MMST.UTCTranEditedDateTime, 
       MMST.TranEditedDateTimeZone, MMST.ReverseTranFlag, MMST.ComputerName, MMST.IPAddress,
	   MMST.ValCurrencyCodeID,MMST.CorporatePartnerID,MMST.ConvertedAmount,MMST.ConvertedValCurrencyCodeID
INTO #MMSTran
FROM vMMSTranNonArchive MMST
JOIN #Membership MS ON MMST.MembershipID = MS.MembershipID
LEFT JOIN vTranItem TI
  ON MMST.MMSTranID = TI.MMSTranID
 AND MMST.ValTranTypeID in (1,4) --LFF Acquisition logic
 AND TI.ProductID in (SELECT MembershipTypeID FROM #ProductIDs)
WHERE MMST.ClubID in (30,40,159,160) --LFF Acquisition logic
  AND MMST.PostDateTime > @InputStartDate
  AND MMST.PostDateTime < @InputEndDate
  AND MMST.ValTranTypeID = 1
  AND MMST.EmployeeID = -2
UNION
SELECT DISTINCT MMST.MMSTranID, 
	   MMST.ClubID,
	   MMST.MembershipID, MMST.MemberID, MMST.DrawerActivityID,
       MMST.TranVoidedID, MMST.ReasonCodeID, MMST.ValTranTypeID, MMST.DomainName, MMST.ReceiptNumber, 
       MMST.ReceiptComment, MMST.PostDateTime, MMST.EmployeeID, MMST.TranDate, MMST.POSAmount,
       MMST.TranAmount, MMST.OriginalDrawerActivityID, MMST.ChangeRendered, MMST.UTCPostDateTime, 
       MMST.PostDateTimeZone, MMST.OriginalMMSTranID, MMST.TranEditedFlag,
       MMST.TranEditedEmployeeID, MMST.TranEditedDateTime, MMST.UTCTranEditedDateTime, 
       MMST.TranEditedDateTimeZone, MMST.ReverseTranFlag, MMST.ComputerName, MMST.IPAddress,
	   MMST.ValCurrencyCodeID,MMST.CorporatePartnerID,MMST.ConvertedAmount,MMST.ConvertedValCurrencyCodeID
FROM vMMSTranNonArchive MMST
JOIN #Clubs
  ON MMST.ClubID = #Clubs.ClubID
WHERE MMST.ClubID not in (30,40,159,160)
  AND MMST.PostDateTime > @InputStartDate
  AND MMST.PostDateTime < @InputEndDate
  AND MMST.ValTranTypeID = 1
  AND MMST.EmployeeID = -2

CREATE INDEX IX_ClubID ON #MMSTran(ClubID)
CREATE INDEX IX_PostDateTime ON #MMSTran(PostDateTime)

--LFF Acquisition changes end


  SELECT C.ClubName, 
         M.MembershipID, 
         M.FirstName, 
         M.LastName,
         P.Description ProductDescription,
         VCC.CurrencyCode CurrencyCode,
         USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate,
         MT.TranAmount LocalCurrencyTranAmount,
         MT.TranAMount * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDTranAmount,
         M.MemberID,
         VR.Description RegionDescription,
         M.JoinDate,
         MT.PostDateTime,
         P.DepartmentID,
         MT.ReasonCodeID,
         RC.Description TranReasonDescription,
         CASE
          WHEN MT.ReasonCodeID = 125
           THEN P2.Description
    	  ELSE P.Description
         END ReportProductGroup,
        TI.ItemAmount LocalCurrencyItemAmount,
        TI.ItemAmount * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDItemAmount,
        TI.ItemSalesTax LocalCurrencyItemSalesTax,
        TI.ItemSalesTax * USDMonthlyAverageExchangeRate.MonthlyAverageExchangeRate USDItemSalesTax,
        C.GLClubId,
		P.GLAccountNumber,
		P.GLSubAccountNumber
    FROM #MMSTran MT
         JOIN vMember M ON MT.MemberID = M.MemberID
         JOIN vTranItem TI ON MT.MMSTranID = TI.MMSTranID
         JOIN vProduct P ON TI.ProductID = P.ProductID
         JOIN vMembership MS ON MT.MembershipID = MS.MembershipID
         JOIN vMembershipType MST ON MS.MembershipTypeID = MST.MembershipTypeID
         JOIN vProduct P2 ON MST.ProductID = P2.ProductID
         JOIN vReasonCode RC ON MT.ReasonCodeID = RC.ReasonCodeID
         JOIN vClub C ON MT.ClubID = C.ClubID
         JOIN #Clubs CI ON MT.ClubID = CI.ClubID
         JOIN vValRegion VR ON C.ValRegionID =  VR.ValRegionID
         JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
         JOIN vMonthlyAverageExchangeRate USDMonthlyAverageExchangeRate
           ON VCC.CurrencyCode = USDMonthlyAverageExchangeRate.FromCurrencyCode
          AND USDMonthlyAverageExchangeRate.ToCurrencyCode = 'USD'
          AND MT.PostDateTime >= USDMonthlyAverageExchangeRate.FirstOfMonthDate
          AND Convert(Datetime,Convert(Varchar,MT.PostDateTime,101),101) <= USDMonthlyAverageExchangeRate.EndOfMonthDate
   WHERE MT.ValTranTypeID = 1 AND --- TranType 1 is a Charge Transaction
         MT.PostDateTime > @InputStartDate AND
         MT.PostDateTime < @InputEndDate AND
         MT.EmployeeID = -2 AND
         P.DepartmentID IN(1,3) AND
         C.DisplayUIFlag = 1

  DROP TABLE #Clubs
  DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
