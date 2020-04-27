
/*
     updated stored proceudre to display memberships that changed status from 
	 a Pending Terminated or Terminated status with an NPT termination reason code to Active, Late Activation, 
	 Non-Paid, Suspended, or Non-Paid, Late Activation. 
*/
-- exec procCognos_NPTChanges '14|151|8|', '4/1/14' , '4/11/14'



CREATE PROC [dbo].[procCognos_NPTChanges](
       @ClubIDList VARCHAR(8000),
       @StartDate DATETIME,
       @EndDate DATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON


DECLARE @HeaderDateRange VARCHAR(33), @ReportRunDateTime VARCHAR(21) 
SET @HeaderDateRange = convert(varchar(12), @StartDate, 107) + ' to ' + convert(varchar(12), @EndDate, 107)
SET @ReportRunDateTime = Replace(Substring(convert(varchar,getdate(),100),1,6)+', '+Substring(convert(varchar,GETDATE(),100),8,10)+' '+Substring(convert(varchar,getdate(),100),18,2),'  ',' ')


-- SELECTED CLUBS
CREATE TABLE #tmpList (StringField VARCHAR(20))
CREATE TABLE #Clubs (ClubID INT)
  EXEC procParseIntegerList @ClubIDList
  INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
  TRUNCATE TABLE #tmpList
  
  

-- Payments / Adjustments
CREATE TABLE #PaymentsAdjustments  (
MemberID INT,  
MembershipHomeClub VARCHAR(60), 
FirstName VARCHAR(50), 
LastName VARCHAR(50), 
Payment VARCHAR(1), 
Adjustment  VARCHAR(1), 
MembershipStatus  VARCHAR(1))

-- Membership Status table
CREATE TABLE #MembershipStatus  (
MemberID INT,  
MembershipHomeClub VARCHAR(60), 
FirstName VARCHAR(50), 
LastName VARCHAR(50), 
Payment VARCHAR(1), 
Adjustment  VARCHAR(1), 
MembershipStatus  VARCHAR(1))


INSERT INTO #PaymentsAdjustments
-- payments and adjustments
SELECT 
	M.MemberID AS MemberNumber, 
	max(MHC.ClubName) AS MembershipHomeClub,
	max(M.FirstName) AS FirstName, 
	max(M.LastName) As LastName, 
	max(CASE WHEN MMST.ValTranTypeID = 2
		THEN 'X' ELSE NULL END ) AS Payment,
	max(case when MMST.ValTranTypeID = 4
		THEN 'X' ELSE NULL END) AS Adjustment,
	--max(NULL) AS MembershipStatus
	NULL AS MembershipStatus
FROM vMembership MS
INNER JOIN vValTerminationReason VTR
	ON VTR.ValTerminationReasonID = MS.ValTerminationReasonID 
INNER JOIN vValMembershipStatus VMS
	ON VMS.ValMembershipStatusID = MS.ValMembershipStatusID 
INNER JOIN vMember M
	ON M.MembershipID = MS.MembershipID
	AND M.ValMemberTypeID = 1 -- primary member
INNER JOIN vClub MHC  -- membership's home club
	ON MHC.ClubID= MS.ClubID

-- list of Payment/Adjustment transactions 
INNER JOIN vMMSTran MMST
	ON MMST.MembershipID = MS.MembershipID
INNER JOIN vDrawerActivity DA
	ON MMST.DrawerActivityID = DA.DrawerActivityID
INNER JOIN vValDrawerStatus VDS 
	ON VDS.ValDrawerStatusID =  DA.ValDrawerStatusID  
	AND DA.ValDrawerStatusID = 3 -- closed drawer
INNER JOIN vValTranType VTT 
	ON VTT.ValTranTypeID = MMST.ValTranTypeID
	AND VTT.ValTranTypeID in (2, 4) -- 2 payment ; 4 adjustment
INNER JOIN #Clubs C 
	ON C.ClubID= MS.ClubID
WHERE 
	CONVERT(varchar(10), MMST.PostDateTime, 101) >= @StartDate 
	AND CONVERT(varchar(10), MMST.PostDateTime, 101) <=@EndDate
	AND MS.ValTerminationReasonID = 24 -- Non-Payment Terms 
	AND MS.ValMembershipStatusID IN (1,2) -- Terminated and Pending Termination
		
GROUP BY M.MemberID
ORDER BY M.MemberID 


-- Membership Status
INSERT INTO #MembershipStatus
SELECT 
	M.MemberID AS MemberNumber, 
	max(MHC.ClubName) AS MembershipHomeClub,
	max(M.FirstName) AS FirstName, 
	max(M.LastName) As LastName, 
	NULL AS Payment,
	NULL AS Adjustment,
	'X' AS MembershipStatus
FROM vMembership MS
INNER JOIN vMember M
	ON M.MembershipID = MS.MembershipID
	AND M.ValMemberTypeID = 1 -- primary member
INNER JOIN vClub MHC  -- membership's home club
	ON MHC.ClubID= MS.ClubID
INNER JOIN  vMembershipAudit MA 
    ON MA.Rowid = MS.MembershipID
INNER JOIN #Clubs C 
	ON C.ClubID= MS.ClubID
WHERE
	CONVERT(varchar(10), MA.ModifiedDateTime, 101) >= @StartDate 
	AND CONVERT(varchar(10), MA.ModifiedDateTime, 101) <=@EndDate
	-- Active, Late Activation, Non-Paid, Suspended, or Non-Paid, Late Activation
	AND MS.ValMembershipStatusID IN (3,4,5,6,7)
	-- NPT termination reason code
	and MA.ColumnName = 'ValTerminationReasonID'
	and MA.OldValue = 24 

GROUP BY M.MemberID
ORDER BY M.MemberID

SELECT 
	CASE WHEN tPA.MemberID IS NULL THEN tMS.MemberID ELSE tPA.MemberID END AS MemberID,
	CASE WHEN tPA.MembershipHomeClub IS NULL THEN tMS.MembershipHomeClub ELSE tPA.MembershipHomeClub END AS MembershipHomeClub, 
	CASE WHEN tPA.FirstName IS NULL THEN tMS.FirstName ELSE tPA.FirstName END AS FirstName,
	CASE WHEN tPA.LastName IS NULL THEN tMS.LastName ELSE tPA.LastName END AS LastName,
	CASE WHEN tPA.Payment IS NULL THEN tMS.Payment ELSE tPA.Payment END AS Payment,
	CASE WHEN tPA.Adjustment IS NULL THEN tMS.Adjustment ELSE tPA.Adjustment END AS Adjustment,
	CASE WHEN tPA.MembershipStatus IS NULL THEN tMS.MembershipStatus ELSE tPA.MembershipStatus END AS MembershipStatus,
	@HeaderDateRange AS HeaderDateRange,
    @ReportRunDateTime AS ReportRunDateTime

FROM #PaymentsAdjustments tPA
FULL OUTER JOIN #MembershipStatus tMS ON tMS.MemberID = tPA.memberID

DROP TABLE #Clubs
DROP TABLE #TmpList
DROP TABLE #MembershipStatus
DROP TABLE #PaymentsAdjustments

END


