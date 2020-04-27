
-- EXEC mmsProgramParticipationSummary '201004', '19'
CREATE PROCEDURE [dbo].[mmsProgramParticipationSummary] (
       @ReportYearMonth VARCHAR(6),
       @ProgramIDs VARCHAR(2000)
) 
AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

/********  Foreign Currency Stuff ********/
DECLARE @ReportingCurrencyCode VARCHAR(15)
SET @ReportingCurrencyCode = 
(SELECT CASE WHEN COUNT(DISTINCT C.ValCurrencyCodeID) >=2 THEN 'USD' ELSE MAX(VCC.CurrencyCode) END AS ReportingCurrency
  FROM vClub C 
  JOIN vValCurrencyCode VCC ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID)

CREATE TABLE #PlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #PlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = 'USD'
/***************************************/

DECLARE @FirstOfReportMonth DATETIME
DECLARE @BeginningOfPrior12MonthPeriod DATETIME
DECLARE @TwelveMonthsPriorYearMonth VARCHAR(6)

SET @FirstOfReportMonth = CAST(SUBSTRING(@ReportYearMonth, 5,2) + '/01/' + SUBSTRING(@ReportYearMonth, 1,4) AS DATETIME)
SET @BeginningOfPrior12MonthPeriod = DATEADD(YEAR, -1, @FirstOfReportMonth)
SET @TwelveMonthsPriorYearMonth = DATENAME(YEAR, @BeginningOfPrior12MonthPeriod) + 
    CASE LEN(DATEPART(MONTH, @BeginningOfPrior12MonthPeriod))
         WHEN 1
              THEN '0' + CAST(DATEPART(MONTH, @BeginningOfPrior12MonthPeriod) AS VARCHAR(2))
              ELSE CAST(DATEPART(MONTH, @BeginningOfPrior12MonthPeriod) AS VARCHAR(2))
    END

CREATE TABLE #tmpList (StringField VARCHAR(50))

CREATE TABLE #ReimbursementPrograms (ReimbursementProgramID VARCHAR(50))
EXEC procParseStringList @ProgramIDs
INSERT INTO #ReimbursementPrograms (ReimbursementProgramID) SELECT StringField FROM #tmpList

CREATE TABLE #AverageMemberships 
       (ReimbursementProgramID INT, 
       AccumulatedAccessMembershipCount INT,
       MonthsOfMembershipBalanceHistory INT,
       AverageMonthlyAccessMembershipCount DECIMAL(10,2))
INSERT INTO #AverageMemberships 
SELECT RPPS.ReimbursementProgramID,
       SUM(AccessMembershipCount), 
       COUNT(RPPS.ReimbursementProgramID),
       SUM(AccessMembershipCount)/COUNT(RPPS.ReimbursementProgramID)
  FROM ReimbursementProgramParticipationSummary RPPS
  JOIN #ReimbursementPrograms RP
    ON RP.ReimbursementProgramID = RPPS.ReimbursementProgramID
 WHERE YearMonth >= @TwelveMonthsPriorYearMonth
   AND YearMonth < @ReportYearMonth

 GROUP BY RPPS.ReimbursementProgramID

CREATE TABLE #ExpiredProgramMembershipsCalc
       (MembershipID INT, 
       ReimbursementProgramID INT)
INSERT INTO #ExpiredProgramMembershipsCalc
SELECT MS.MembershipID,
       MR.ReimbursementProgramID
  FROM vMembership MS
  JOIN vMember M
    ON M.MembershipID = MS.MembershipID
  JOIN vMemberReimbursement MR
    ON M.MemberID = MR.MemberID
  JOIN vMembershipType MT
    ON MT.MembershipTypeID = MS.MembershipTypeID
  JOIN vProduct P
    ON P.ProductID = MT.ProductID
  JOIN #ReimbursementPrograms RP
    ON RP.ReimbursementProgramID = MR.ReimbursementProgramID
 WHERE MS.ExpirationDate >= @BeginningOFPrior12MonthPeriod
   AND MS.ExpirationDate < @FirstOfReportMonth
   AND MT.ValCheckInGroupID != 0
   AND P.Description NOT LIKE '%Short%'
   AND P.Description NOT LIKE '%Empl%'
   AND P.Description NOT LIKE '%Trade%'
   AND P.Description NOT LIKE '%Invest%'
   AND P.Description NOT LIKE '%House%'
 GROUP BY MS.MembershipID,
       MR.ReimbursementProgramID

