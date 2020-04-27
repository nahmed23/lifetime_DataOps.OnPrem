


CREATE     PROC dbo.mmsTranddt_Trandt_TopTrainersAdHoc(
            @ClubList VARCHAR(1000),
            @StartDate SMALLDATETIME,
            @EndDate SMALLDATETIME,
            @EmployeeList VARCHAR(1000),
            @TranTypeList VARCHAR(1000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

 -- Report Logging
  DECLARE @Identity AS INT
  INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
  SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Clubs (ClubName VARCHAR(50))
       IF @ClubList <> 'All'
       BEGIN
           --INSERT INTO #Club EXEC procParseStringList @ClubList
         EXEC procParseStringList @ClubList
         INSERT INTO #Clubs (ClubName) SELECT StringField FROM #tmpList
         TRUNCATE TABLE #tmpList
       END
CREATE TABLE #Employee (EmployeeID VARCHAR(50))
       IF @EmployeeList <> 'All'
       BEGIN
           --INSERT INTO #Employee EXEC procParseStringList @EmployeeList
         EXEC procParseStringList @EmployeeList
         INSERT INTO #Employee (EmployeeID) SELECT StringField FROM #tmpList
         TRUNCATE TABLE #tmpList
       END
CREATE TABLE #TranType (Description VARCHAR(50))
       IF @TranTypeList <> 'All'
       BEGIN
           --INSERT INTO #TranType EXEC procParseStringList @TranTypeList
         EXEC procParseStringList @TranTypeList
         INSERT INTO #TranType (Description) SELECT StringField FROM #tmpList
         TRUNCATE TABLE #tmpList
       END
         ELSE
   INSERT INTO #TranType SELECT Description FROM dbo.Vvaltrantype

SELECT VR1.Description AS Region, 
       C1.ClubName, 
       VTT.Description AS TranType,
       E.FirstName AS EmployeeFirstName, E.LastName AS EmployeeLastName, 
       M.FirstName AS MemberFirstName, M.LastName AS MemberLastName,
       MMST.MemberID, MMST.TranAmount,
       MMST.TranDate, MMST.PostDateTime AS Postdate, P.DepartmentID,
       MMST.MMSTranID, TI.ItemAmount, TI.ItemSalesTax,
       MMST.POSAmount, MMST.TranVoidedID, TI.TranItemID,
       VR2.Description AS MembershipRegion, 
       C2.ClubName AS MembershipClub, MMST.ClubID,
       VR1.Description AS TranRegionDescription, 
       P.Description AS ProductDescription, 
       MMST.DrawerActivityID,
       D.Description AS DeptDescription, RC.Description AS ReasonDescription
  FROM dbo.vClub C1
  JOIN dbo.vMMSTran MMST
       ON C1.ClubID = MMST.ClubID
  JOIN dbo.vValRegion VR1
       ON VR1.ValRegionID = C1.ValRegionID
  JOIN dbo.vMember M
       ON M.MemberID = MMST.MemberID
  JOIN dbo.vValTranType VTT
       ON VTT.ValTranTypeID = MMST.ValTranTypeID
  JOIN dbo.vMembership MS
       ON MMST.MembershipID = MS.MembershipID
  JOIN dbo.vClub C2
       ON MS.ClubID = C2.ClubID
  JOIN dbo.vValRegion VR2
       ON C2.ValRegionID = VR2.ValRegionID
  JOIN dbo.vEmployee E
       ON (E.EmployeeID = MMST.EmployeeID)
  JOIN dbo.vTranItem TI
       ON (MMST.MMSTranID = TI.MMSTranID)
  JOIN dbo.vProduct P
       ON (TI.ProductID = P.ProductID)
  JOIN dbo.vDepartment D
       ON (P.DepartmentID = D.DepartmentID) 
  JOIN vReasonCode RC
       ON MMST.ReasonCodeID = RC.ReasonCodeID
 WHERE VTT.Description IN (SELECT Description FROM #TranType) AND
       (C1.ClubName IN (SELECT ClubName FROM #Clubs) OR
       @ClubList = 'All') AND
       MMST.PostDateTime BETWEEN @StartDate AND @EndDate AND
       (E.EmployeeID IN (SELECT EmployeeID FROM #Employee) OR
       @EmployeeList = 'All')
       AND D.DepartmentID in(7,9,10,19)

UNION ALL

SELECT VR2.Description AS Region, 
       C2.ClubName, 
       VTT.Description AS TranType,
       E.FirstName AS EmployeeFirstName, E.LastName AS EmployeeLastName, 
       M.FirstName AS MemberFirstName, M.LastName AS MemberLastName,
       M.MemberID, MMST.TranAmount,
       MMST.TranDate, MMST.PostDateTime AS Postdate, D.DepartmentID,
       MMST.MMSTranID, TI.ItemAmount, TI.ItemSalesTax,
       MMST.POSAmount, MMST.TranVoidedID, TI.TranItemID,
       VR2.Description AS MembershipRegion, 
       C2.ClubName AS MembershipClub, C1.ClubID,
       VR1.Description AS TranRegionDescription, 
       P.Description AS ProductDescription, 
       MMST.DrawerActivityID,
       D.Description AS DeptDescription, RC.Description AS ReasonDescription
  FROM dbo.vClub C1
  JOIN dbo.vMMSTran MMST
       ON C1.ClubID = MMST.ClubID
  JOIN dbo.vValRegion VR1
       ON VR1.ValRegionID = C1.ValRegionID
  JOIN dbo.vMember M
       ON M.MemberID = MMST.MemberID
  JOIN dbo.vValTranType VTT
       ON VTT.ValTranTypeID = MMST.ValTranTypeID
  JOIN dbo.vMembership MS
       ON MMST.MembershipID = MS.MembershipID
  JOIN dbo.vClub C2
       ON MS.ClubID = C2.ClubID
  JOIN dbo.vValRegion VR2
       ON C2.ValRegionID = VR2.ValRegionID
  JOIN dbo.vEmployee E
       ON (E.EmployeeID = MMST.EmployeeID)
  JOIN dbo.vTranItem TI
       ON (MMST.MMSTranID = TI.MMSTranID)
  JOIN dbo.vProduct P
       ON (TI.ProductID = P.ProductID)
  JOIN dbo.vDepartment D
       ON (P.DepartmentID = D.DepartmentID)
  JOIN vReasonCode RC
       ON MMST.ReasonCodeID = RC.ReasonCodeID 
 WHERE MMST.ClubID = 13 AND
       (C2.ClubName IN (SELECT ClubName FROM #Clubs) OR
       @ClubList = 'All') AND
       VTT.Description IN (SELECT Description FROM #TranType) AND
       MMST.PostDateTime BETWEEN @StartDate AND @EndDate AND
       (E.EmployeeID IN (SELECT EmployeeID FROM #Employee) OR
       @EmployeeList = 'All')
       AND D.DepartmentID in(7,9,10,19)

DROP TABLE #Clubs
DROP TABLE #Employee
DROP TABLE #TranType
DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END









