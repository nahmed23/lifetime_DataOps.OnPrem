
CREATE PROC [dbo].[mmsDuesAssessment_Detail] (
  @ClubIDs VARCHAR(1000),
  @InputStartDate DATETIME,
  @InputEndDate DATETIME,
  @DepartmentIDs VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

--
--  THIS PROCEDURE RETURNS THE TOTAL NUMBER OF EACH TYPE OF MEMBERSHIP
--  AND THE TOTAL DUES IT SHOULD BRING IN MONTHLY
--
-- Params: A | separated CLUB ID List AND a DATE RANGE
--
-- EXEC mmsDuesAssessment_Detail '151', 'Apr 1, 2011', 'Apr 2, 2011', '9'
--------------------------------------------------
-- Modified Date: 12/3/2010 BSD DBCR 03331
--                12/28/2011 BSD: Added LFF Acquisition logic


  CREATE TABLE #tmpList (StringField VARCHAR(50))

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY
  
  -- Parse the ClubIDs into a temp table
  EXEC procParseIntegerList @ClubIDs
  CREATE TABLE #Clubs (ClubID INT)INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList

TRUNCATE TABLE #tmpList

-- Parse the DepartmentIDs into a temp table
  EXEC procParseIntegerList @DepartmentIDs
  CREATE TABLE #Departments (DepartmentID INT)INSERT INTO #Departments (DepartmentID) SELECT StringField FROM #tmpList
  
/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C
  JOIN #Clubs ON C.ClubID = #Clubs.ClubID OR #Clubs.ClubID = 0
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= Year(@InputStartDate)
  AND PlanYear <= Year(@InputEndDate)
  AND ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE PlanYear >= Year(@InputStartDate)
  AND PlanYear <= Year(@InputEndDate)
  AND ToCurrencyCode = 'USD'
  


SELECT DISTINCT MMST.MMSTranID, 
       MMST.ClubID,
       MMST.MembershipID, MMST.MemberID, MMST.DrawerActivityID,
       MMST.TranVoidedID, MMST.ReasonCodeID, MMST.ValTranTypeID, MMST.DomainName, MMST.ReceiptNumber, 
       MMST.ReceiptComment, MMST.PostDateTime, MMST.EmployeeID, MMST.TranDate, MMST.POSAmount,
       MMST.TranAmount, MMST.OriginalDrawerActivityID, MMST.ChangeRendered, MMST.UTCPostDateTime, 
       MMST.PostDateTimeZone, MMST.OriginalMMSTranID, MMST.TranEditedFlag,
       MMST.TranEditedEmployeeID, MMST.TranEditedDateTime, MMST.UTCTranEditedDateTime, 
       MMST.TranEditedDateTimeZone, MMST.ReverseTranFlag, MMST.ComputerName, MMST.IPAddress,
       MMST.ValCurrencyCodeID,MMST.CorporatePartnerID,MMST.ConvertedAmount,MMST.ConvertedValCurrencyCodeID,
       YEAR(MMST.PostDateTime) PostDateTimeYear
INTO #MMSTran
FROM vMMSTran MMST
JOIN #Clubs
  ON MMST.ClubID = #Clubs.ClubID
WHERE MMST.PostDateTime > @InputStartDate
  AND MMST.PostDateTime < @InputEndDate
  AND MMST.ValTranTypeID = 1
  AND MMST.EmployeeID = -2

CREATE INDEX IX_ClubID ON #MMSTran(ClubID)
CREATE INDEX IX_PostDateTime ON #MMSTran(PostDateTime)

/***************************************/

  SELECT C.ClubName, 
         M.MembershipID, 
         M.FirstName, 
         M.LastName,
         P.Description ProductDescription,        
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
        C.GLClubId,
        P.GLAccountNumber,
        P.GLSubAccountNumber,
/******  Foreign Currency Stuff  *********/
       VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
       MT.TranAmount * #PlanRate.PlanRate as TranAmount,       
       MT.TranAmount as LocalCurrency_TranAmount,       
       MT.TranAmount * #ToUSDPlanRate.PlanRate as USD_TranAmount,
       TI.ItemAmount * #PlanRate.PlanRate as ItemAmount,       
       TI.ItemAmount as LocalCurrency_ItemAmount,       
       TI.ItemAmount * #ToUSDPlanRate.PlanRate as USD_ItemAmount,
       TI.ItemSalesTax * #PlanRate.PlanRate as ItemSalesTax,       
       TI.ItemSalesTax as LocalCurrency_ItemSalesTax,       
       TI.ItemSalesTax * #ToUSDPlanRate.PlanRate as USD_ItemSalesTax              
/***************************************/
 
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
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND PostDateTimeYear = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND PostDateTimeYear = #ToUSDPlanRate.PlanYear
/*******************************************/
  JOIN #Departments ON P.DepartmentID = #Departments.DepartmentID
/*******************************************/
   WHERE MT.ValTranTypeID = 1 AND --- TranType 1 is a Charge Transaction
         MT.PostDateTime > @InputStartDate AND
         MT.PostDateTime < @InputEndDate AND
         MT.EmployeeID = -2 AND
        -- P.DepartmentID IN(1,3) AND
         C.DisplayUIFlag = 1 AND
         P.GLAccountNumber <> 4010 -- BSD 12/3/2010

  DROP TABLE #Clubs
  DROP TABLE #tmpList
  DROP TABLE #PlanRate
  DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