CREATE TABLE #ExpiredProgramMemberships 
       (ReimbursementProgramID INT,
       Attrition_12Month INT)
INSERT INTO #ExpiredProgramMemberships 
SELECT ReimbursementProgramID, 
       COUNT(MembershipID)
  FROM #ExpiredProgramMembershipsCalc
 GROUP BY ReimbursementProgramID
 ORDER BY ReimbursementProgramID

CREATE TABLE #Trailing12MonthAttritionData
       (ReimbursementProgramID INT,
       AverageMonthlyAccessMembershipCount DECIMAL(10,2),
       Attrition_12Month INT,
       MonthsOfMembershipBalanceHistory INT,
       Trailing12MonthAttrition DECIMAL(10,2))
INSERT INTO #Trailing12MonthAttritionData
SELECT AM.ReimbursementProgramID,
       AM.AverageMonthlyAccessMembershipCount, 
       EPM.Attrition_12Month,
       AM.MonthsOfMembershipBalanceHistory, 
       (EPM.Attrition_12Month/AM.AverageMonthlyAccessMembershipCount)
  FROM #AverageMemberships AM
  LEFT JOIN #ExpiredProgramMemberships EPM
    ON EPM.ReimbursementProgramID = AM.ReimbursementProgramID
 ORDER BY AM.ReimbursementProgramID

CREATE TABLE #ProgramMembershipCalc 
       (ReimbursementProgramID INT,
       ReimbursementProgramName VARCHAR(50),
       MembershipCount INT, 
       MemberCount INT,
       AccessMembershipFlag BIT, 
       TotalDues MONEY, 
       DuesPlusTax MONEY, 
       MonthYear VARCHAR(15))
INSERT INTO #ProgramMembershipCalc
SELECT RPPD.ReimbursementProgramID,
       RPPD.ReimbursementProgramName,
       COUNT(RPPD.MembershipID),
       SUM(RPPD.MemberCount),
       RPPD.AccessMembershipFlag,
       SUM(DuesPrice),
       SUM((DuesPrice+(DuesPrice*(SalesTaxPercentage/100)))),
       RPPD.MonthYear
  FROM ReimbursementProgramParticipationDetail RPPD
  JOIN #ReimbursementPrograms RP
    ON RP.ReimbursementProgramID = RPPD.ReimbursementProgramID
 WHERE YearMonth = @ReportYearMonth
 GROUP BY RPPD.ReimbursementProgramID,
       RPPD.ReimbursementProgramName,
       RPPD.AccessMembershipFlag, 
       RPPD.MonthYear
 ORDER BY RPPD.ReimbursementProgramName

CREATE TABLE #ProgramMembership 
       (ReimbursementProgramID INT,
       ReimbursementProgramName VARCHAR(50),
       TotalMemberships INT, 
       TotalIndividualMembers INT,
       TotalMembershipDuesNoTax MONEY, 
       TotalAccessMemberships INT, 
       TotalNonAccessMemberships INT,
       AccessMembershipDuesPlusTax MONEY,
       NonAccessMembershipDuesPlusTax MONEY,
       MonthYear VARCHAR(15))
INSERT INTO #ProgramMembership
SELECT ReimbursementProgramID,
       ReimbursementProgramName,
       SUM(MembershipCount),
       SUM(MemberCount),
       SUM(TotalDues), 
       SUM(CASE WHEN AccessMembershipFlag = 1
                THEN MembershipCount
                ELSE 0
           END),
       SUM(CASE WHEN AccessMembershipFlag = 0
                THEN MembershipCount
                ELSE 0
           END),
       SUM(CASE WHEN AccessMembershipFlag = 1
                THEN DuesPlusTax
                ELSE 0
           END),
       SUM(CASE WHEN AccessMembershipFlag = 0
                THEN DuesPlusTax
                ELSE 0
           END),
       MonthYear
  FROM #ProgramMembershipCalc 
 GROUP BY ReimbursementProgramID,
       ReimbursementProgramName,
       MonthYear

