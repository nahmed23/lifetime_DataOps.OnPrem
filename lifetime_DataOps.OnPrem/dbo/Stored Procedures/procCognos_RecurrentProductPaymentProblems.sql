/*
-- =============================================
	Exec procCognos_RecurrentProductPaymentProblems '151', 'all departments'
	Select * from vClub ORDER BY ClubName
*/

CREATE           PROC [dbo].[procCognos_RecurrentProductPaymentProblems] (
  @ClubIDList VARCHAR(1000),
  @DepartmentName VARCHAR(1000)
  
)
AS
BEGIN

SET XACT_ABORT ON
SET NOCOUNT ON

DECLARE @ReportRunDateTime VARCHAR(21) 
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')


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

/***************************************/

  -- Parse the Dept. Name into a temp table
CREATE TABLE #Dept (DeptName VARCHAR(50))
IF @DepartmentName <> 'All Departments'
 BEGIN 
  EXEC procParseStringList @DepartmentName
  INSERT INTO #Dept (DeptName) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList
 END
ELSE
 BEGIN
  INSERT INTO #Dept (DeptName) SELECT Description FROM vDepartment
 END


SELECT 
	C.ClubName, 
	D.Description DeptName, 
	P.Description ProductName,  
	PrimaryMbr.FirstName, PrimaryMbr.LastName,
	PrimaryMbr.FirstName + ', ' + PrimaryMbr.LastName AS PrimaryMbrName, 
	PrimaryMbr.MemberID,
	E.FirstName ComEmpFirstName,
	E.LastName ComEmpLastName,
	TI.TranItemID, 
/******  Foreign Currency Stuff  *********/
       #PlanRate.PlanRate,
       @ReportingCurrencyCode as ReportingCurrencyCode,
	   TI.ItemAmount * #PlanRate.PlanRate as ItemAmount,	  
	   MB.CommittedBalance * #PlanRate.PlanRate as CommittedBalance,
/***************************************/
	@ReportRunDateTime AS ReportRunDateTime	

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
/*******************************************/
 LEFT OUTER JOIN vEmployee E ON  SC.EmployeeID=E.EmployeeID
 JOIN vProduct P ON TI.ProductID = P.ProductID
 JOIN vDepartment D ON P.DepartmentID = D.DepartmentID
 JOIN #Dept #D ON D.Description = #D.DeptName --OR @DepartmentName='All Departments')
 JOIN vMembershipBalance MB ON MMST.MembershipID = MB.MembershipID
    
WHERE	
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

END

