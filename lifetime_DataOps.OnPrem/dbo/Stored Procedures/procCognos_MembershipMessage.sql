

------ Sample execution
---- EXEC procCognos_MembershipMessage '14|8', 'Opened|Received', '01/1/2016', '01/31/2016', '0', 'N','All Types|See Message History for details.'
------

CREATE PROC [dbo].[procCognos_MembershipMessage] (
  @ClubIDList VARCHAR(1000),
  @MessageStatusList VARCHAR(4000),
  @OpenStartDate DATETIME,
  @OpenEndDate DATETIME,
  @EmployeeIDList VARCHAR(8000),
  @EmployeeOnlyFlag VARCHAR(10),
  @MessageTypeList VARCHAR(8000)
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON


DECLARE @HeaderDateRange VARCHAR(33), @ReportRunDateTime VARCHAR(21) 
SET @HeaderDateRange = convert(varchar(12), @OpenStartDate, 107) + ' to ' + convert(varchar(12), @OpenEndDate, 107)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')

IF @EmployeeOnlyFlag = 'Y' -- all clubs selected if report run for an employee; employee can enter messages for different clubs
   SET @ClubIDList = '0'

CREATE TABLE #tmpList (StringField VARCHAR(50))
CREATE TABLE #Clubs (ClubID INT)
  EXEC procParseIntegerList @ClubIDList
  INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList

  IF @ClubIDList = '0'
   BEGIN 
    TRUNCATE TABLE #Clubs  
    INSERT INTO #Clubs (ClubID) SELECT ClubID FROM vClub
   END  
  
CREATE TABLE #MessageStatus (Description VARCHAR(50))
   EXEC procParseStringList @MessageStatusList
   INSERT INTO #MessageStatus (Description) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList

CREATE TABLE #EmployeeIDs (EmployeeID INT)
   EXEC procParseIntegerList @EmployeeIDList
   INSERT INTO #EmployeeIDs (EmployeeID) SELECT StringField FROM #tmpList
   TRUNCATE TABLE #tmpList

CREATE TABLE #MessageTypes (Description VARCHAR(50))
  EXEC procParseStringList @MessageTypeList
  INSERT INTO #MessageTypes  (Description) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList

  IF @MessageTypeList like '%All Types%'
   BEGIN 
    TRUNCATE TABLE #MessageTypes  
    INSERT INTO #MessageTypes (Description) SELECT Description FROM vValMembershipMessageType
   END  

DECLARE @HeaderMessageTypeList VARCHAR(8000)
SET @HeaderMessageTypeList = CASE WHEN 'All Types' IN (SELECT item FROM fnParsePipeList(@MessageTypeList)) THEN 'All Message Types'
                                       ELSE REPLACE(@MessageTypeList,'|',', ') END

SELECT ValMembershipMessageTypeID
INTO #MessageTypeIDs
FROM #MessageTypes  MessageTypes
 JOIN vValMembershipMessageType VMT
  ON MessageTypes.Description = VMT.Description


SET @OpenEndDate = DATEADD (DD,1,@OpenEndDate)

SELECT 
       @HeaderDateRange AS HeaderDateRange,
       @ReportRunDateTime AS ReportRunDateTime,
	   C.ClubName, 
	   VR.Description RegionDescription,
	   VMS2.Description MessageStatusDescription, 
	   M.MemberID,
	   M.FirstName,
       M.LastName, 
       MSM.MembershipMessageID, 
       --MSM.OpenDateTime,
       CONVERT(VARCHAR, MSM.OpenDateTime, 1)+ ' ' +' ' +substring(convert(varchar,MSM.OpenDateTime,0),13,5)+' '+substring(convert(varchar,MSM.OpenDateTime,100),18,2)+ ' '+MSM.OpenDateTimeZone AS OpenDateTime,
       CONVERT(VARCHAR, MSM.ReceivedDateTime, 1)+ ' ' +' ' +substring(convert(varchar,MSM.ReceivedDateTime,0),13,5)+' '+substring(convert(varchar,MSM.ReceivedDateTime,100),18,2)+ ' '+MSM.ReceivedDateTimeZone AS ReceivedDateTime,
       CONVERT(VARCHAR, MSM.CloseDateTime, 1)+ ' ' +' ' +substring(convert(varchar,MSM.CloseDateTime,0),13,5)+' '+substring(convert(varchar,MSM.CloseDateTime,100),18,2)+ ' '+MSM.CloseDateTimeZone AS ClosedDateTime,               
       --MSM.Comment, -- see DisplayMessage=Substr ( LongMessage, 1, 100 ) report column for more details?? MSMT.Description MessageCodeDescription, 
       --MSMT.Description MessageCodeDescription, 
       SUBSTRING(
       CASE WHEN MSMT.Description = 'See Message History for converted message' 
			THEN MSM.Comment 
			ELSE MSMT.Description +' '+ MSM.Comment END,1,100) AS DisplayMessage,   
       
       MSMT.Description MessageTypeDescription,
       MSM.Comment,
       E.EmployeeID, E.FirstName EmployeeFirstname, E.LastName EmployeeLastname,
       
       MSM.OpenDateTime AS OpenDateTime_Sort,
       MSM.ReceivedDateTime AS ReceivedDateTime_Sort, 
       MSM.CloseDateTime AS CloseDateTime_Sort,
       CASE WHEN VMS2.Description = 'Opened'THEN 1
            WHEN VMS2.Description = 'Received' THEN 2 
            ELSE 3 END StatusSortOrder,
	   @HeaderMessageTypeList AS HeaderMessageTypeList
 
  FROM dbo.vMembershipMessage MSM
  JOIN dbo.vEmployee E
       ON MSM.OpenEmployeeID = E.EmployeeID
  JOIN #EmployeeIDs #E
       ON E.EmployeeID = #E.EmployeeID OR #E.EmployeeID = 0
  JOIN dbo.vValMessageStatus VMS2
       ON MSM.ValMessageStatusID = VMS2.ValMessageStatusID
  JOIN #MessageStatus MSS
       ON VMS2.Description = MSS.Description
  JOIN dbo.vMembership MS
       ON MSM.MembershipID = MS.MembershipID
  JOIN dbo.vClub C
       ON MS.ClubID = C.ClubID
  JOIN #Clubs CS
       ON C.ClubID = CS.ClubID
  JOIN dbo.vValRegion VR
       ON C.ValRegionID = VR.ValRegionID
  JOIN dbo.vMember M
       ON M.MembershipID = MS.MembershipID
  JOIN dbo.vValMembershipStatus VMS
       ON VMS.ValMembershipStatusID = MS.ValMembershipStatusID
  JOIN dbo.vValMembershipMessageType MSMT              ---------- changed to equal join since new parameter setting now forces it anyway
       ON (MSM.ValMembershipMessageTypeID = MSMT.ValMembershipMessageTypeID) 
  JOIN #MessageTypeIDs  MessageTypes
       ON MessageTypes.ValMembershipMessageTypeID = MSM.ValMembershipMessageTypeID
 WHERE M.ValMemberTypeID = 1 AND
       VMS.Description IN ('Active', 'Late Activation', 'Non-Paid', 'Non-Paid, Late Activation', 'Pending Termination', 'Suspended') AND
       MSM.OpenDateTime >= @OpenStartDate AND MSM.OpenDateTime < @OpenEndDate AND
       C.DisplayUIFlag = 1 
       --(E.EmployeeID = @EmployeeID OR @EmployeeID = 0) 
       
DROP TABLE #Clubs
DROP TABLE #MessageStatus
DROP TABLE #tmpList
DROP TABLE #EmployeeIDs
DROP TABLE #MessageTypes 
DROP TABLE #MessageTypeIDs

END



