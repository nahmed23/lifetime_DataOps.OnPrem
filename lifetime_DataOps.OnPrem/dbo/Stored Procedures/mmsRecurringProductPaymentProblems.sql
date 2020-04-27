





-- =============================================
-- Author:		Greg Burdick
-- Create date: 10/2/2007 1617
-- Description:	This procedure is designed to provide output for the PT Recurrent Product
--				Payment Problems report.
-- =============================================

---
---	Exec mmsRecurringProductPaymentProblems '141', 'all'
---	Select * from vClub ORDER BY ClubName

CREATE           PROC [dbo].[mmsRecurringProductPaymentProblems] (
  @ClubIDList VARCHAR(1000),
  @Dept VARCHAR(1000)
)
AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON

--DECLARE @FirstDOM DATETIME
--SET @FirstDOM = CAST('01' + '/' + CAST(MONTH(Current_Timestamp) AS VARCHAR) + '/' + CAST(YEAR(Current_Timestamp) AS VARCHAR) AS DATETIME)

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  CREATE TABLE #tmpList (StringField VARCHAR(50))
  
  -- Parse the ClubIDs into a temp table
  EXEC procParseIntegerList @ClubIDList
  CREATE TABLE #Clubs (ClubID VARCHAR(50))
  INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList

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
WHERE ToCurrencyCode = @ReportingCurrencyCode

CREATE TABLE #ToUSDPlanRate (PlanRate DECIMAL(14,4), FromCurrencyCode VARCHAR(15), PlanYear INT)
INSERT INTO #ToUSDPlanRate
SELECT PlanExchangeRate, FromCurrencyCode, PlanYear
FROM PlanExchangeRate
WHERE ToCurrencyCode = 'USD'
/***************************************/

  -- Parse the Dept. Name into a temp table
  EXEC procParseStringList @Dept
  CREATE TABLE #Dept (DeptName VARCHAR(50))
  INSERT INTO #Dept (DeptName) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList

SELECT C.ClubName, D.Description DeptName, 
	P.Name ProductName,  
	PrimaryMbr.FirstName, PrimaryMbr.LastName,
	PrimaryMbr.LastName + ', ' + PrimaryMbr.FirstName PrimaryMbrName, 
	PrimaryMbr.MemberID,
	E.FirstName ComEmpFirstName,E.LastName ComEmpLastName,
	TI.TranItemID, 
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   TI.ItemAmount * #PlanRate.PlanRate as ItemAmount,	  
	   TI.ItemAmount as LocalCurrency_ItemAmount,	  
	   TI.ItemAmount * #ToUSDPlanRate.PlanRate as USD_ItemAmount,
	   MB.CommittedBalance * #PlanRate.PlanRate as CommittedBalance,	  
	   MB.CommittedBalance as LocalCurrency_CommittedBalance,	  
	   MB.CommittedBalance * #ToUSDPlanRate.PlanRate as USD_CommittedBalance	     
/***************************************/

FROM 
 vMMSTran MMST 
 JOIN vTranItem TI ON MMST.MMSTranID = TI.MMSTranID
 LEFT OUTER JOIN vSaleCommission SC ON TI.TranItemID = SC.TranItemID
 JOIN vClub C ON MMST.ClubID=C.ClubID
 JOIN #Clubs #C ON C.ClubID = #C.ClubID
 JOIN vMember PrimaryMbr ON MMST.MembershipID=PrimaryMbr.MembershipID
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MMST.TranDate) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(MMST.TranDate) = #ToUSDPlanRate.PlanYear
/*******************************************/
 LEFT OUTER JOIN vEmployee E ON  SC.EmployeeID=E.EmployeeID
 JOIN vProduct P ON TI.ProductID = P.ProductID
 JOIN vDepartment D ON P.DepartmentID = D.DepartmentID
 JOIN #Dept #D ON (D.Description = #D.DeptName OR @Dept='All')
 JOIN vMembershipBalance MB ON MMST.MembershipID = MB.MembershipID
    
WHERE
--		 MMST.MMSTranID IN 	
--		(SELECT MMST2.MMSTranID
--		 MMST.ClubID, MB.MembershipID, TI.ItemAmount, MB.CommittedBalance,
--		 P.ValRecurrentProductTypeID, MMST.ValTranTypeID,
--		 MMST.TranDate
--		FROM vTranItem TI
--		 JOIN vMMSTran MMST2 ON TI.MMSTranID = MMST.MMSTranID
--		 JOIN vProduct P ON TI.ProductID = P.ProductID
--		 JOIN vMembershipBalance MB ON MMST.MembershipID = MB.MembershipID
--		WHERE
--		 PrimaryMbr.MembershipID = MMST.MembershipID	
		 P.ValRecurrentProductTypeID NOT IN( 1,2) AND
		 MMST.ValTranTypeID = 1	AND
		 TI.ItemAmount > 0 AND	
		 (
			MONTH(MMST.TranDate) = MONTH(Current_Timestamp) AND
			YEAR(MMST.TranDate) = YEAR(Current_Timestamp)
		 ) AND
		 MB.CommittedBalance > 0	--	anytime during the month		 
	--	 ) 
		 AND PrimaryMbr.ValMemberTypeID = 1


ORDER BY C.ClubName, D.Description	--, P.Name, PrimaryMbr.LastName, PrimaryMbr.FirstName

  DROP TABLE #tmpList
  DROP TABLE #Clubs
  DROP TABLE #Dept
  DROP TABLE #PlanRate
  DROP TABLE #ToUSDPlanRate

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity


END

