

-- =============================================
-- Object:			dbo.mmsRecurringProductPaymentProblems_RecentTransactionsOnly
-- Author:			Greg Burdick
-- Create date: 	10/26/2007
-- Description:		This procedure is designed to provide output for the PT Recurrent Product
--					Payment Problems report.
-- Last Modified date:	
-- 	
---	Exec mmsRecurringProductPaymentProblems_RecentTransactionsOnly '132', 'all'
---	Select * from vClub ORDER BY ClubName
--
-- =============================================

CREATE           PROC [dbo].[mmsRecurringProductPaymentProblems_RecentTransactionsOnly] (
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

  -- Parse the Dept. Name into a temp table
  EXEC procParseStringList @Dept
  CREATE TABLE #Dept (DeptName VARCHAR(50))
  INSERT INTO #Dept (DeptName) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList

SELECT MMSRRS.PostingClubName,
	MMSRRS.DeptDescription,
	P.Name ProductName, MMSRRS.ProductDescription, 
	PrimaryMbr.FirstName, MMSRRS.MemberFirstName,
	PrimaryMbr.LastName, MMSRRS.MemberLastName,
	PrimaryMbr.LastName + ', ' + PrimaryMbr.FirstName PrimaryMbrName,
	MMSRRS.MemberLastName + ', ' + MMSRRS.MemberFirstName PriMbrName, 
	PrimaryMbr.MemberID, MMSRRS.MemberID,
	E.FirstName ComEmpFirstName, MMSRRS.EmployeeFirstName,
	E.LastName ComEmpLastName, MMSRRS.EmployeeLastName,
	MMSRRS.TranItemID,
	MMSRRS.ItemAmount,
	MB.CommittedBalance

FROM 
dbo.MMSRevenueReportSummary MMSRRS
-- vMMSTran MMST 
-- JOIN vTranItem TI ON MMST.MMSTranID = TI.MMSTranID
-- LEFT OUTER JOIN vSaleCommission SC ON TI.TranItemID = SC.TranItemID
 LEFT OUTER JOIN vSaleCommission SC ON MMSRRS.TranItemID = SC.TranItemID 
--JOIN vClub C ON MMST.ClubID=C.ClubID
--JOIN vClub C ON MMSRRS.PostingClubId = C.ClubID 
 JOIN #Clubs #C ON MMSRRS.PostingClubId = #C.ClubID
 JOIN vMember PrimaryMbr ON MMSRRS.MembershipID=PrimaryMbr.MembershipID
 LEFT OUTER JOIN vEmployee E ON  SC.EmployeeID=E.EmployeeID
 JOIN vProduct P ON MMSRRS.ProductID = P.ProductID
-- JOIN vDepartment D ON P.DepartmentID = D.DepartmentID
 JOIN #Dept #D ON (D.Description = #D.DeptName OR @Dept='All')
 JOIN vMembershipBalance MB ON MMSRRS.MembershipID = MB.MembershipID
    
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
		 P.ValRecurrentProductTypeID = 3 AND
--		 MMST.ValTranTypeID = 1	AND
		 MMSRRS.ValTranTypeID = 1	AND

		 MMSRRS.ItemAmount > 0 AND	
		 (
			MONTH(MMSRRS.TranDate) = MONTH(Current_Timestamp) AND
			YEAR(MMSRRS.TranDate) = YEAR(Current_Timestamp)
		 ) AND
		 MB.CommittedBalance > 0	--	anytime during the month		 
	--	 ) 
		 AND PrimaryMbr.ValMemberTypeID = 1


ORDER BY C.ClubName, D.Description	--, P.Name, PrimaryMbr.LastName, PrimaryMbr.FirstName

  DROP TABLE #tmpList
  DROP TABLE #Clubs
  DROP TABLE #Dept

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity


END








