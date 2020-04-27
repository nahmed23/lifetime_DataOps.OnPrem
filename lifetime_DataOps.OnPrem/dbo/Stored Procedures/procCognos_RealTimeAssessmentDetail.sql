
Create proc [dbo].[procCognos_RealTimeAssessmentDetail] (

  @ClubIDs VARCHAR(1000),
  @InputStartDate DATETIME,
  @InputEndDate DATETIME,
  @DepartmentNames VARCHAR(4000)
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
-- EXEC [procCognos_RealTimeAssessmentDetail] '205|141', 'JANUARY 1, 2012', 'January 3, 201', 'Member Dues/Fees'
-- EXEC [procCognos_RealTimeAssessmentDetail] '141', 'JANUARY 1, 2012', 'Jan 3, 2012', 'Member Dues/Fees'
-- EXEC [procCognos_RealTimeAssessmentDetail] '141', 'OCTOBER 9, 2013', 'Oct 9, 2013', 'Member Dues/Fees'
--------------------------------------------------

  CREATE TABLE #tmpList (StringField VARCHAR(50))
  
  -- Parse the ClubIDs into a temp table
  EXEC procParseIntegerList @ClubIDs
  CREATE TABLE #Clubs (ClubID INT)INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList

TRUNCATE TABLE #tmpList

-- Parse the DepartmentIDs into a temp table
  EXEC dbo.procParseStringList @DepartmentNames
  CREATE TABLE #Departments (DepartmentID INT)
  
  INSERT INTO #Departments (DepartmentID) 
  SELECT D.DepartmentID FROM vDepartment D
     JOIN #tmpList ON #tmpList.StringField = D.Description

DECLARE @IncludeTodaysTransactionsFlag CHAR(1)
SET @IncludeTodaysTransactionsFlag = CASE WHEN @InputStartDate >= CONVERT(Datetime,CONVERT(Varchar,GetDate(),101),101) 
                                               OR @InputEndDate >= CONVERT(Datetime,CONVERT(Varchar,GetDate(),101),101)
                                               THEN 'Y'
                                          ELSE 'N' END
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
  
DECLARE @HeaderAssessmentDateRange VARCHAR(33), @ReportRunDateTime VARCHAR(21) 
SET @HeaderAssessmentDateRange = convert(varchar(12), @InputStartDate, 107) + ' through ' + convert(varchar(12), @InputStartDate, 107)

SET @ReportRunDateTime = Replace(Substring(convert(varchar,GetDate(),100),1,6)+', '+Substring(convert(varchar,GetDate(),100),8,10)+' '+Substring(convert(varchar,GetDate(),100),18,2),'  ',' ')

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
WHERE MMST.PostDateTime >= Convert(Datetime,Convert(Varchar,GetDate(),101),101)
  AND MMST.ValTranTypeID = 1 -- charge transactions
  AND MMST.EmployeeID = -2
  AND @IncludeTodaysTransactionsFlag = 'Y'

CREATE INDEX IX_ClubID ON #MMSTran(ClubID)
CREATE INDEX IX_PostDateTime ON #MMSTran(PostDateTime)

/***************************************/

  SELECT 
         VR.Description TransactionRegion,
		 C.ClubName as TransactionClubName, 
		 C.ClubCode, 
         M.MembershipID, 
         M.MemberID,
         M.FirstName as MemberFirstName, 
         M.LastName as MemberLastName,
         Convert(varchar(10),M.JoinDate,101) as MemberJoinDate,
         CONVERT(varchar(10),MT.PostDateTime,101) + ' ' + CONVERT(varchar(8),MT.PostDateTime,108) as AssessmentPostDateTime,
         P.Description ProductDescription,        
         D.Description as MMSDepartmentName,
         MT.ReasonCodeID as TransactionReasonCodeID,
         RC.Description TransactionReasonDescription,
         P2.Description AS MembershipType,        
        C.GLClubID,
        P.GLAccountNumber,
        P.GLSubAccountNumber,
        C.WorkdayRegion,
        P.WorkdayAccount,
        P.WorkdayCostCenter,
        P.WorkdayOffering,

/******  Foreign Currency Stuff  *********/
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
       MT.TranAmount * #PlanRate.PlanRate as TransactionAmount,       
       TI.ItemAmount * #PlanRate.PlanRate as ItemAmount,           
       TI.ItemSalesTax * #PlanRate.PlanRate as ItemSalesTaxAmount,       
       
       VCC.CurrencyCode as LocalCurrencyCode,
       MT.TranAmount as LocalCurrencyTransactionAmount,       
       TI.ItemAmount as LocalCurrencyItemAmount,       
       TI.ItemSalesTax as LocalCurrencyItemSalesTaxAmount,       
       
       MT.TranAmount * #ToUSDPlanRate.PlanRate as USDTransactionAmount,
       TI.ItemAmount * #ToUSDPlanRate.PlanRate as USDItemAmount,
       TI.ItemSalesTax * #ToUSDPlanRate.PlanRate as USDItemSalesTaxAmount,              
/***************************************/
        @HeaderAssessmentDateRange AS HeaderAssessmentDateRange,
        @ReportRunDateTime AS ReportRunDateTime  
    
    INTO #Transactions    
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
  JOIN vDepartment D ON #Departments.DepartmentID = D.DepartmentID
/*******************************************/
   WHERE MT.ValTranTypeID = 1 AND --- Charge Transaction
         MT.EmployeeID = -2 AND
         C.DisplayUIFlag = 1    
              
SELECT #Transactions.TransactionRegion,
       #Transactions.TransactionClubName,
       #Transactions.ClubCode,
       #Transactions.MembershipID,
       #Transactions.MemberID,
       #Transactions.MemberFirstName,
       #Transactions.MemberLastName,
       #Transactions.MemberJoinDate,       
       #Transactions.AssessmentPostDateTime,
       #Transactions.ProductDescription,
       #Transactions.MMSDepartmentName,              
       #Transactions.TransactionReasonCodeID,
       #Transactions.TransactionReasonDescription,
       #Transactions.MembershipType,
       #Transactions.GLClubID,
       #Transactions.GLAccountNumber,
       #Transactions.GLSubAccountNumber,    
       #Transactions.WorkdayRegion,
       #Transactions.WorkdayAccount,
       #Transactions.WorkdayCostCenter,
       #Transactions.WorkdayOffering,
       #Transactions.PlanRate,
       #Transactions.ReportingCurrencyCode, 
       #Transactions.TransactionAmount,
       #Transactions.ItemAmount,
       #Transactions.ItemSalesTaxAmount,
       #Transactions.LocalCurrencyCode,
       #Transactions.LocalCurrencyTransactionAmount, 
       #Transactions.LocalCurrencyItemAmount ,
       #Transactions.LocalCurrencyItemSalesTaxAmount,
       #Transactions.USDTransactionAmount,
       #Transactions.USDItemAmount,
       #Transactions.USDItemSalesTaxAmount,
       @HeaderAssessmentDateRange HeaderAssessmentDateRange,
       @ReportRunDatetime ReportRunDateTime
                     
  FROM #Transactions
 WHERE (SELECT COUNT(*) FROM #Transactions) > 0
UNION ALL
SELECT CAST(NULL AS VARCHAR(50)) TransactionRegion,
       CAST(NULL AS VARCHAR(50)) TransactionClubName,
       CAST(NULL AS VARCHAR(18)) ClubCode,
       CAST(NULL AS INT) MembershipID,
       CAST(NULL AS INT) MemberID,
       CAST(NULL AS VARCHAR(50)) MemberFirstName,
       CAST(NULL AS VARCHAR(80)) MemberLastName,
       CAST(NULL AS VARCHAR(12)) MemberJoinDate,       
       CAST(NULL AS VARCHAR(21)) AssessmentPostDateTime,
       CAST(NULL AS VARCHAR(50)) ProductDescription,
       CAST(NULL AS VARCHAR(50)) MMSDepartmentName,              
       CAST(NULL AS VARCHAR(50)) TransactionReasonCodeID,
       CAST(NULL AS VARCHAR(50)) TransactionReasonDescription,
       CAST(NULL AS VARCHAR(50)) MembershipType,
       CAST(NULL AS INT)         GLClubID,
       CAST(NULL AS VARCHAR(10)) GLAccountNumber,
       CAST(NULL AS VARCHAR(21)) GLSubAccountNumber,    
       CAST(NULL AS VARCHAR(4))  WorkdayRegion,
       CAST(NULL AS VARCHAR(10)) WorkdayAccount,
       CAST(NULL AS VARCHAR(6))  WorkdayCostCenter,
       CAST(NULL AS VARCHAR(10)) WorkdayOffering,
       CAST(NULL AS DECIMAL(14,4)) ToUSDPlanExchangeRate,
       CAST(NULL AS VARCHAR(15))   ReportingCurrencyCode, 
       CAST(NULL AS DECIMAL(16,6)) TransactionAmount,
       CAST(NULL AS DECIMAL(16,6)) ItemAmount,
       CAST(NULL AS DECIMAL(16,6)) ItemSalesTaxAmount,
       CAST(NULL AS VARCHAR(15))   LocalCurrencyCode,
       CAST(NULL AS DECIMAL(16,6)) LocalCurrencyTransactionAmount, 
       CAST(NULL AS DECIMAL(16,6)) LocalCurrencyItemAmount ,
       CAST(NULL AS DECIMAL(16,6)) LocalCurrencyItemSalesTaxAmount,
       CAST(NULL AS DECIMAL(16,6)) USDTransactionAmount,
       CAST(NULL AS DECIMAL(16,6)) USDItemAmount,
       CAST(NULL AS DECIMAL(16,6)) USDItemSalesTaxAmount,              
       @HeaderAssessmentDateRange HeaderAssessmentDateRange,
       @ReportRunDatetime ReportRunDateTime
       
 WHERE (SELECT COUNT(*) FROM #Transactions) = 0

  DROP TABLE #Clubs
  DROP TABLE #tmpList
  DROP TABLE #PlanRate
  DROP TABLE #ToUSDPlanRate
  DROP TABLE #Transactions 
END


