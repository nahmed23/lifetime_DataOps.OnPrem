












--
-- Returns a set of tran records for the Revenuerpt
-- 
-- Parameters include a date range and three | separated lists one Clubs, Departments, ProductIDs
--
-- This proc adds 1 minute to the endpostdate to include records within the last minute
--
-- EXEC dbo.mmsRevenuerpt_Revenue '10/1/05', '10/26/05', 'All', 'Merchandise|Personal Training|Nutrition Coaching|Group Fitness',86

CREATE                PROC dbo.mmsRevenuerpt_Revenue_oldnew (
  @StartPostDate SMALLDATETIME,
  @EndPostDate SMALLDATETIME,
  @ClubList VARCHAR(8000),
  @DepartmentList VARCHAR(8000),
  @ProductIDList VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

  DECLARE @AdjustedEndPostDate AS SMALLDATETIME
  DECLARE @StartDate AS DATETIME
  DECLARE @EndDate AS DATETIME

  SET @StartDate = CONVERT(DATETIME,CONVERT(VARCHAR,DATEADD(m,-1, GETDATE() - DAY(GETDATE()-1)),110),110)
  SET @EndDate = CONVERT(DATETIME,CONVERT(VARCHAR,GETDATE(),110),110)

  SET @AdjustedEndPostDate = DATEADD(mi, 1, @EndPostDate)

-- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

  CREATE TABLE #tmpList (StringField VARCHAR(50))
  CREATE TABLE #Clubs (ClubName VARCHAR(50))
  IF @ClubList <> 'All'
    BEGIN
      EXEC procParseStringList @ClubList
      INSERT INTO #Clubs (ClubName) SELECT StringField FROM #tmpList
      TRUNCATE TABLE #tmpList
    END
  ELSE
    BEGIN
      INSERT INTO #Clubs (ClubName) SELECT ClubName FROM dbo.vClub
    END
-----
  --drop table #Clubs_Sel
  CREATE TABLE #Clubs_Sel (ClubID int, ClubName varchar(50), ValRegionID tinyint, DisplayUIFlag bit)

  INSERT INTO #Clubs_Sel (ClubID,ClubName,ValRegionID,DisplayUIFlag) 
	SELECT C.ClubID, C.ClubName, C.ValRegionID, C.DisplayUIFlag FROM dbo.vClub C JOIN #Clubs CI ON C.ClubName = CI.ClubName
---
  CREATE TABLE #Departments (Department VARCHAR(50))
  IF @DepartmentList <> 'All'
    BEGIN  
      EXEC procParseStringList @DepartmentList
      INSERT INTO #Departments (Department) SELECT StringField FROM #tmpList
      TRUNCATE TABLE #tmpList
    END
  ELSE
    BEGIN
      INSERT INTO #Departments (Department) SELECT Description FROM dbo.vDepartment
    END

  CREATE TABLE #Products (Product INT)
   IF @ProductIDList <> 'All'
     BEGIN
       EXEC procParseIntegerList @ProductIDList
       INSERT INTO #Products(Product)SELECT StringField FROM #tmpList
       TRUNCATE TABLE #tmpList
     END
    ELSE
     BEGIN
      INSERT INTO #Products VALUES(0)
     END

  IF @StartPostDate >= @StartDate
     AND @EndPostDate < @EndDate
  BEGIN
          SELECT PostingClubName, ItemAmount, DeptDescription, ProductDescription, MembershipClubname,
                 PostingClubid, DrawerActivityID, PostDateTime, TranDate, TranTypeDescription, ValTranTypeID,
                 MemberID, ItemSalesTax, EmployeeID, PostingRegionDescription, MemberFirstname, MemberLastname,
                 EmployeeFirstname, EmployeeLastname, ReasonCodeDescription, TranItemID, TranMemberJoinDate,
                 MMSR.MembershipID, ProductID, TranClubid, Quantity, @StartPostDate AS ReportStartDate,
                 @EndPostDate AS ReportEndDate, CO.CompanyName, CO.CorporateCode
          FROM vMMSRevenueReportSummary MMSR
               JOIN #Clubs CS
                 ON MMSR.PostingClubName = CS.ClubName
               JOIN #Departments DS
                 ON MMSR.DeptDescription = DS.Department
               JOIN #Products PS
                 ON (MMSR.ProductID = PS.Product OR PS.Product = 0)
 	       JOIN dbo.vMembership MS 
		 ON MS.MembershipID = MMSR.MembershipID
 	       LEFT JOIN dbo.vCompany CO 
                 ON CO.CompanyID = MS.CompanyID
          WHERE MMSR.PostDateTime >= @StartPostDate AND
                MMSR.PostDateTime < @AdjustedEndPostdate 
  END
  ELSE
  BEGIN
          SELECT C2.ClubName PostingClubName, TI.ItemAmount, D.Description DeptDescription,
                 P.Description ProductDescription, C.ClubName MembershipClubname, MMST.ClubID PostingClubid,
                 MMST.DrawerActivityID, MMST.PostDateTime, MMST.TranDate,
                 VTT.Description TranTypeDescription, MMST.ValTranTypeID, MMST.MemberID,
                 TI.ItemSalesTax, MMST.EmployeeID, VR.Description PostingRegionDescription,
                 M.FirstName MemberFirstname, M.LastName MemberLastname, E.FirstName EmployeeFirstname,
                 E.LastName EmployeeLastname, RC.Description ReasonCodeDescription, TI.TranItemID,
                 M.JoinDate TranMemberJoinDate, MMST.MembershipID, P.ProductID, MMST.ClubID TranClubid, TI.Quantity,
                 @StartPostDate AS ReportStartDate,@EndPostDate AS ReportEndDate, CO.CompanyName, CO.CorporateCode
          FROM dbo.vMMSTran MMST
                JOIN #Clubs_Sel C2 
                   ON C2.ClubID = MMST.ClubID  
--                JOIN dbo.vClub C2 
--                   ON C2.ClubID = MMST.ClubID  
--                JOIN #Clubs CI
--                    ON C2.ClubName = CI.ClubName
               JOIN dbo.vValRegion VR
                 ON C2.ValRegionID = VR.ValRegionID
               JOIN dbo.vTranItem TI
                 ON TI.MMSTranID = MMST.MMSTranID
               JOIN dbo.vProduct P
                 ON P.ProductID = TI.ProductID
                JOIN #Products PS
                  ----ON P.ProductID = PS.Product
                  ON (P.ProductID = PS.Product OR PS.Product = 0)
               JOIN dbo.vDepartment D
                 ON D.DepartmentID = P.DepartmentID
               JOIN #Departments DS
                 ON D.Description = DS.Department
               JOIN dbo.vMembership MS
                 ON MS.MembershipID = MMST.MembershipID
               JOIN dbo.vClub C
                 ON MS.ClubID = C.ClubID
               JOIN dbo.vValTranType VTT
                 ON MMST.ValTranTypeID = VTT.ValTranTypeID
               JOIN dbo.vMember M
                 ON M.MemberID = MMST.MemberID
               JOIN dbo.vReasonCode RC
                 ON RC.ReasonCodeID = MMST.ReasonCodeID
               LEFT OUTER JOIN dbo.vEmployee E 
                 ON E.EmployeeID = MMST.EmployeeID
  	       LEFT JOIN dbo.vCompany CO 
                 ON CO.CompanyID = MS.CompanyID
         WHERE MMST.PostDateTime >= @StartPostDate AND
                MMST.PostDateTime < @AdjustedEndPostdate AND
                MMST.TranVoidedID IS NULL AND
                VTT.ValTranTypeID IN (1, 3, 4, 5) AND
                C2.DisplayUIFlag = 1



--           UNION ALL
-- 
-- 	  SELECT C2.ClubName PostingClubName, TI.ItemAmount, D.Description DeptDescription,
-- 	         P.Description ProductDescription, C2.ClubName MembershipClubname, C2.ClubID PostingClubid, MMST.DrawerActivityID,
-- 	         MMST.PostDateTime, MMST.TranDate, VTT.Description TranTypeDescription,
-- 	         MMST.ValTranTypeID, M.MemberID, TI.ItemSalesTax, MMST.EmployeeID,
-- 	         VR.Description PostingRegionDescription, M.FirstName MemberFirstname, M.LastName MemberLastname,
-- 	         E.FirstName EmployeeFirstname, E.LastName EmployeeLastname, RC.Description ReasonCodeDescription,
-- 	         TI.TranItemID, M.JoinDate TranMemberJoinDate, MMST.MembershipID,
-- 	         P.ProductID, MMST.ClubID TranClubid, TI.Quantity,@StartPostDate AS ReportStartDate,@EndPostDate AS ReportEndDate, CO.CompanyName, CO.CorporateCode
-- 	  FROM dbo.vMMSTran MMST
-- 	       JOIN dbo.vClub C
-- 	         ON C.ClubID = MMST.ClubID
-- 	       JOIN dbo.vTranItem TI
-- 	         ON TI.MMSTranID = MMST.MMSTranID
-- 	       JOIN dbo.vProduct P
-- 	         ON P.ProductID = TI.ProductID
--                JOIN #Products PS
--                  ON (P.ProductID = PS.Product OR PS.Product = 0)
-- 	       JOIN dbo.vDepartment D
--                  ON D.DepartmentID = P.DepartmentID
-- 	       JOIN dbo.vMembership MS
-- 	         ON MS.MembershipID = MMST.MembershipID
-- 	       JOIN dbo.vClub C2
-- 	         ON MS.ClubID = C2.ClubID
-- 	       JOIN dbo.vValRegion VR
-- 	         ON C2.ValRegionID = VR.ValRegionID
-- 	       JOIN dbo.vValTranType VTT
-- 	         ON MMST.ValTranTypeID = VTT.ValTranTypeID
-- 	       JOIN dbo.vMember M
-- 	         ON M.MemberID = MMST.MemberID
-- 	       JOIN dbo.vReasonCode RC
-- 	         ON RC.ReasonCodeID = MMST.ReasonCodeID
-- 	       LEFT OUTER JOIN dbo.vEmployee E
-- 	         ON E.EmployeeID = MMST.EmployeeID
--  	       LEFT JOIN dbo.vCompany CO 
--                  ON CO.CompanyID = MS.CompanyID
-- 		
-- 	  WHERE C2.ClubName IN (SELECT ClubName FROM #Clubs) AND
-- 	      D.Description IN (SELECT Department FROM #Departments) AND
--               ----P.ProductID IN (SELECT Product FROM #Products) AND
-- 	      C.ClubID = 13 AND
-- 	      MMST.PostDateTime >= @StartPostDate AND
-- 	      MMST.PostDateTime < @AdjustedEndPostDate AND
-- 	      VTT.ValTranTypeID IN (1, 3, 4, 5) AND
-- 	      MMST.TranVoidedID IS NULL

  END

  DROP TABLE #Clubs
  DROP TABLE #Departments
  DROP TABLE #Products
  DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END












