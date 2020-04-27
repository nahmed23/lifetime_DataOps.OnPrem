

CREATE   PROCEDURE [dbo].[mmsDuesAssessment_Summary] (
  @ClubIDList VARCHAR(2000),
  @InputStartDate DATETIME,
  @InputEndDate DATETIME,
  @DepartmentIDList VARCHAR(2000)
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
-- EXEC dbo.mmsDuesAssessment_Summary '151', '9/1/09', '9/3/09', 'ALL'
-- 292 count
-- Ruslan Condratiuc 02/03/10
-- added following columns: Itemamount, ItemSalestax ,GLClubId, GLAccount, GLSubAccount
--
-- Modified Date: 12/3/2010 BSD DBCR 03331
-- EXEC mmsDuesAssessment_Summary 'All', 'Apr 1, 2011', 'Apr 2, 2011'

  CREATE TABLE #tmpList (StringField VARCHAR(50))
  CREATE TABLE #Clubs (ClubID VARCHAR(50))
IF @ClubIDList <> 'All'
BEGIN
   EXEC procParseStringList @ClubIDList
   INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
   INSERT INTO #Clubs (ClubID) SELECT ClubID FROM vClub WHERE DisplayUIFlag = 1
END   

CREATE TABLE #Departments (DepartmentID INT)
IF @DepartmentIDList <> 'All'
BEGIN
   EXEC procParseStringList @DepartmentIDList
   INSERT INTO #Departments (DepartmentID) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
   INSERT INTO #Departments (DepartmentID) SELECT DepartmentID FROM vDepartment 
END   

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY     

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
       MMST.ValCurrencyCodeID,MMST.CorporatePartnerID,MMST.ConvertedAmount,MMST.ConvertedValCurrencyCodeID
INTO #MMSTran
FROM vMMSTran MMST
JOIN #Clubs
  ON MMST.ClubID = #Clubs.ClubID
WHERE MMST.PostDateTime > @InputStartDate
  AND MMST.PostDateTime < @InputEndDate
  AND MMST.ValTranTypeID = 1
  AND MMST.EmployeeID = -2

/***************************************/

  SELECT C.ClubName, 
         Count(M.MembershipID) AS CountofMembership, 
         P.Description ProductDescription,         
         VR.Description RegionDescription,
         P.DepartmentID,
         MT.ReasonCodeID,
         @InputStartDate AS StartDate,
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
       Sum(MT.TranAmount * #PlanRate.PlanRate) AS TotalAssessment,
       Sum(MT.TranAmount) AS LocalCurrency_TotalAssessment,
       Sum(MT.TranAmount * #ToUSDPlanRate.PlanRate) AS USD_TotalAssessment,
       Sum(TI.ItemAmount * #PlanRate.PlanRate) AS ItemAmount,
       Sum(TI.ItemAmount) AS LocalCurrency_ItemAmount,
       Sum(TI.ItemAmount * #ToUSDPlanRate.PlanRate) AS USD_ItemAmount,
       Sum(TI.ItemSalesTax * #PlanRate.PlanRate) AS ItemSalesTax,
       Sum(TI.ItemSalesTax) AS LocalCurrency_ItemSalesTax,
       Sum(TI.ItemSalesTax * #ToUSDPlanRate.PlanRate) AS USD_ItemSalesTax
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
         JOIN #Clubs CI ON C.ClubID = CI.ClubID --OR CI.ClubID = 0
         JOIN vValRegion VR ON C.ValRegionID =  VR.ValRegionID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MT.PostDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(MT.PostDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
  JOIN #Departments
       ON P.DepartmentID = #Departments.DepartmentID
/*******************************************/
   WHERE MT.ValTranTypeID = 1 AND --- TranType 1 is a Charge Transaction
         MT.PostDateTime > @InputStartDate AND
         MT.PostDateTime < @InputEndDate AND
         MT.EmployeeID = -2 AND
         --P.DepartmentID IN(1,3) AND
         --C.DisplayUIFlag = 1 AND
         P.GLAccountNumber <> 4010 -- BSD 12/3/2010

GROUP BY 
    C.ClubName, C.GLClubId, P.Description, P2.Description,
    P.GLAccountNumber,
    P.GLSubAccountNumber,
    MT.ReasonCodeID, VR.Description, P.DepartmentID, VCC.CurrencyCode, #PlanRate.PlanRate

  DROP TABLE #Clubs
  DROP TABLE #tmpList
  DROP TABLE #PlanRate
  DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END
