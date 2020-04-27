


--
-- Returns a set of revenue tran records for the Life Studio DSSR report
-- 
-- Parameters include a preset "1st of Prior Month through yesterday's date" and
-- a preset list of departments for all clubs, also a list of club names or 'All'
--
--

CREATE                PROC dbo.mmsLS_DSSR_Revenue_MTD (
         @ClubList VARCHAR(8000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

  DECLARE @StartDate AS DATETIME
  DECLARE @EndDate AS DATETIME
  DECLARE @ReportDate AS DATETIME
  DECLARE @FirstOfPriorMonth AS DATETIME

  SET @StartDate = CONVERT(DATETIME,CONVERT(VARCHAR,(GETDATE() - DAY(GETDATE()-1)),110),110)
  SET @EndDate = CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE(),110),110)
  SET @ReportDate = CONVERT(DATETIME,CONVERT(VARCHAR,DATEADD(d,-1,GETDATE()),110),110)
  SET @FirstOfPriorMonth = DATEADD(m,-1,CONVERT(DATETIME,CONVERT(VARCHAR,(GETDATE() - DAY(GETDATE()-1)),110),110))

  CREATE TABLE #tmpList (StringField VARCHAR(50))

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY
  
   --- Parse the ClubIDs into a temp table
  EXEC procParseStringList @ClubList
  CREATE TABLE #Clubs (ClubName VARCHAR(50))
  INSERT INTO #Clubs (ClubName) SELECT StringField FROM #tmpList

  TRUNCATE TABLE #tmpList

  BEGIN
          SELECT PostingClubName, ItemAmount,DeptDescription, ProductDescription,MembershipClubname,
                 PostingClubid, DrawerActivityID, PostDateTime, TranDate, TranTypeDescription, ValTranTypeID, 
                 MemberID, ItemSalesTax, EmployeeID,PostingRegionDescription,MemberFirstname, MemberLastname,
                 EmployeeFirstname, EmployeeLastname,ReasonCodeDescription,TranItemID, TranMemberJoinDate, 
                 MembershipID, MMSR.ProductID,TranClubid, Quantity,@ReportDate AS ReportDate,
                 CASE
		 WHEN MMSR.PostDateTime >= @ReportDate
                      AND MMSR.PostDateTime < @EndDate
		 THEN 1
		 ELSE 0
	         END TodayFlag,
                 CASE
                 WHEN MMSR.PostDateTime < @StartDate
                 THEN 1
                 ELSE 0
                 END PriorMonthTransactionFlag,
                 P.PackageProductFlag
          FROM vMMSRevenueReportSummary MMSR
               JOIN #Clubs CS
                ON MMSR.PostingClubName = CS.ClubName
	         OR CS.ClubName = 'All'
               JOIN vProduct P
		ON P.ProductID = MMSR.ProductID
          WHERE MMSR.PostDateTime >= @FirstOfPriorMonth 
                AND MMSR.PostDateTime < @EndDate 
                AND MMSR.DeptDescription = 'Mind Body'
                    

END

DROP TABLE #Clubs
DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



