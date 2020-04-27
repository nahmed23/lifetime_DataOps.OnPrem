
-- =============================================
-- Object:			dbo.mmsMipCategory
-- Author:			Greg Burdick
-- Create date: 	10/29/2008, releasing on 11/26/08 dbcr_3879a
-- Description:		This procedure counts member interests for specified club(s) and date range;
-- Modified date:	1/19/2009 GRB; rr361 changes deploying with dbcr_4067 on 1/21/2009
-- 	
-- Exec mmsMipCategory '10', '12/25/08', '12/25/08 11:59 AM'
-- =============================================

CREATE			PROC [dbo].[mmsMipCategory] 
(
	@ClubIDList VARCHAR(2000),
	@StartDate SMALLDATETIME,
	@EndDate SMALLDATETIME
)
AS
BEGIN
SET XACT_ABORT ON
SET NOCOUNT ON

-- Report Logging
DECLARE @Identity AS INT
INSERT INTO HyperionReportLog (SPName, StartDateTime) VALUES  (OBJECT_NAME(@@PROCID), getdate())
SET @Identity = @@IDENTITY

CREATE TABLE #tmpList (StringField Int)
CREATE TABLE #Clubs (ClubID Int)
IF @ClubIDList <> 'All'
	BEGIN
		EXEC procParseIntegerList @ClubIDList
		INSERT INTO #Clubs (ClubID) SELECT StringField FROM #tmpList
		TRUNCATE TABLE #tmpList
	END
ELSE
	BEGIN
		INSERT INTO #Clubs (ClubID) SELECT ClubID FROM dbo.vClub
	END

DECLARE @TotalMembers AS INT
SET @TotalMembers = (SELECT COUNT(DISTINCT vm.MemberID) TotalUniqueMembers	-- spec. #16
			FROM vMembership vms
				JOIN #Clubs tc ON vms.ClubID = tc.ClubID
				JOIN vMember vm ON vms.MembershipID = vm.MembershipID
			WHERE ValMembershipStatusID <> 1	-- non-terminated memberships only
				AND ActiveFlag = 1
				AND ValMemberTypeID <> 4	-- non-junior members only
			)


SELECT MMCI.MIPMemberCategoryItemID,MMCI.MemberID,MMCI.MIPCategoryItemID
INTO #MIPMemberCategoryItem
FROM vMIPMemberCategoryItem MMCI 
JOIN (
		SELECT MemberID
		FROM vMembership vms
			JOIN #Clubs tc ON vms.ClubID = tc.ClubID
			JOIN vMember vm ON vms.MembershipID = vm.MembershipID
		WHERE ValMembershipStatusID <> 1	-- non-terminated memberships only
			AND ActiveFlag = 1
			AND ValMemberTypeID <> 4		-- non-junior members only
			) a ON mmci.MemberID = a.MemberID
WHERE mmci.InsertedDateTime >= @StartDate AND mmci.InsertedDateTime <= @EndDate

SELECT vmc.Description [Web Category], 
	CONVERT(VARCHAR(50),vmi.Description) [Interest Area], 
--	mci.ValMIPInterestCategoryID,
--	mmci.InsertedDateTime,
	vmic.Description [Interest Category],
	COUNT(MIPMemberCategoryItemID) Count,
	MAX(@TotalMembers) TotalMembers
FROM vValMIPItem vmi
	LEFT JOIN vMIPCategoryItem mci ON vmi.ValMIPItemID = mci.ValMIPItemID
	LEFT JOIN vValMIPInterestCategory vmic ON mci.ValMIPInterestCategoryID = vmic.ValMIPInterestCategoryID
	LEFT JOIN  vValMIPCategory vmc ON mci.ValMIPCategoryID = vmc.ValMIPCategoryID
	LEFT JOIN #MIPMemberCategoryItem mmci ON mmci.MIPCategoryItemID = mci.MIPCategoryItemID
WHERE 
	 mci.ActiveFlag = 1					-- active interests only
GROUP BY vmc.Description, vmi.Description, vmic.Description--, mmci.InsertedDateTime
ORDER BY vmc.Description, vmi.Description, vmic.Description--, mmci.InsertedDateTime

DROP TABLE #tmpList
DROP TABLE #Clubs
DROP TABLE #MIPMemberCategoryItem
-- Report Logging
UPDATE HyperionReportLog
SET EndDateTime = getdate()
WHERE ReportLogID = @Identity

END
