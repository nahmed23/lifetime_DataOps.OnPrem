



-- =============================================
-- Object:			dbo.mmsRecurringProductAudit
-- Author:			Greg Burdick
-- Create date: 	9/24/2007
-- Description:		This procedure is designed to provide output for the PT Recurrent Product
--					Audit report.
-- Modified date:	11/8/2007 GRB:	corrected object reference in GRANT EXECUTE code;
--					10/26/2007 GRB: product description instead of p.Name; make LastName and FirstName available for sorting w/in report
--									modified NumberOfMonths calc.
-- 	
---	Exec mmsRecurringProductAudit 'Apr 1, 2011', 'Apr 3, 2011', 141, 'all'
---	Select * from vMembershipRecurrentProduct ORDER BY ClubID
--
-- =============================================

CREATE         PROC [dbo].[mmsRecurringProductAudit] (
  @RecurrProdStartDate DATETIME,
  @RecurrProdEndDate DATETIME,
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

SELECT 
	C.ClubName, 
	D.Description DeptDescription, MRP.MembershipRecurrentProductID, 
	MRP.CreatedDateTime as CreatedDateTime_Sort, 
	Replace(SubString(Convert(Varchar, MRP.CreatedDateTime),1,3)+' '+LTRIM(SubString(Convert(Varchar, MRP.CreatedDateTime),5,DataLength(Convert(Varchar, MRP.CreatedDateTime))-12)),' '+Convert(Varchar,Year(MRP.CreatedDateTime)),', '+Convert(Varchar,Year(MRP.CreatedDateTime))) as CreatedDateTime,
	P.Name ProductName, P.Description ProductDesc, 
	CASE 	
		WHEN PkgMbr.MemberID IS NULL THEN  
			PrimaryMbr.FirstName + ' ' + PrimaryMbr.LastName
		Else PkgMbr.FirstName + ' ' + PkgMbr.LastName
	END MemberName,
	CASE 	
		WHEN PkgMbr.MemberID IS NULL THEN  
			PrimaryMbr.LastName
		Else PkgMbr.LastName
	END MemberLastName,
	CASE 	
		WHEN PkgMbr.MemberID IS NULL THEN  
			PrimaryMbr.FirstName
		Else PkgMbr.FirstName
	END MemberFirstName,
	CASE 	
		WHEN PkgMbr.MemberID IS NULL THEN  
			PrimaryMbr.MemberID
		Else PkgMbr.MemberID
	END MemberID,
	MRP.MembershipID, MRP.ActivationDate, 
	Replace(SubString(Convert(Varchar, MRP.ActivationDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MRP.ActivationDate),5,DataLength(Convert(Varchar, MRP.ActivationDate))-12)),' '+Convert(Varchar,Year(MRP.ActivationDate)),', '+Convert(Varchar,Year(MRP.ActivationDate))) as ActivationDate_Formatted,
	MRP.TerminationDate, 
	Replace(SubString(Convert(Varchar, MRP.TerminationDate),1,3)+' '+LTRIM(SubString(Convert(Varchar, MRP.TerminationDate),5,DataLength(Convert(Varchar, MRP.TerminationDate))-12)),' '+Convert(Varchar,Year(MRP.TerminationDate)),', '+Convert(Varchar,Year(MRP.TerminationDate))) as TerminationDate_Formatted,
--	count the number of product assessments: how many 1st of months between Activation and Termination?	
	CASE	
		WHEN MRP.TerminationDate <= MRP.ActivationDate THEN
			77.77
		WHEN DAY(MRP.ActivationDate) = 1 THEN
			DATEDIFF(m, MRP.ActivationDate, MRP.TerminationDate) + 1 
		ELSE DATEDIFF(m, MRP.ActivationDate, MRP.TerminationDate)
	END NumberOfMonths,
	E.FirstName, E.LastName,
	COALESCE(E.FirstName, '') + ' ' + COALESCE(E.LastName, '') Commission,
	MRP.NumberOfSessions, 
	MRP.PricePerSession * #PlanRate.PlanRate as PricePerSession,	  
	MRP.PricePerSession as LocalCurrency_PricePerSession,	  
	MRP.PricePerSession * #ToUSDPlanRate.PlanRate as USD_PricePerSession,
/******  Foreign Currency Stuff  *********/
	   VCC.CurrencyCode as LocalCurrencyCode,
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   MRP.Price * #PlanRate.PlanRate as Price,	  
	   MRP.Price as LocalCurrency_Price,	  
	   MRP.Price * #ToUSDPlanRate.PlanRate as USD_Price	     
/***************************************/

FROM vMembershipRecurrentProduct MRP
 JOIN vClub C ON MRP.ClubID=C.ClubID
 JOIN #Clubs #C ON C.ClubID = #C.ClubID
 LEFT OUTER JOIN vMember PkgMbr ON MRP.MemberID=PkgMbr.MemberID
 JOIN vMember PrimaryMbr ON MRP.MembershipID=PrimaryMbr.MembershipID
 LEFT OUTER JOIN vEmployee E ON  MRP.CommissionEmployeeID=E.EmployeeID
 JOIN vProduct P ON  MRP.ProductID=P.ProductID
 JOIN vDepartment D ON P.DepartmentID=D.DepartmentID
 JOIN #Dept #D ON (D.Description = #D.DeptName OR @Dept='All')
/********** Foreign Currency Stuff **********/
  JOIN vValCurrencyCode VCC
       ON C.ValCurrencyCodeID = VCC.ValCurrencyCodeID
  JOIN #PlanRate
       ON VCC.CurrencyCode = #PlanRate.FromCurrencyCode
      AND YEAR(MRP.CreatedDateTime) = #PlanRate.PlanYear
  JOIN #ToUSDPlanRate
       ON VCC.CurrencyCode = #ToUSDPlanRate.FromCurrencyCode
      AND YEAR(MRP.CreatedDateTime) = #ToUSDPlanRate.PlanYear
/*******************************************/
    
WHERE
PrimaryMbr.ValMemberTypeID = 1 AND
MRP.CreatedDateTime BETWEEN @RecurrProdStartDate AND @RecurrProdEndDate --AND
--C.ClubID=@ClubIDList AND
--(D.Name=@Dept OR @Dept='All')

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