SELECT PM.ReimbursementProgramID,
       PM.ReimbursementProgramName,
       PM.TotalMemberships, 
       PM.TotalIndividualMembers,
       PM.TotalMembershipDuesNoTax * #PlanRate.PlanRate as TotalMembershipDuesNoTax, 
       PM.TotalMembershipDuesNoTax as LocalCurrency_TotalMembershipDuesNoTax, 
       PM.TotalMembershipDuesNoTax * #ToUSDPlanRate.PlanRate as USD_TotalMembershipDuesNoTax, 
       PM.TotalAccessMemberships, 
       PM.TotalNonAccessMemberships,
       PM.AccessMembershipDuesPlusTax * #PlanRate.PlanRate as AccessMembershipDuesPlusTax,
       PM.AccessMembershipDuesPlusTax as LocalCurrency_AccessMembershipDuesPlusTax,
       PM.AccessMembershipDuesPlusTax * #ToUSDPlanRate.PlanRate as USD_AccessMembershipDuesPlusTax,
       PM.NonAccessMembershipDuesPlusTax * #PlanRate.PlanRate as NonAccessMembershipDuesPlusTax,
       PM.NonAccessMembershipDuesPlusTax as LocalCurrency_NonAccessMembershipDuesPlusTax,
       PM.NonAccessMembershipDuesPlusTax * #ToUSDPlanRate.PlanRate as USD_NonAccessMembershipDuesPlusTax,
       PM.MonthYear,
       CASE WHEN TMA.Trailing12MonthAttrition IS NULL 
            THEN 0 
            ELSE TMA.Trailing12MonthAttrition 
       END Trailing12MonthAttrition,
/******  Foreign Currency Stuff  *********/
       VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
/***************************************/
       CO.CompanyName PartnerProgramCompanyName,
       CO.CorporateCode PartnerProgramCompanyCode
  FROM #ProgramMembership PM    
/********** Foreign Currency Stuff **********/
  JOIN vReimbursementProgram RP
    ON PM.ReimbursementProgramID = RP.ReimbursementProgramID
  JOIN #ReimbursementPrograms
    ON RP.ReimbursementProgramID = #ReimbursementPrograms.ReimbursementProgramID
  JOIN vMemberReimbursement MR
    ON RP.ReimbursementProgramID = MR.ReimbursementProgramID
  JOIN vMember M
    ON MR.MemberID = M.MemberID
  JOIN vMembership MS
    ON M.MembershipID = MS.MembershipID
  JOIN vClub C
    ON MS.ClubID = C.ClubID
  JOIN vValCurrencyCode VCC
    ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
    ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
   AND YEAR(GETDATE()) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
    ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
   AND YEAR(GETDATE()) = #ToUSDPlanRate.PlanYear
/*******************************************/    
  LEFT JOIN #Trailing12MonthAttritionData TMA
    ON PM.ReimbursementProgramID = TMA.ReimbursementProgramID
  LEFT JOIN vCompany CO
    ON RP.CompanyID = CO.CompanyID

GROUP BY PM.ReimbursementProgramID, PM.ReimbursementProgramName,PM.TotalMemberships,PM.TotalIndividualMembers,
PM.TotalMembershipDuesNoTax, PM.TotalAccessMemberships, PM.TotalNonAccessMemberships,PM.AccessMembershipDuesPlusTax, 
PM.NonAccessMembershipDuesPlusTax, PM.MonthYear, Trailing12MonthAttrition, VCC.CurrencyCode, #PlanRate.PlanRate,
#ToUSDPlanRate.PlanRate,CO.CompanyName,CO.CorporateCode

DROP TABLE #ExpiredProgramMembershipsCalc
DROP TABLE #ExpiredProgramMemberships
DROP TABLE #AverageMemberships
DROP TABLE #Trailing12MonthAttritionData
DROP TABLE #ProgramMembershipCalc
DROP TABLE #ProgramMembership
DROP TABLE #tmpList
DROP TABLE #ReimbursementPrograms
DROP TABLE #PlanRate
DROP TABLE #ToUSDPlanRate

-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END
