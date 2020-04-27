


-- Find employee position, role, security group by club, 
-- sec group, pos, or emp ID
-- parameters : ClubID, Security Group, Position, Employee ID
-- EXEC dbo.mmsEmpPosSec_PosSecGroup 'All', 'All', 'All', 'All'
-- EXEC dbo.mmsEmpPosSec_PosSecGroup 'Apple Valley, MN', 'All', 'All', 'All'

CREATE    PROC dbo.mmsEmpPosSec_PosSecGroup (
  @ClubIDList VARCHAR(2000),
  @PositionIDList VARCHAR(2000),
  @SecGroupList VARCHAR(1000),
  @EmployeeID VARCHAR(1000)
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
CREATE TABLE #Clubs (ClubID VARCHAR(50))
       IF @ClubIDList <> 'All'
BEGIN
   --INSERT INTO #Clubs EXEC procParseStringList @ClubList
   EXEC procParseStringList @ClubIDList
   INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList
END
ELSE
BEGIN
  INSERT INTO #Clubs VALUES('All')
END
CREATE TABLE #Position (EmployeeRoleID VARCHAR(50))
       IF @PositionIDList <> 'All'
       BEGIN
           --INSERT INTO #Position EXEC procParseStringList @PositionList
           EXEC procParseStringList @PositionIDList
           INSERT INTO #Position (EmployeeRoleID) SELECT StringField FROM #tmpList
           TRUNCATE TABLE #tmpList
       END
	ELSE
	BEGIN
	  INSERT INTO #Position VALUES('All')
	END
CREATE TABLE #SecGroup (Description VARCHAR(50))
       IF @SecGroupList <> 'All'
       BEGIN
           --INSERT INTO #SecGroup EXEC procParseStringList @SecGroupList
           EXEC procParseStringList @SecGroupList
           INSERT INTO #SecGroup (Description) SELECT StringField FROM #tmpList
           TRUNCATE TABLE #tmpList
       END
	ELSE
	BEGIN
	  INSERT INTO #SecGroup VALUES('All')
	END
CREATE TABLE #EmployeeID (EmployeeID VARCHAR(50))
       IF @EmployeeID <> 'All'
       BEGIN
           --INSERT INTO #EmployeeID EXEC procParseStringList @EmployeeID    
           EXEC procParseStringList @EmployeeID
           INSERT INTO #EmployeeID (EmployeeID) SELECT StringField FROM #tmpList
           TRUNCATE TABLE #tmpList
       END
	ELSE
	BEGIN
	  INSERT INTO #EmployeeID VALUES('All')
	END

SELECT C.ClubName, E.EmployeeID, E.FirstName,
       E.LastName, VER.LTUPositionID, 
       VER.Description AS PositionDescription,
       SGER.ValSecurityGroupID, 
       VSG.Description AS SecurityGroupDescription
  FROM dbo.vEmployee E 
  JOIN #EmployeeID EI
       ON Cast(E.EmployeeID as VarChar(50)) = EI.EmployeeID OR EI.EmployeeID = 'All'
  JOIN dbo.vEmployeeRole ER
       ON E.EmployeeID = ER.EmployeeID
  JOIN dbo.vValEmployeeRole VER
       ON ER.ValEmployeeRoleID = VER.ValEmployeeRoleID   
  JOIN #Position P
	ON Cast(VER.ValEmployeeRoleID as VarChar(50)) = P.EmployeeRoleID OR P.EmployeeRoleID = 'All'
--       ON VER.Description = P.Description OR P.Description = 'All'
  JOIN dbo.vClub C
       ON E.ClubID = C.ClubID
  JOIN #Clubs CS
       ON Cast(C.ClubID as VarChar(50)) = CS.ClubID OR CS.ClubID = 'All'
  LEFT JOIN dbo.vSecurityGroupEmployeeRole SGER
       ON (VER.ValEmployeeRoleID = SGER.ValEmployeeRoleID)
  LEFT JOIN dbo.vValSecurityGroup VSG
       ON (SGER.ValSecurityGroupID = VSG.ValSecurityGroupID) 
 WHERE --(C.ClubName IN (SELECT ClubName FROM #Clubs) OR
       --@ClubList = 'All') AND
       --(VER.Description IN (SELECT Description FROM #Position) OR
       --@PositionList = 'All') AND
       (VSG.Description IN (SELECT Description FROM #SecGroup) OR
       @SecGroupList = 'All') AND
       --(E.EmployeeID IN (SELECT EmployeeID FROM #EmployeeID) OR
       --@EmployeeID = 'All') AND
       E.ActiveStatusFlag = 1
       
DROP TABLE #Clubs
DROP TABLE #Position
DROP TABLE #SecGroup
DROP TABLE #EmployeeID
DROP TABLE #tmpList

-- Report Logging
  UPDATE HyperionReportLog
  SET EndDateTime = getdate()
  WHERE ReportLogID = @Identity

END



